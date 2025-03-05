INCLUDE "hardware.inc/hardware.inc"

SECTION "INPUT", ROM0
; Gets the current buttons pressed.
; Bits 0-3 = buttons, bits 4-7 = dpad.  
; Lives in ROM0.
;
; Returns:
; - `b`: Byte of buttons held
; - `c`: Byte of buttons pressed
;
; Saves: `de`, `hl`  
; Destroys: `af`, `bc`
ReadInput::

    ; Set up for reading the buttons
    ld c, low(rP1)
    ld a, P1F_GET_BTN
    ldh [c], a
    ldh [c], a
    nop 

    ; Read the buttons
    REPT 8
        ldh a, [c]
    ENDR
    and a, %00001111
    ld b, a

    ; Set up for reading the DPAD
    ld a, P1F_GET_DPAD
    ldh [c], a
    ldh [c], a
    nop 

    ; Read the DPAD
    REPT 8
        ldh a, [c]
    ENDR
    and a, %00001111
    swap a
    or a, b
    cpl

    ; Get buttons pressed
    ld b, a
    ldh a, [hInput]
    xor a, b
    and a, b
    ldh [hInputPressed], a
    ld c, a
    ld a, b
    ldh [hInput], a

    ; Reset input register and return
    ld a, $FF
    ldh [rP1], a
    ret
;
