    IF !DEF(UTILS_INC)
    DEF UTILS_INC EQU 1

; Check if the given "value" is a 16-bit register.
; The result is stored in `IS_R16`.
;
; Input:
; - `1`: "value" to check
MACRO is_r16
    REDEF IS_R16 EQU \
        STRCMP(STRLWR("\1"), "bc") == 0 || \
        STRCMP(STRLWR("\1"), "de") == 0 || \
        STRCMP(STRLWR("\1"), "hl") == 0 || \
        STRCMP(STRLWR("\1"), "sp") == 0
ENDM



; Write a 16-bit value to [hl+].
;
; Input:
; - `1`: "value" to write
;
; Destroys: `a`
MACRO write_n16
    ld a, low(\1)
    ld [hl+], a
    ld a, high(\1)
    ld [hl+], a
ENDM

    ENDC
