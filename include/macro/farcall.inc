    IF !DEF(MACRO_FARCALL_INC)
    DEF MACRO_FARCALL_INC EQU 1

; Switches banks, and jumps to the given symbol.
; `a` will be clobbered before the jump,
; and can therefore not be used as function arguments.
; Does not switch banks back when returning.
;
; Input (1):
; - `1`: Symbol to call (label)
;
; Input (2):
; - `1`: Condition code
; - `2`: Symbol to call (label)
;
; Destroys: `a`, unknown
MACRO farcall
    ASSERT bank(@) == 0, "farcall - can only do non-returning farcall from ROM0"
    IF _NARG == 1
        ld a, bank(\1)
        ld [rROMB0], a
        call \1
    ELSE
        ld a, bank(\2)
        ld [rROMB0], a
        call \1, \2
    ENDC
ENDM



; Switches banks, and jumps to the given symbol.
; `a` and `hl` will be clobbered before the jump,
; and can therefore not be used as function arguments.
; Switches banks back before returning.
;
; Input:
; - `1`: Symbol to call (label)
;
; Destroys: `a`, `hl`, unknown
MACRO farcall_x
    ASSERT bank(@) != 0, "farcall - should not use farcall_x from ROM0"
    ld a, bank(@)
    ldh [hBankNumber], a
    ld a, bank(\1)
    ld hl, \1
    call FarcallHandlerX
ENDM

    ENDC
