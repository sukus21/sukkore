INCLUDE "hardware.inc/hardware.inc"
INCLUDE "macro/memcpy.inc"
INCLUDE "macro/numtohex.inc"
INCLUDE "macro/relpointer.inc"
INCLUDE "vqueue/vqueue.inc"
INCLUDE "gameloop/entsys_demo/vram.inc"
INCLUDE "macro/farcall.inc"

SECTION "TESTLOOP DATA", ROMX

TestloopFont: INCBIN "font.1bpp"
.end
TestloopSlots: INCBIN "gameloop/entsys_demo/slots.2bpp"
.end
TestloopCursor: INCBIN "gameloop/entsys_demo/cursor.2bpp"
.end

TestloopStr:
    .f64 db " 64:$    "
    .f32 db " 32:$    "
    .f16 db " 16:$    "
;

; Transfer routine, responsible for loading the required assets.
;
; Saves: none
TestloopTransfer:
    
    ; Clear tilemap
    ld hl, _SCRN0
    ld bc, $00_40
    call MemsetChunked

    ; Copy font tiles
    ld bc, TestloopFont
    ld d, (TestloopFont.end - TestloopFont) >> 3
    ld hl, VT_ENTALLOC_FONT
    call MemcpyTile1BPP
    
    ; Copy chunk tiles
    ld bc, TestloopSlots
    ld d, (TestloopSlots.end - TestloopSlots) >> 4
    ld hl, VT_ENTALLOC_CHUNKS
    call MemcpyTile2BPP

    ; Copy cursor tiles
    ld bc, TestloopCursor
    ld d, (TestloopCursor.end - TestloopCursor) >> 4
    ld hl, VT_ENTALLOC_CURSOR
    call MemcpyTile2BPP

    ; Set background position
    ld a, -16
    ldh [rSCX], a
    ldh [rSCY], a

    ; Set DMG palettes
    ld a, %11100100
    call PaletteSetBGP
    ld a, %11011100
    call PaletteSetOBP0

    ; Ok, I think we are done here!
    ret
;



SECTION "GAMELOOP TEST", ROM0

; Does not return.
; Should not be called, but jumped to from another gameloop,
; or after resetting the stack.
; Lives in ROM0.
GameloopTest::

    ; Load assets
    vqueue_enqueue TestloopTransfer
    call GameloopLoading

    ; Initialize a few variables
    xor a
    ld [wAllocationDemoX], a
    ld [wAllocationDemoY], a
    ld [wAllocationDemoSize], a
    ld [wAllocationDemoCounter], a
    dec a
    ld [wAllocationDemoPerformance], a

    ; Clear OAM
    ld a, high(wOAM)
    call hDMA

    ; Enable LCD
    ld a, LCDCF_ON | LCDCF_OBJON | LCDCF_BGON | LCDCF_BLK01
    ldh [rLCDC], a
    call WaitVBlank

    ; Initialize audio
    farcall InitAudio

    ; Play some nice music :{)
    ; ld bc, MiiChannelSong
    ld bc, SchombatSong
    call PlaySound

    ; Main loop
    .loop
    call ReadInput

    ; Select what allocation mode to do
    ld hl, wAllocationDemoSize
    ld a, [hl]
    bit PADB_SELECT, c
    jr z, :+
        inc [hl]
        ld a, [hl]
        cp a, 3
        jr c, :+
        xor a
        ld [hl], a
    :

    ld a, [wInputPressed]
    bit PADB_B, a
    jr z, :+
        ld bc, EpicTestSoundOne
        call PlaySound
    :

    ; Get sprite Y-position
    add a, a
    add a, a
    add a, a
    add a, 71
    ld c, a

    ; Get sprite and apply Y-position
    ld b, 4
    ld h, high(wOAM)
    call SpriteGet
    ld [hl], c
    inc l

    ; Make up an X-position and tile ID
    ld [hl], 47
    inc l
    ld [hl], VTI_ENTALLOC_CURSOR

    ; Allocate new entity
    ld a, [wInputPressed]
    bit PADB_A, a
    jr z, .noAlloc
        ld c, 1
        call WaitScanline
        ld a, [wAllocationDemoSize]
        cp a, 0
        jr nz, :+
            call EntsysNew64
            jr .allocDone
        :
        cp a, 1
        jr nz, :+
            call EntsysNew32
            jr .allocDone
        :
        cp a, 2
        jr nz, .noAlloc
        call EntsysNew16
        ; Falls into `allocDone`

        .allocDone
        ; Set entity bank to 1
        ld a, 1
        ld [bc], a
        ldh a, [rLY]
        ld [wAllocationDemoPerformance], a
    .noAlloc

    ; Free entities
    ld a, [wInputPressed]
    ld b, a
    ld hl, wAllocationDemoX
    ld a, [hl+]
    ld d, a ; x-axis
    ld e, [hl] ; y-axis

    ; Move on X-axis
    bit PADB_LEFT, b
    jr z, :+
        dec d
    :
    bit PADB_RIGHT, b
    jr z, :+
        inc d
    :
    ld a, d
    and a, %00001111
    ld d, a

    ; Move on Y-axis
    bit PADB_UP, b
    jr z, :+
        dec e
    :
    bit PADB_DOWN, b
    jr z, :+
        inc e
    :
    ld a, e
    and a, %00000011

    ; Save modified values
    ld [hl-], a
    ld [hl], d

    ; Draw cursor sprite
    add a, a
    add a, a
    add a, a
    add a, 28
    ld c, a ; y-position

    ; Get sprite
    ld b, 4
    ld h, high(wOAM)
    call SpriteGet
    ld [hl], c
    inc l

    ; Make up an X-position and tile ID
    ld a, d
    add a, a
    add a, a
    add a, a
    add a, 24
    ld [hl+], a
    ld [hl], VTI_ENTALLOC_CURSOR

    ; Actually free entities
    ld a, [wInputPressed]
    bit PADB_B, a
    jr z, .noFree
        ld c, 1
        call WaitScanline
        ld l, d
        swap l
        ld a, high(wEntsys)
        add a, e
        ld h, a
        call EntsysFree
        ldh a, [rLY]
        ld [wAllocationDemoPerformance], a
    .noFree

    ; Get quick status of all entities
    ld hl, wEntsys
    ld de, wAllocationDemoStatus
    .entityLoop
        ; Is slot enabled?
        ld a, [hl+]
        ld b, VTI_ENTALLOC_CHUNK_FREE + 2
        or a, a
        ld c, 1
        ld a, [hl-]
        jr z, .entityInner

        ; Get size of slot
        ld b, VTI_ENTALLOC_CHUNK_FULL
        swap a
        and a, %00000111
        ld c, a
        rr a
        add a, b
        ld b, a

        ; Store this and move on to next entity
        .entityInner
            ld a, b
            ld [de], a
            inc de
            ld a, l
            add a, $10
            ld l, a
            ld a, 0
            adc a, h
            ld h, a

            ; Multi-slot entity, repeat?
            dec c
            jr nz, .entityInner
        ;
        
        ; OOB check
        cp a, high(wEntsys.end)
        jr nz, .entityLoop
    ;

    ; Copy status for first64
    ld h, d
    ld l, e
    ld de, TestloopStr
    ld b, 9*3
    memcpy_custom hl, de, b

    ; Create sprites for performance metric
    ld a, [wAllocationDemoPerformance]
    num_to_hex a, d, e
    ld b, 8
    ld h, high(wOAM)
    call SpriteGet
    ld [hl], 64
    inc l
    ld [hl], 24
    inc l
    ld [hl], d
    inc l
    inc l
    ld [hl], 64
    inc l
    ld [hl], 32
    inc l
    ld [hl], e

    ; Create sprites for load time
    ld a, [wLoadingFrames]
    num_to_hex a, d, e
    ld b, 8
    ld h, high(wOAM)
    call SpriteGet
    ld [hl], 20
    inc l
    ld [hl], 8
    inc l
    ld [hl], d
    inc l
    inc l
    ld [hl], 20
    inc l
    ld [hl], 16
    inc l
    ld [hl], e

    ; Do sound updates
    farcall UpdateAudio

    ; Wait for Vblank
    ld h, high(wOAM)
    call SpriteFinish
    xor a
    ldh [rIF], a
    halt
    nop

    ; Copy entity status to tilemap
    ld hl, VM_ENTALLOC_CHUNKS
    ld de, wAllocationDemoStatus
    .vramLoop
        ld a, [de]
        inc de
        ld [hl+], a
        ld a, e
        and a, %00001111
        jr nz, .vramLoop

        ld a, l
        or a, %00011111
        inc a
        ld l, a
        
        ld a, e
        cp a, $40
        jr nz, .vramLoop
    ;

    ld b, 9
    ld hl, VM_ENTALLOC_SIZE_64
    memcpy_custom hl, de, b

    ld b, 9
    ld hl, VM_ENTALLOC_SIZE_32
    memcpy_custom hl, de, b

    ld b, 9
    ld hl, VM_ENTALLOC_SIZE_16
    memcpy_custom hl, de, b

    ; OAM DMA and repeat loop
    ld a, high(wOAM)
    call hDMA
    jp .loop
;



SECTION UNION "GAMELOOP UNION", WRAM0, ALIGN[8]

wAllocationDemoStatus: ds 128
wAllocationDemoX: ds 1
wAllocationDemoY: ds 1
wAllocationDemoSize: ds 1
wAllocationDemoPerformance: ds 1
wAllocationDemoCounter:: ds 1
