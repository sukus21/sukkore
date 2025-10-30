    IF !DEF(STRUCT_WORKER_INC)
    DEF STRUCT_WORKER_INC EQU 1

INCLUDE "utils.inc"
INCLUDE "config.inc"

; Allocated space for the stack dedicated to VQueue job routines.
DEF WORKER_STACK_SIZE EQU $20



; Initializes a Worker thread.
; If 2 arguments are provided, the call can be made conditional.
;
; Input (1):
; - `1`: Routine (label)
;
; Input (2):
; - `1`: Condition code
; - `2`: Worker routine (label)
;
; Returns:
; - `hl`: `THREAD_T` pointer (if condition met)
;
; Saves: none
MACRO worker_enqueue
    IF _NARG == 1
        ld de, \1
        ld b, bank(\1)
        call WorkerGet
    ELSE
        ld de, \2
        ld b, bank(\2)
        call \1, WorkerGet
    ENDC
ENDM

    ENDC
