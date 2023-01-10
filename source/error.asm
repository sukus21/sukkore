INCLUDE "hardware.inc"
INCLUDE "color.inc"

SECTION "ERROR SCREEN VECTOR", ROM0[$0038]
    
; Switches bank and jumps.
; Should be called using an `rst` instruction.
; Lives in ROM0.
;
; Input:
; - `hl`: Pointer to error message
v_error::
    jp error_start
;

SECTION "ERROR SCREEN LOADER", ROM0
; Couldn't fit in vector table.
error_start:
    ld [w_error_tempregs+0], a
    ld a, bank(sinewave)
    ld [rROMB0], a
    jp sinewave
;



SECTION "ERROR SCREEN", ROMX, ALIGN[8]

;Just a bunch of 0's
zero: ds 512, $00

;Gradual sine curve
grad:
ANGLE = 0.0
MULTR = 0.0
    REPT 2048
ANGLE = ANGLE + 512.0
MULTR = MULTR + DIV(16.0, 2048.0)
    db MUL(MULTR, SIN(ANGLE)) >> 17
    ENDR

;Regular sine curve
sine:
ANGLE = 0.0
    REPT 512
    db MUL(16.0, SIN(ANGLE)) >> 17
ANGLE = ANGLE + 512.0
    ENDR



;Background tileset
error_tiles:
    INCBIN "errorscreen/face.tls"
    .end
;

;Sprite tiles
error_sprites:
    INCBIN "errorscreen/sprites.tls"
    .end
;

error_font:
    INCBIN "errorscreen/font.tls"
    .end
;

;Tilemap data
error_map:
    INCBIN "errorscreen/tilemap.tlm"
    error_map_e:
;

;Sprite initialization data
error_spritedata:
    INCBIN "errorscreen/objdata.bin"
    .end
;

;Background palette
error_palette_bg:
    color_dmg_blk
    color_dmg_wht
    color_dmg_blk
    color_dmg_wht
;

;Sprite palette
error_palette_obj:
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
sinewave:
    
    ;Stop everything
    di

    ;Save A, HL and SP temporarily
    ;A was previously saved
    ld a, h
    ld [w_error_tempregs + 6], a
    ld a, l
    ld [w_error_tempregs + 7], a
    pop hl
    ld [w_error_tempregs + 9], sp
    ld a, [w_error_tempregs + 10]
    ld [w_error_tempregs + 8], a

    ;Save AF
    ld sp, w_error_tempregs + 3
    ld hl, sp - 1
    push af

    ;Save BC and DE
    ld a, b
    ld [hl+], a
    ld a, c
    ld [hl+], a
    ld a, d
    ld [hl+], a
    ld a, e
    ld [hl+], a

    ;Save rIE and rIF
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
    ld sp, w_error_stack
    
    ;Is LCD already disabled?
    ld hl, rLCDC
    bit 7, [hl]

    ;If yes, skip disabling the LCD
    jr z, :+

        ;Wait for Vblank
        ld hl, rLY
        ld a, 144
        .wait
        cp a, [hl]
        jr nz, .wait

        ;Disable LCD
        xor a
        ld [rLCDC], a
    :

    ;Reset background scrolling
    ld a, -16
    ldh [rSCX], a
    xor a
    ldh [rSCY], a

    ;Set window position
    ld a, 84
    ldh [rWY], a
    ld a, 102
    ldh [rWX], a

    ;Set palettes to black and white
    xor a
    ld hl, error_palette_bg
    call palette_copy_bg
    xor a
    ld hl, error_palette_obj
    call palette_copy_spr

    ;Clear VRAM
    xor a
    ldh [rVBK], a
    ld b, 0
    ld de, $2000
    ld hl, _VRAM
    call memfill

    ;Clear VRAM again, but for the second VRAM bank
    ld a, 1
    ldh [rVBK], a
    ld b, 0
    ld de, $2000
    ld hl, $8000
    call memfill
    xor a
    ldh [rVBK], a

    ;Copy register view to _SCRN1
    ld hl, $9BFF
    ld de, w_error_tempregs
    ld bc, "af"
    call numtoscreen
    ld bc, "bc"
    call numtoscreen
    ld bc, "de"
    call numtoscreen
    ld bc, "hl"
    call numtoscreen
    ld bc, "sp"
    call numtoscreen
    ld bc, "in"
    call numtoscreen

    ;Check old HL value
    ld a, [w_error_tempregs+6]
    ld h, a
    ld a, [w_error_tempregs+7]
    ld l, a

    ;Check values at this position
    ld a, [hl+]
    cp a, $FF
    ld a, 0
    jr nz, .nomessage
    ld a, [hl+]
    or a, a ;cp a, 0
    jr nz, .nomessage
        ;There is a crash message, copy it to tilemap
        ld b, h
        ld c, l
        ld hl, $9AC0
        call strcopy
        ld a, $FF
    .nomessage
    ldh [h_setup], a

    ;DMA setup
    call sprite_setup
    
    ;Load face graphics into VRAM
    ld hl, $9000
    ld bc, error_tiles
    ld de, $0800
    call memcopy
    ld hl, $8800
    ld de, error_tiles.end - error_tiles - $0800
    call memcopy
    
    ;Load numbers into VRAM
    ld hl, $8900
    ld bc, error_font + $100
    ld de, 16*10
    call memcopy
    ld bc, error_font + 33*16
    ld de, 16*6
    call memcopy

    ;Copy font into VRAM
    ld bc, error_font
    ld de, $0600
    call memcopy

    ;Copy sprites into VRAM
    ld hl, $8000
    ld bc, error_sprites
    ld de, error_sprites.end - error_sprites
    call memcopy

    ;Load map into VRAM
    ld bc, error_map
    ld hl, $9800
    ld de, 0

    .loop
    ;Copy the data
    ld a, [bc]
    inc bc
    ld [hl+], a

    ;Horizontal counter
    inc d
    ld a, $10
    cp a, d
    jr nz, .loop
    ld d, 0

    ;Horizontal offset
    push bc
    ld bc, $10
    add hl, bc
    pop bc

    ;Vertical offset
    inc e
    ld a, $10
    cp a, e
    jr nz, .loop

    ;Set DMG palettes
    ld a, %00110011
    ld [rBGP], a
    ld a, %11000100
    ld [rOBP0], a

    ;Set sprite data
    ;Saves me time, because I don't want to do it manually
    ld hl, w_oam_mirror
    ld bc, error_spritedata
    ld de, $A0
    call memcopy
    
    ;Update OAM
    call h_dma_routine

    ;Prepare
    ld hl, zero+144

    ;Enable interupts
    ld a, STATF_MODE00
    ld [rSTAT], a
    ld a, IEF_STAT
    ld [rIE], a
    xor a
    ld [rIF], a

    ;re-enable LCD
    ld a, LCDCF_ON | LCDCF_BLK21 | LCDCF_OBJ16 | LCDCF_OBJON | LCDCF_BGON | LCDCF_WIN9C00
    ldh [rLCDC], a
    ;Falls into `error_wait`



error_wait:
    ldh a, [rIF]
    xor a, 2
    ldh [rIF], a
    halt
    ;Falls into `int_stat`

;Stat
int_stat:

    ;Write previously found value
    ld a, b
    ldh [rSCY], a

    ;Decrement wave pointer
    dec de

    ;Grab final thing
    ld a, [de]
    sub a, $08
    ld b, a



    ;VBLANK CHECK
    ;Check scanline number
    ldh a, [rLY]
    cp a, $8F
    jr z, .vwait
    cp a, $86
    jp nz, error_wait
    ldh a, [h_setup]
    or a, a
    jp z, error_wait

    ;Show error message
    .vwait
    ld a, 40
    ldh [rSCY], a

    ;Save these for later
    push bc
    ldh a, [rSCX]
    ld b, a
    ldh a, [rLCDC]
    ld c, a
    and a, ~(LCDCF_OBJON |LCDCF_WINON)
    ldh [rLCDC], a
    xor a
    ldh [rSCX], a

    ;This is the final scanline, just wait for VBlank
    ld a, IEF_VBLANK
    ldh [rIE], a
    halt 


    
    ;VBLANK
    ;Restore PPU registers
    ld a, b
    ldh [rSCX], a
    ld a, c
    ldh [rLCDC], a

    ;Cool and fun input test
    call input

    ;Go to the start of the animation if A is pressed
    bit PADB_A, c
    jr z, :+
        ld hl, grad+40
    :

    ;Go to the end of the animation if B is pressed
    bit PADB_B, c
    jr z, :+
        ld hl, sine+144
    :

    bit PADB_SELECT, c
    jr z, :+
        ldh a, [rLCDC]
        xor a, LCDCF_WINON
        ldh [rLCDC], a
    :

    ;Save things on the stack
    push hl

    ;Decrease all 40 sprites Y-position
    ld b, 40
    ld hl, w_oam_mirror
    ld de, $0004
    .loop40
        dec [hl]
        add hl, de
        dec b
        jr nz, .loop40
    ;

    ;Move right sprites away if window is open
    ldh a, [rLCDC]
    ld c, a
    ld b, 9
    ld hl, w_oam_mirror+16*4+1
    .loop20w
        bit LCDCB_WINON, a
        set 6, [hl]
        jr nz, :+
            res 6, [hl]
        :
        add hl, de
        dec b
        jr nz, .loop20w

    ;Run sprite DMA
    call h_dma_routine

    ;Retrieve sine pointer from stack
    pop hl
    pop bc

    ;Increase sine pointer
    inc hl
    
    ;Decrease sine pointer if too high
    ld a, high(sine)+2
    cp a, h
    jr nz, :+
    dec h
    :

    ;Load sine pointer back into DE
    ld d, h
    ld e, l

    ;Prepare next cycle
    ld a, [de]
    sub a, 31
    ld b, a

    ;Do this
    ldh [rSCY], a

    ;Reenable interupts
    xor a
    ldh [rIF], a
    ld a, 2
    ldh [rIE], a
    jp error_wait
;



; Copies a numbers to the screen as hex.
; 
; Input:
; - `bc`: Number prefix (immediate value)
; - `hl`: Pointer to tilemap position - 32
numtoscreen:

    ;Move HL into position
    ld a, l
    or a, %00011111
    ld l, a
    inc hl

    ;Copy text
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

    ;High digit
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

    ;Low digit
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

    ;Return
    ret 
;



; Error messages and their character map.
error_messages:
    PUSHC
    NEWCHARMAP chm_errormsg
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

    ;Strings containing error messages
    error_strings:
    error_entityoverflow::  db $FF, $00, "ENTITY OVERFLOW", $00
    POPC
;
