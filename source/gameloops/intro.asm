INCLUDE "hardware.inc"
INCLUDE "macros/color.inc"
INCLUDE "macros/memcpy.inc"

SECTION "INTRO", ROMX, ALIGN[8]

; Creates 32 colors, fading from white to the given color.
;
; Input:
; - 1: Red (0-31)
; - 2: Green (0-31)
; - 3: Blue (0-31)
MACRO white_fade
    DEF iteration = 1.0
    REPT 32
        DEF red = \1.0 + MUL((31.0 - \1.0), iteration)
        DEF green = \2.0 + MUL((31.0 - \2.0), iteration)
        DEF blue = \3.0 + MUL((31.0 - \3.0), iteration)
        color_t red >> 16, green >> 16, blue >> 16
        DEF iteration -= DIV(1.0, 31.0)
    ENDR
    
    ;Cleanup
    PURGE iteration
    PURGE red
    PURGE green
    PURGE blue
ENDM

; Raw palette data.
intro_palettes:
    .yellow     white_fade 31, 31,  0
    .red        white_fade 31,  0,  0
    .gray       white_fade 18, 18, 18
    .black      white_fade  0,  0,  0
    .darkgray   white_fade 10, 10, 10
;

; Tilemap data for logo. 
; Contains a DMG- and CGB version.
intro_tilemap:
    .cgb INCBIN "intro/sukus_cgb.tlm"
    .dmg INCBIN "intro/sukus_dmg.tlm"
;

; Tileset for logo and font.
intro_tileset:
    INCBIN "intro/intro.tls"
    .end
;



; Plays the "Sukus Production" splash screen.
; Routine will keep running until the animation is over, then return.
; Modifies screen data.
; Assumes LCD is turned on.
;
; Destroys: all
intro::

    ;Wait for VBLANK
    xor a
    ldh [rIF], a
    ld a, IEF_VBLANK
    ldh [rIE], a
    halt
    nop

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
    or a, a ;cp a, 0
    jr nz, .skip_dmg
        ld bc, intro_tilemap.dmg
    .skip_dmg
    call mapcopy_screen

    ;Check if attributes should be set?
    ldh a, [h_is_color]
    or a, a ;cp a, 0
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
        .face_loop
            ;Set data
            REPT 8
                ld [hl+], a
            ENDR

            ;Jump to next line or break
            add hl, de
            dec c
            jr nz, .face_loop
        ;
        xor a
        ldh [rVBK], a
    .attrskip

    ;Reenable LCD
    ld hl, rLCDC
    ld a, LCDCF_ON | LCDCF_BGON
    ld [hl], a

    ;Fade in
    ld b, 0
    call intro_fadein

    ;Show the still image for a bit
    .fadenone
        ;Wait for Vblank
        xor a
        ldh [rIF], a
        ld a, IEF_VBLANK
        ldh [rIE], a
        halt
        nop

        ;Set default palette
        ld a, %11100100
        ldh [rBGP], a

        ;Count down
        ld hl, w_intro_timer
        dec [hl]
        ld a, $E0
        cp a, [hl]
        jr nz, .fadenone
    ;

    ;Waiting phase is OVER!
    ;Fade out
    ld b, 0
    call intro_fadeout

    ;Wait for Vblank again
    xor a
    ldh [rIF], a
    ld a, IEF_VBLANK
    ldh [rIE], a
    halt
    nop

    ;Return
    ret
;



; Fades the screen from white.
; Assumes LCD is on.
; Modifies palette data.
;
; Input:
; - `b.0`: Is GBcompo (1 = yes)
;
; Destroys: all
intro_fadein:
    ;Set intro flags
    xor a
    ld [w_intro_timer], a
    ld [w_intro_state], a
    ldh [rBGP], a
    ldh [rOBP0], a

    ;Set default DMG palettes
    ld a, %11100100
    ld [w_buffer], a
    ld a, %10010000
    ld [w_buffer+1], a

    ;Fade in
    .fadein
        ;Wait for Vblank
        xor a
        ldh [rIF], a
        ld a, IEF_VBLANK
        ldh [rIE], a
        halt
        nop

        ;Do the fading
        ld hl, w_intro_timer
        inc [hl]
        ld a, [hl]
        add a, a
        and a, %00111111
        ld c, a
        push bc
        call intro_fading
        pop bc

        ;Are we done fading in?
        ld a, e
        cp a, $3E
        jr nz, .fadein
    ;

    ;Return
    ret
;



; Fades the screen to white.
; Assumes LCD is on.
; Modifies palette data.
;
; Input:
; - `b.0`: Is GBcompo (1 = yes)
;
; Destroys: all
intro_fadeout:
    ;Set flags
    xor a
    ld [w_intro_timer], a
    inc a ;ld a, 1
    ld [w_intro_state], a

    ;Fade colors out
    .fadeout
        ;Wait for Vblank (again)
        xor a
        ldh [rIF], a
        ld a, IEF_VBLANK
        ldh [rIE], a
        halt
        nop

        ;Fade out
        ld hl, w_intro_timer
        dec [hl]
        ld a, [hl]
        add a, a
        and a, %00111111
        ld c, a
        push bc
        call intro_fading
        pop bc

        ;Are we done yet?
        ld a, c
        cp a, $00
        jr nz, .fadeout
    ;

    ;Return
    ret
;



; Subroutine for `intro`.
; Modifies CGB- or DMG palettes (depends on mode).
; Assumes VRAM access.
;
; Input:
; - `b.0`: Is GBcompo (1 = true)
; - `c`: Opacity
;
; Saves: `c`
intro_fading:

    ;Check if this is a color machine or not
    ldh a, [h_is_color]
    or a, a ;cp a, 0
    jr nz, .color_real

        ;DMG mode
        ld a, c
        ld e, c
        and a, %00001111
        or a, a ;cp a, 0
        ret nz

        ;Set values
        ldh a, [rBGP]
        ld d, a
        ldh a, [rOBP0]
        ld e, a
        ld hl, w_buffer ;stores DMG palette
        ld a, [w_intro_state]
        cp a, 1
        jr z, .fadeout
            ;Fade in BGP
            ld a, d
            rr [hl]
            rra
            rr [hl]
            rra
            ldh [rBGP], a

            ;Fade in OBP0
            inc l
            ld a, e
            rr [hl]
            rra
            rr [hl]
            rra
            ldh [rOBP0], a

            ;Return
            ret 

        .fadeout
            ;Fade out BGP
            sla d
            sla d
            ld a, d
            ldh [rBGP], a

            ;Fade out OBP0
            sla e
            sla e
            ld a, d
            ldh [rOBP0], a

            ;Return
            ret
        ;

    ;CGB mode
    .color_real
        ld a, c
        ld de, w_buffer
        bit 0, b
        jr nz, .gbcompo

            ;Palette 1, logo
            ld hl, intro_palettes.yellow
            call intro_fade_color
            call intro_fade_color
            call intro_fade_color
            call intro_fade_color

            ;Palette 2, text
            ;White, doesn't need to change
            ld a, $FF
            ld [de], a
            inc e
            ld [de], a
            inc e

            ld hl, intro_palettes.black
            call intro_fade_color
            ld hl, intro_palettes.gray
            call intro_fade_color
            call intro_fade_color
            
            ;Copy palettes
            ld e, c ;save this from being clobbered
            ld hl, w_buffer
            xor a
            call palette_copy_bg
            call palette_copy_bg
            xor a
            ld hl, w_buffer + $08
            call palette_copy_spr

            ;Return
            ld c, e
            ret 
        
        .gbcompo
            ;White, no calcs needed
            ld a, $FF
            ld [de], a
            inc e
            ld [de], a
            inc e

            ;The other colors
            ld hl, intro_palettes.gray
            call intro_fade_color
            ld hl, intro_palettes.darkgray
            call intro_fade_color
            ld hl, intro_palettes.black
            call intro_fade_color

            ;Apply palettes
            ld e, c
            ld hl, w_buffer
            xor a
            call palette_copy_bg
            xor a
            ld l, low(w_buffer)
            call palette_copy_spr

            ;Return
            ld c, e
            ret
        ;
    ;
;



; Helper routine for fading.
; Only used for CGB colors.
;
; Input:
; - `c`: Opacity
; - `de`: Color desination
; - `hl`: Color fade table
;
; Saves: `bc`
intro_fade_color:
    ;Create proper index
    ld a, c
    add a, l
    ld l, a
    jr nc, :+
        inc h
    :

    ;Copy data
    ld a, [hl+]
    ld [de], a
    inc e
    ld a, [hl-]
    ld [de], a
    inc e

    ;Return
    ld a, l
    sub a, c
    jr nc, :+
        dec h
    :
    add a, $40
    ld l, a
    ret nc
    inc h
    ret
;



; Small custom memory copier.
; 20*18 (360) bytes, enough to fill the screen.
; Every 20 copied bytes, 12 bytes are skipped.
;
; Input:
; - `hl`: Destination
; - `bc`: Source
;
; Destroys: `de`
mapcopy_screen::
    ld e, 18

    .loop
        ;Copy tilemap to screen, 20 tiles at a time
        ld d, 20
        memcpy_custom hl, bc, d

        ;Skip data pointer ahead
        ld a, l
        add a, 32 - 20
        jr nc, :+
            inc h
        :
        ld l, a

        ;End of loop
        dec e
        jr nz, .loop
    ;

    ;Return
    ret
;
