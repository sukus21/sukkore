    IF !DEF(SOUND_INC)
    DEF SOUND_INC EQU 1

; == YELLER FLAGS == ;

DEF YELLER_FLAGB_IS_OCCUPIED EQU 0
DEF YELLER_FLAGB_BREAK_LOOP EQU 1
DEF YELLER_FLAGB_FORCE_TERMINATION EQU 2
DEF YELLER_FLAGB_USES_CH1 EQU 4
DEF YELLER_FLAGB_USES_CH2 EQU 5
DEF YELLER_FLAGB_USES_CH3 EQU 6
DEF YELLER_FLAGB_USES_CH4 EQU 7

DEF YELLER_FLAGF_IS_OCCUPIED EQU 1<<YELLER_FLAGB_IS_OCCUPIED ; NOTE: If clear, then all other flags must also be clear.

; If set, yeller will not execute YELLER_OPS_JUMP_UNLESS_SIGNAL steps.
; 
; Can be used to end a looping sound effects.
DEF YELLER_FLAGF_BREAK_LOOP EQU 1<<YELLER_FLAGB_BREAK_LOOP

; If set, the yeller will terminate on the next update.
; 
; The main purpose for this flag is for ending looping music.
DEF YELLER_FLAGF_FORCE_TERMINATION EQU 1<<YELLER_FLAGB_FORCE_TERMINATION

DEF YELLER_FLAGF_USES_CH1 EQU 1<<YELLER_FLAGB_USES_CH1
DEF YELLER_FLAGF_USES_CH2 EQU 1<<YELLER_FLAGB_USES_CH2
DEF YELLER_FLAGF_USES_CH3 EQU 1<<YELLER_FLAGB_USES_CH3
DEF YELLER_FLAGF_USES_CH4 EQU 1<<YELLER_FLAGB_USES_CH4


; == YELLER OPS == ;

MACRO YELLER_DELAY_OP
    db \1 * 2 + 1
ENDM

; Immediately terminates the yeller.
DEF YELLER_OPS_TERMINATE EQU $02

; If YELLER_FLAGF_BREAK_LOOP is not set: Dictates the address of the next step in the sequence, rather
; than letting it be the next step stored in memory.
; 
; If YELLER_FLAGS_BREAK LOOP is set: Does nothing.
; 
; Note that the delay parameter of this op is seperate from and coexists with the one implicitly stored
; after most steps. The delay parameter is used if YELLER_FLAGF_BREAK_LOOP is not set. Otherwise, the
; common delay value is used.
; 
; PARAMS:
; - Relative destination offset: 2 bytes
; - Delay: 1 byte
DEF YELLER_OPS_JUMP EQU $04

; Plays on channel 1.
;
; Params:
; - One byte for each I/O register that belongs to channel 1. (5 in total)
DEF YELLER_OPS_PLAY_SQUARE_WAVE EQU $08

; Plays on channel 2.
;
; Params:
; - One byte for each I/O register that belongs to channel 2. (4 in total)
DEF YELLER_OPS_PLAY_SQUARE_WAVE_2 EQU $0A

DEF YELLER_OPS_PLAY_FORM_WAVE EQU $0C

; Plays on channel 4.
;
; Params:
; - One byte for each I/O register that belongs to channel 4. (4 in total)
DEF YELLER_OPS_PLAY_NOISE_WAVE EQU $0E

    ENDC