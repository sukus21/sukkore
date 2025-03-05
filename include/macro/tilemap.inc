    IF !DEF(MACRO_TILEMAP_INC)
    DEF MACRO_TILEMAP_INC EQU 1

; Contains the result of a `tilemap_alloc` invocation.
DEF tlmv_addr = 0

; Finishes allocation of a tilemap.
; Invoking this is required to define multiple tilemaps in one file.
MACRO tilemap_alloc_finish
    DEF __tlmv_x = 0
    REPT 32
        DEF __tlmv_y = 0
        REPT 32
            IF DEF(__tlmv_{d:__tlmv_x}_{d:__tlmv_y})
                PURGE __tlmv_{d:__tlmv_x}_{d:__tlmv_y}
            ENDC
            DEF __tlmv_y = __tlmv_y + 1
        ENDR
        DEF __tlmv_x = __tlmv_x + 1
    ENDR
ENDM



; Allocates a region of SCRN space.
; Remember to invoke `tilemap_alloc_finish` when done.
;
; Input:
; - `1`: Tilemap addr
; - `2`: Constant name
; - `3`: X-position
; - `4`: Y-position
; - `5`: Width
; - `6`: Height
;
; Returns:
; - `tlmv_addr`: Address to top-left tile
MACRO tilemap_alloc
    ASSERT \3 + \5 <= 32, "x+width above 32 for \2"
    ASSERT \4 + \6 <= 32, "y+height above 32 for \2"
    ASSERT _NARG == 6, "tilemap_alloc requires 6 parameters for \2"

    ; Make sure all spots are valid
    DEF __tlmv_x = \3
    REPT \5
        DEF __tlmv_y = \4
        REPT \6
            ASSERT !DEF(__tlmv_{d:__tlmv_x}_{d:__tlmv_y}), STRFMT("tilemap position (%d,%d) occupied for %s", __tlmv_x, __tlmv_y, \2)
            DEF __tlmv_{d:__tlmv_x}_{d:__tlmv_y} = 1
            DEF __tlmv_y = __tlmv_y + 1
        ENDR
        DEF __tlmv_x = __tlmv_x + 1
    ENDR

    ; Define parameters
    DEF tlmv_addr = \1 + \3 + (\4 * 32)
    PURGE __tlmv_x, __tlmv_y
ENDM



; Pointer to tilemap position.
; Does not allocate space in the tilemap buffer.
; Coordinates of this can overlap with any allocation.
;
; Input:
; - `1`: Tilemap addr
; - `2`: Constant name
; - `3`: X-position
; - `4`: Y-position
;
; Returns:
; - `tlmv_addr`: Tilemap address
MACRO tilemap_ptr
    ASSERT \3 <= 32, "x+width above 32 for \2"
    ASSERT \4 <= 32, "y+height above 32 for \2"
    ASSERT _NARG == 4, "tilemap_ptr requires 4 parameters for \2"
    DEF tlmv_addr = \1 + \3 + (\4 * 32)
ENDM

    ENDC
