    IF !DEF(MACRO_NUMTOHEX_INC)
    DEF MACRO_NUMTOHEX_INC EQU 1

; Converts a number into hexadecimal ASCII.
;
; Input:
; - `1`: Value to convert
; - `2`: Destination high (`r8`)
; - `3`: Destination low (`r8`)
;
; Output:
; - `2`: Upper nybble as ASCII
; - `3`: Lower nybble as ASCII
;
; Destroys: `af`
MACRO num_to_hex
    IF STRCMP("\1", "a") != 0
        ld a, \1
    ENDC
    ld \2, a

    ; Convert low nybble
    and a, %00001111
    add a, "0"
    cp a, ":"
    jr c, .numToHex1\@
        add a, "A" - ":"
    .numToHex1\@
    ld \3, a

    ; Convert high nybble
    ld a, \2
    swap a
    and a, %00001111
    add a, "0"
    cp a, ":"
    jr c, .numToHex2\@
        add a, "A" - ":"
    .numToHex2\@
    ld \2, a
ENDM

    ENDC
