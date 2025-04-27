    IF !DEF(CONFIG_INC)
    DEF CONFIG_INC EQU 1

; Toggle if banking is enabled for ROMX.
; Can be checked at compile time to avoid some bank-switching calls.
DEF CONFIG_BANKABLE_ROMX EQU 1

; Toggle if banking is enabled for SRAM.
; Can be checked at compile time to avoid some bank-switching calls.
DEF CONFIG_BANKABLE_SRAM EQU 1

; Toggle if the game makes use the extra bankable CGB WRAMX.
; Can be checked at compile time to avoid some bank-switching calls.
DEF CONFIG_BANKABLE_WRAMX EQU 1

; Toggle if the game makes use of bankable CGB VRAM.
; Can be checked at compile time to avoid some bank-switching calls.
DEF CONFIG_BANKABLE_VRAM EQU 0

    ENDC
