INCLUDE "hardware.inc"

;Allocate 256 bytes for the stack, just to be safe
stack_size equ $100
SECTION "STACK", WRAM0[$D000 - stack_size]
    w_stack_begin:: ds stack_size ;Top of stack
    w_stack:: ds $00 ;Base of stack
    ASSERT w_stack_begin + stack_size == $D000 ;Make sure things work out
;



SECTION "VARIABLE INITIALIZATION", ROMX

; Initializes ALL variables.
variables_init::

    ;Copy WRAM0 variables
    ld hl, w_variables ;Start of variable space
    ld bc, var_w0 ;Initial variable data
    ld de, var_w0_end - var_w0 ;Data length
    call memcpy

    ;Copy WRAMX variables
    ld hl, w_entsys ;Start of variable space
    ld bc, var_wx ;Initial variable data
    ld de, var_wx_end - var_wx ;Data length
    call memcpy

    ;Copy HRAM variables
    ld hl, h_variables ;Start of variable space
    ld bc, var_h ;Initial variable data
    ld de, var_h_end - var_h ;Data length
    call memcpy

    ;Return
    ret
;



; Contains the initial values of all variables in WRAM0.
var_w0:
    LOAD "WRAM0 VARIABLES", WRAM0, ALIGN[8]
        w_variables:

        ;256 bytes of memory that can be used for anything.
        w_buffer:: ds 256

        ;Sprite stuff
        w_oam_mirror:: ds $A4, $00
        ASSERT low(w_oam_mirror) == 0

        ;That intro thing
        w_intro_state:: db $00
        w_intro_timer:: db $00

        ;Entity system variables
        w_entsys_first16:: dw $0000
        w_entsys_first32:: dw $0000
        w_entsys_first64:: dw w_entsys
    ENDL
    var_w0_end:
;

; Contains the initial values of all variables in WRAMX.
var_wx:
    LOAD "WRAMX VARIABLES", WRAMX, ALIGN[8]
        w_entsys::
            REPT 256
                w_entsys_bank_\@: db $00
                w_entsys_next_\@: db $40
                w_entsys_step_\@: dw $0000
                ds 12
            ENDR
        ;
    ENDL
    var_wx_end:
;

; Contains the initial values for all HRAM variables.
var_h:
    LOAD "HRAM VARIABLES", HRAM
        h_variables::

        ;OAM DMA routine in HRAM
        h_dma_routine::

            ;Initialize OAM DMA
            ld a, HIGH(w_oam_mirror)
            ldh [rDMA], a

            ;Wait until transfer is complete
            ld a, 40
            .wait
            dec a
            jr nz, .wait

            ;Return
            ret
        ;

        ;Input
        h_input:: db $FF
        h_input_pressed:: db $00
        ;

        ;Important system variables
        h_setup:: db $FF
        h_is_color:: db $FF
        h_bank_number:: db $01
        h_sprite_slot:: db $00
        ;

        ;Shadow scrolling registers
        h_scx:: db $00
        h_scy:: db $00

        ;RNG stuff
        h_rng::
        h_rng_seed:: db $7E, $B2
        h_rng_out:: db $00, $00
        ;
    ENDL
    var_h_end:
;
