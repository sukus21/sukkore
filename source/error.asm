INCLUDE "hardware.inc"
INCLUDE "color.inc"

SECTION "ERROR SCREEN VECTOR", ROM0[$0038]
    
; Switches bank and jumps.
; Should be called using `rst` instruction.
; Lives in ROM0.
v_error::
    ld a, bank(sinewave)
    ld [$2000], a
    jp sinewave
;



SECTION "ERROR SCREEN", ROMX, ALIGN[8]

;Just a bunch of 0's
zero:
    ds 512, $00

;Gradual sine curve
grad:
ANGLE = 0.0
MULTR = 0.0
    REPT 2048
ANGLE = ANGLE + 256.0
MULTR = MULTR + DIV(32.0, 2048.0)
    db MUL(MULTR, SIN(ANGLE)) >> 16
    ENDR

;Regular sine curve
sine:
ANGLE = 0.0
    REPT 512
    db MUL(32.0, SIN(ANGLE)) >> 16
ANGLE = ANGLE + 256.0
    ENDR



;Background tileset
error_tiles:
    INCBIN "errorscreen/face.tls"
    error_tiles_e:
;

;Sprite tiles
error_sprites:
    INCBIN "errorscreen/sprites.tls"
    error_sprites_e:
;

;Tilemap data
error_map:
    INCBIN "errorscreen/tilemap.tlm"
    error_map_e:
;

;Sprite initialization data
error_spritedata:
    INCBIN "errorscreen/objdata.bin"
;

;Background palette
error_palette_bg:
    color_dmg_blk
    color_dmg_wht
    color_dmg_dkg
    color_dmg_blk
;

;Sprite palette
error_palette_obj:
    color_dmg_wht
    color_dmg_ltg
    color_dmg_wht
    color_dmg_blk
;



; Main error handling function.
; Keeps
sinewave::
    
    ;Reset stack pointer
    di
    ld sp, w_stack
    
    ;Is LCD already disabled?
    ld hl, rLCDC
    bit LCDCB_ON, [hl]

    ;If yes, skip disabling LCD
    jr z, :+

        ;Wait for Vblank
        ld hl, rLY
        ld a, SCRN_Y
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

    ;Set palettes to black and white
    ld hl, error_palette_bg
    call palette_copy_bg
    xor a
    ld hl, error_palette_obj
    call palette_copy_spr

    ;Clear VRAM
    ld b, 0
    ld de, $2000
    ld hl, _VRAM
    call memfill

    ;Clear VRAM again, but for the second VRAM bank
    ld a, 1
    ldh [rVBK], a
    ld b, 0
    ld de, $2000
    ld hl, _VRAM
    call memfill
    xor a
    ldh [rVBK], a

    ;DMA setup
    call sprite_setup

    ;Clear OAM
    ld hl, w_oam_mirror
    ld b, a
    ld de, $0100
    call memfill
    call h_dma_routine
    
    ;Load graphics into VRAM
    ld hl, _VRAM
    ld bc, error_tiles
    ld de, error_tiles_e - error_tiles
    call memcopy

    ld hl, _VRAM + $0BE0
    ld bc, error_sprites
    ld de, error_sprites_e - error_sprites
    call memcopy

    ;Load map into VRAM
    ld bc, error_map
    ld hl, _SCRN0
    ld de, $0000

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
    ldh [rBGP], a
    ld a, %11000100
    ldh [rOBP0], a

    ;Set sprite data
    ;Saves me time, because I don't want to do it manually
    ld hl, w_oam_mirror
    ld bc, error_spritedata
    ld de, $0100
    call memcopy
    
    ;Update OAM
    call h_dma_routine

    ;Prepare
    ld hl, zero+SCRN_Y

    ;Enable interupts
    ld a, STATF_MODE00
    ldh [rSTAT], a
    ld a, IEF_STAT
    ldh [rIE], a
    xor a
    ldh [rIF], a

    ;re-enable LCD
    ld a, LCDCF_ON | LCDCF_BG8000 | LCDCF_OBJ16 | LCDCF_OBJON | LCDCF_BGON
    ldh [rLCDC], a


;Manually wait for STAT interupt request
error_wait:
    ldh a, [rIF]
    xor a, IEF_STAT
    ldh [rIF], a
    halt

;Interupt request happened
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
    jp nz, error_wait

    ;This is the final scanline, just wait for VBlank
    ld a, LCDCF_BGON
    ldh [rIE], a
    halt 


    
    ;VBLANK
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
        ld hl, sine+SCRN_Y
    :

    ;Save things on the stack
    push hl

    ;Decrease all 40 sprites Y-position
    ld b, OAM_COUNT
    ld hl, w_oam_mirror
    ld de, $0004
    .loop
        dec [hl]
        add hl, de
        dec b
        jr nz, .loop
    ;

    ;Run sprite DMA
    call h_dma_routine

    ;Retrieve and increment sine pointer from stack
    pop hl
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

    ;Do this for now
    ldh [rSCY], a

    ;Reenable interupts
    xor a
    ldh [rIF], a
    ld a, IEF_STAT
    ldh [rIE], a
    jp error_wait
;

; Various error codes.
error_strings:

; Vblank interupt was triggered
error_vblank:: db "VBLANK INTERUPT VECTOR", $00
error_entityoverflow:: db "ENTITY OVERFLOW", $00