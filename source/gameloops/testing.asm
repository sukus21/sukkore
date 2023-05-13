INCLUDE "hardware.inc"

SECTION "GAMELOOP TEST", ROM0

; Does not return.
; Should not be called, but jumped to from another gameloop,
; or after resetting the stack.
; Lives in ROM0.
gameloop_test::
    
    ;Load rectangles
    xor a
    ldh [rVBK], a
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