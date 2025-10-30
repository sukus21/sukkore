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



; Converts a number into a 8-bit bitmask.  
; Only the lower 3 bits of the source are looked at.
;
; Input:
; - `1`: Destination register (r8)
; - `2`: Value (n8/r8)
;
; Destroys: `f`
MACRO to_bitmask_8
    IF ISCONST(\1 & $07)
        ld \2, 1 << \1
    ELSE
        ld \2, 1

        ; Lowest bit
        bit 0, \1
        IF STRCMP(STRLWR("\2"), "a")
            jr z, @+3
            rlca
        ELSE
            jr z, @+4
            rlc \2
        ENDC

        ; Middle bit
        bit 1, \1
        IF STRCMP(STRLWR("\2"), "a")
            jr z, @+4
            rlca
            rlca
        ELSE
            jr z, @+6
            rlc \2
            rlc \2
        ENDC

        ; Highest bit
        bit 2, \1
        jr z, @+4
        swap \2
    ENDC
ENDM



; Converts an 8-bit bitmask into a number.
; Assumes only a single bit of the bitmask is set.
; Does not clear the destination register before use.
;
; Input:
; - `1`: Destination register (r8, not a)
; - `2`: Bitmask value (r8/n8)
;
; Destroys: `af`
MACRO from_bitmask_8
    IF ISCONST(\2)
        IF \2 == %0000_0001
            ld \2, 0
        ELIF \2 == %0000_0010
            ld \2, 1
        ELIF \2 == %0000_0100
            ld \2, 2
        ELIF \2 == %0000_1000
            ld \2, 3
        ELIF \2 == %0001_0000
            ld \2, 4
        ELIF \2 == %0010_0000
            ld \2, 5
        ELIF \2 == %0100_0000
            ld \2, 6
        ELIF \2 == %1000_0000
            ld \2, 7
        ELSE
            FAIL "invalid constant bitmask"
        ENDC
    ELSE
        ld a, \2

        ; Highest bit
        cp a, %0001_0000
        jr c, @+8
            swap a
            and a, %0000_1111
            set 2, \1
        ;

        ; Middle bit
        cp a, %0000_0100
        jr c, @+8
            rra
            rra
            and a, %0000_0011
            set 1, \1
        ;

        ; Lowest bit
        dec a
        jr nz, @+3
            inc \1
        ;
    ENDC
ENDM



; Converts an 16-bit bitmask into a number.
; Assumes only a single bit of the bitmask is set.
; Does not clear the destination register before use.
;
; Input:
; - `1`: Destination register (r8, not `a`)
; - `2`: Bitmask value (r16/n16)
;
; Destroys: `af`
MACRO from_bitmask_16
    IF ISCONST(\2)
        IF \2 == %0000_0000_0000_0001
            ld \2, 0
        ELIF \2 == %0000_0000_0000_0010
            ld \2, 1
        ELIF \2 == %0000_0000_0000_0100
            ld \2, 2
        ELIF \2 == %0000_0000_0000_1000
            ld \2, 3
        ELIF \2 == %0000_0000_0001_0000
            ld \2, 4
        ELIF \2 == %0000_0000_0010_0000
            ld \2, 5
        ELIF \2 == %0000_0000_0100_0000
            ld \2, 6
        ELIF \2 == %0000_0000_1000_0000
            ld \2, 7
        ELIF \2 == %0000_0001_0000_0000
            ld \2, 8
        ELIF \2 == %0000_0010_0000_0000
            ld \2, 9
        ELIF \2 == %0000_0100_0000_0000
            ld \2, 10
        ELIF \2 == %0000_1000_0000_0000
            ld \2, 11
        ELIF \2 == %0001_0000_0000_0000
            ld \2, 12
        ELIF \2 == %0010_0000_0000_0000
            ld \2, 13
        ELIF \2 == %0100_0000_0000_0000
            ld \2, 14
        ELIF \2 == %1000_0000_0000_0000
            ld \2, 15
        ELSE
            FAIL "invalid constant bitmask"
        ENDC
    ELSE
        ; Really highest bit
        ld a, high(\2)
        or a, a
        jr nz, @+6
            ld a, low(\2)
            jr @+4
            set 3, \2
        ;

        ; Highest bit
        cp a, %0001_0000
        jr c, @+8
            swap a
            and a, %0000_1111
            set 2, \1
        ;

        ; Middle bit
        cp a, %0000_0100
        jr c, @+8
            rra
            rra
            and a, %0000_0011
            set 1, \1
        ;

        ; Lowest bit
        dec a
        jr nz, @+3
            inc \1
        ;
    ENDC
ENDM



; Increments a register if the carry flag is set.
;
; Input:
; - `1`: Register to increment (r8/r16)
MACRO inc_c
    jr nc, @+3
    inc \1
ENDM

    ENDC
