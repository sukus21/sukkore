    IF !DEF(STRUCT_VQUEUE_INC)
    DEF STRUCT_VQUEUE_INC EQU 1

; Determines if set mode is enabled or not.
; Used on `VQUEUE_TYPE`.
DEF VQUEUEB_MODEFLAG EQU 7
DEF VQUEUEF_MODEFLAG EQU %10000000

; Enables set-mode.
; Data is not copied, but set to a single value.
; The value to set is stored at `VQUEUE_SOURCE_BANK`.
DEF VQUEUE_MODEFLAG_SETMODE EQU %10000000

; Enables copy-mode.
; In copy-mode, data is copied from source to destination.
; Source is a 3-byte pointer, the first reserved for ROM bank number.
DEF VQUEUE_MODEFLAG_COPYMODE EQU 0

RSRESET

; The number of slots in the VRAM transfer queue.
DEF VQUEUE_QUEUE_SIZE EQU 16

; Vqueue element not currently used.
DEF VQUEUE_TYPE_NONE RB 1

; Data transfer is direct, 1-to-1.
; Ideal for copying tiles.
; One transfer operation = 16 bytes.
DEF VQUEUE_TYPE_DIRECT RB 1

; Works with half a row at a time.
; Every 16 processed bytes, the destination pointer is moved 16 bytes forward.
; One transfer operation = 16 bytes.
DEF VQUEUE_TYPE_HALFROW RB 1

; Sets destination data in "columns".
; Places one source byte every 32 destination bytes.
; Makes best sense to use when copying vertical strips to tilemaps.
; One transfer operation = 1 column (32 bytes).
; When one column is done, move onto the next column.
DEF VQUEUE_TYPE_COLUMN RB 1

; Works with 20 bytes at a time.
; Every 20 processed bytes, the destination pointer is moved 12 bytes forward.
; One transfer operation = 20 bytes.
DEF VQUEUE_TYPE_SCREENROW RB 1

RSRESET

; Type of this vqueue element.
; Check `VQUEUE_TYPE_*` to see available types.
; If the highest bit is set, "set" mode is enabled.
DEF VQUEUE_TYPE RB 1

; Number of transfer operations to perform.
; Does not have to mean bytes.
DEF VQUEUE_LENGTH RB 1

; Number of transfer operations completed.
; When this number matches the length, the transfer is considered complete.
DEF VQUEUE_PROGRESS RB 1

; Pointer to destination data.
DEF VQUEUE_DESTINATION RB 2

; Source data ROM bank.
DEF VQUEUE_SOURCE_BANK RB 1

; Pointer to source data.
DEF VQUEUE_SOURCE RB 2

; Increments the value at this address when transfer is complete.
DEF VQUEUE_WRITEBACK RB 2

; A VRAM transfer queue object.
DEF VQUEUE_T RB 0



; Prepares a label to be copied.
; This macro expands to 10 bytes of data.
;
; Input:
; - `1`: Transfer type (`VQUEUE_TYPE_*`)
; - `2`: Transfer operation count (n8)
; - `3`: Destination (address/label)
; - `4`: Source (label)
; - `5*`: Writeback pointer (address/label, default: 0)
MACRO vqueue_prepare
    db \1           ;type
    db \2           ;transfer operation count
    db $00          ;progress
    dw \3           ;destination
    db bank(\4)     ;source bank
    dw \4           ;source
    IF _NARG == 5
        dw \5       ;writeback pointer
    ELSE
        dw $0000    ;writeback pointer
    ENDC
ENDM



; Prepares a label to be copied.
; Assumes the source label has an exported `.end` sublabel.
; Throws errors if data length is not divisible by \4.
; This macro expands to 10 bytes of data.
;
; Input:
; - `1`: Transfer type (`VQUEUE_TYPE_*`)
; - `2`: Destination (address/label)
; - `3`: Source (label)
; - `4*`: Writeback pointer (address/label, default: 0)
; - `5*`: Source divisible by (n8, default: 16)
MACRO vqueue_prepare_copy
    IF _NARG == 5
        ASSERT (\3.end - \3) % (\5) == 0
    ELSE
        ASSERT (\3.end - \3) % (16) == 0
    ENDC

    db \1 | VQUEUE_MODEFLAG_COPYMODE    ;type
    IF _NARG == 5
        db (\3.end - \3) / (\5)         ;transfer operation count
    ELSE
        db (\3.end - \3) / (16)         ;transfer operation count
    ENDC
    db $00                              ;progress
    dw \2                               ;destination
    db bank(\3)                         ;source bank
    dw \3                               ;source
    IF _NARG >= 4
        dw \4                           ;writeback pointer
    ELSE
        dw $0000                        ;writeback pointer
    ENDC
ENDM



; Prepares a vqueue transfer, that can be enqueued fast.
; Automatically appends the `SETMODE` flag.
; This macro expands to 10 bytes of data.
;
; Input:
; - `1`: Transfer type (`VQUEUE_TYPE_*`)
; - `2`: Transfer operation count (n8)
; - `3`: Destination (address/label)
; - `4`: Byte value (n8)
; - `5*`: Writeback pointer (address/label, default: 0)
MACRO vqueue_prepare_set
    db \1 | VQUEUE_MODEFLAG_SETMODE ;type
    db \2                           ;transfer operation count
    db $00                          ;progress
    dw \3                           ;destination
    db \4                           ;fill byte
    dw $0000                        ;source data (unused for SET mode)
    IF _NARG == 5
        dw \5                       ;writeback pointer
    ELSE
        dw $0000                    ;writeback pointer
    ENDC
ENDM



; This macro enqueues a prepared vqueue transfer automatically.  
; Use `vqueue_prepare` to prepare a transfer.  
; Switches banks.
;
; Input:
; - `1`: Prepared transfer (label)
;
; Destroys: `af`, `de`, `hl`
MACRO vqueue_enqueue_auto
    ld a, bank(\1)
    ld [rROMB0], a
    ld de, \1
    call vqueue_enqueue
ENDM



; Macro that adds an element to the VRAM transfer queue.
; Does not set writeback pointer.
;
; Input:
; - `1`: Transfer type (`VQUEUE_TYPE_*`)
; - `2`: Transfer operation count (n8)
; - `3`: Destination (address/label)
; - `4`: Source (label)
;
; Returns:
; - `hl`: `VQUEUE` pointer, at `VQUEUE_WRITEBACK`
;
; Destroys: `af`  
; Saves: `bc`, `de`
MACRO vqueue_add
    call vqueue_get

    ;Write type and length
    ld a, \1
    ld [hl+], a ;type
    ld a, \2
    ld [hl+], a ;length
    xor a
    ld [hl+], a ;progress

    ;Write destination
    ld a, low(\3)
    ld [hl+], a ;destination (low)
    ld a, high(\3)
    ld [hl+], a ;destination (high)
    
    ;Write source
    ld a, bank(\4)
    ld [hl+], a
    ld a, low(\4)
    ld [hl+], a
    ld a, high(\4)
    ld [hl+], a
ENDM



; Macro that adds a copy-mode transfer to the VRAM transfer queue.
; Assumes the source label has an exported `.end` sublabel.
; Throws errors if data length is not divisible by \4.
; Does not set writeback pointer.
;
; Input:
; - `1`: Transfer type (`VQUEUE_TYPE_*`)
; - `2`: Destination (address/label/r16)
; - `3`: Source (label)
; - `4*`: Source divisible by (default: 16)
;
; Returns:
; - `hl`: `VQUEUE` pointer, at `VQUEUE_WRITEBACK`
;
; Destroys: `af`  
; Saves: `bc`, `de`
MACRO vqueue_add_copy
    IF _NARG == 4
        ASSERT (\3.end - \3) % (\4) == 0
    ELSE
        ASSERT (\3.end - \3) % (16) == 0
    ENDC
    call vqueue_get

    ;Write type and length
    ld a, \1 | VQUEUE_MODEFLAG_COPYMODE
    ld [hl+], a ;type
    IF _NARG == 4
        ld a, (\3.end - \3) / (\4)
    ELSE
        ld a, (\3.end - \3) / (16)
    ENDC
    ld [hl+], a ;length
    xor a
    ld [hl+], a ;progress

    ;Write destination
    ld a, low(\2)
    ld [hl+], a ;destination (low)
    ld a, high(\2)
    ld [hl+], a ;destination (high)
    
    ;Write source
    ld a, bank(\3)
    ld [hl+], a
    ld a, low(\3)
    ld [hl+], a
    ld a, high(\3)
    ld [hl+], a
ENDM



; Macro that adds a set-mode transfer to the VRAM transfer queue.
; Does not set writeback pointer.
;
; Input:
; - `1`: Transfer type (`VQUEUE_TYPE_*`)
; - `2`: Transfer operation count (n8)
; - `3`: Destination (address/label)
; - `4`: Set value (n8)
;
; Returns:
; - `hl`: `VQUEUE` pointer, at `VQUEUE_WRITEBACK`
;
; Destroys: `af`  
; Saves: `bc`, `de`
MACRO vqueue_add_set
    call vqueue_get

    ;Write type and length
    ld a, \1 | VQUEUE_MODEFLAG_SETMODE
    ld [hl+], a ;type
    ld a, \2
    ld [hl+], a ;length
    xor a
    ld [hl+], a ;progress

    ;Write destination
    ld a, low(\3)
    ld [hl+], a ;destination (low)
    ld a, high(\3)
    ld [hl+], a ;destination (high)
    
    ;Write fill byte
    ld a, \4
    ld [hl+], a
    inc l
    inc l
ENDM



; Macro that adds a direct-type copy-mode transfer to the VRAM transfer queue.
; Assumes the source label has an exported `.end` sublabel.
;
; Input:
; - `1`: Transfer type (`VQUEUE_TYPE_*`)
; - `2`: Destination (address/label/r16)
; - `3`: Source (label)
; - `4*`: Writeback pointer (address/label/r16, default: 0)
;
; Destroys: `af`  
; Saves: `bc`, `de`, `hl`
MACRO vqueue_addw
    push hl
    vqueue_add_copy \1, \2, \3
    ld a, low(\4)
    ld [hl+], a
    ld [hl], high(\4)
    pop hl
ENDM

    ENDC
