INCLUDE "hardware.inc/hardware.inc"
INCLUDE "macro/color.inc"
INCLUDE "macro/farcall.inc"

SECTION "SETUP", ROM0

; Supposed to run first thing when the game starts.
; Lives in ROM0.
setup::
    ld sp, w_stack
    call dma_init

    ;Is this GBC hardware?
    call detect_gbc

    ;What did we get?
    ldh [h_is_color], a
    cp a, 0
    jr z, .is_DMG
        
        ;CGB machine
        jr .is_CGB

    .is_DMG
        ;DMG machine
        ;fallthrough

    .is_CGB

    ;Does game require GBC functionality?
    ld a, [$0143]
    cp a, CART_COMPATIBLE_GBC
    jr nz, :+

        ;Game DOES require GBC functionality
        ldh a, [h_is_color]
        cp a, 0
        jr nz, :+
        ld hl, error_color_required
        rst v_error
    :

    ;Set setup variable to true
    ld a, 1
    ldh [h_setup], a

    ;Do my intro with the logo
    xor a
    ldh [rSCX], a
    ldh [rSCY], a
    farcall intro

    ; Skip GBC detection and RNG reset.
    ; Lives in ROM0.
    .partial::

    ;Wait for Vblank
    di
    xor a
    ldh [rIF], a
    ld a, IEF_VBLANK
    ldh [rIE], a
    halt
    nop

    ;Disable LCD
    ld hl, rLCDC
    res LCDCB_ON, [hl]

    ;Reset stack pointer
    ld sp, w_stack

    ;Check if RNG seed should be saved
    ldh a, [h_setup]
    cp a, 0
    push af
    jr z, .rngskip

        ;Save RNG values to stack
        ld hl, h_rng
        ld a, [hl+]
        ld b, a
        ld a, [hl+]
        ld c, a
        ld a, [hl+]
        ld d, a
        ld e, [hl]

        ;Stack shuffling
        pop af
        push bc
        push de
        push af
    .rngskip

    ;Setup ALL variables
    farcall variables_init

    ;Put RNG seed back maybe
    pop af
    jr z, .rngignore
        
        ;Retrieve RNG values from stack
        pop de
        pop bc
        ld hl, h_rng
        ld a, b
        ld [hl+], a
        ld a, c
        ld [hl+], a
        ld a, d
        ld [hl+], a
        ld [hl], e
    .rngignore

    ;Jump to main
    jp main
;
