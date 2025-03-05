INCLUDE "hardware.inc/hardware.inc"
INCLUDE "macro/color.inc"
INCLUDE "macro/farcall.inc"

SECTION "SETUP", ROM0

; Supposed to run first thing when the game starts.
; Lives in ROM0.
Setup::
    ld sp, w_stack
    call dma_init

    ; Is this GBC hardware?
    call DetectCGB

    ; What did we get?
    ldh [hIsCGB], a
    cp a, 0
    jr z, .isDMG
        ; CGB machine
        jr .isCGB

    .isDMG
        ; DMG machine
        ; fallthrough

    .isCGB

    ; Does game require GBC functionality?
    ld a, [$0143]
    cp a, CART_COMPATIBLE_GBC
    jr nz, :+

        ; Game DOES require GBC functionality
        ldh a, [hIsCGB]
        cp a, 0
        jr nz, :+
        ld hl, ErrorColorRequired
        rst vError
    :

    ; Set setup variable to true
    ld a, 1
    ldh [hSetup], a

    ; Do my intro with the logo
    xor a
    ldh [rSCX], a
    ldh [rSCY], a
    farcall Intro

    ; Skip GBC detection and RNG reset.
    ; Lives in ROM0.
    .partial::

    ; Wait for Vblank
    di
    xor a
    ldh [rIF], a
    ld a, IEF_VBLANK
    ldh [rIE], a
    halt
    nop

    ; Disable LCD
    ld hl, rLCDC
    res LCDCB_ON, [hl]

    ; Reset stack pointer
    ld sp, w_stack

    ; Check if RNG seed should be saved
    ldh a, [hSetup]
    cp a, 0
    push af
    jr z, .skipRNG

        ; Save RNG values to stack
        ld hl, hRNG
        ld a, [hl+]
        ld b, a
        ld a, [hl+]
        ld c, a
        ld a, [hl+]
        ld d, a
        ld e, [hl]

        ; Stack shuffling
        pop af
        push bc
        push de
        push af
    .skipRNG

    ; Setup ALL variables
    farcall VariablesInit

    ; Put RNG seed back maybe
    pop af
    jr z, .ignoreRNG
        
        ; Retrieve RNG values from stack
        pop de
        pop bc
        ld hl, hRNG
        ld a, b
        ld [hl+], a
        ld a, c
        ld [hl+], a
        ld a, d
        ld [hl+], a
        ld [hl], e
    .ignoreRNG

    ; Jump to main
    jp Main
;
