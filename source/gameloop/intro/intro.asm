INCLUDE "hardware.inc/hardware.inc"
INCLUDE "macro/color.inc"
INCLUDE "macro/memcpy.inc"

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
    
    ; Cleanup
    PURGE iteration
    PURGE red
    PURGE green
    PURGE blue
ENDM

; Raw palette data.
IntroPalettes:
    .yellow     white_fade 31, 31,  0
    .red        white_fade 31,  0,  0
    .gray       white_fade 18, 18, 18
    .black      white_fade  0,  0,  0
    .darkgray   white_fade 10, 10, 10
;

; Tilemap data for logo. 
; Contains a DMG- and CGB version.
IntroTilemap:
    .cgb INCBIN "gameloop/intro/sukus_cgb.tlm"
    .dmg INCBIN "gameloop/intro/sukus_dmg.tlm"
;

; Tileset for logo and font.
IntroTileset:
    INCBIN "gameloop/intro/intro.tls"
.end



; Plays the "Sukus Production" splash screen.
; Routine will keep running until the animation is over, then return.
; Modifies screen data.
; Assumes LCD is turned on.
;
; Destroys: all
Intro::

    ; Initialize vars
    xor a
    ld [wIntroState], a
    ld [wIntroTimer], a

    ; Wait for VBLANK
    call WaitVBlank

    ; There is Vblank!
    ; Disable LCD
    xor a
    ldh [rLCDC], a

    ; Copy font to VRAM
    ld hl, _VRAM + $1000
    ld bc, IntroTileset
    ld de, IntroTileset.end - IntroTileset
    call Memcpy

    ; Copy tilemap
    xor a
    ldh [rVBK], a
    ld hl, _SCRN0
    ld bc, IntroTilemap

    ; DMG tilemap?
    ld a, [wIsCGB]
    or a, a ; cp a, 0
    jr nz, .skip_dmg
        ld bc, IntroTilemap.dmg
    .skip_dmg
    call MemcpyScreen

    ; Check if attributes should be set?
    ld a, [wIsCGB]
    or a, a ; cp a, 0
    jr z, .skipAttr

        ; Set tile attributes
        ld a, 1
        ldh [rVBK], a 
        ld hl, _SCRN0
        ld b, 1
        ld de, $400
        call Memset

        ; Make face use palette 0
        ld hl, _SCRN0 + 6 + (32 * 3)
        ld c, 8
        ld a, 0
        ld de, 24
        .faceLoop
            ; Set data
            REPT 8
                ld [hl+], a
            ENDR

            ; Jump to next line or break
            add hl, de
            dec c
            jr nz, .faceLoop
        ;
        xor a
        ldh [rVBK], a
    .skipAttr

    ; Reenable LCD
    ld hl, rLCDC
    ld a, LCDCF_ON | LCDCF_BGON
    ld [hl], a

    ; Fade in
    ld b, 0
    call IntroFadeIn

    ; Show the still image for a bit
    .fadeNone
        call WaitVBlank

        ; Set default palette
        ld a, %11100100
        ldh [rBGP], a

        ; Count down
        ld hl, wIntroTimer
        dec [hl]
        ld a, $E0
        cp a, [hl]
        jr nz, .fadeNone
    ;

    ; Waiting phase is OVER!
    ; Fade out
    ld b, 0
    call IntroFadeOut

    ; Wait for Vblank again
    call WaitVBlank

    ; Return
    ret
;



; Fades the screen from white.
; Assumes LCD is on.
; Modifies palette data.
;
; Input:
; - `b.0`: Is gbCompo (1 = yes)
;
; Destroys: all
IntroFadeIn:
    ; Set intro flags
    xor a
    ld [wIntroTimer], a
    ld [wIntroState], a
    ldh [rBGP], a
    ldh [rOBP0], a

    ; Set default DMG palettes
    ld a, %11100100
    ld [wIntroPaletteDmg0], a
    ld a, %10010000
    ld [wIntroPaletteDmg1], a

    ; Fade in
    .fadeIn
        call WaitVBlank

        ; Do the fading
        ld hl, wIntroTimer
        inc [hl]
        ld a, [hl]
        add a, a
        and a, %00111111
        ld c, a
        push bc
        call IntroFading
        pop bc

        ; Are we done fading in?
        ld a, e
        cp a, $3E
        jr nz, .fadeIn
    ;

    ; Return
    ret
;



; Fades the screen to white.
; Assumes LCD is on.
; Modifies palette data.
;
; Input:
; - `b.0`: Is gbCompo (1 = yes)
;
; Destroys: all
IntroFadeOut:
    ; Set flags
    xor a
    ld [wIntroTimer], a
    inc a ; ld a, 1
    ld [wIntroState], a

    ; Fade colors out
    .fadeOut
        call WaitVBlank

        ; Fade out
        ld hl, wIntroTimer
        dec [hl]
        ld a, [hl]
        add a, a
        and a, %00111111
        ld c, a
        push bc
        call IntroFading
        pop bc

        ; Are we done yet?
        ld a, c
        cp a, $00
        jr nz, .fadeOut
    ;

    ; Return
    ret
;



; Subroutine for `intro`.
; Modifies CGB- or DMG palettes (depends on mode).
; Assumes VRAM access.
;
; Input:
; - `b.0`: Is gbCompo (1 = true)
; - `c`: Opacity
;
; Saves: `c`
IntroFading:

    ; Check if this is a color machine or not
    ld a, [wIsCGB]
    or a, a ; cp a, 0
    jr nz, .isCGB

        ; DMG mode
        ld a, c
        ld e, c
        and a, %00001111
        or a, a ; cp a, 0
        ret nz

        ; Set values
        ldh a, [rBGP]
        ld d, a
        ldh a, [rOBP0]
        ld e, a
        ld hl, wIntroPaletteDmg0 ; stores DMG palette
        ld a, [wIntroState]
        cp a, 1
        jr z, .fadeOut
            ; Fade in BGP
            ld a, d
            rr [hl]
            rra
            rr [hl]
            rra
            ldh [rBGP], a

            ; Fade in OBP0
            inc l
            ld a, e
            rr [hl]
            rra
            rr [hl]
            rra
            ldh [rOBP0], a

            ; Return
            ret 

        .fadeOut
            ; Fade out BGP
            sla d
            sla d
            ld a, d
            ldh [rBGP], a

            ; Fade out OBP0
            sla e
            sla e
            ld a, d
            ldh [rOBP0], a

            ; Return
            ret
        ;

    ; CGB mode
    .isCGB
        ld a, c
        ld de, wIntroPaletteCgb0
        bit 0, b
        jr nz, .gbCompo

            ; Palette 1, logo
            ld hl, IntroPalettes.yellow
            call IntroFadeColor
            call IntroFadeColor
            call IntroFadeColor
            call IntroFadeColor

            ; Palette 2, text
            ; White, doesn't need to change
            ld a, $FF
            ld [de], a
            inc e
            ld [de], a
            inc e

            ld hl, IntroPalettes.black
            call IntroFadeColor
            ld hl, IntroPalettes.gray
            call IntroFadeColor
            call IntroFadeColor
            
            ; Copy palettes
            ld e, c ; save this from being clobbered
            ld hl, wIntroPaletteCgb0
            xor a
            call PaletteCopyBG
            call PaletteCopyBG
            xor a
            ld hl, wIntroPaletteDgb1
            call PaletteCopyOBJ

            ; Return
            ld c, e
            ret 
        
        .gbCompo
            ; White, no calcs needed
            ld a, $FF
            ld [de], a
            inc e
            ld [de], a
            inc e

            ; The other colors
            ld hl, IntroPalettes.gray
            call IntroFadeColor
            ld hl, IntroPalettes.darkgray
            call IntroFadeColor
            ld hl, IntroPalettes.black
            call IntroFadeColor

            ; Apply palettes
            ld e, c
            ld hl, wIntroPaletteCgb0
            xor a
            call PaletteCopyBG
            xor a
            ld hl, wIntroPaletteCgb0
            call PaletteCopyOBJ

            ; Return
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
IntroFadeColor:
    ; Create proper index
    ld a, c
    add a, l
    ld l, a
    jr nc, :+
        inc h
    :

    ; Copy data
    ld a, [hl+]
    ld [de], a
    inc e
    ld a, [hl-]
    ld [de], a
    inc e

    ; Return
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



SECTION UNION "WRAMX BUFFER", WRAMX, ALIGN[8]
    UNION
        wIntroPaletteDmg0: ds 1
        wIntroPaletteDmg1: ds 1
    NEXTU
        wIntroPaletteCgb0: ds 8
        wIntroPaletteDgb1: ds 8
    ENDU

    ; Intro state.
    ; Only used in `source/intro.asm`.
    wIntroState: ds 0

    ; Intro timer.
    ; Only used in `source/intro.asm`.
    wIntroTimer: ds 0
;
