INCLUDE "hardware.inc/hardware.inc"
INCLUDE "macro/memcpy.inc"
INCLUDE "vqueue/vqueue.inc"

SECTION "PAINTER", ROM0

; Resets painter position.  
; Does NOT clear the paint buffer.  
; Lives in ROM0.
;
; Saves: `f`, `bc`, `de`, `hl`
PainterReset::
    push hl
    ld hl, wPainterPosition
    ld a, low(wPaint)
    ld [hl+], a
    ld [hl], high(wPaint)
    pop hl
    ret
;



; Pastes raw tile data into paint buffer.  
; Assumes the correct bank is switched in already.  
; Lives in ROM0.
;
; Input:
; - `bc`: Tile data
; - `de`: Length in bytes
;
; Saves: `bc`, `de`, `hl`
PainterFill::
    ld a, d
    or a, e
    ret z
    push bc
    push de
    push hl

    ; Do some copyin'
    ld hl, wPainterPosition
    ld a, [hl+]
    ld h, [hl]
    ld l, a
    call Memcpy

    ; Save pointer
    ld a, l
    ld [wPainterPosition], a
    ld a, h
    ld [wPainterPosition+1], a

    ; Return
    pop hl
    pop de
    pop bc
    ret
;



; Paints on top of existing canvas.
; Pixels of color 0 saves original background.  
; Assumes the correct bank is switched in already.  
; Lives in ROM0.
;
; Input:
; - `bc`: Tile data
; - `de`: Length in bytes
;
; Saves: `de`, `hl`
PainterPaint::
    res 0, e
    ld a, d
    or a, e
    ret z
    push de
    push hl

    ; Get current pointer position
    ld hl, wPainterPosition
    ld a, [hl+]
    ld h, [hl]
    ld l, a

    .loop
        ; Decrement counter and save it
        dec de
        dec e
        push de

        ; Read source -> DE
        ld a, [bc]
        inc bc
        ld d, a
        ld a, [bc]
        ld e, a
        inc bc
        push bc

        ; Create counter -> C
        ld c, 8
        .loopInner
            bit 0, d
            jr nz, .place
            bit 0, e
            jr z, .skip
            .place
                res 0, [hl]
                bit 0, d
                jr z, :+
                    set 0, [hl]
                :
                inc l
                res 0, [hl]
                bit 0, e
                jr z, :+
                    set 0, [hl]
                :
                dec l
            .skip
            rlc d
            rlc e
            rlc [hl]
            inc l
            rlc [hl]
            dec l
            dec c
            jr nz, .loopInner
        ;

        ; One iteration over
        inc l
        inc hl
        pop bc
        pop de
        ld a, d
        or a, e
        jr nz, .loop
    ;

    ; Save pointer
    ld a, l
    ld [wPainterPosition], a
    ld a, h
    ld [wPainterPosition+1], a

    ; Return
    pop hl
    pop de
    ret
;



; Clears part of the paint buffer.  
; Lives in ROM0.
;
; Input:
; - `de`: Length in bytes
;
; Saves: `bc`, `de`, `hl`
PainterClear::
    ld a, d
    or a, e
    ret z
    push bc
    push de
    push hl

    ; Get buffer position
    ld hl, wPainterPosition
    ld a, [hl+]
    ld h, [hl]
    ld l, a

    ; Start going
    .loop
        xor a
        ld [hl+], a
        dec de
        ld a, d
        or a, e
        jr nz, .loop
    ;

    ; Save pointer
    ld a, l
    ld [wPainterPosition], a
    ld a, h
    ld [wPainterPosition+1], a

    ; Return
    pop hl
    pop de
    pop bc
    ret
;



SECTION "PAINTER VARIABLES", WRAM0

    ; Current painter position.
    wPainterPosition:: ds 2
;



SECTION "PAINTER BUFFER", WRAMX

    ; Paint buffer.
    wPaint:: ds $400
;
