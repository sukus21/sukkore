INCLUDE "hardware.inc"

; What tile to start drawing from
def rectangle_tiles equ $E0
def rectangle_tile_top equ rectangle_tiles
def rectangle_tile_bottom equ rectangle_tiles+2

SECTION "RECTANGLE DRAWER NEW", ROM0

; Tileset used by rectangle drawing.
; Should be placed at tile ID `rectangle_tiles`.
; Lives in ROM0.
rectangle_tileset::
db $FF, $FF, $00, $00, $00, $00, $00, $00
db $00, $00, $00, $00, $00, $00, $00, $00
db $00, $00, $00, $00, $00, $00, $00, $00
db $00, $00, $00, $00, $00, $00, $00, $00
db $80, $80, $80, $80, $80, $80, $80, $80
db $80, $80, $80, $80, $80, $80, $80, $80
db $00, $00, $00, $00, $00, $00, $00, $00
db $00, $00, $00, $00, $00, $00, $00, $00



; Loads rectangle tiles into VRAM.
; Assumes VRAM access.
; Overwrites VRAM tiles.
; Lives in ROM0.
rectangle_load::
    ld hl, _VRAM + rectangle_tiles * 16
    ld bc, rectangle_tileset
    ld d, 4*16
    jp memcopy_short
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
        ld h, high(w_oam_mirror)
        ld l, a

        ;Top sprite
        ld a, c
        ld [hl+], a
        ld a, b
        ld [hl+], a
        ld a, rectangle_tiles
        ld [hl+], a
        xor a
        ld [hl+], a

        ;Bottom sprite
        ld a, e
        ld [hl+], a
        ld a, b
        ld [hl+], a
        ld a, rectangle_tiles
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
    ld h, high(w_oam_mirror)
    ld l, a

    .loop_hor
        ;Top sprite
        ld a, c
        ld [hl+], a
        ld a, b
        ld [hl+], a
        ld a, rectangle_tiles
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
        ld a, rectangle_tiles
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
        ld h, high(w_oam_mirror)
        ld l, a

        ;Left sprite
        ld a, c
        ld [hl+], a
        ld a, b
        ld [hl+], a
        ld a, rectangle_tiles+2
        ld [hl+], a
        xor a
        ld [hl+], a

        ;Right sprite
        ld a, c
        ld [hl+], a
        ld a, d
        ld [hl+], a
        ld a, rectangle_tiles+2
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
    ld h, high(w_oam_mirror)
    ld l, a

    .loop_ver
        ;Left sprite
        ld a, c
        ld [hl+], a
        ld a, b
        ld [hl+], a
        ld a, rectangle_tiles+2
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
        ld a, rectangle_tiles+2
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
