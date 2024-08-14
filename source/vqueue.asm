INCLUDE "hardware.inc/hardware.inc"
INCLUDE "struct/vqueue.inc"
INCLUDE "macro/memcpy.inc"

; If this scanline has been reached, do not perform any more transfer operations.
DEF VQUEUE_ITERATION_TIME EQU $97

SECTION "VRAM QUEUE", ROM0

; Get a vqueue slot pointer.
; When adding multiple transfers, completion order is not guaranteed.  
; Lives in ROM0.
;
; Returns:
; - `hl`: `VQUEUE` pointer
;
; Saves: `bc`, `de`
vqueue_get::
    ld hl, w_vqueue_first
    ld a, [hl+]
    ld h, [hl]
    ld l, a
    push de
    push hl

    ;Increment this pointer a wee bit
    ld a, l
    add a, VQUEUE_T
    ld e, a
    ld a, h
    adc a, 0
    ld d, a

    ;Out of bounds check
    cp a, high(w_vqueue.end)
    jr nz, :+
        ld a, e
        cp a, low(w_vqueue.end)
        jr nz, :+

        ;Uh oh, overflow alert
        ld hl, error_vqueueoverflow
        rst v_error
    :

    ;Store this back as the new first slot
    ld hl, w_vqueue_first
    ld a, e
    ld [hl+], a
    ld [hl], d

    ;Yes, good, return
    pop hl
    pop de
    ret
;



; Enqueue a prepared vqueue transfer (See `vqueue_prepare`).  
; Assumes the correct ROM-bank is switched in.  
; Lives in ROM0.
;
; Input:
; - `de`: Prepared transfer
vqueue_enqueue::
    call vqueue_get
    ld b, VQUEUE_T
    memcpy_custom hl, de, b
    ret
;



; Enqueues multiple prepared vqueue transfers,
; stored one after the other in memory.  
; Assumes correct ROM-bank is switched in.  
; Lives in ROM0.
;
; Input:
; - `de`: Prepared transfers
; - `b`: Number of transfers
;
; Destroys: all
vqueue_enqueue_multi::
    ld a, b
    or a, a
    ret z

    ;Start loopin' away
    .loop
    call vqueue_get
    ld c, VQUEUE_T
    memcpy_custom hl, de, c
    dec b
    jr nz, .loop
    ret
;



; Clears all vqueue transfers, even ones currently in progress.  
; Lives in ROM0.
;
; Saves: `c`, `de`
vqueue_clear::
    ld hl, w_vqueue
    ld a, l
    ld [w_vqueue_first], a
    ld a, h
    ld [w_vqueue_first+1], a
    ld b, VQUEUE_QUEUE_SIZE

    .loop

    ;Is this a valid entry?
    ld a, [hl]
    cp a, VQUEUE_TYPE_NONE
    ret z

    ;Clear this entry
    xor a
    REPT VQUEUE_T
        ld [hl+], a
    ENDR

    ;Next entry?
    dec b
    jr nz, .loop

    ;Nope, this is the end
    ret
;



; Checks if vqueue is empty.  
;
; Returns:
; - `fZ`: Is empty (z = yes)
;
; Destroys: `af`
vqueue_empty::
    ld a, [w_vqueue]
    cp a, VQUEUE_TYPE_NONE
    ret
;



; Execute transfers from the VRAM queue.  
; Assumes VRAM access.  
; Switches banks.  
; Lives in ROM0.  
;
; Destroys: all
vqueue_execute::
    ;Get type of transfer
    ld hl, w_vqueue
    ld a, [hl+]
    cp a, VQUEUE_TYPE_NONE
    ret z

    ;Set-mode?
    bit VQUEUEB_MODEFLAG, a
    jr z, .copymode
        res VQUEUEB_MODEFLAG, a
        cp a, VQUEUE_TYPE_DIRECT
        jr nz, :+
            call vqueue_set_direct
            ret z
            jr .finish
        :

        cp a, VQUEUE_TYPE_HALFROW
        jr nz, :+
            call vqueue_set_halfrow
            ret z
            jr .finish
        :

        cp a, VQUEUE_TYPE_COLUMN
        jr nz, :+
            call vqueue_set_column
            ret z
            jr .finish
        :

        cp a, VQUEUE_TYPE_SCREENROW
        jr nz, :+
            call vqueue_set_screenrow
            ret z
            jr .finish
        :

        ;Transfer type not found
        jr .finish
    ;

    ;Copy-mode
    .copymode
        cp a, VQUEUE_TYPE_DIRECT
        jr nz, :+
            call vqueue_copy_direct
            ret z
            jr .finish
        :

        cp a, VQUEUE_TYPE_HALFROW
        jr nz, :+
            call vqueue_copy_halfrow
            ret z
            jr .finish
        :

        cp a, VQUEUE_TYPE_COLUMN
        jr nz, :+
            call vqueue_copy_column
            ret z
            jr .finish
        :

        cp a, VQUEUE_TYPE_SCREENROW
        jr nz, :+
            call vqueue_copy_screenrow
            ret z
            jr .finish
        :

        ;Type not found
        jr .finish
    ;

    ;Finish a transfer
    .finish
        ;Set type to none
        ld hl, w_vqueue + VQUEUE_TYPE
        ld [hl], VQUEUE_TYPE_NONE

        ;Perform writeback
        ld l, low(w_vqueue) + VQUEUE_WRITEBACK
        ld a, [hl+]
        ld c, [hl]
        ld [hl], 0
        ld h, c
        ld l, a
        bit 7, h
        jr z, :+
            inc [hl]
        :

        ;Move to last queued transfer
        ld hl, w_vqueue_first
        ld a, [hl+]
        sub a, VQUEUE_T
        jr nc, :+
            dec [hl]
        :
        ld c, a
        ld a, [hl-]
        ld [hl], c
        ld h, a
        ld l, c

        ;Transfer exists?
        ld a, [hl]
        cp a, VQUEUE_TYPE_NONE
        ret z

        ;Copy transfer to first slot
        ld bc, w_vqueue
        ld [bc], a
        inc c
        ld a, VQUEUE_TYPE_NONE
        ld [hl+], a
        REPT VQUEUE_T-1
            ld a, [hl+]
            ld [bc], a
            inc c
        ENDR

        ;Do we have time to start this transfer?
        ldh a, [rLY]
        cp a, VQUEUE_ITERATION_TIME
        jp c, vqueue_execute
    ;

    ;Return
    ret 
;



MACRO vqueue_copy_start
    ;Get length remaining
    ld a, [hl+]
    ld d, a ;length total -> D
    ld a, [hl+]
    ld e, a ;progress -> E

    ;Get destination -> BC
    ld a, [hl+]
    ld c, a
    ld a, [hl+]
    ld b, a

    ;Get source -> HL
    ld a, [hl+]
    ld [rROMB0], a
    ld a, [hl+]
    ld h, [hl]
    ld l, a

    .loop
ENDM

MACRO vqueue_copy_end
    ;Is it over?
    inc e
    ld a, e
    sub a, d
    jr nz, :+
        inc a ;reset Z-flag
        ret
    :

    ;Time for another iteration?
    ldh a, [rLY]
    cp a, VQUEUE_ITERATION_TIME
    IF @ - .loop > 127
        jp c, .loop
    ELSE
        jr c, .loop
    ENDC

    ;Time is up
    ;Save transfer completion count
    ld a, e
    ld d, h
    ld e, l
    ld hl, w_vqueue + VQUEUE_PROGRESS
    ld [hl+], a

    ;Save destination
    ld a, c
    ld [hl+], a
    ld a, b
    ld [hl+], a

    ;Save source
    inc hl
    ld a, e
    ld [hl+], a
    ld [hl], d

    ;Return
    xor a ;sets Z-flag
    ret
ENDM

MACRO vqueue_set_start
    ;Get length remaining
    ld a, [hl+]
    ld d, a ;length total -> D
    ld a, [hl+]
    ld e, a ;progress -> E

    ;Get destination -> BC
    ld a, [hl+]
    ld c, a
    ld a, [hl+]
    ld b, a

    ;Get source -> A, move destination to HL
    ld a, [hl]
    ld h, b
    ld l, c
    ld b, a

    .loop
    ld a, b
ENDM

MACRO vqueue_set_end
    ;Is it over?
    inc e
    ld a, e
    sub a, d ;set A to 0 if Z flag
    jr nz, :+
        inc a ;reset Z-flag
        ret
    :

    ;Time for another iteration?
    ldh a, [rLY]
    cp a, VQUEUE_ITERATION_TIME
    IF @ - .loop > 127
        jp c, .loop
    ELSE
        jr c, .loop
    ENDC

    ;Time is up
    ;Save transfer completion count
    ld b, h
    ld c, l
    ld hl, w_vqueue + VQUEUE_PROGRESS
    ld a, e
    ld [hl+], a

    ;Save destination
    ld a, c
    ld [hl+], a
    ld a, b
    ld [hl+], a

    ;Return
    xor a ;sets Z-flag
    ret
ENDM



; Subroutine for `vqueue_execute`.  
; Same notes as `vqueue_execute`.
;
; Input:
; - `hl`: `VQUEUE` pointer, at `VQUEUE_LENGTH`
;
; Returns:
; - `fZ`: Transfer ended early
vqueue_copy_direct:
    vqueue_copy_start
    REPT 16
        ld a, [hl+]
        ld [bc], a
        inc bc
    ENDR
    vqueue_copy_end
;



; Subroutine for `vqueue_execute`.  
; Same notes as `vqueue_execute`.
;
; Input:
; - `hl`: `VQUEUE` pointer, at `VQUEUE_LENGTH`
;
; Returns:
; - `fZ`: Transfer ended early
vqueue_set_direct:
    vqueue_set_start
    REPT 16
        ld [hl+], a
    ENDR
    vqueue_set_end
;



; Subroutine for `vqueue_execute`.  
; Same notes as `vqueue_execute`.
;
; Input:
; - `hl`: `VQUEUE` pointer, at `VQUEUE_LENGTH`
;
; Returns:
; - `fZ`: Transfer ended early
vqueue_copy_halfrow:
    vqueue_copy_start
    REPT 16
        ld a, [hl+]
        ld [bc], a
        inc bc
    ENDR

    ;Move destination pointer
    ld a, c
    add a, 16
    ld c, a
    jr nc, :+
        inc b
    :
    
    vqueue_copy_end
;



; Subroutine for `vqueue_execute`.  
; Same notes as `vqueue_execute`.
;
; Input:
; - `hl`: `VQUEUE` pointer, at `VQUEUE_LENGTH`
;
; Returns:
; - `fZ`: Transfer ended early
vqueue_set_halfrow:
    vqueue_set_start
    REPT 16
        ld [hl+], a
    ENDR

    ;Move destination pointer
    ld a, l
    add a, 16
    ld l, a
    jr nc, :+
        inc h
    :
    
    vqueue_set_end
;



; Subroutine for `vqueue_execute`.  
; Same notes as `vqueue_execute`.
;
; Input:
; - `hl`: `VQUEUE` pointer, at `VQUEUE_LENGTH`
;
; Returns:
; - `fZ`: Transfer ended early
vqueue_copy_column:
    vqueue_copy_start
    push bc
    REPT 32
        ld a, [hl+]
        ld [bc], a
        ld a, c
        add a, 32
        ld c, a
        jr nc, :+
            inc b
        :
    ENDR

    ;Move destination pointer
    pop bc
    inc bc
    
    vqueue_copy_end
;



; Subroutine for `vqueue_execute`.  
; Same notes as `vqueue_execute`.
;
; Input:
; - `hl`: `VQUEUE` pointer, at `VQUEUE_LENGTH`
;
; Returns:
; - `fZ`: Transfer ended early
vqueue_set_column:
    vqueue_set_start
    push bc
    REPT 32
        ld [hl+], a
        ld a, l
        add a, 32
        ld l, a
        jr nc, :+
            inc h
        :
    ENDR

    ;Move destination pointer
    pop hl
    inc hl
    
    vqueue_set_end
;



; Subroutine for `vqueue_execute`.  
; Same notes as `vqueue_execute`.
;
; Input:
; - `hl`: `VQUEUE` pointer, at `VQUEUE_LENGTH`
;
; Returns:
; - `fZ`: Transfer ended early
vqueue_copy_screenrow:
    vqueue_copy_start
    REPT 20
        ld a, [hl+]
        ld [bc], a
        inc bc
    ENDR

    ;Move destination pointer
    ld a, c
    add a, 12
    ld c, a
    jr nc, :+
        inc b
    :
    
    vqueue_copy_end
;



; Subroutine for `vqueue_execute`.  
; Same notes as `vqueue_execute`.
;
; Input:
; - `hl`: `VQUEUE` pointer, at `VQUEUE_LENGTH`
;
; Returns:
; - `fZ`: Transfer ended early
vqueue_set_screenrow:
    vqueue_set_start
    REPT 20
        ld [hl+], a
    ENDR

    ;Move destination pointer
    ld a, l
    add a, 12
    ld l, a
    jr nc, :+
        inc h
    :
    
    vqueue_set_end
;
