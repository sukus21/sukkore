INCLUDE "hardware.inc/hardware.inc"
INCLUDE "macro/memcpy.inc"

SECTION "OAM DMA", ROM0

; Initializes the OAM DMA routine.  
; Lives in ROM0.
;
; Saves: none
OamDmaInit::
    memcpy_label DMARoutine, hDMA
    ret
;

DMARoutine:
LOAD "OAM DMA ROUTINE", HRAM

    ; Run OAM DMA with a pre-specified input.  
    ; Interrupts should be disabled while this runs.  
    ; Assumes OAM access.
    ;
    ; Input:
    ; - `a`: High byte of OAM mirror
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
    ;



    ; LYC interrupt jump-to routine.
    ; Contains a single `jp n16` instruction.
    ; The pointer can be overwritten to whatever you want to jump to.
    hLYC:: jp vError
ENDL
.end
