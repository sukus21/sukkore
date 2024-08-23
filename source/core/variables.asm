INCLUDE "hardware.inc/hardware.inc"
INCLUDE "entsys.inc"
INCLUDE "macro/color.inc"
INCLUDE "struct/oam_mirror.inc"
INCLUDE "struct/vqueue.inc"

SECTION "DMA INIT", ROM0

; Initializes DMA routine only.
; Lives in ROM0.
;
; Saves: none
dma_init::
    ld hl, h_dma
    ld bc, var_h + (h_dma - h_variables)
    ld d, h_dma.end - h_dma

    ;Return directly after copying
    jp memcpy_short
;



;Allocate 256 bytes for the stack, just to be safe
DEF STACK_SIZE EQU $100
SECTION "STACK", WRAM0[_RAMBANK - STACK_SIZE]
    ; Top of stack.
    w_stack_begin:: ds STACK_SIZE

    ; Base of stack.
    w_stack:: ds $00

    ;Make sure things work out
    ASSERT w_stack_begin + STACK_SIZE == _RAMBANK
;



SECTION "VARIABLE INITIALIZATION", ROMX

; Initializes ALL variables.
variables_init::

    ;Copy WRAM0 variables
    ld hl, w_variables ;Start of variable space
    ld bc, var_w0 ;Initial variable data
    ld de, var_w0_end - var_w0 ;Data length
    call memcpy

    ;Initialize entity system
    call entsys_clear

    ;Initialize OAM mirrors
    ld hl, w_oam
    ld bc, $00_00
    call memset_short

    ;Copy HRAM variables
    ld hl, h_variables ;Start of variable space
    ld bc, var_h ;Initial variable data
    ld d, var_h_end - var_h ;Data length
    call memcpy_short

    ;Return
    ret
;



; Contains the initial values of all variables in WRAM0.
var_w0:
    LOAD "WRAM0 INITIALIZED", WRAM0, ALIGN[8]
        w_variables:

        ; 256 bytes of memory that can be used for anything.
        w_buffer:: ds 256

        ; Intro state.
        ; Only used in `source/intro.asm`.
        w_intro_state:: db $00

        ; Intro timer.
        ; Only used in `source/intro.asm`.
        w_intro_timer:: db $00

        ; Stack-position to exit an entity's gameloop.
        w_entsys_exit:: dw $0000

        ; Added to camera X-position every frame.
        w_camera_xspeed:: dw $0000

        ; Camera offset in pixels.
        w_camera_xpos:: dw $4000

        ; Color palette for CGB mode.
        w_cgb_palette::
            color_dmg_wht
            color_dmg_ltg
            color_dmg_dkg
            color_dmg_blk
            ASSERT high(w_cgb_palette) == high(w_cgb_palette+7)
        ;
        
        ; Fade value for scene transitions.
        w_fade_state:: db $00
        w_bgp:: dw $0000
        w_obp0:: dw $0000
        w_obp1:: dw $0000

        ; If you just need some address, this will do.
        w_vqueue_writeback:: db $00

        ; Points to the first available vqueue slot.
        w_vqueue_first:: dw w_vqueue

        ; Array of `VQUEUE_T`.
        ; Only first entry is all on the same page.
        w_vqueue:: ds VQUEUE_T * VQUEUE_QUEUE_SIZE, VQUEUE_TYPE_NONE
        .end::
        ASSERT high(w_vqueue) == high(w_vqueue + VQUEUE_T)

        ; Rectangle sprite tile ID
        w_sprite_rectangle:: db $00

        ; Current painter position.
        w_painter_position:: dw w_paint

    ENDL
    var_w0_end:
;



SECTION "HRAM INITIALIZATION", ROM0

; Contains the initial values for all HRAM variables.
var_h:
    LOAD "HRAM VARIABLES", HRAM
        h_variables::

        ; Collision buffer for faster collision routines.
        h_colbuf::
        h_colbuf1:: ds 4
        h_colbuf2:: ds 4

        ; Run OAM DMA with a pre-specified input.  
        ; Interrupts should be disabled while this runs.  
        ; Assumes OAM access.
        ;
        ; Input:
        ; - `a`: High byte of OAM table
        ;
        ; Destroys: `af`
        h_dma::
            ldh [rDMA], a

            ;Wait until transfer is complete
            ld a, 40
            .wait
            dec a
            jr nz, .wait

            ;Return
            ret
            .end
        ;

        ; LYC interrupt jump-to routine.
        ; Contains a single `jp n16` instruction.
        ; The pointer can be overwritten to whatever you want to jump to.
        h_LYC:: jp v_error

        ; When benchmarking, this value is used as the upper 8 bits of the counter.
        h_benchmark:: db $00

        ; Bitfield of buttons held.
        ; Use with `PADB_*` or `PADF_*` from `hardware.inc`.
        h_input:: db $FF

        ; Bitfield of buttons held.
        ; Use with `PADB_*` or `PADF_*` from `hardware.inc`.
        h_input_pressed:: db $00

        ; Is set to non-zero when setup is complete.
        h_setup:: db $FF

        ; Non-zero if CGB-mode is enabled.
        h_is_color:: db $FF

        ; Which ROM-bank is currently switched in.
        h_bank_number:: db $01

        ; RNG variables.
        h_rng::

        ; Seed for the next RNG value.
        h_rng_seed:: db $7E, $B2

        ; Last RNG output.
        h_rng_out:: db $00, $00
    ENDL
    var_h_end:
;



SECTION "WRAMX UNINITIALIZED", WRAMX, ALIGN[8]
    ; Entity system.
    w_entsys::
        DEF entity_current = 0
        REPT ENTSYS_CHUNK_COUNT
            w_entsys_bank_{d:entity_current}: ds 1
            w_entsys_next_{d:entity_current}: ds 1
            w_entsys_step_{d:entity_current}: ds 2
            w_entsys_flags_{d:entity_current}: ds 1
            w_entsys_ypos_{d:entity_current}: ds 2
            w_entsys_xpos_{d:entity_current}: ds 2
            w_entsys_height_{d:entity_current}: ds 1
            w_entsys_width_{d:entity_current}: ds 1
            w_entsys_vars_{d:entity_current}: ds 5
            DEF entity_current += 1
        ENDR
        PURGE entity_current
    w_entsys_end::

    ; Entity system allocation status.
    ; Each bit corresponds to one chunk.
    w_entsys_clusters:: ds ENTSYS_CLUSTER_COUNT

    ; Paint buffer.
    w_paint:: ds $400
;



SECTION "WRAM0 UNITITIALIZED", WRAM0, ALIGN[8]
    ; OAM mirror, used for DMA.
    w_oam:: ds OAMMIRROR_T
    ASSERT low(w_oam) == 0
;
