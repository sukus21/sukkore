INCLUDE "hardware.inc/hardware.inc"
INCLUDE "struct/oam_mirror.inc"

SECTION "SPRITES", ROM0

; Get one or multiple sprites.  
; Lives in ROM0.
; 
; Input:
; - `b`: Sprite count * 4
; - `h`: High-pointer to OAMMIR struct
;
; Returns:
; - `hl`: Pointer to sprite slot(s)
;
; Saves: `bc`, `de`, `h`
sprite_get::

    ;Allocate B amount of sprites
    ld l, OAMMIRROR_COUNT
    ld a, [hl]
    add a, b
    ld [hl], a

    ;Rewind pointer and return
    sub a, b
    ld l, a
    ret 
;



; Clear remaining sprite slots.  
; Lives in ROM0.
;
; Input:
; - `h`: High-pointer to OAMMIR struct
;
; Destroys: `l`  
; Saves: `bc`, `de`
sprite_finish::

    ;Get pointer to first unused sprite
    ld l, OAMMIRROR_PREVIOUS
    ld a, [hl-]
    ld l, [hl] ;hl = OAMMIR_COUNT

    ;Cap-fiddling, prevents errors
    cp a, l
    jr z, .done
    or a ;cp a, 0
    jr nz, :+
        ld a, $A0
    :

    ;Clear out memory
    .loop
        ld [hl], 0
        inc l
        cp a, l
        jr nc, .loop
    .done

    ;Reset sprite count and return
    ld l, OAMMIRROR_COUNT
    ld a, [hl+]
    ld [hl-], a
    ld [hl], 0
    ret 
;
