    IF !DEF(STRUCT_OAMMIRROR_INC)
    DEF STRUCT_OAMMIRROR_INC EQU 1

; Size of a OAM mirror struct.
; Should always be byte-aligned.
DEF OAMMIRROR_T EQU $100
RSRESET

; The OAM mirror itself.
DEF OAMMIRROR_OAM RB $A0
RSSET _RS + $50 ; filler, in case too many sprites are allocated per frame

; Low-pointer to first free sprite in this mirror.
DEF OAMMIRROR_COUNT RB $01

; Number of bytes in the mirror used previous frame.
; Used to speed up `SpriteFinish`.
DEF OAMMIRROR_PREVIOUS RB $01

    ENDC
