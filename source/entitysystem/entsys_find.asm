INCLUDE "entsys.inc"
INCLUDE "macro/relpointer.inc"

SECTION "ENTSYS FIND", ROM0


MACRO find
    push bc
    ld hl, wEntsys

    .check
        ; Is this entity allocated?
        ld a, [hl+]
        or a, a
        ld a, [hl-]
        jr z, .next
        ld b, a

        ; Match all flags
        set 2, l
        ld a, [hl]
        res 2, l
        IF \1 == 1
            and a, c
            xor a, c
            ld a, b
            jr nz, .next
        ELSE
            and a, c
            ld a, b
            jr z, .next
        ENDC

        ; Ok, we have outselves a match!
        pop bc
        or a, h ; reset Z flag
        ret
    ;

    ; Input:
    ; - `a`: Entity size
    ; - `hl`: Entity pointer (`ENTVAR_BANK`)
    .next
        add a, l
        ld l, a
        jr nc, .check
        inc h
        ld a, h
        cp a, high(wEntsys.end)
        jr c, .check

        ; Nope, we are done here
        pop bc
        xor a ; set Z flag
        ret
    ;
ENDM

MACRO collision
    call EntsysCollisionPrepare1

    ; Find entity with these flags
    .prepared::
    call \1
    ret z

    ; Ok, grab rectangle params
    .collide
    push bc
    push hl
    call EntsysCollisionPrepare2

    ; Perform collision call
    call EntsysCollisionRR8F

    ; Did we find anything?
    pop hl
    pop bc
    jr z, :+
    ret nz
    :
ENDM



; Find an entity with the given flags.
; All flags must match for entity to be valid.
; Returns a pointer to the first entity found.  
; Lives in ROM0.
;
; Input:
; - `c`: Filter flags (`ENTSYS_FLAGF_*`)
;
; Returns:
; - `fZ`: Found entity (z = no, nz = yes)
; - `hl`: Entity pointer (`$0000` when none found)
;
; Saves: `bc`, `de`
EntsysFindAll::
    find 1

    ; Continue a previous search.
    ; Documentation from `EntsysFindAll` applies.
    ; Input entity is not checked.  
    ; Lives in ROM0.
    ;
    ; Input:
    ; - `c`: Filter flags (`ENTSYS_FLAGF_*`)
    ; - `hl`: Entity pointer (`ENTVAR_BANK`)
    ;
    ; Returns:
    ; - `hl`: Entity pointer (`$0000` when none found)
    ;
    ; Saves: `bc`, `de`
    EntsysFindAll.continue::
    push bc
    inc l
    ld a, [hl-]
    jr .next
;



; Find an entity with the given flags.
; An entity is a match if any of the given flags match.
; Returns a pointer to the first entity found.  
; Lives in ROM0.
;
; Input:
; - `c`: Filter flags (`ENTSYS_FLAGF_*`)
;
; Returns:
; - `fZ`: Found entity (z = no, nz = yes)
; - `hl`: Entity pointer (`$0000` when none found)
;
; Saves: `bc`, `de`
EntsysFindAny::
    find 0

    ; Continue a previous search.
    ; Documentation from `EntsysFindAny` applies.
    ; Input entity is not checked.  
    ; Lives in ROM0.
    ;
    ; Input:
    ; - `c`: Filter flags (`ENTSYS_FLAGF_*`)
    ; - `hl`: Entity pointer (`ENTVAR_BANK`)
    ;
    ; Returns:
    ; - `hl`: Entity pointer (`$0000` when none found)
    ;
    ; Saves: `bc`, `de`
    EntsysFindAny.continue::
    push bc
    inc l
    ld a, [hl-]
    jr .next
;



; Low-precision collision check.
; Only checks for entities with all specified flags.
; Only tests using high-bytes of positions.  
; Lives in ROM0.
;
; Input:
; - `c`: Flags to test for (`ENTSYS_FLAGF_*`)
; - `hl`: Source entity (anywhere)
;
; Returns:
; - `fZ`: Found anything (z = no, nz = yes)
; - `hl`: Collided entity
;
; Destroys: all
EntsysCollisionAll::
    collision EntsysFindAll

    ; Low-precision collision check.
    ; Only tests using high-bytes of positions, and only for entities with all supplied flags.
    ; Check more entities if needed.  
    ; Assumes `hColBuf` is unchanged.  
    ; Lives in ROM0.
    ;
    ; Input:
    ; - `c`: Flags to test for (`ENTSYS_FLAGF_*`)
    ; - `hl`: Last found entity pointer (`ENTVAR_BANK`)
    ;
    ; Returns:
    ; - `fZ`: Found anything (z = no, nz = yes)
    ; - `hl`: Collided entity
    ;
    ; Saves: `c`  
    ; Destroys: `af`, `b`, `de`
    EntsysCollisionAll.continue::
    call EntsysFindAll.continue
    jr nz, .collide
    ret
;



; Low-precision collision check.
; Only checks for entities with any of the specified flags.
; Only tests using high-bytes of positions.  
; Lives in ROM0.
;
; Input:
; - `c`: Flags to test for (`ENTSYS_FLAGF_*`)
; - `hl`: Source entity (anywhere)
;
; Returns:
; - `fZ`: Found anything (z = no, nz = yes)
; - `hl`: Collided entity
;
; Destroys: all
EntsysCollisionAny::
    collision EntsysFindAny

    ; Low-precision collision check.
    ; Only tests using high-bytes of positions, and only for entities with any of the supplied flags.
    ; Check more entities if needed.  
    ; Assumes `hColBuf` is unchanged.  
    ; Lives in ROM0.
    ;
    ; Input:
    ; - `c`: Flags to test for (`ENTSYS_FLAGF_*`)
    ; - `hl`: Last found entity pointer (`ENTVAR_BANK`)
    ;
    ; Returns:
    ; - `fZ`: Found anything (z = no, nz = yes)
    ; - `hl`: Collided entity
    ;
    ; Saves: `c`  
    ; Destroys: `af`, `b`, `de`
    EntsysCollisionAny.continue::
    call EntsysFindAny.continue
    jr nz, .collide
    ret
;
