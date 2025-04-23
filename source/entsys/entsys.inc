    IF !DEF(ENTSYS_INC)
    DEF ENTSYS_INC EQU 1

INCLUDE "macro/relpointer.inc"

; Number of entity chunks available
; Assumed to be a multiple of 16.
DEF ENTSYS_CHUNK_COUNT EQU 64

; Number of clusters in entity system.
; Each cluster is 8 chunks, one for each bit.
DEF ENTSYS_CLUSTER_COUNT EQU ENTSYS_CHUNK_COUNT >> 3

RSRESET

; ROM bank an entity's data is located in.
; Cannot be ROM0, as a value of `0` means an entity is free.
DEF ENTVAR_BANK RB 1

; How many bytes to next entity.
; This value is both a relative pointer to the next entity, and the size of the current entity.  
; Should always be either `$40`, `$20` or `$10`.
DEF ENTVAR_NEXT RB 1

; Pointer to the entity's step function (function that gets run every game frame).
; This should be located in the same ROM bank as specified `ENTVAR_BANK`.
DEF ENTVAR_STEP RB 2

; Says a lot about a given entity.
DEF ENTVAR_FLAGS RB 1

; This is where the entity variable space starts.
; Entities using this value cannot be collided with.
DEF ENTVAR_VAR RB 0

; Entity Y-position.
; Little endian.
DEF ENTVAR_YPOS RB 2

; Entity X-position.
; Little endian.
DEF ENTVAR_XPOS RB 2

; Entity height in pixels.
DEF ENTVAR_HEIGHT RB 1

; Entity width in pixels.
DEF ENTVAR_WIDTH RB 1

; This is where variable space begins for collision-enabled objects.
DEF ENTVAR_COL_VAR RB 0


RSRESET

; This entity has collision enabled.
; If this flag is NOT set, `ENTVAR_COL_*` offsets to not apply.
DEF ENTSYS_FLAGF_COLLISION EQU 1 << _RS
DEF ENTSYS_FLAGB_COLLISION RB 1



; Allocate new entity, set bank and step-pointer.  
; Initializes relpointer.
;
; Input:
; - `1`: Entity size (16, 32 or 64)
; - `2`: Entity step pointer (label)
; - `3`: Flags (`ENTSYS_FLAGF_*`)
;
; Returns:
; - `hl`: Entity pointer (use relpointer)
;
; Destroys: all
MACRO entsys_new
    call entsys_new\1
    ld h, b
    ld l, c
    relpointer_init l

    ; Write bank and step pointer
    ld [hl], bank(\2)
    relpointer_move ENTVAR_STEP
    ld a, low(\2)
    ld [hl+], a
    ld a, high(\2)
    ld [hl-], a

    ; Set flags
    relpointer_move ENTVAR_FLAGS
    ld [hl], \3
ENDM



; Initializes relpointer for an entity.
;
; Input:
; - `hl`: Somewhere
; - `1`: Starting position (n8)
; - `2*`: Entity bitmask (n8, default: `%11100000`)
;
; Returns:
; - `hl`: Relpointer to position `1`.
;
; Destroys: `af`
MACRO entsys_relpointer_init
    ld a, l
    IF _NARG == 2
        and a, \2
    ELSE
        and a, %11100000
    ENDC
    or a, \1
    ld l, a
    relpointer_init l, \1
ENDM

    ENDC
