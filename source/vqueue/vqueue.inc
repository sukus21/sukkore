    IF !DEF(STRUCT_VQUEUE_INC)
    DEF STRUCT_VQUEUE_INC EQU 1

INCLUDE "utils.inc"
INCLUDE "config.inc"

; Allocated space for the stack dedicated to VQueue job routines.
DEF VQUEUE_STACK_SIZE EQU $20



RSRESET

; Source data bank.
; Written to `rROMB0` if `CONFIG_BANKABLE_ROMX` is 1.
; Written to `rRAMB` if `CONFIG_BANKABLE_SRAM` is 1.
; Written to `rSVBK` if `CONFIG_BANKABLE_WRAMX` is 1.
DEF VQUEUE_SOURCE_BANK RB 1

; Destination data bank.
; Written to `rVBK`, if `CONFIG_BANKABLE_VRAM` is 1.
DEF VQUEUE_DESTINATION_BANK RB 1

DEF VQUEUE_REGISTER_PC RW 1
DEF VQUEUE_REGISTER_SP RW 1
DEF VQUEUE_REGISTER_BC RW 1
DEF VQUEUE_REGISTER_DE RW 1
DEF VQUEUE_REGISTER_HL RW 1
DEF VQUEUE_REGISTER_AF RW 1

; The value at this address is decremented when a transfer finishes.
DEF VQUEUE_WRITEBACK RW 1

; A VQueue job struct.
DEF VQUEUE_T RB 0



; Creates a prepared VQueue transfer.
; This macro expands to 16 bytes of data.
;
; Input:
; - `1`: PC (label/n16)
; - `2*`: HL value
; - `3*`: BC value
; - `4*`: DE value
; - `5*`: AF value
; - `6*`: writeback address (label/n16)
; - `7*`: destination bank (n8)
; - `8*`: source bank (n8)
MACRO vqueue_prepare

    ; source bank
    IF _NARG >= 8
        db \8
    ELSE
        db bank(@)
    ENDC

    ; destination bank
    IF _NARG >= 7
        db \7
    ELSE
        db $00
    ENDC

    ; PC
    dw \1

    ; SP
    dw wVQueueStack
    
    ; BC
    IF _NARG >= 3
        dw \3
    ELSE
        dw $0000
    ENDC

    ; DE
    IF _NARG >= 4
        dw \4
    ELSE
        dw $0000
    ENDC

    ; HL
    IF _NARG >= 2
        dw \2
    ELSE
        dw $0000
    ENDC

    ; AF
    IF _NARG >= 5
        dw \5
    ELSE
        dw $0000
    ENDC

    ; Writeback
    IF _NARG >= 6
        dw \6
    ELSE
        dw $0000
    ENDC
ENDM



; Prepares a label to be copied to VRAM.
; This macro expands to 16 bytes of data.
;
; Input:
; - `1`: destination (label/n16)
; - `2`: source (label)
; - `3`: destination bank (n8)
; - `4`: writeback pointer (label/n16)
MACRO vqueue_prepare_memcpy
    IF \2.end - \2 <= 256
        vqueue_prepare MemcpyShort, \1, \2, (\2.end - \2) << 8, $0000, \4, \3, bank(\2)
    ELSE
        vqueue_prepare Memcpy, \1, \2, \2.end - \2, $0000, \4, \3, bank(\2)
    ENDC
ENDM



; Prepares data to be filled in VRAM.
; This macro expands to 16 bytes of data.
;
; Input:
; - `1`: destination (label/n16)
; - `2`: byte value (n8)
; - `3`: byte count (n16)
; - `4`: destination bank (n8)
; - `5`: writeback pointer (label/n16)
MACRO vqueue_prepare_memset
    IF \3 <= 256
        vqueue_prepare MemsetShort \1, (\2 << 8) | \3, $0000, $0000, \5, \4
    ELSE
        vqueue_prepare Memset, \1, \2, \3, $0000, \5, \4
    ENDC
ENDM



; Macro that adds a memcpy transfer to the VRAM transfer queue.
; Assumes the source label has an exported `.end` sublabel.
; Does not set writeback pointer.
;
; Input:
; - `1`: Destination (label/n16/r16)
; - `2`: Source (label)
; - `3*`: Destination bank (n8)
;
; Returns:
; - `hl`: `VQUEUE` pointer, at `VQUEUE_WRITEBACK`
;
; Destroys: `af`  
; Saves: `bc`, `de`
MACRO vqueue_add_memcpy
    call VQueueGet
    
    ; Write source bank
    ld a, bank(\2)
    ld [hl+], a

    ; Write destination bank
    is_r16 \1
    IF !ISCONST(#\1) && !IS_R16
        ld a, bank(\1)
    ELIF _NARG >= 3
        ld a, \3
    ELSE
        IF CONFIG_BANKABLE_VRAM
            WARN "no VRAM bank specified, defaulting to 0"
        ENDC
        xor a
    ENDC
    ld [hl+], a

    ; Write registers
    ; Maybe this can be a short memcpy?
    IF \2.end - \2 <= 256
        write_n16 MemcpyShort   ; Program counter
        write_n16 wVQueueStack  ; Stack pointer
        write_n16 \2            ; BC, source address
        inc l
        ld a, \2.end - \2
        ld [hl+], a             ; D, byte length
        write_n16 \1            ; HL, destination
    ELSE
        ; Write registers
        write_n16 Memcpy        ; Program counter
        write_n16 wVQueueStack  ; Stack pointer
        write_n16 \2            ; BC, source address
        write_n16 \2.end - \2   ; DE, byte length
        write_n16 \1            ; HL, destination
    ENDC

    ; Write AF
    xor a
    ld [hl+], a
    ld [hl+], a
ENDM

    ENDC
