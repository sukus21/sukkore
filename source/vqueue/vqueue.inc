    IF !DEF(STRUCT_VQUEUE_INC)
    DEF STRUCT_VQUEUE_INC EQU 1

INCLUDE "utils.inc"
INCLUDE "config.inc"

; Allocated space for the stack dedicated to VQueue job routines.
DEF VQUEUE_STACK_SIZE EQU $20



RSRESET

; ROMX bank.
; Written to `rROMB0` if `CONFIG_BANKABLE_ROMX` is 1.
DEF VQUEUE_BANK_ROMX RB 1

; SRAM bank.
; Written to `rRAMB` if `CONFIG_BANKABLE_SRAM` is 1.
DEF VQUEUE_BANK_SRAM RB 1

; CGB WRAMX bank.
; Written to `rSVBK` if `CONFIG_BANKABLE_WRAMX` is 1.
DEF VQUEUE_BANK_WRAMX RB 1

; CGB VRAM bank.
; Written to `rVBK`, if `CONFIG_BANKABLE_VRAM` is 1.
DEF VQUEUE_BANK_VRAM RB 1

DEF VQUEUE_REGISTER_PC RW 1
DEF VQUEUE_REGISTER_SP RW 1
DEF VQUEUE_REGISTER_BC RW 1
DEF VQUEUE_REGISTER_DE RW 1
DEF VQUEUE_REGISTER_HL RW 1
DEF VQUEUE_REGISTER_AF RW 1

; A VQueue job struct.
DEF VQUEUE_T RB 0



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
; - `hl`: `VQUEUE_T` pointer (if condition met)
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
