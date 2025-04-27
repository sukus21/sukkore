INCLUDE "hardware.inc/hardware.inc"
INCLUDE "entsys/entsys.inc"
INCLUDE "macro/color.inc"
INCLUDE "macro/memcpy.inc"
INCLUDE "struct/oam_mirror.inc"
INCLUDE "vqueue/vqueue.inc"

SECTION "DMA INIT", ROM0

; Initializes DMA routine only.
; Lives in ROM0.
;
; Saves: none
dma_init::
    ld hl, hDMA
    ld bc, VarH + (hDMA - hVariables)
    ld d, hDMA.end - hDMA

    ; Return directly after copying
    jp MemcpyShort
;



; Allocate 256 bytes for the stack, just to be safe
DEF STACK_SIZE EQU $100
SECTION "STACK", WRAM0[_RAMBANK - STACK_SIZE]
    ; Top of stack.
    w_stack_begin:: ds STACK_SIZE

    ; Base of stack.
    w_stack:: ds $00

    ; Make sure things work out
    ASSERT w_stack_begin + STACK_SIZE == _RAMBANK
;



SECTION "VARIABLE INITIALIZATION", ROMX

; Initializes ALL variables.
VariablesInit::

    ; Copy WRAM0 and HRAM variables
    memcpy_label VarW0, wVariables
    memcpy_label VarH, hVariables

    ; Initialize entity system
    call EntsysClear

    ; Initialize OAM mirror
    ld hl, wOAM
    ld bc, $00_00
    call MemsetShort

    ; Return
    ret
;



; Contains the initial values of all variables in WRAM0.
VarW0:
    LOAD "WRAM0 INITIALIZED", WRAM0, ALIGN[8]
        wVariables:

        ; Stack-position to exit an entity's gameloop.
        wEntsysExit:: dw $0000

        ; Color palette for CGB mode.
        wPaletteCGB::
            color_dmg_wht
            color_dmg_ltg
            color_dmg_dkg
            color_dmg_blk
            ASSERT high(wPaletteCGB) == high(wPaletteCGB+7)
        ;

        ; Fade value for scene transitions.
        wFadeState:: db $00
        wPaletteBGP:: dw $0000
        wPaletteOBP0:: dw $0000
        wPaletteOBP1:: dw $0000

        ; Rectangle sprite tile ID
        wSpriteRectangle:: db $00

        ; Current painter position.
        wPainterPosition:: dw wPaint

    ENDL
.end



SECTION "HRAM INITIALIZATION", ROM0

; Contains the initial values for all HRAM variables.
VarH:
    LOAD "HRAM VARIABLES", HRAM
        hVariables::

        ; Collision buffer for faster collision routines.
        hColBuf::
        hColBuf1:: ds 4
        hColBuf2:: ds 4

        ; Sprite template attributes
        hSpriteAttr:: ds 1

        ; Sprite template bitmask
        hSpriteBits:: ds 1

        ; Sprite template loop counter
        hSpriteIter:: ds 1

        ; Sprite template X-delta
        hSpriteXdelta:: ds 1

        ; Sprite template Y-delta
        hSpriteYdelta:: ds 1

        ; Run OAM DMA with a pre-specified input.  
        ; Interrupts should be disabled while this runs.  
        ; Assumes OAM access.
        ;
        ; Input:
        ; - `a`: High byte of OAM table
        ;
        ; Destroys: `af`
        hDMA::
            ldh [rDMA], a

            ; Wait until transfer is complete
            ld a, 40
            .wait
            dec a
            jr nz, .wait

            ; Return
            ret
            .end
        ;

        ; LYC interrupt jump-to routine.
        ; Contains a single `jp n16` instruction.
        ; The pointer can be overwritten to whatever you want to jump to.
        hLYC:: jp vError

        ; When benchmarking, this value is used as the upper 8 bits of the counter.
        hBenchmark:: db $00

        ; Bitfield of buttons held.
        ; Use with `PADB_*` or `PADF_*` from `hardware.inc`.
        hInput:: db $FF

        ; Bitfield of buttons held.
        ; Use with `PADB_*` or `PADF_*` from `hardware.inc`.
        hInputPressed:: db $00

        ; Is set to non-zero when setup is complete.
        hSetup:: db $FF

        ; Non-zero if CGB-mode is enabled.
        hIsCGB:: db $FF

        ; Which ROM-bank is currently switched in.
        hBankNumber:: db $01

        ; RNG variables.
        hRNG::

        ; Seed for the next RNG value.
        hRNGSeed:: db $7E, $B2

        ; Last RNG output.
        hRNGOut:: db $00, $00
    ENDL
.end



SECTION "WRAMX UNINITIALIZED", WRAMX, ALIGN[8]

    ; Entity system.
    wEntsys::
    FOR ENTITY_CURRENT, ENTSYS_CHUNK_COUNT
        .bank{d:ENTITY_CURRENT}: ds 1
        .next{d:ENTITY_CURRENT}: ds 1
        .step{d:ENTITY_CURRENT}: ds 2
        .flags{d:ENTITY_CURRENT}: ds 1
        .ypos{d:ENTITY_CURRENT}: ds 2
        .xpos{d:ENTITY_CURRENT}: ds 2
        .height{d:ENTITY_CURRENT}: ds 1
        .width{d:ENTITY_CURRENT}: ds 1
        .vars{d:ENTITY_CURRENT}: ds 5
    ENDR
    .end::

    ; Entity system allocation status.
    ; Each bit corresponds to one chunk.
    wEntsysClusters:: ds ENTSYS_CLUSTER_COUNT

    ; Paint buffer.
    wPaint:: ds $400
;



SECTION UNION "WRAMX BUFFER", WRAMX, ALIGN[8]

    ; 256 bytes of memory that can be used for anything.
    wBuffer: ds 256
;



SECTION "WRAM0 UNITITIALIZED", WRAM0, ALIGN[8]
    ; OAM mirror, used for DMA.
    wOAM:: ds OAMMIRROR_T
    ASSERT low(wOAM) == 0
;
