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
SpriteGet::

    ; Allocate B amount of sprites
    ld l, OAMMIRROR_COUNT
    ld a, [hl]
    add a, b
    ld [hl], a

    ; Rewind pointer and return
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
SpriteFinish::

    ; Get pointer to first unused sprite
    ld l, OAMMIRROR_PREVIOUS
    ld a, [hl-]
    ld l, [hl] ; hl = OAMMIR_COUNT

    ; Cap-fiddling, prevents errors
    cp a, l
    jr z, .done
    or a ; cp a, 0
    jr nz, :+
        ld a, $A0
    :

    ; Clear out memory
    .loop
        ld [hl], 0
        inc l
        cp a, l
        jr nc, .loop
    .done

    ; Reset sprite count and return
    ld l, OAMMIRROR_COUNT
    ld a, [hl+]
    ld [hl-], a
    ld [hl], 0
    ret 
;



; Draw a sprite using the given sprite template.  
; Lives in ROM0.
;
; Input:
; - `a`: Sprite attributes
; - `b`: Sprite X
; - `c`: Sprite Y
; - `de`: Template pointer
; - `h`: High-byte of OAM mirror pointer
;
; Saves: none
SpriteDrawTemplate::
    push hl
    ld l, a
    ldh [hSpriteAttr], a

    ; Adjust X-position
    ld a, b
    sub a, 8
    ld b, a

    ; Handle mirroring
    ld a, 8
    bit OAMB_XFLIP, l
    jr z, :+
        ld a, b
        add a, 24
        ld b, a
        ld a, -8
    :
    ldh [hSpriteXdelta], a

    ; Handle flipping
    ld a, 16 ; TODO: 8x16 or 8x8 mode
    bit OAMB_YFLIP, l
    jr z, :+
        add a, c
        ld c, a
        ld a, -16
    :
    ldh [hSpriteYdelta], a
    pop hl
    push bc

    ; How many sprites do we need to allocate?
    ld a, [de]
    inc de
    ldh [hSpriteBits], a
    ld c, a
    xor a ; reset carry flag
    ld b, a
    ldh [hSpriteIter], a
    REPT 8
        sla c
        adc a, b
    ENDR
    
    ; Allocate sprites -> HL
    add a, a
    add a, a
    ld b, a
    call SpriteGet

    ; Begin writing sprite data
    pop bc
    .loop
        ldh a, [hSpriteBits]
        sla a
        ldh [hSpriteBits], a
        jr c, :+
            ret z
            jr .nextSprite
        :

        ; Write X and Y position
        ld a, c
        ld [hl+], a
        ld a, b
        ld [hl+], a
        push bc

        ; Sprite tile
        ld a, [de]
        inc de
        ld [hl+], a

        ; Sprite attributes
        ld a, [de]
        inc de
        ld b, a
        ldh a, [hSpriteAttr]
        xor a, b
        ld [hl+], a
        pop bc

        ; Scoot X-position over for the next sprite
        .nextSprite
        ldh a, [hSpriteXdelta]
        add a, b
        ld b, a
        ldh a, [hSpriteIter]
        inc a
        ldh [hSpriteIter], a
        
        ; Reset X and increment Y
        cp a, 4
        jr nz, .loop
            ldh a, [hSpriteXdelta]
            add a, a
            add a, a
            cpl a
            inc a
            add a, b
            ld b, a
            ldh a, [hSpriteYdelta]
            add a, c
            ld c, a
            jr .loop
        ;
    ;
;



; Copies a sprite template to a RAM location, while modifying it.  
; Lives in ROM0.
;
; Input:
; - `b`: Tile offset
; - `c`: Attribute change
; - `de`: Destination
; - `hl`: Source
;
; Saves: `bc`
SpriteModifyTemplate::
    push bc

    ; How many entries to copy?
    ld a, [hl+]
    ld c, a
    xor a
    ld b, a
    REPT 8
        sla c
        adc a, b
    ENDR
    pop bc
    ret z
    ldh [hSpriteIter], a

    ; Copy data
    .loop
        ld a, [hl+]
        add a, b
        ld [de], a
        inc de
        ld a, [hl+]
        xor a, c
        ld [de], a
        inc de

        ; End of loop?
        ldh a, [hSpriteIter]
        dec a
        ret z
        ldh [hSpriteIter], a
        jr .loop
    ;
;
