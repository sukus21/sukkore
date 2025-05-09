    IF !DEF(MACRO_MEMCPY_INC)
    DEF MACRO_MEMCPY_INC EQU 1

; Macro that copies data from one location to another using the CPU.
; Auto-optimizes HL+ and single-byte counter.
;
; Input:
; - `1`: Destination (`r16`)
; - `2`: Source (`r16`)
; - `3`: Byte count (`r8`/`r16`, not `a`)
;
; Destroys: `1`, `2`, `3`, `af`
MACRO memcpy_custom
    STATIC_ASSERT STRCMP(STRLWR("\1"), STRLWR("\2")) != 0, "memcpy - register \1 cannot be used multiple times"
    STATIC_ASSERT STRCMP(STRLWR("\1"), STRLWR("\3")) != 0, "memcpy - register \1 cannot be used multiple times"
    STATIC_ASSERT STRCMP(STRLWR("\2"), STRLWR("\3")) != 0, "memcpy - register \2 cannot be used multiple times"

    .memcpyCustom\@
    ; Read source
    IF STRCMP(STRLWR("\2"), "hl") == 0
        ld a, [hl+]
    ELSE
        ld a, [\2]
        inc \2
    ENDC

    ; Write to destination
    IF STRCMP(STRLWR("\1"), "hl") == 0
        ld [hl+], a
    ELSE
        ld [\1], a
        inc \1
    ENDC

    ; Decrement counter
    dec \3
    IF STRCMP(STRLWR("\3"), "bc") == 0
        ld a, b
        or a, c
    ENDC
    IF STRCMP(STRLWR("\3"), "de") == 0
        ld a, d
        or a, e
    ENDC
    IF STRCMP(STRLWR("\3"), "hl") == 0
        ld a, h
        or a, l
    ENDC
    jr nz, .memcpyCustom\@
ENDM



; Input:
; - `1`: Source (label)
; - `2`: Destination
; - `3`: (optional) Length
;
; Destroys: all
MACRO memcpy_label
    ld hl, \2
    ld bc, \1
    IF _NARG == 3
        ld de, \3
    ELSE
        ld de, \1.end - \1
    ENDC
    call Memcpy
ENDM

    ENDC
