INCLUDE "hardware.inc"
INCLUDE "color.inc"

SECTION "INTRO", ROM0, ALIGN[8]

; Raw palette data.
; Lives in ROM0.
intro_palettes:
    INCBIN "intro/sukus_fade.pal"
    .end
;

; Tilemap data for logo. 
; Contains a DMG- and CGB version.
; Lives in ROM0.
intro_tilemap:
    INCBIN "intro/sukus_cgb.tlm"
    .dmg
    INCBIN "intro/sukus_dmg.tlm"
    .end
;

; Tileset for logo and font.
; Lives in ROM0.
intro_tileset:
    INCBIN "intro/intro.tls"
    .end
;



;Color pointer offsets
_intro_yellow equ $00
_intro_red equ $40
_intro_gray equ $80
_intro_black equ $C0



; Plays the "Sukus Production screen".
; Routine will keep running until the animation is over, then return.
; Modifies screen data.
; Assumes LCD is turned on.
; Lives in ROM0.
;
; Destroys: all
intro::

    ;Wait for VBLANK
    xor a
    ldh [rIF], a
    ld a, IEF_VBLANK
    ldh [rIE], a
    halt 

    ;There is Vblank!
    ;Disable LCD
    xor a
    ldh [rLCDC], a

    ;Copy font to VRAM
    ld hl, _VRAM + $1000
    ld bc, intro_tileset
    ld de, intro_tileset.end - intro_tileset
    call memcpy

    ;Copy tilemap
    xor a
    ldh [rVBK], a
    ld hl, _SCRN0
    ld bc, intro_tilemap

    ;DMG tilemap?
    ldh a, [h_is_color]
    cp a, 0
    jr nz, :+
        ld a, %11100100
        ld [w_buffer], a
        ld bc, intro_tilemap.dmg
    :
        ld de, 20
        call memcpy
        ld a, l
        and a, %11100000
        add a, 32
        jr nc, :+
            inc h
        :
        ld l, a
        ld a, h
        cp a, $9A
        jr nz, :--
        ld a, l
        cp a, $40
        jr nz, :--

    ;Check if attributes should be set?
    ldh a, [h_is_color]
    cp a, 0
    jr z, .attrskip

        ;Set tile attributes
        ld a, 1
        ldh [rVBK], a 
        ld hl, _SCRN0
        ld b, 1
        ld de, $400
        call memset

        ;Make face use palette 0
        ld hl, _SCRN0 + 6 + (32 * 3)
        ld c, 8
        ld a, 0
        ld de, 24
        :
            ;Set data
            REPT 8
                ld [hl+], a
            ENDR

            ;Jump to next line or break
            add hl, de
            dec c
            jr nz, :-
        ;
    .attrskip

    ;Set intro flags
    xor a
    ld [w_intro_timer], a
    ld [w_intro_state], a

    ;Set DMG palette
    ldh [rBGP], a

    ;Reenable LCD
    ld hl, rLCDC
    ld a, LCDCF_ON | LCDCF_BGON
    ld [hl], a

    ;Fade in
    .fade
    ld hl, w_intro_timer
    inc [hl]
    ld a, [hl]
    add a, a
    and a, %00111111
    ld c, a
    call intro_faderoutine
    ld a, e
    cp a, $3E
    jr z, .phase2

    ;Wait for Vblank
    xor a
    ldh [rIF], a
    ld a, IEF_VBLANK
    ldh [rIE], a
    halt 
    jr .fade


    ;Wait for Vblank again
    .phase2
    xor a
    ldh [rIF], a
    ld a, IEF_VBLANK
    ldh [rIE], a
    halt 

    ;Now in Vblank, count down
    ld a, %11100100
    ldh [rBGP], a
    ld hl, w_intro_timer
    dec [hl]
    ld a, $E0
    cp a, [hl]
    jr nz, .phase2
    ld a, 1
    ld [w_intro_state], a
    ld [hl], 0

    ;Wait for Vblank (again)
    .fadeout
    xor a
    ldh [rIF], a
    ld a, IEF_VBLANK
    ldh [rIE], a
    halt 

    ;Fade out
    ld hl, w_intro_timer
    dec [hl]
    ld a, [hl]
    add a, a
    and a, %00111111
    ld c, a
    call intro_faderoutine
    ld a, e
    cp a, $00
    jr nz, .fadeout

    ;Wait for Vblank again
    xor a
    ldh [rIF], a
    ld a, IEF_VBLANK
    ldh [rIE], a
    halt

    ;Resume whatever was happening
    ret 
;



; Subroutine for `intro`.
; Modifies CGB- and DMG palette(s).
; Assumes VRAM access.
; Lives in ROM0.
;
; Input:
; - `c`: Opacity
;
; Returns:
; - `e`: Input opacity
intro_faderoutine:

    ;Check if this is a color machine or not
    ldh a, [h_is_color]
    cp a, 0
    jr nz, .color_real

        ;DMG mode
        ld a, c
        ld e, c
        and a, %00001111
        cp a, 0
        ret nz

        ;Set values
        ldh a, [rBGP]
        ld b, a
        ld hl, w_buffer
        ld a, [w_intro_state]
        cp a, 1
        jr z, :+

            ;Fade in
            rr [hl]
            rr b
            rr [hl]
            rr b
            ld a, b
            ldh [rBGP], a
            ret 
        :
            ;Fade out
            sla b
            sla b
            ld a, b
            ldh [rBGP], a
            ret
        ;

    ;CGB mode
    .color_real
        ld a, c
        ld de, w_buffer
        ld hl, intro_palettes + _intro_yellow

        ;Helper macro
        MACRO _fade_color
            add a, \1
            ld l, a
            ld a, [hl+]
            ld [de], a
            inc e
            ld a, [hl]
            ld [de], a
            inc e
            ld a, c
        ENDM

        ;Palette 1, logo
        _fade_color l
        _fade_color low(intro_palettes + _intro_red)
        _fade_color low(intro_palettes + _intro_gray)
        _fade_color low(intro_palettes + _intro_black)

        ;Palette 2, text

        ;White, doesn't need to change
        ld a, $FF
        ld [de], a
        inc e
        ld [de], a
        inc e
        ld a, c
        _fade_color low(intro_palettes + _intro_black)
        _fade_color low(intro_palettes + _intro_gray)
        _fade_color low(intro_palettes + _intro_black)
        ld e, c
        
        ;Copy palettes
        ld hl, w_buffer
        xor a
        call palette_copy_bg
        call palette_copy_bg

        ;Return
        ret 
    ;
;
