INCLUDE "hardware.inc/hardware.inc"
INCLUDE "macro/color.inc"


SECTION "ERROR SCREEN VECTOR", ROM0[$0038]
    
; Switches bank and jumps.  
; Should be called using an `rst` instruction.  
; Lives in ROM0.
;
; Input:
; - `hl`: Pointer to error message
VecError::
    jp ErrorStart
;



SECTION "ERROR SCREEN LOADER", ROM0

; Could not fit in vector table.
; Lives in ROM0.
ErrorStart:
    ld [wRegisterCacheA], a
    ld a, bank(GameloopError)
    ld [rROMB0], a
    jp GameloopError
;



SECTION "ERROR SCREEN", ROMX, ALIGN[8]

; Just a bunch of 0's
Zero: ds 512, $00

; Gradual sine curve
Grad:
    DEF SINE_SPEED = 4.0
    DEF SINE_POWER = 8.0
    DEF ANGLE = 0.0
    DEF SCALE = 0.0
    REPT 2048
        DEF ANGLE += DIV(SINE_SPEED, 256.0)
        DEF SCALE += DIV(SINE_POWER, 2048.0)
        db MUL(SCALE, SIN(ANGLE)) >> 16
    ENDR
;

; Regular sine curve
Sine:
    DEF ANGLE = 0.0
    REPT 512
        DEF ANGLE += DIV(SINE_SPEED, 256.0)
        db MUL(SINE_POWER, SIN(ANGLE)) >> 16
    ENDR

    PURGE SINE_SPEED
    PURGE SINE_POWER
    PURGE ANGLE
    PURGE SCALE
;

; Background tileset
ErrorTiles: INCBIN "gameloop/error/face.1bpp"
.end

; Sprite tiles
ErrorSprites: INCBIN "gameloop/error/sprites.2bpp"
.end

; Font tiles
ErrorFont: INCBIN "gameloop/error/font.1bpp"
.end

; Tilemap data
ErrorMap: INCBIN "gameloop/error/face.tilemap"
.end

; Sprite initialization data
ErrorSpriteData:
    db $C0, $10, $02, $00,   $C0, $18, $04, $00
    db $D0, $10, $06, $00,   $D0, $18, $08, $00
    db $E0, $10, $0A, $00,   $E0, $18, $0C, $00
    db $F0, $10, $0E, $00,   $F0, $18, $10, $00
    db $00, $14, $00, $00
    
    db $00, $E0, $00, $00,   $00, $E0, $00, $00
    db $00, $E0, $00, $00,   $00, $E0, $00, $00
    db $00, $E0, $00, $00,   $00, $E0, $00, $00
    db $00, $E0, $00, $00

    db $C0, $90, $02, $00,   $C0, $98, $04, $00
    db $D0, $90, $06, $00,   $D0, $98, $08, $00
    db $E0, $90, $0A, $00,   $E0, $98, $0C, $00
    db $F0, $90, $0E, $00,   $F0, $98, $10, $00
    db $00, $94, $00, $00

    db $00, $E0, $00, $00,   $00, $E0, $00, $00
    db $00, $E0, $00, $00,   $00, $E0, $00, $00
    db $00, $E0, $00, $00,   $00, $E0, $00, $00
    db $00, $E0, $00, $00,   $00, $E0, $00, $00
    db $00, $E0, $00, $00,   $00, $E0, $00, $00
    db $00, $E0, $00, $00,   $00, $E0, $00, $00
    db $00, $E0, $00, $00,   $00, $E0, $00, $00
    db $00, $E0, $00, $00
.end

; Background palette
ErrorPaletteBG:
    color_dmg_blk
    color_dmg_wht
    color_dmg_blk
    color_dmg_wht
;

; Sprite palette
ErrorPaletteOBJ:
    color_dmg_wht
    color_dmg_ltg
    color_dmg_wht
    color_dmg_blk
;



; Main error handling function.
; Keeps running until the game is turned off.
; TODO: make sure this also works in GBC mode.
;
; Input:
; - `hl`: Pointer to error message
;
; Destroys: all
GameloopError:
    
    ; Stop everything
    di

    ; Save A, HL and SP temporarily
    ; A was previously saved
    ld a, h
    ld [wRegisterCacheH], a
    ld a, l
    ld [wRegisterCacheL], a
    ld [wRegisterCacheSP + 1], sp
    ld a, [wRegisterCacheSP + 2]
    ld [wRegisterCacheSP], a
    pop hl

    ; Save AF
    ld sp, wRegisterCacheF + 2
    push af
    ld hl, sp + 1

    ; Save BC and DE
    ld a, b
    ld [hl+], a
    ld a, c
    ld [hl+], a
    ld a, d
    ld [hl+], a
    ld a, e
    ld [hl+], a

    ; Save rIE and rIF
    ld a, l
    add a, 4
    ld l, a
    jr nc, :+
        inc h
    :
    ldh a, [rIE]
    ld [hl+], a
    ldh a, [rIF]
    ld [hl+], a
    ld sp, wStack

    ; Is LCD already disabled?
    ld hl, rLCDC
    bit 7, [hl]

    ; If yes, skip disabling the LCD
    jr z, :+

        ; Wait for Vblank
        ld hl, rLY
        ld a, 144
        .wait
        cp a, [hl]
        jr nz, .wait

        ; Disable LCD
        xor a
        ldh [rLCDC], a
    :

    ; Turn off audio
    xor a
    ldh [rNR52], a

    ; Reset background scrolling
    ld a, -16
    ldh [rSCX], a
    xor a
    ldh [rSCY], a

    ; Set window position
    ld a, 84
    ldh [rWY], a
    ld a, 102
    ldh [rWX], a

    ; Set palettes to black and white
    xor a
    ld hl, ErrorPaletteBG
    call PaletteCopyBG
    xor a
    ld hl, ErrorPaletteOBJ
    call PaletteCopyOBJ

    ; Clear VRAM
    xor a
    ldh [rVBK], a
    ld b, 0
    ld de, $2000
    ld hl, _VRAM
    call Memset

    ; Clear VRAM again, but for the second VRAM bank
    ld a, 1
    ldh [rVBK], a
    ld b, 0
    ld de, $2000
    ld hl, $8000
    call Memset
    xor a
    ldh [rVBK], a

    ; Copy register view to _SCRN1
    ld hl, $9BFF
    ld de, wRegisterCache
    ld bc, "a"<<8 | "f"
    call ErrorNumberToScreen
    ld bc, "b"<<8 | "c"
    call ErrorNumberToScreen
    ld bc, "d"<<8 | "e"
    call ErrorNumberToScreen
    ld bc, "h"<<8 | "l"
    call ErrorNumberToScreen
    ld bc, "s"<<8 | "p"
    call ErrorNumberToScreen
    ld bc, "i"<<8 | "n"
    call ErrorNumberToScreen

    ; Check old HL value
    ld a, [wRegisterCacheH]
    ld h, a
    ld a, [wRegisterCacheL]
    ld l, a

    ; Check values at this position
    ld a, [hl+]
    cp a, $FF
    ld a, 0
    jr nz, .noMessage
    ld a, [hl+]
    or a, a ; cp a, 0
    jr nz, .noMessage
        ; There is a crash message, copy it to tilemap
        ld b, h
        ld c, l
        ld hl, $9AC0
        call Strcpy
        ld a, $FF
    .noMessage
    ld [wHasMessage], a

    ; DMA setup
    call OamDmaInit

    ; Load face graphics into VRAM
    ld hl, $9000
    ld bc, ErrorTiles
    ld de, $400
    call Memcpy1BPP
    ld hl, $8800
    ld de, ErrorTiles.end - ErrorTiles - $0400
    call Memcpy1BPP

    ; Load numbers into VRAM
    ld hl, $8900
    ld bc, ErrorFont + ("0" - " ") * 8
    ld de, 10 * 8
    call Memcpy1BPP
    ld bc, ErrorFont + ("A" - " ") * 8
    ld de, 6 * 8
    call Memcpy1BPP

    ; Copy font into VRAM
    ld bc, ErrorFont
    ld de, ErrorFont.end - ErrorFont
    call Memcpy1BPP

    ; Copy sprites into VRAM
    ld hl, $8000
    ld bc, ErrorSprites
    ld de, ErrorSprites.end - ErrorSprites
    call Memcpy

    ; Load map into VRAM
    ld bc, ErrorMap
    ld hl, $9800
    ld de, 0

    .loop
    ; Copy the data
    ld a, [bc]
    inc bc
    ld [hl+], a

    ; Horizontal counter
    inc d
    ld a, $10
    cp a, d
    jr nz, .loop
    ld d, 0

    ; Horizontal offset
    push bc
    ld bc, $10
    add hl, bc
    pop bc

    ; Vertical offset
    inc e
    ld a, $10
    cp a, e
    jr nz, .loop

    ; Set DMG palettes
    ld a, %00011011
    call PaletteSetBGP
    ld a, %00011100
    call PaletteSetOBP0

    ; Set sprite data
    ; Saves me time, because I don't want to do it manually
    ld hl, wOAM
    ld bc, ErrorSpriteData
    ld de, $A0
    call Memcpy

    ; Update OAM
    ld a, high(wOAM)
    call hDMA

    ; Prepare
    ld hl, Zero+144
    ld d, h
    ld e, l

    ; Enable interupts
    ld a, STATF_MODE00
    ldh [rSTAT], a
    ld a, IEF_STAT
    ldh [rIE], a
    xor a
    ldh [rIF], a

    ; re-enable LCD
    ld a, LCDCF_ON | LCDCF_BLK21 | LCDCF_OBJ16 | LCDCF_OBJON | LCDCF_BGON | LCDCF_WIN9C00
    ldh [rLCDC], a
    ; Falls into `ErrorWait`



ErrorWait:
    xor a
    ldh [rIF], a
    halt
    nop
    ; Falls into `ErrorStatInterrupt`

; Stat
ErrorStatInterrupt:

    ; Write previously found value
    ld a, b
    ldh [rSCY], a

    ; Decrement wave pointer
    dec de

    ; Grab final thing
    ld a, [de]
    sub a, $08
    ld b, a

    ; VBLANK CHECK
    ; Check scanline number
    ldh a, [rLY]
    cp a, $86
    jr nz, :+
        ld a, [wHasMessage]
        or a, a
        jr z, ErrorWait
    :
    cp a, $8F
    jr c, ErrorWait

    ; Show error message
    ld a, 40
    ldh [rSCY], a

    ; Save these for later
    push bc
    ldh a, [rSCX]
    ld b, a
    ldh a, [rLCDC]
    ld c, a
    and a, ~(LCDCF_OBJON | LCDCF_WINON)
    ldh [rLCDC], a
    xor a
    ldh [rSCX], a

    ; This is the final scanline, wait for VBlank
    .waitForVBlank
        ldh a, [rSTAT]
        and a, STATF_LCD
        dec a
        jr nz, .waitForVBlank
    ;


    ; VBLANK
    ; Restore PPU registers
    ld a, b
    ldh [rSCX], a
    ld a, c
    ldh [rLCDC], a

    ; Cool and fun input test
    call ReadInput

    ; Go to the start of the animation if A is pressed
    bit PADB_A, c
    jr z, :+
        ld hl, Grad+40
    :

    ; Go to the end of the animation if B is pressed
    bit PADB_B, c
    jr z, :+
        ld hl, Sine+144
    :

    bit PADB_SELECT, c
    jr z, :+
        ldh a, [rLCDC]
        xor a, LCDCF_WINON
        ldh [rLCDC], a
    :

    bit PADB_START, c
    jp nz, Main

    ; Save things on the stack
    push hl

    ; Decrease all 40 sprites Y-position
    ld b, 40
    ld hl, wOAM
    ld de, $0004
    .loop40
        dec [hl]
        add hl, de
        dec b
        jr nz, .loop40
    ;

    ; Move right sprites away if window is open
    ldh a, [rLCDC]
    ld c, a
    ld b, 9
    ld hl, wOAM+16*4+1
    .loop20w
        bit LCDCB_WINON, a
        set 6, [hl]
        jr nz, :+
            res 6, [hl]
        :
        add hl, de
        dec b
        jr nz, .loop20w

    ; Run sprite DMA
    ld a, high(wOAM)
    call hDMA

    ; Retrieve sine pointer from stack
    pop hl
    pop bc

    ; Increase sine pointer
    inc hl

    ; Decrease sine pointer if too high
    ld a, high(Sine)+2
    cp a, h
    jr nz, :+
    dec h
    :

    ; Load sine pointer back into DE
    ld d, h
    ld e, l

    ; Prepare next cycle
    ld a, [de]
    sub a, 31
    ld b, a

    ; Do this
    ldh [rSCY], a

    ; Reenable interupts
    xor a
    ldh [rIF], a
    ld a, IEF_STAT
    ldh [rIE], a
    jp ErrorWait
;



; Copies a numbers to the screen as hex.
; 
; Input:
; - `bc`: Number prefix (immediate value)
; - `hl`: Pointer to tilemap position - 32
ErrorNumberToScreen:

    ; Move HL into position
    ld a, l
    or a, %00011111
    ld l, a
    inc hl

    ; Copy text
    ld a, b
    add a, $80
    ld [hl+], a
    ld a, c
    add a, $80
    ld [hl+], a
    ld a, ":"+$80
    ld [hl+], a
    ld a, "$"+$80
    ld [hl+], a

    ; High digit
    ld a, [de]
    and a, %11110000
    swap a
    add a, $90
    ld [hl+], a
    ld a, [de]
    and a, %00001111
    add a, $90
    ld [hl+], a
    inc de

    ; Low digit
    ld a, [de]
    and a, %11110000
    swap a
    add a, $90
    ld [hl+], a
    ld a, [de]
    and a, %00001111
    add a, $90
    ld [hl+], a
    inc de

    ; Return
    ret 
;



; Error messages and their character map.
ErrorMessages:
    PUSHC
    NEWCHARMAP CHM_ERROR_MSG
    CHARMAP " ", $A0
    CHARMAP "!", $A1
    CHARMAP "\"", $A2
    CHARMAP "#", $A3
    CHARMAP "$", $A4
    CHARMAP "%", $A5
    CHARMAP "&", $A6
    CHARMAP "'", $A7
    CHARMAP "(", $A8
    CHARMAP ")", $A9
    CHARMAP "*", $AA
    CHARMAP "+", $AB
    CHARMAP ",", $AC
    CHARMAP "-", $AD
    CHARMAP ".", $AE
    CHARMAP "/", $AF
    CHARMAP "0", $B0
    CHARMAP "1", $B1
    CHARMAP "2", $B2
    CHARMAP "3", $B3
    CHARMAP "4", $B4
    CHARMAP "5", $B5
    CHARMAP "6", $B6
    CHARMAP "7", $B7
    CHARMAP "8", $B8
    CHARMAP "9", $B9
    CHARMAP ":", $BA
    CHARMAP ";", $BB
    CHARMAP "<", $BC
    CHARMAP "=", $BD
    CHARMAP ">", $BE
    CHARMAP "?", $BF

    CHARMAP "A", $C1
    CHARMAP "B", $C2
    CHARMAP "C", $C3
    CHARMAP "D", $C4
    CHARMAP "E", $C5
    CHARMAP "F", $C6
    CHARMAP "G", $C7
    CHARMAP "H", $C8
    CHARMAP "I", $C9
    CHARMAP "J", $CA
    CHARMAP "K", $CB
    CHARMAP "L", $CC
    CHARMAP "M", $CD
    CHARMAP "N", $CE
    CHARMAP "O", $CF
    CHARMAP "P", $D0
    CHARMAP "Q", $D1
    CHARMAP "R", $D2
    CHARMAP "S", $D3
    CHARMAP "T", $D4
    CHARMAP "U", $D5
    CHARMAP "V", $D6
    CHARMAP "W", $D7
    CHARMAP "X", $D8
    CHARMAP "Y", $D9
    CHARMAP "Z", $DA
    CHARMAP "[", $DB
    CHARMAP "\\", $DC
    CHARMAP "]", $DD
    CHARMAP "^", $DE
    CHARMAP "_", $DF

    CHARMAP "a", $C1
    CHARMAP "b", $C2
    CHARMAP "c", $C3
    CHARMAP "d", $C4
    CHARMAP "e", $C5
    CHARMAP "f", $C6
    CHARMAP "g", $C7
    CHARMAP "h", $C8
    CHARMAP "i", $C9
    CHARMAP "j", $CA
    CHARMAP "k", $CB
    CHARMAP "l", $CC
    CHARMAP "m", $CD
    CHARMAP "n", $CE
    CHARMAP "o", $CF
    CHARMAP "p", $D0
    CHARMAP "q", $D1
    CHARMAP "r", $D2
    CHARMAP "s", $D3
    CHARMAP "t", $D4
    CHARMAP "u", $D5
    CHARMAP "v", $D6
    CHARMAP "w", $D7
    CHARMAP "x", $D8
    CHARMAP "y", $D9
    CHARMAP "z", $DA
    CHARMAP "\{", $DB
    CHARMAP "|", $DC
    CHARMAP "}", $DD
    CHARMAP "~", $DE

    ; Create error message, with correct signature.
    ; Expands to a `db` command.
    ;
    ; Input:
    ; - `1`: Error message string
    MACRO create_message
        db $FF, $00, \1, $00
    ENDM

    ; Strings containing error messages
    ErrorStrings:
    ErrorEntityOverflow::   create_message "ENTITY OVERFLOW"
    ErrorColorRequired::    create_message "ONLY PLAYS ON CGB"
    ErrorVQueueOverflow::   create_message "VQUEUE OVERFLOW"
    ErrorRomXBankMarker::   create_message "ROMX BANK W/O MARK"
    ErrorRomXBankCount::    create_message "BAD ROMX BANK COUNT"
    ErrorSramBankCount::    create_message "BAD SRAM BANK COUNT"
    ErrorInvalidYellerOpcode::    create_message "INVALID YELLER OPCODE"
    ErrorInvalidGameData::    create_message "INVALID GAME DATA"
    POPC
;



SECTION UNION "WRAMX BUFFER", WRAMX, ALIGN[8]
    wRegisterCache:
    wRegisterCacheA: ds 1
    wRegisterCacheF: ds 1
    wRegisterCacheB: ds 1
    wRegisterCacheC: ds 1
    wRegisterCacheD: ds 1
    wRegisterCacheE: ds 1
    wRegisterCacheH: ds 1
    wRegisterCacheL: ds 1
    wRegisterCacheSP: ds 3
    wHasMessage: ds 1
;
