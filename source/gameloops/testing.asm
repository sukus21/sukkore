INCLUDE "hardware.inc/hardware.inc"
INCLUDE "macro/memcpy.inc"
INCLUDE "macro/numtohex.inc"
INCLUDE "struct/vqueue.inc"

SECTION "TESTLOOP DATA", ROMX

testloop_font:
    INCBIN "font.tls"
    INCBIN "testing_entityslots.tls"
    .end
;

testloop_str:
    .f64 db " 64:$"
    .f32 db " 32:$"
    .f16 db " 16:$"
;

testloop_transfers:
    vqueue_prepare_set VQUEUE_TYPE_DIRECT, 128, _SCRN0, 0
    vqueue_prepare_copy VQUEUE_TYPE_DIRECT, _VRAM8000, testloop_font
;

SECTION "GAMELOOP TEST", ROM0

; Does not return.
; Should not be called, but jumped to from another gameloop,
; or after resetting the stack.
; Lives in ROM0.
gameloop_test::
    ld de, testloop_transfers
    ld b, 2
    call vqueue_enqueue_multi
    call gameloop_loading

    ;Set palette
    ld a, %11100100
    ldh [rBGP], a
    ldh [rOBP0], a

    ;Set screen position
    ld a, -16
    ldh [rSCX], a
    ldh [rSCY], a

    ;Initialize a few variables
    xor a
    ld hl, w_buffer+128
    ld [hl+], a
    ld [hl+], a
    ld [hl+], a

    ;Clear OAM
    ld a, high(w_oam)
    call h_dma

    ;Enable Vblank interrupt
    xor a
    ldh [rIF], a
    ld a, IEF_VBLANK
    ldh [rIE], a

    ;Enable LCD
    ld a, LCDCF_ON | LCDCF_OBJON | LCDCF_BGON | LCDCF_BLK01
    ldh [rLCDC], a
    halt
    nop

    ;Main loop
    .loop
    call input

    ;Select what allocation mode to do
    ld hl, w_buffer+130
    ld a, [hl]
    bit PADB_SELECT, c
    jr z, :+
        inc [hl]
        ld a, [hl]
        cp a, 3
        jr c, :+
        xor a
        ld [hl], a
    :

    ;Get sprite Y-position
    add a, a
    add a, a
    add a, a
    add a, 71
    ld c, a

    ;Get sprite and apply Y-position
    ld b, 4
    ld h, high(w_oam)
    call sprite_get
    ld [hl], c
    inc l

    ;Make up an X-position and tile ID
    ld [hl], 47
    inc l
    ld [hl], $86

    ;Allocate new entity
    ldh a, [h_input_pressed]
    bit PADB_A, a
    jr z, .no_alloc
        ld c, 1
        call wait_scanline
        ld a, [w_buffer+130]
        cp a, 0
        jr nz, :+
            call entsys_new64
            jr .alloc_done
        :
        cp a, 1
        jr nz, :+
            call entsys_new32
            jr .alloc_done
        :
        cp a, 2
        jr nz, .no_alloc
        call entsys_new16
        ;Falls into `alloc_done`

        .alloc_done
        ;Set entity bank to 1
        ld a, 1
        ld [bc], a
        ldh a, [rLY]
        ld [w_buffer+131], a
    .no_alloc

    ;Free entities
    ldh a, [h_input_pressed]
    ld b, a
    ld hl, w_buffer+128
    ld a, [hl+]
    ld d, a ;x-axis
    ld e, [hl] ;y-axis

    ;Move on X-axis
    bit PADB_LEFT, b
    jr z, :+
        dec d
    :
    bit PADB_RIGHT, b
    jr z, :+
        inc d
    :
    ld a, d
    and a, %00001111
    ld d, a

    ;Move on Y-axis
    bit PADB_UP, b
    jr z, :+
        dec e
    :
    bit PADB_DOWN, b
    jr z, :+
        inc e
    :
    ld a, e
    and a, %00000011

    ;Save modified values
    ld [hl-], a
    ld [hl], d

    ;Draw cursor sprite
    add a, a
    add a, a
    add a, a
    add a, 28
    ld c, a ;y-position

    ;Get sprite
    ld b, 4
    ld h, high(w_oam)
    call sprite_get
    ld [hl], c
    inc l

    ;Make up an X-position and tile ID
    ld a, d
    add a, a
    add a, a
    add a, a
    add a, 24
    ld [hl+], a
    ld [hl], $86

    ;Actually free entities
    ldh a, [h_input_pressed]
    bit PADB_B, a
    jr z, .no_free
        ld c, 1
        call wait_scanline
        ld l, d
        swap l
        ld a, high(w_entsys)
        add a, e
        ld h, a
        call entsys_free
        ldh a, [rLY]
        ld [w_buffer+131], a
    .no_free

    ;Get quick status of all entities
    ld hl, w_entsys
    ld de, w_buffer
    .entity_loop
        ;Is slot enabled?
        ld a, [hl+]
        ld b, $83
        or a, a
        jr z, :+
            ld b, $80
        :

        ;Get size of slot
        ld a, [hl-]
        swap a
        and a, %00000111
        ld c, a
        rr a
        add a, b
        ld b, a

        ;Store this and move on to next entity
        .entity_inner
            ld a, b
            ld [de], a
            inc de
            ld a, l
            add a, $10
            ld l, a
            ld a, 0
            adc a, h
            ld h, a

            ;Multi-slot entity, repeat?
            dec c
            jr nz, .entity_inner
        ;
        
        ;OOB check
        cp a, $D4
        jr nz, .entity_loop
    ;

    ;Copy status for first64
    ld h, d
    ld l, e
    ld de, testloop_str.f64
    ld b, 5
    memcpy_custom hl, de, b
    num_to_hex [w_entsys_first64+1], b, c
    ld a, b
    ld [hl+], a
    ld a, c
    ld [hl+], a
    num_to_hex [w_entsys_first64], b, c
    ld a, b
    ld [hl+], a
    ld a, c
    ld [hl+], a

    ;Copy status for first32
    ld b, 5
    ;ld de, testloop_str.f32 ;It's already there
    memcpy_custom hl, de, b
    num_to_hex [w_entsys_first32+1], b, c
    ld a, b
    ld [hl+], a
    ld a, c
    ld [hl+], a
    num_to_hex [w_entsys_first32], b, c
    ld a, b
    ld [hl+], a
    ld a, c
    ld [hl+], a

    ;Copy status for first16
    ld b, 5
    ;ld de, testloop_str.f16 ;It's already there
    memcpy_custom hl, de, b
    num_to_hex [w_entsys_first16+1], b, c
    ld a, b
    ld [hl+], a
    ld a, c
    ld [hl+], a
    num_to_hex [w_entsys_first16], b, c
    ld a, b
    ld [hl+], a
    ld a, c
    ld [hl+], a

    ;Create sprites for performance metric
    ld a, [w_buffer+131]
    num_to_hex a, d, e
    ld b, 8
    ld h, high(w_oam)
    call sprite_get
    ld [hl], 64
    inc l
    ld [hl], 24
    inc l
    ld [hl], d
    inc l
    inc l
    ld [hl], 64
    inc l
    ld [hl], 32
    inc l
    ld [hl], e

    ;Wait for Vblank
    ld h, high(w_oam)
    call sprite_finish
    xor a
    ldh [rIF], a
    halt
    nop

    ;Copy entity status to tilemap
    ld hl, _SCRN0
    ld de, w_buffer
    .vram_loop
        ld a, [de]
        inc de
        ld [hl+], a
        ld a, e
        and a, %00001111
        jr nz, .vram_loop

        ld a, l
        or a, %00011111
        inc a
        ld l, a
        
        ld a, e
        cp a, $40
        jr nz, .vram_loop
    ;

    ld b, 9
    ld hl, _SCRN0 + 131+32
    memcpy_custom hl, de, b

    ld b, 9
    ld hl, _SCRN0 + 131+64
    memcpy_custom hl, de, b

    ld b, 9
    ld hl, _SCRN0 + 131+96
    memcpy_custom hl, de, b

    ;OAM DMA and repeat loop
    ld a, high(w_oam)
    call h_dma
    jp .loop
;
