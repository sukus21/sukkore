INCLUDE "hardware.inc"
INCLUDE "macros/memcpy.inc"
INCLUDE "struct/vqueue.inc"

SECTION "PAINTER", ROM0

; Resets painter position.  
; Does NOT clear the paint buffer.  
; Lives in ROM0.
;
; Saves: `f`, `bc`, `de`, `hl`
painter_reset::
    push hl
    ld hl, w_painter_position
    ld a, low(w_paint)
    ld [hl+], a
    ld [hl], high(w_paint)
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
painter_fill::
    ld a, d
    or a, e
    ret z
    push bc
    push de
    push hl

    ;Do some copyin'
    ld hl, w_painter_position
    ld a, [hl+]
    ld h, [hl]
    ld l, a
    call memcpy

    ;Save pointer
    ld a, l
    ld [w_painter_position], a
    ld a, h
    ld [w_painter_position+1], a

    ;Return
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
painter_paint::
    res 0, e
    ld a, d
    or a, e
    ret z
    push de
    push hl

    ;Get current pointer position
    ld hl, w_painter_position
    ld a, [hl+]
    ld h, [hl]
    ld l, a

    .loop
        ;Decrement counter and save it
        dec de
        dec e
        push de

        ;Read source -> DE
        ld a, [bc]
        inc bc
        ld d, a
        ld a, [bc]
        ld e, a
        inc bc
        push bc

        ;Create counter -> C
        ld c, 8
        .loop_inner
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
            jr nz, .loop_inner
        ;

        ;One iteration over
        inc l
        inc hl
        pop bc
        pop de
        ld a, d
        or a, e
        jr nz, .loop
    ;

    ;Save pointer
    ld a, l
    ld [w_painter_position], a
    ld a, h
    ld [w_painter_position+1], a

    ;Return
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
painter_clear::
    ld a, d
    or a, e
    ret z
    push bc
    push de
    push hl

    ;Get buffer position
    ld hl, w_painter_position
    ld a, [hl+]
    ld h, [hl]
    ld l, a

    ;Start going
    .loop
        xor a
        ld [hl+], a
        dec de
        ld a, d
        or a, e
        jr nz, .loop
    ;

    ;Save pointer
    ld a, l
    ld [w_painter_position], a
    ld a, h
    ld [w_painter_position+1], a

    ;Return
    pop hl
    pop de
    pop bc
    ret
;
