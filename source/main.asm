INCLUDE "hardware.inc"



SECTION "ENTRY POINT", ROM0[$0100]
    
    ;Disable interupts and jump
    di
    jp setup

    ;Space reserved for the header
    ds $4C, $00
;



SECTION "MAIN", ROM0[$0150]

; Entrypoint of game code, jumped to after setup is complete.
; Lives in ROM0.
main::
    
    ;Endless loop for now
    jr main
;