    IF !DEF(MACRO_COLOR_INC)
    DEF MACRO_COLOR_INC EQU 1

; Default palette.  
; Color order:  
; White -> ltgray -> dkgray -> black
DEF PALETTE_DEFAULT EQU $E4

; Default palette with black and white swapped.  
; Color order:  
; Black -> ltgray -> dkgray -> white
DEF PALETTE_INVERTED EQU $27


; The bitmask to apply to `wFadeState` to get the fading state.
DEF COLOR_FADEM_STATE EQU %11000000

; The bitmask to apply to `wFadeState` to get the current fade step.
DEF COLOR_FADEM_STEP EQU %00110000

; The bitmask to apply to `wFadeState` to get the fade timer.
DEF COLOR_FADEM_TIMER EQU %0000_1111

; Fade routine is not active.
DEF COLOR_FADESTATE_NONE EQU %00_000000

; Fade routine has faded to black.
DEF COLOR_FADESTATE_DONE EQU %01_000000

; Fade routine is fading colors from black.
DEF COLOR_FADESTATE_IN EQU %10_000000

; Fade routine is fading colors to black.
DEF COLOR_FADESTATE_OUT EQU %11_000000

; If this bit of `wFadeState` is set, the fade-routine is running.
DEF COLOR_FADEB_RUNNING EQU 7

; If the `COLOR_FADEB_RUNNING` bit of `wFadeState` is set, use this bit to find fade direction.  
; 0 = fade in.  
; 1 = fade out.
DEF COLOR_FADEB_DIRECTION EQU 6


; Color macro, useful for defining palettes.
; Expands to a single `dw` command.
; 
; Input:
; - 1: Red (0-31)
; - 2: Green (0-31)
; - 3: Blue (0-31)
MACRO color_t
    dw ((\3) << 10) + ((\2) << 5) + (\1)
ENDM

; The color that closest matches DMG black.
MACRO color_dmg_blk
    color_t 0, 0, 0
ENDM

; The color that closest matches DMG dark gray.
MACRO color_dmg_dkg
    color_t 7, 7, 7
ENDM

; The color that closest matches DMG light gray.
MACRO color_dmg_ltg
    color_t 13, 13, 13
ENDM

; The color that closest matches DMG white.
MACRO color_dmg_wht
    color_t 31, 31, 31
ENDM

    ENDC
