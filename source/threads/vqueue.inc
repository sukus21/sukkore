    IF !DEF(STRUCT_VQUEUE_INC)
    DEF STRUCT_VQUEUE_INC EQU 1

INCLUDE "utils.inc"
INCLUDE "config.inc"


; Allocated space for the stack dedicated to VQueue job routines.
DEF VQUEUE_STACK_SIZE EQU $20



; Initializes a VQueue transfer.
; If 2 arguments are provided, the call can be made conditional.
;
; Input (1):
; - `1`: Transfer routine (label)
;
; Input (2):
; - `1`: Condition code
; - `2`: Transfer routine (label)
;
; Returns:
; - `hl`: `THREAD_T` pointer (if condition met)
;
; Saves: none
MACRO vqueue_enqueue
    IF _NARG == 1
        ld de, \1
        ld b, bank(\1)
        call VQueueGet
    ELSE
        ld de, \2
        ld b, bank(\2)
        call \1, VQueueGet
    ENDC
ENDM

    ENDC
