    IF !DEF(STRUCT_VRAM_ENTSYS_ALLOC_DEMO_INC)
    DEF STRUCT_VRAM_ENTSYS_ALLOC_DEMO_INC EQU 1

INCLUDE "hardware.inc/hardware.inc"
INCLUDE "macro/tilemap.inc"

; Block 0
RSSET $00
    DEF EQRB EQUS "$8000 + $10 * _RS"

    ; Font graphics
    DEF VT_ENTALLOC_FONT EQU EQRB
    DEF VTI_ENTALLOC_FONT RB $80
ASSERT _RS <= $80

; Block 1
RSSET $80
    PURGE EQRB
    DEF EQRB EQUS "$8000 + $10 * _RS"
    DEF VT_ENTALLOC_CHUNKS EQU EQRB

    ; Occupied chunk
    DEF VT_ENTALLOC_CHUNK_FULL EQU EQRB
    DEF VTI_ENTALLOC_CHUNK_FULL RB 3

    ; Free chunk
    DEF VT_ENTALLOC_CHUNK_FREE EQU EQRB
    DEF VTI_ENTALLOC_CHUNK_FREE RB 3

    ; Cursor sprite
    DEF VT_ENTALLOC_CURSOR EQU EQRB
    DEF VTI_ENTALLOC_CURSOR RB 1
ASSERT _RS <= $100
 

; SCRN 0
    tilemap_alloc _SCRN0, "VM_ENTALLOC_CHUNKS", 0, 0, 16, 4
    ; Location of chunk viewer.  
    ; Spans 16x4 tiles.  
    ; Located on `SCRN0`.
    DEF VM_ENTALLOC_CHUNKS EQU tlmv_addr

    tilemap_alloc _SCRN0, "VM_ENTALLOC_SIZE_64", 3, 5, 9, 1
    DEF VM_ENTALLOC_SIZE_64 EQU tlmv_addr

    tilemap_alloc _SCRN0, "VM_ENTALLOC_SIZE_32", 3, 6, 9, 1
    DEF VM_ENTALLOC_SIZE_32 EQU tlmv_addr

    tilemap_alloc _SCRN0, "VM_ENTALLOC_SIZE_16", 3, 7, 9, 1
    DEF VM_ENTALLOC_SIZE_16 EQU tlmv_addr

    tilemap_alloc_finish
;

    ENDC
