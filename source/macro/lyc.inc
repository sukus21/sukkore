    IF !DEF(MACRO_LYC_INC)
    DEF MACRO_LYC_INC EQU 1

; Sets the bytes at `hLYC` to the given label.
; Removes the value that was previously there.
;
; Input:
; - `1`: Address/label
;
; Destroys: `a`
MACRO LYC_set_jumppoint
    ld a, low(\1)
    ldh [hLYC+1], a
    ld a, high(\1)
    ldh [hLYC+2], a
ENDM



; Wait for H-blank by polling rSTAT.
; Assumes LCD is turned on.
; Assumes non-vblank.
;
; Destroys: `af`
MACRO LYC_wait_hblank
    ld a, STATF_MODE00
    ldh [rSTAT], a
    halt
    nop
    ld a, STATF_LYC
    ldh [rSTAT], a
    ldh [rIF], a
ENDM

    ENDC
