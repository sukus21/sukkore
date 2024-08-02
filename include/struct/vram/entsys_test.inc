    IF !DEF(STRUCT_VRAM_ENTSYS_TEST_INC)
    DEF STRUCT_VRAM_ENTSYS_TEST_INC EQU 1

INCLUDE "hardware.inc/hardware.inc"
INCLUDE "macros/tilemap.inc"

;Block 0 (sprites only)
RSSET $00
    DEF EQRB EQUS "$8000 + $10 * _RS"

    ; Player tileset.
    DEF VT_TOWER_PLAYER EQU EQRB
    DEF VTI_TOWER_PLAYER RB $30

    ; Enemy tileset(s).
    DEF VT_TOWER_ENEMIES EQU EQRB
    DEF VTI_TOWER_ENEMIES RB $50
ASSERT _RS <= $80

;Block 1 (sprites + backgrounds)
RSSET $80
    PURGE EQRB
    DEF EQRB EQUS "$8000 + $10 * _RS"

    ; Enemy tileset(s) 2.
    DEF VT_TOWER_ENEMIES2 EQU EQRB
    DEF VTI_TOWER_ENEMIES2 RB $30

    ; Location of coin tileset.
    DEF VT_TOWER_COIN EQU EQRB
    DEF VTI_TOWER_COIN RB $08

    ; Location of particle tileset.
    DEF VT_TOWER_PARTICLE EQU EQRB
    DEF VTI_TOWER_PARTICLE RB $08

    ; HUD tiles.
    DEF VT_TOWER_HUD EQU EQRB
    DEF VTI_TOWER_HUD RB $10

    ; HUD font tiles.
    DEF VT_TOWER_FONT EQU EQRB
    DEF VTI_TOWER_FONT RB $0A

    ; Location of platform tileset.
    DEF VT_TOWER_PLATFORM EQU EQRB
    DEF VTI_TOWER_PLATFORM RB $20
    DEF VTI_TOWER_PLATFORM_END RB 0
ASSERT _RS <= $100

;Block 2 (backgrounds only)
RSSET $00
    PURGE EQRB
    DEF EQRB EQUS "$9000 + $10 * _RS"

    ; Location of background tileset.
    ; This tileset is very dynamic.
    DEF VT_TOWER_BACKGROUND EQU EQRB
    DEF VTI_TOWER_BACKGROUND RB $60

    ;Location of tower tileset.
    DEF VT_TOWER_TOWER EQU EQRB
    DEF VTI_TOWER_TOWER RB $20
ASSERT _RS <= $80


;SCRN 0
    tilemap_alloc _SCRN0, "VM_TOWER_BACKGROUND0", 0, 0, 16, 18
    ; Location of background tilemap, used by the window layer.  
    ; Spans 16x18 tiles.  
    ; Located on `SCRN0`.
    DEF VM_TOWER_BACKGROUND0 EQU tlmv_addr

    tilemap_alloc _SCRN0, "VM_TOWER_TOWER0", 16, 0, 16, 32
    ; Location of tower tilemap.  
    ; Spans 16x32 tiles.  
    ; Located on `SCRN0`.
    DEF VM_TOWER_TOWER0 EQU tlmv_addr

    tilemap_alloc_finish
;

;SCRN 1
    tilemap_alloc _SCRN1, "VM_TOWER_BACKGROUND1", 0, 0, 16, 18
    ; Location of background tilemap, used by the window layer.
    ; Spans 16x18 tiles.  
    ; Located on `SCRN1`.
    DEF VM_TOWER_BACKGROUND1 EQU tlmv_addr

    tilemap_alloc _SCRN1, "VM_TOWER_TOWER1", 16, 0, 16, 26
    ; Location of tower tilemap.  
    ; Spans 16x26 tiles.  
    ; Located on `SCRN1`.
    DEF VM_TOWER_TOWER1 EQU tlmv_addr
    
    tilemap_alloc _SCRN1, "VM_TOWER_HUD", 0, 26, 32, 3
    ; Location of HUD tilemap.
    ; HUD elements go here.
    ; 32 * 3 tiles.
    DEF VM_TOWER_HUD EQU tlmv_addr

    tilemap_alloc _SCRN1, "VM_TOWER_PLATFORM", 0, 29, 32, 3
    ; Location of platform tilemap.
    ; I have not yet decided if I'll need the full 3-tile height.
    ; Still reserving it, just in case.
    ; 32 * 3 tiles.
    DEF VM_TOWER_PLATFORM EQU tlmv_addr

    tilemap_alloc_finish
;

    ENDC
