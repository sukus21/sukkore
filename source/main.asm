INCLUDE "hardware.inc/hardware.inc"


SECTION "NOTICE", ROM0[$0000]
rom_message:
    db "sukkore", 0
;


SECTION "ENTRY POINT", ROM0[$0100]

; Entrypoint of the program.  
; Do not call manually.  
; Lives in ROM0.
entrypoint:
    ;Disable interupts and jump
    di
    jp setup

    ;Space reserved for the header
    ds $4C, $00
;



SECTION "VBLANK INTERRUPT", ROM0[INT_HANDLER_VBLANK]

; Vblank interrupt vector.
; Does nothing, as this is not how I detect Vblank.  
; Does NOT set IME when returning.  
; Lives in ROM0.
v_vblank::
    ret
;



SECTION "STAT INTERRUPT", ROM0[INT_HANDLER_STAT]

; Stat interrupt vector.
; Always assumed to be triggered by LY=LYC.
; Jumps to the routine at `h_LYC`.  
; Lives in ROM0.
v_stat::
    jp h_LYC
;



SECTION "TIMER INTERRUPT", ROM0[INT_HANDLER_TIMER]

; Timer interrupt handler.
; Assumed to only be used for benchmarking.  
; Lives in ROM0.
v_timer::
    push af
    ldh a, [h_benchmark]
    inc a
    ldh [h_benchmark], a
    pop af
    reti
;



SECTION "METADATA", ROM0

; Contains information about the current build.  
; Lives in ROM0.
meta_version_string:: db "{__RGBDS_VERSION__}"
meta_build_time_local:: db __ISO_8601_LOCAL__
meta_build_time_utc:: db __ISO_8601_UTC__



SECTION "MAIN", ROM0

; Entrypoint of game code, jumped to after setup is complete.
; LCD is off at this point.  
; Lives in ROM0.
main:: 
    ;Darken all palettes
    ld a, $FF
    call set_palette_bgp
    call set_palette_obp0
    call set_palette_obp1

    ;Enable LCD with a few flags
    ld a, LCDCF_ON | LCDCF_BLK21 | LCDCF_BGON | LCDCF_WINON
    ldh [rLCDC], a
    
    ;Go to gameloop
    jp gameloop_test
;
