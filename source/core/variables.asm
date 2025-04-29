INCLUDE "hardware.inc/hardware.inc"
INCLUDE "entsys/entsys.inc"
INCLUDE "macro/color.inc"
INCLUDE "macro/memcpy.inc"
INCLUDE "vqueue/vqueue.inc"

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

        ; Fade value for scene transitions.
        wFadeState:: db $00

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

        ; When benchmarking, this value is used as the upper 8 bits of the counter.
        hBenchmark:: db $00

        ; Is set to non-zero when setup is complete.
        hSetup:: db $FF

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
