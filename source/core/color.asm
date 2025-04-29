INCLUDE "hardware.inc/hardware.inc"
INCLUDE "macro/color.inc"
INCLUDE "macro/memcpy.inc"
INCLUDE "vqueue/vqueue.inc"

SECTION "COLOR", ROM0

; Default CGB palette when running in pseudo-DMG mode.  
; Lives in ROM0.
ColorsCGB:
    color_dmg_wht
    color_dmg_ltg
    color_dmg_dkg
    color_dmg_blk
.end



; Initializes pseudo-DMG mode colors.  
; Lives in ROM0.
;
; Saves: none
ColorInit::
    memcpy_label ColorsCGB, wPaletteCGB
    
    ld hl, wPaletteDMG
    ld bc, $00_06
    jp MemsetShort
;



; Detect if current hardware is CGB compatible or not.  
; Lives in ROM0.
; 
; Returns:
; - `a`: result (0 = not CGB compatible)
; - `fZ`: result (0 = CGB compatible)
; - `fC`: result (1 = CGB compatible)
;
; Saves: none
DetectCGB::
    ld hl, _RAMBANK
    ld c, low(rSVBK)

    ; Save bank page
    ldh a, [c]
    ld b, a

    ; Overwrite byte 1
    ld a, 1
    ldh [c], a
    ld d, [hl]
    ld [hl], a

    ; Overwrite byte 2
    inc a
    ldh [c], a
    ld e, [hl]
    ld [hl], a

    ; Compare
    dec a
    ldh [c], a
    ld a, [hl]
    sub a, 2

    ; Restore without altering flags
    ld [hl], d
    ld d, a
    ld a, 1
    ldh [c], a
    ld [hl], e
    ld a, b
    ldh [c], a

    ; Return
    ld a, d
    ld [wIsCGB], a
    ret
;



; Set CPU speed.  
; Fails if not on a CGB machine.  
; Lives in ROM0.
;
; Input:
; - `b.7`: Desired speed
;
; Destroys: `a`, `hl`
; Saves: `e`
SetCPUSpeed::

    ; Ignore ENTIRELY if not on a color machine
    ld a, [wIsCGB]
    cp a, 0
    ret z

    ; Ignore function call if CPU speed is already as desired
    ld hl, rKEY1
    ld a, [hl]
    and a, KEY1F_DBLSPEED
    cp a, b
    ret z

    ; Double CPU speed
    ldh a, [rIE]
    ld d, a
    xor a
    ldh [rIE], a
    ld a, b
    ldh [rKEY1], a
    ld a, P1F_GET_NONE
    ldh [rP1], a
    stop 
    ld a, d
    ldh [rIE], a

    ; Return
    ret
;



; Set a CGB palette using a DMG value.
;
; Input:
; - `1`: DMG register
; - `2`: CGB palette specify register
; - `3`: CGB palette index (0/1)
;
; Destroys: `f`
MACRO set_palette
    ldh [\1], a
    ld a, [wIsCGB]
    or a, a
    ldh a, [\1]
    ret z

    ; CGB time
    push bc
    push hl

    ; Prepare data transfer
    ld b, a
    ld c, low(\2)
    ld a, BCPSF_AUTOINC | (\3 * 8)
    ldh [c], a
    inc c
    ld hl, wPaletteCGB

    ; Start
    REPT 4
        ld a, b
        and a, %00000011
        add a, a
        add a, low(wPaletteCGB)
        ld l, a

        ; Copy color
        ld a, [hl+]
        ldh [c], a
        ld a, [hl+]
        ldh [c], a

        ; End of loop
        rrc b
        rrc b
    ENDR

    ; Return
    ld a, b
    pop hl
    pop bc
    ret 
ENDM



; Set CGB background palette, as if it was DMG.  
; Assumes palette access.  
; Lives in ROM0.
;
; Input:
; - `a`: Palette
;
; Destroys: `f`
PaletteSetBGP::
    ld [wPaletteBGP], a
    set_palette rBGP, rBCPS, 0
;



; Set CGB object palette 0, as if it was DMG.  
; Assumes palette access.  
; Lives in ROM0.
;
; Input:
; - `a`: Palette
;
; Destroys: `f`
PaletteSetOBP0::
    ld [wPaletteOBP0], a
    set_palette rOBP0, rOCPS, 0
;



; Set CGB object palette 1, as if it was DMG.  
; Assumes palette access.  
; Lives in ROM0.
;
; Input:
; - `a`: Palette
;
; Destroys: `f`
PaletteSetOBP1::
    ld [wPaletteOBP1], a
    set_palette rOBP1, rOCPS, 1
;



; Copies a cgb palette to background color memory.  
; Assumes palette access.  
; Lives in ROM0.
;
; Input:
; - `hl`: Palette address
; - `a`: Palette index * 8
;
; Returns:
; - `hl`: `$0010`
; - `a`: `$08`
;
; Destroys: `bc`
; Saves: `de`
PaletteCopyBG::

    ; Write palette index
    ld b, a
    set BCPSB_AUTOINC, a
    ldh [rBCPS], a
    ld c, low(rBCPD)

    ; Copy the palette
    REPT 8
        ld a, [hl+]
        ldh [c], a
    ENDR

    ; Increase palette index
    ld a, b
    add a, $08

    ; Return
    ret
;



; Copies a cgb palette to sprite color memory.  
; Assumes palette access.  
; Lives in ROM0.
;
; Input:
; - `hl`: Palette address
; - `a`: Palette index * 8
;
; Returns:
; - `hl`: Palette address + `$10`
; - `a`: Palette index + `$08`
;
; Destroys: `bc`
; Saves: `de`
PaletteCopyOBJ::

    ; Write palette index
    ld b, a
    set OCPSB_AUTOINC, a
    ldh [rOCPS], a
    ld c, low(rOCPD)

    ; Copy the palette
    REPT 8
        ld a, [hl+]
        ldh [c], a
    ENDR

    ; Increase palette index
    ld a, b
    add a, $08

    ; Return
    ret
;



; Copies ALL CGB palettes.  
; Assumes palette access.  
; Lives in ROM0.
; 
; Input:
; - `hl`: Palette address
;
; Saves: `de`
PaletteCopyAll::

    ; Set up background palette transfer
    ld a, BCPSF_AUTOINC
    ldh [rBCPS], a
    ld c, low(rBCPD)
    ld b, 8

    ; Copy background palettes
    .copyBG
        ; Copy one palette
        REPT 8
            ld a, [hl+]
            ldh [c], a
        ENDR

        ; Counter
        dec b
        jr nz, .copyBG
    ;

    ; Set up sprite palette transfer
    ld a, OCPSF_AUTOINC
    ldh [rOCPS], a
    ld c, low(rOCPD)
    ld b, 8

    ; Copy sprite palettes
    .copyOBJ

        ; Copy one palette
        REPT 8
            ld a, [hl+]
            ldh [c], a
        ENDR

        ; Counter
        dec b
        jr nz, .copyOBJ
    ;

    ; Return
    ret 
;



; Creates a copy of the currently loaded CGB palettes.  
; Lives in ROM0.
;
; Input:
; - `hl`: Where to store the new palettes
; 
; Destroys: all
PaletteMakeLighter::
    ld d, h
    ld e, l
    push hl

    ; First, copy all palettes to the destination
    ld hl, rBCPS
    ld [hl], 0
    ld c, low(rBCPD)
    ld b, $40

    .copyBG
        ldh a, [c]
        ld [de], a
        inc de
        inc [hl]
        dec b
        jr nz, .copyBG
    ;

    ; Now copy sprite palettes
    ld hl, rOCPS
    ld [hl], 0
    ld c, low(rOCPD)
    ld b, $40

    .copyOBJ
        ldh a, [c]
        ld [de], a
        inc de
        inc [hl]
        dec b
        jr nz, .copyOBJ
    ;



    ; Initialize modifying
    pop hl
    ld b, $40
    push bc

    .modify
        ld a, [hl+]
        ld e, a
        ld a, [hl-]
        ld d, a

        ; Red
        ld a, d
        and a, %01111100
        add a, %00001100
        bit 7, a
        jr z, :+
            ld a, %01111100
        :
        ld b, a

        ; Green
        ld a, d
        and a, %00000011
        ld c, a
        ld a, e
        and a, %11100000
        or a, c
        swap a
        add a, %00000110
        bit 6, a
        jr z, :+
            ld a, %00111110
        :
        swap a
        ld c, a
        and a, %00000011
        or a, b
        ld b, a

        ; Blue
        ld a, e
        and a, %00011111
        add a, %00000011
        bit 5, a
        jr z, :+
        ld a, %00011111
        :
        or a, c
        ld c, a

        ; Store this value
        ld a, c
        ld [hl+], a
        ld a, b
        ld [hl+], a

        pop bc
        dec b
        push bc
        jr nz, .modify

    ; Return
    pop af
    ret 
;



; Prepared VQueue transfer which resets all tilemap attributes.
ColorVQueueResetAttributes:: vqueue_prepare_memset _SCRN0, 0, $800, 1, 0



SECTION "COLOR VARIABLES", WRAM0, ALIGN[3]

    ; Color palette for CGB mode.  
    ; Intended for DMG games running in CGB mode.
    wPaletteCGB:: ds 8

    ; DMG-style color palette for CGB systems.
    ; Reserves 2 bytes, to allow shifting palette fully in and out.
    wPaletteDMG::
    wPaletteBGP:: ds 2
    wPaletteOBP0:: ds 2
    wPaletteOBP1:: ds 2

    ; Non-zero if CGB-mode is enabled.
    wIsCGB:: ds 1
;
