    IF !DEF(CONFIG_INC)
    DEF CONFIG_INC EQU 1

; Determines if dev mode is enabled or not.
; Set this flag to 0 when building the final release.
DEF CONFIG_DEV EQU 1

; Number of total ROM banks, including ROM0.
; This has to be manually updated as the ROM size grows.
DEF CONFIG_ROM_BANK_COUNT EQU 2

; Number of total SRAM banks.
; This has to be manually updated, as potential savegames grow in size.
DEF CONFIG_SRAM_BANK_COUNT EQU 0

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
DEF CONFIG_BANKABLE_VRAM EQU 1

    ENDC
