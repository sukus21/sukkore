INCLUDE "hardware.inc"



SECTION "ENTRY POINT", ROM0[$0100]
    
    ;Disable interupts and jump
    di
    jp setup

    ;Space reserved for the header
    ds $4C, $00
;



SECTION "MAIN", ROM0[$0150]

; Entrypoint of game code, jumped to after setup is complete.
; Lives in ROM0.
main::
    call rectangle_load

    ;Enable Vblank interrupt
    xor a
    ldh [rIF], a
    ld a, IEF_VBLANK
    ldh [rIE], a

    ;Clear OAM
    call h_dma_routine

    ;Initial rectangle things
    ld hl, w_buffer
    ld a, $10
    ld [hl+], a
    ld a, $13
    ld [hl+], a
    ld a, $2C
    ld [hl+], a
    ld a, 13
    ld [hl+], a
    ld a, $10
    ld [hl+], a
    ld a, $13
    ld [hl+], a
    ld a, $2C
    ld [hl+], a
    ld a, 13
    ld [hl+], a

    ;Enable LCD
    ld a, LCDCF_ON | LCDCF_OBJON
    ldh [rLCDC], a
    halt 

    ;Main loop
    .loop
    call input
    ld h, b
    
    ;Do rectangle things
    ldh a, [h_input]
    ld e, a
    bit PADB_B, a
    jr z, :+
    ld e, 0
    :
    ld hl, w_buffer
    call rectangle_movement

    ;Same but for rectangle 2
    ldh a, [h_input]
    ld e, a
    bit PADB_B, a
    jr nz, :+
    ld e, 0
    :
    ld hl, w_buffer+4
    call rectangle_movement

    ;Wait for Vblank
    call sprite_finish
    xor a
    ldh [rIF], a
    halt 

    ;Draw requested rectangles
    call h_dma_routine
    jr .loop
;
