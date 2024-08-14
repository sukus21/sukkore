INCLUDE "hardware.inc/hardware.inc"
INCLUDE "struct/vqueue.inc"

; What tile to start drawing from
DEF RECTANGLE_TILES EQU $E0
DEF RECTANGLE_TILE_TOP EQU RECTANGLE_TILES
DEF RECTANGLE_TILE_BOTTOM EQU RECTANGLE_TILES+2

SECTION "RECTANGLE DRAWER", ROM0

; Tileset used by rectangle drawing.  
; Should be placed at tile ID `RECTANGLE_TILES`.  
; Lives in ROM0.
rectangle_tileset:
    db $FF, $FF, $00, $00, $00, $00, $00, $00
    db $00, $00, $00, $00, $00, $00, $00, $00
    db $00, $00, $00, $00, $00, $00, $00, $00
    db $00, $00, $00, $00, $00, $00, $00, $00
    db $80, $80, $80, $80, $80, $80, $80, $80
    db $80, $80, $80, $80, $80, $80, $80, $80
    db $00, $00, $00, $00, $00, $00, $00, $00
    db $00, $00, $00, $00, $00, $00, $00, $00
.end



; Tileset used by rectangle estimate drawer.  
; Lives in ROM0.
rectangle_points_tileset:
    db $80, $C0, $C0, $40, $00, $00, $00, $00
    db $00, $00, $00, $00, $00, $00, $00, $00
    db $00, $00, $00, $00, $00, $00, $00, $00
    db $00, $00, $00, $00, $00, $00, $00, $00
.end



; Loads tile (singular) required for rectangle point shenanigans.  
; Queues VQUEUE transfer.  
; Lives in ROM0.
;
; Input:
; - `b`: Destination tile ID
rectangle_points_load::
    ld a, b
    ld [w_sprite_rectangle], a

    ;Get real address pointer -> DE
    swap a
    ld b, a
    and a, %11110000
    add a, low(_VRAM)
    ld e, a
    ld a, b
    and a, %00001111
    add a, high(_VRAM)
    ld d, a

    ;Add VQUEUE transfer
    vqueue_add_copy VQUEUE_TYPE_DIRECT, de, rectangle_points_tileset
    ret
;



; Loads rectangle tiles into VRAM.
; Assumes VRAM access.
; Overwrites VRAM tiles.
; Lives in ROM0.
rectangle_load::
    ld hl, _VRAM + RECTANGLE_TILES * 16
    ld bc, rectangle_tileset
    ld d, 4*16
    jp memcpy_short
;



; Test function for rectangle behaviour.
; Lives in ROM0.
;
; Input:
; - `e`: player input
; - `hl`: Pointer to rectangle buffer [XYwh]
rectangle_movement::

    ;X-position
    bit PADB_A, e
    jr nz, :+
    bit PADB_LEFT, e
    jr z, :+
        dec [hl]
    :
    bit PADB_A, e
    jr nz, :+
    bit PADB_RIGHT, e
    jr z, :+
        inc [hl]
    :
    ld a, [hl+]
    ld b, a

    ;Y-position
    bit PADB_A, e
    jr nz, :+
    bit PADB_UP, e
    jr z, :+
        dec [hl]
    :
    bit PADB_A, e
    jr nz, :+
    bit PADB_DOWN, e
    jr z, :+
        inc [hl]
    :
    ld a, [hl+]
    ld c, a

    ;Width
    bit PADB_A, e
    jr z, :+
    bit PADB_LEFT, e
    jr z, :+
        dec [hl]
    :
    bit PADB_A, e
    jr z, :+
    bit PADB_RIGHT, e
    jr z, :+
        inc [hl]
    :
    ld a, [hl+]
    ld d, a

    ;Height
    bit PADB_A, e
    jr z, :+
    bit PADB_UP, e
    jr z, :+
        dec [hl]
    :
    bit PADB_A, e
    jr z, :+
    bit PADB_DOWN, e
    jr z, :+
        inc [hl]
    :
    ld a, [hl+]
    ld e, a

    ;Draw rectangle
    call rectangle_draw
    ret 
;



; Function to draw a rectangle using sprites.  
; TODO: proper 8/16 support  
; Lives in ROM0.
;
; Input:
; - `b`: leftmost X-position of rectangle
; - `c`: topmost Y-position of rectangle
; - `d`: width of rectangle
; - `e`: height of rectangle
;
; Saves: none
rectangle_draw::

    ;Adjust positions
    ld a, b
    add a, 8
    ld b, a
    ld a, c
    add a, 16
    ld c, a
    push bc
    push de

    ;Get bottom Y-position in E
    ld a, c
    add a, e
    dec a
    ld e, a

    ;Draw top and bottom
    ld a, d
    and a, %00000111
    jr z, :+
        push bc

        ;Get edge X-position
        ld a, b
        add a, d
        sub a, 8
        ld h, a

        ;Allocate edge sprites
        ld b, 8
        call sprite_get
        ld b, h
        ld h, high(w_oam)
        ld l, a

        ;Top sprite
        ld a, c
        ld [hl+], a
        ld a, b
        ld [hl+], a
        ld a, RECTANGLE_TILES
        ld [hl+], a
        xor a
        ld [hl+], a

        ;Bottom sprite
        ld a, e
        ld [hl+], a
        ld a, b
        ld [hl+], a
        ld a, RECTANGLE_TILES
        ld [hl+], a
        xor a
        ld [hl+], a

        ;Restore state
        pop bc
    :

    ;Get sprites
    ld h, b
    ld a, d
    and a, %11111000
    ld b, a
    rrca 
    rrca 
    rrca 
    jr z, .done_hor
    push af
    call sprite_get
    ld b, h
    ld h, high(w_oam)
    ld l, a

    .loop_hor
        ;Top sprite
        ld a, c
        ld [hl+], a
        ld a, b
        ld [hl+], a
        ld a, RECTANGLE_TILES
        ld [hl+], a
        xor a
        ld [hl+], a

        ;Bottom sprite
        ld a, e
        ld [hl+], a
        ld a, b
        ld [hl+], a
        add a, 8
        ld b, a
        ld a, RECTANGLE_TILES
        ld [hl+], a
        xor a
        ld [hl+], a

        ;More sprites?
        pop af
        dec a
        jr z, .done_hor
        push af
        jr .loop_hor
    .done_hor

    ;Vertical time
    pop de
    pop bc

    ;Get rightmost X-position in D
    ld a, b
    add a, d
    dec a
    ld d, a

    ;Draw left and right
    ld a, e
    and a, %00000111
    jr z, :+
        push bc

        ;Get edge Y-position
        ld a, c
        add a, e
        sub a, 8
        ld c, a

        ;Allocate edge sprites
        ld h, b
        ld b, 8
        call sprite_get
        ld b, h
        ld h, high(w_oam)
        ld l, a

        ;Left sprite
        ld a, c
        ld [hl+], a
        ld a, b
        ld [hl+], a
        ld a, RECTANGLE_TILES+2
        ld [hl+], a
        xor a
        ld [hl+], a

        ;Right sprite
        ld a, c
        ld [hl+], a
        ld a, d
        ld [hl+], a
        ld a, RECTANGLE_TILES+2
        ld [hl+], a
        xor a
        ld [hl+], a

        ;Restore state
        pop bc
    :

    ;Get sprites
    ld h, b
    ld a, e
    and a, %11111000
    ld b, a
    rrca 
    rrca 
    rrca 
    ret z
    push af
    call sprite_get
    ld b, h
    ld h, high(w_oam)
    ld l, a

    .loop_ver
        ;Left sprite
        ld a, c
        ld [hl+], a
        ld a, b
        ld [hl+], a
        ld a, RECTANGLE_TILES+2
        ld [hl+], a
        xor a
        ld [hl+], a

        ;Right sprite
        ld a, c
        ld [hl+], a
        add a, 8
        ld c, a
        ld a, d
        ld [hl+], a
        ld a, RECTANGLE_TILES+2
        ld [hl+], a
        xor a
        ld [hl+], a

        ;More sprites?
        pop af
        dec a
        ret z
        push af
        jr .loop_ver
    ;

    ;Return
    ret
;



; Draw the corners of a rectangle using sprites.  
; Assumes the required sprite tile(s) are loaded.  
; Lives in ROM0.
;
; Input:
; - `b`: Leftmost X-position of rectangle
; - `c`: Topmost Y-position of rectangle
; - `d`: Rightmost X-position of rectangle
; - `e`: Lowest Y-position of rectangle
; - `h`: high byte of OAM mirror pointer
;
; Saves: none
rectangle_points_draw::
    push bc
    ld b, 4*4
    call sprite_get
    pop bc

    ;Draw top-left
    ld a, c
    add a, 16
    ld c, a
    ld [hl+], a
    ld a, b
    add a, 8
    ld b, a
    ld [hl+], a
    ld a, [w_sprite_rectangle]
    ld [hl+], a
    xor a
    ld [hl+], a

    ;Draw top-right
    ld a, c
    ld [hl+], a
    ld a, d
    add a, 6
    ld d, a
    ld [hl+], a
    ld a, [w_sprite_rectangle]
    ld c, a
    ld [hl+], a
    xor a
    ld [hl+], a

    ;Draw bottom-left
    ld a, e
    add a, 14
    ld e, a
    ld [hl+], a
    ld a, b
    ld [hl+], a
    ld a, c
    ld [hl+], a
    xor a
    ld [hl+], a

    ;Draw bottom-right
    ld a, e
    ld [hl+], a
    ld a, d
    ld [hl+], a
    ld a, c
    ld [hl+], a
    ld [hl], 0

    ;Return
    ret
;
