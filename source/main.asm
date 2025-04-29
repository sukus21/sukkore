INCLUDE "hardware.inc/hardware.inc"


SECTION "NOTICE", ROM0[$0000]
RomMessage:
    db "sukkore", 0
;


SECTION "ENTRY POINT", ROM0[$0100]

; Entrypoint of the program.  
; Do not call manually.  
; Lives in ROM0.
Entrypoint:
    ; Disable interupts and jump
    di
    jp Setup

    ; Space reserved for the header
    ds $4C, $00
;



SECTION "VBLANK INTERRUPT", ROM0[INT_HANDLER_VBLANK]

; Vblank interrupt vector.
; Does nothing, as this is not how I detect Vblank.  
; Does NOT set IME when returning.  
; Lives in ROM0.
VecVblank::
    ret
;



SECTION "STAT INTERRUPT", ROM0[INT_HANDLER_STAT]

; Stat interrupt vector.
; Always assumed to be triggered by LY=LYC.
; Jumps to the routine at `hLYC`.  
; Lives in ROM0.
VecSTAT::
    jp hLYC
;



SECTION "TIMER INTERRUPT", ROM0[INT_HANDLER_TIMER]

; Timer interrupt handler.
; Assumed to only be used for benchmarking.  
; Lives in ROM0.
VecTimer::
    push af
    ldh a, [hBenchmark]
    inc a
    ldh [hBenchmark], a
    pop af
    reti
;



SECTION "METADATA", ROM0

; Contains information about the current build.  
; Lives in ROM0.
MetaVersionString:: db "{__RGBDS_VERSION__}"
MetaBuildTimeLocal:: db __ISO_8601_LOCAL__
MetaBuildTimeUTC:: db __ISO_8601_UTC__



SECTION "MAIN", ROM0

; Entrypoint of game code, jumped to after setup is complete.
; LCD is off at this point.  
; Lives in ROM0.
Main:: 
    ; Darken all palettes
    ld a, $FF
    call PaletteSetBGP
    call PaletteSetOBP0
    call PaletteSetOBP1

    ; Enable LCD with a few flags
    ld a, LCDCF_ON | LCDCF_BLK21 | LCDCF_BGON | LCDCF_WINON
    ldh [rLCDC], a
    
    ; Go to gameloop
    jp GameloopTest
;



; Allocate 256 bytes for the stack, just to be safe
DEF STACK_SIZE EQU $100
SECTION "STACK", WRAM0[_RAMBANK - STACK_SIZE]
    ; Top of stack.
    wStackBegin:: ds STACK_SIZE

    ; Base of stack.
    wStack:: ds $00

    ; Make sure things work out
    ASSERT wStackBegin + STACK_SIZE == _RAMBANK
;
