INCLUDE "hardware.inc/hardware.inc"
INCLUDE "macro/color.inc"
INCLUDE "macro/farcall.inc"
INCLUDE "vqueue/vqueue.inc"
INCLUDE "gameloop/intro/vram.inc"

DEF INTRO_FADE_FRAMES EQU 31
DEF INTRO_WAIT_FRAMES EQU 44


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
;

; Tilemap data for DMG logo.
IntroTilemapDMG: INCBIN "gameloop/intro/sukus_dmg.tlm"
.end

; Tilemap data for DMG logo.
IntroTilemapCGB: INCBIN "gameloop/intro/sukus_cgb.tlm"
.end

; Tileset for logo and font.
IntroTileset: INCBIN "gameloop/intro/intro.tls"
.end

; Prepared VQueue transfers for DMG
IntroVQueueDMG:
    vqueue_prepare PalsetDMG, %1_00000000, %1_00000000, %1_00000000
    vqueue_prepare_memcpy VT_INTRO_TILES, IntroTileset, 0, 0
    vqueue_prepare MemcpyScreen, VM_INTRO_SPLASH, IntroTilemapDMG
;

; Prepared VQueue transfers for CGB
IntroVQueueCGB:
    vqueue_prepare_memcpy VT_INTRO_TILES, IntroTileset, 0, 0
    vqueue_prepare MemcpyScreen, VM_INTRO_SPLASH, IntroTilemapCGB
    vqueue_prepare_memset VM_INTRO_SPLASH, 1, $400, 1, 0
    vqueue_prepare IntroSetFaceAttributes, VM_INTRO_FACE, 0, 0, 0, 0, 1
;



; Sets attributes for the face.
;
; Input:
; - `hl`: face address
IntroSetFaceAttributes:
    ld c, 8
    ld a, 0
    ld de, 24
    .loop
        ; Set data
        REPT 8
            ld [hl+], a
        ENDR

        ; Jump to next line or break
        add hl, de
        dec c
        jr nz, .loop
    ;

    ret
;



; Plays the "Sukus Production" splash screen.
; Routine will keep running until the animation is over, then return.  
; Modifies screen data.  
; Assumes LCD is turned on.
;
; Destroys: all
Intro::

    ; Reset scroll position
    xor a
    ldh [rSCX], a
    ldh [rSCY], a

    ; Reset variables
    xor a
    ld [wIntroTimer], a

    ; Set up VQueue transfers
    ld a, [wIsCGB]
    or a, a ; cp a, 0
    jr z, .isDMG
        ld de, IntroVQueueCGB
        ld b, 4
        call VQueueEnqueueMulti
        jr .queued
    .isDMG
        ld de, IntroVQueueDMG
        ld b, 3
        call VQueueEnqueueMulti
    .queued

    ; Wait for transfers to complete
    call GameloopLoading
        
    ; Wait for VBlank to enable LCD features
    call WaitVBlank
    ld a, LCDCF_ON | LCDCF_BGON
    ldh [rLCDC], a

    ; Set target DMG palettes
    ld a, %11100100
    ld [wIntroPaletteDMG0], a
    ld a, %10010000
    ld [wIntroPaletteDMG1], a

    ; Do all the things
    call IntroFadeIn
    call IntroWait
    call IntroFadeOut

    ; Before we leave, let's clear the tilemap attributes
    ld de, ColorVQueueResetAttributes
    ld b, 1
    call VQueueEnqueueMulti
    call GameloopLoading

    ; Ok, we are done
    ret
;



; Fades the screen from white.
; Assumes LCD is on.
; Modifies palette data.
;
; Destroys: all
IntroFadeIn:
    ; Initialize color and variables
    xor a
    ld [wIntroTimer], a

    ; Fade in
    .loop
        call WaitVBlank

        ; Do the fading
        ld hl, wIntroTimer
        inc [hl]
        ld a, [hl]
        add a, a
        ld bc, %00111111
        and a, c
        ld c, a
        call IntroFading

        ; Are we done fading in?
        ld a, [wIntroTimer]
        cp a, INTRO_FADE_FRAMES
        jr nz, .loop
    ;

    ; Return
    ret
;



; Fades the screen from white.
; Assumes LCD is on.
; Modifies palette data.
;
; Destroys: all
IntroFadeOut:
    ; Initialize color and variables
    xor a
    ld [wIntroTimer], a

    ; Fade in
    .loop
        call WaitVBlank

        ; Do the fading
        ld hl, wIntroTimer
        inc [hl]
        ld a, INTRO_FADE_FRAMES
        sub a, [hl]
        add a, a
        ld bc, %00111111
        and a, c
        ld c, a
        call IntroFading

        ; Are we done fading in?
        ld a, [wIntroTimer]
        cp a, INTRO_FADE_FRAMES
        jr nz, .loop
    ;

    ; Return
    ret
;



; Waits for a while.  
; Assumes the LCD is on.
IntroWait:
    xor a
    ld [wIntroTimer], a
    
    .loop
        call WaitVBlank

        ld hl, wIntroTimer
        inc [hl]
        ld a, [hl]
        cp a, INTRO_WAIT_FRAMES
        jr nz, .loop
    ;

    ; Return
    ret
;



; Subroutine for `intro`.  
; Modifies palettes.  
; Assumes VRAM access.
;
; Input:
; - `c`: Opacity (0 - 31)
IntroFading:

    ; Check if this is a color machine or not
    ld a, [wIsCGB]
    or a, a ; cp a, 0
    jr nz, .isCGB

        ; Flatten opacity to a 2-bit value -> C
        ld a, c
        swap a
        and a, %11
        ld c, a
        ld a, 3
        sub a, c
        ld c, a

        ; Color to modify -> D
        ; Result -> E
        ld a, [wIntroPaletteDMG0]
        call IntroFadeColorDMG
        ldh [rBGP], a
        ld a, [wIntroPaletteDMG1]
        call IntroFadeColorDMG
        ldh [rOBP0], a

        ; And we done
        ret
    ;

    ; CGB mode
    .isCGB
        ld a, c
        ld de, wIntroPaletteCGB0

        ; Palette 1, logo
        ld hl, IntroPalettes.yellow
        call IntroFadeColorCGB
        call IntroFadeColorCGB
        call IntroFadeColorCGB
        call IntroFadeColorCGB

        ; Palette 2, text
        ; White, doesn't need to change
        ld a, $FF
        ld [de], a
        inc e
        ld [de], a
        inc e

        ld hl, IntroPalettes.black
        call IntroFadeColorCGB
        ld hl, IntroPalettes.gray
        call IntroFadeColorCGB
        call IntroFadeColorCGB
        
        ; Copy palettes
        ld hl, wIntroPaletteCGB0
        xor a
        call PaletteCopyBG
        call PaletteCopyBG
        xor a
        ld hl, wIntroPaletteCGB1
        call PaletteCopyOBJ

        ; Return
        ret
    ;
;



; Helper routine for fading.
; Only used for CGB colors.
;
; Input:
; - `a`: Source palette
; - `c`: Opacity (0-3)
;
; Returns:
; - `a`: Result palette
;
; Saves: `c`
IntroFadeColorDMG:
    ld b, a
    ld e, 0
    ld d, 4

    .loop
        ; Read color -> A
        ld a, b
        rrc b
        rrc b

        ; Modify color
        and a, %11
        sub a, c
        jr nc, :+
            xor a
        :

        ; Write color back
        or a, e
        rrca
        rrca
        ld e, a

        dec d
        jr nz, .loop
    ;

    ; Done
    ld a, e
    ret
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
IntroFadeColorCGB:
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



SECTION UNION "GAMELOOP UNION", WRAM0, ALIGN[8]
    UNION
        wIntroPaletteDMG0: ds 1
        wIntroPaletteDMG1: ds 1
    NEXTU
        wIntroPaletteCGB0: ds 8
        wIntroPaletteCGB1: ds 8
    ENDU

    ; Intro timer.
    wIntroTimer: ds 0
;
