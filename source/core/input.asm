INCLUDE "hardware.inc"

SECTION "INPUT", ROM0
; Gets the current buttons pressed.
; Bits 0-3 = buttons, bits 4-7 = dpad.
; Lives in ROM0.
;
; Returns:
; - `b`: Byte of buttons held
; - `c`: Byte of buttons pressed
;
; Saves: `e`, `hl`
; Destroys: `af`, `bc`, `d`
input::

    ;Previous buttons pressed
    ldh a, [h_input]
    ld d, a
    ld c, low(rP1)

    ;Set up for reading the buttons
    ld a, P1F_GET_BTN
    ldh [c], a
    ldh [c], a
    nop 

    ;Read the buttons
    ldh a, [c]
    ldh a, [c]
    ldh a, [c]
    ldh a, [c]
    ldh a, [c]
    ldh a, [c]
    ldh a, [c]
    ldh a, [c]
    and a, %00001111
    ld b, a

    ;Set up for reading the DPAD
    ld a, P1F_GET_DPAD
    ldh [c], a
    ldh [c], a
    nop 

    ;Read the DPAD
    ldh a, [c]
    ldh a, [c]
    ldh a, [c]
    ldh a, [c]
    ldh a, [c]
    ldh a, [c]
    ldh a, [c]
    ldh a, [c]
    and a, %00001111
    swap a
    or a, b
    cpl
    ld b, a

    ;Get buttons pressed
    ldh [h_input], a
    ld c, a
    xor a, d
    and a, c
    ld c, a
    ldh [h_input_pressed], a

    ;Reset input register and return
    ld a, $FF
    ldh [rP1], a
    ret
;
