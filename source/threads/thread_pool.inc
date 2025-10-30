    IF !DEF(STRUCT_THREAD_POOL_INC)
    DEF STRUCT_THREAD_POOL_INC EQU 1

INCLUDE "utils.inc"


RSRESET

; How many threads are allocated to the pool right now.
DEF THREAD_POOL_ALLOCATED RB 1

; Contains a number of low-pointers to `THREAD_T`.
; The exact number of slots depends on the allocated space.  
; TODO: build a length constraint into the pool?
DEF THREAD_POOL_BUFFER RB 0



; Allocates a thread and adds it to the thread pool.
;
; Input:
; - `de`: Thread pool address (label/n16)
;
; Returns:
; - `hl`: `THREAD_T` pointer
;
; Saves: `b`
MACRO thread_pool_allocate
    ; Allocate new thread
    call ThreadAllocate

    ; Get new thread slot -> A
    ld a, [de]
    inc a
    ld [de], a

    ; Move thread pool pointer to slot
    add a, e
    ld e, a
    inc_c d

    ; Write thread low-pointer to thread pool pool
    ld a, l
    ld [de], a
ENDM



; Checks if a thread pool is empty.
;
; Input:
; - `1`: Thread pool pointer (r16/label/address)
;
; Returns:
; - `fZ`: is empty (z = yes)
;
; Destroys: `af`
MACRO thread_pool_empty
    ld a, [\1]
    or a, a
ENDM



; Input:
; - `hl`: Pointer to thread pool counter
;
; Saves: `hl`, `de`, `c`
MACRO thread_pool_free
    ; Decrement thread counter
    dec [hl]
    jr z, .threadPoolFreed
    
    ; Read counter -> B
    ld a, [hl+]
    ld b, a

    ; Move pointer to end of pool -> HL
    add a, l
    ld l, a
    inc_c h

    ; Shift queue contents
    .threadPoolFreeLoop
        ld a, [hl-]
        ld c, [hl]
        ld [hl], a

        dec b
        jr nz, .threadPoolFreeLoop
    ;

    .threadPoolFreed
ENDM

    ENDC
