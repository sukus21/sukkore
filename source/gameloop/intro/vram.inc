    IF !DEF(INTRO_VRAM_INC)
    DEF INTRO_VRAM_INC EQU 1

INCLUDE "hardware.inc/hardware.inc"
INCLUDE "macro/tilemap.inc"

; Block 2
RSSET $00
    DEF EQRB EQUS "$9000 + $10 * _RS"

    ; Splash graphics
    DEF VT_INTRO_TILES EQU EQRB
    DEF VTI_INTRO_TILES RB $24
ASSERT _RS <= $80

; SCRN 0
    ; Full-screen intro tilemap splash.  
    ; Spans 20x18 tiles.  
    ; Located on `SCRN0`.
    DEF VM_INTRO_SPLASH EQU _SCRN0

    tilemap_alloc _SCRN0, "VM_INTRO_FACE", 6, 3, 8, 8
    ; Location of the face.  
    ; Occupies an 8x8 area.  
    ; Located on `SCRN0`.
    DEF VM_INTRO_FACE EQU tlmv_addr
;

    ENDC
