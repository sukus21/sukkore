INCLUDE "hardware.inc/hardware.inc"

SECTION "SNIPPETS", ROM0

; Copies data from one location to another using the CPU.
; Lives in ROM0.
;
; Input:
; - `hl`: Destination
; - `bc`: Source
; - `de`: Byte count
;
; Returns:
; - `hl`: Destination + Byte count
; - `bc`: Source + Byte count
;
; Destroys: `af`, `de`
memcpy::

    ;Copy the data
    ld a, [bc]
    ld [hl+], a
    inc bc
    dec de

    ;Check byte count
    ld a, d
    or e
    jr nz, memcpy

    ;Return
    ret 
;



; Copies data from one location to another using the CPU.
; Lives in ROM0.
;
; Input:
; - `hl`: Destination
; - `bc`: Source
; - `d`: Byte count
;
; Returns:
; - `hl`: Destination + Byte count
; - `bc`: Source + Byte count
;
; Saves: `e`
memcpy_short::

    ;Copy the data
    ld a, [bc]
    ld [hl+], a
    inc bc

    ;Check byte count
    dec d
    jr nz, memcpy_short

    ;Return
    ret 
;



; Sets a number of bytes at a location to a single value.
; Lives in ROM0.
;
; Input:
; - `hl`: Destination
; - `b`: Fill byte
; - `de`: Byte count
;
; Returns:
; - `hl`: Destination + Byte count
; - `de`: `$0000`
;
; Destroys: `af`
memset::

    ;Fill data
    ld a, b
    ld [hl+], a
    dec de

    ;Check byte count
    ld a, d
    or e
    jr nz, memset

    ;Return
    ret
;



; Sets a number of bytes at a location to a single value.
; Lives in ROM0.
;
; Input:
; - `hl`: Destination
; - `b`: Fill byte
; - `c`: Byte count
;
; Returns:
; - `hl`: Destination + Byte count
; - `c`: `$00`
;
; Destroys: `af`  
; Saves: `de`
memset_short::

    ;Fill data
    ld a, b
    ld [hl+], a
    dec c

    ;Check byte count
    jr nz, memset_short

    ;Return
    ret
;



; Same as memcpy, but only stops once 0 is seen.
; Made specifically to copy text.
; Lives in ROM0.
;
; Input:
; - `hl`: Destination
; - `bc`: Source
;
; Saves: `de`
strcpy::

    ;Read character from stream
    ld a, [bc]
    inc bc

    ;If character is null, return
    or a, a
    ret z

    ;Write character to output and continue
    ld [hl+], a
    jr strcpy
;



; Compares two strings.
; Lives in ROM0.
; 
; Input: 
; - `hl`: String 1
; - `de`: String 2
;
; Returns:
; `fz`: Strings are equal (z=1, strings are equal)
;
; Saves: `bc`
strcomp::

    ;Compare values, return if they don't match
    ld a, [de]
    cp a, [hl]
    ret nz

    ;Return if [hl] == 0
    inc de
    ld a, [hl+]
    cp a, 0
    ret z

    ;Keep going
    jr strcomp
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
palette_copy_bg::

    ;Write palette index
    ld b, a
    set BCPSB_AUTOINC, a
    ldh [rBCPS], a
    ld c, low(rBCPD)

    ;Copy the palette
    REPT 8
        ld a, [hl+]
        ldh [c], a
    ENDR

    ;Increase palette index
    ld a, b
    add a, $08

    ;Return
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
palette_copy_spr::

    ;Write palette index
    ld b, a
    set OCPSB_AUTOINC, a
    ldh [rOCPS], a
    ld c, low(rOCPD)

    ;Copy the palette
    REPT 8
        ld a, [hl+]
        ldh [c], a
    ENDR

    ;Increase palette index
    ld a, b
    add a, $08

    ;Return
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
palette_copy_all::

    ;Set up background palette transfer
    ld a, BCPSF_AUTOINC
    ldh [rBCPS], a
    ld c, low(rBCPD)
    ld b, 8

    ;Copy background palettes
    .bgcopy
        ;Copy one palette
        REPT 8
            ld a, [hl+]
            ldh [c], a
        ENDR

        ;Counter
        dec b
        jr nz, .bgcopy
    ;

    ;Set up sprite palette transfer
    ld a, OCPSF_AUTOINC
    ldh [rOCPS], a
    ld c, low(rOCPD)
    ld b, 8

    ;Copy sprite palettes
    .sprcopy

        ;Copy one palette
        REPT 8
            ld a, [hl+]
            ldh [c], a
        ENDR

        ;Counter
        dec b
        jr nz, .sprcopy
    ;

    ;Return
    ret 
;



; Creates a copy of the currently loaded CGB palettes.
; Lives in ROM0.
;
; Input:
; - `hl`: Where to store the new palettes
; 
; Destroys: all
palette_make_lighter::
    ld d, h
    ld e, l
    push hl

    ;First, copy all palettes to the destination
    ld hl, rBCPS
    ld [hl], 0
    ld c, low(rBCPD)
    ld b, $40

    .copybg
        ldh a, [c]
        ld [de], a
        inc de
        inc [hl]
        dec b
        jr nz, .copybg
    ;

    ;Now copy sprite palettes
    ld hl, rOCPS
    ld [hl], 0
    ld c, low(rOCPD)
    ld b, $40

    .copyobj
        ldh a, [c]
        ld [de], a
        inc de
        inc [hl]
        dec b
        jr nz, .copyobj
    ;



    ;Initialize modifying
    pop hl
    ld b, $40
    push bc

    .modify
        ld a, [hl+]
        ld e, a
        ld a, [hl-]
        ld d, a

        ;Red
        ld a, d
        and a, %01111100
        add a, %00001100
        bit 7, a
        jr z, :+
            ld a, %01111100
        :
        ld b, a

        ;Green
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

        ;Blue
        ld a, e
        and a, %00011111
        add a, %00000011
        bit 5, a
        jr z, :+
        ld a, %00011111
        :
        or a, c
        ld c, a

        ;Store this value
        ld a, c
        ld [hl+], a
        ld a, b
        ld [hl+], a

        pop bc
        dec b
        push bc
        jr nz, .modify

    ;Return
    pop af
    ret 
;



; Switches bank and calls a given address.
; Does NOT switch banks back after returning.
; Usefull when bankjumping from a non-bankable area.
; Lives in ROM0.
;
; Input:
; - `b`: ROM bank number
; - `hl`: Address to jump to
;
; Destroys: `a`, unknown
bank_call_0::

    ;Switch banks
    ld a, b
    ldh [h_bank_number], a
    ld [rROMB0], a

    ;Jump
    jp hl
;



; Switches bank and calls a given address.
; Switches banks back after returning.
; Lives in ROM0.
;
; Input:
; - `b`: ROM bank number
; - `hl`: Address to jump to
;
; Destroys: `a`, unknown
; Saves: `rROMB0`
bank_call_x::

    ;Set up things for returning
    ldh a, [h_bank_number]
    push af

    ;Switch banks
    ld a, b
    ldh [h_bank_number], a
    ld [rROMB0], a

    ;Jump
    call _hl_

    ;Returning after jump, reset bank number
    pop af
    ldh [h_bank_number], a
    ld [rROMB0], a

    ;Return
    ret
;



; Switches bank and calls a given address.
; Switches banks back after returning.
; Lives in ROM0.
;
; Input:
; - `d`: ROM bank number
; - `hl`: Address to jump to
;
; Destroys: `a`, unknown
; Saves: `rROMB0`
bank_call_xd::

    ;Store current bank number
    ldh a, [h_bank_number]
    push af

    ;Switch banks
    ld a, d
    ldh [h_bank_number], a
    ld [rROMB0], a

    ;Jump
    call _hl_

    ;Returning after jump, reset banks
    pop af
    ldh [h_bank_number], a
    ld [rROMB0], a

    ;Return
    ret 
;



; Literally just jumps to the address of HL.
; Lives in ROM0.
; 
; Input:
; - `hl`: Address to jump to
; 
; Destroys: unknown
_hl_::
    jp hl
;



; Jumps to the address of BC.
; Avoid using this if possible, only exists for completeness.
; Lives in ROM0.
;
; Input:
; - `bc`: Address to jump to
;
; Destroys: unknown
_bc_::
    push bc
    ret 
;



; Jumps to the address of DE.
; Avoid using this if possible, only exists for completeness.
; Lives in ROM0.
;
; Input:
; - `de`: Address to jump to
;
; Destroys: unknown
_de_::
    push de
    ret 
;



; Set CPU speed.
; Lives in ROM0.
;
; Input:
; - `b.7`: Desired speed
;
; Destroys: `a`, `hl`
; Saves: `e`
cpu_speedtogle::

    ;Ignore ENTIRELY if not on a color machine
    ldh a, [h_is_color]
    cp a, 0
    ret z

    ;Ignore function call if CPU speed is already as desired
    ld hl, rKEY1
    ld a, [hl]
    and a, KEY1F_DBLSPEED
    cp a, b
    ret z

    ;Double CPU speed
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

    ;Return
    ret
;



; Stalls until it reaches the desired scanline.
; Returns in HBLANK the scanline before.
; Does not use interrupts.
; Lives in ROM0.
;
; Input:
; - `c`: Desired scanline
;
; Destroys: `af`, `hl`, `b`
; Saves: `de`
wait_scanline::

    ;Wait for scanline
    dec c
    ld hl, rLY
    ld a, c
    :
    cp a, [hl]
    jr nz, :-

    ;Scanline has been hit, wait for mode 0
    ld l, low(rSTAT) ;h was set to $FF previously
    ld b, STATF_LCD
    :
    ld a, [hl]
    and a, b
    jr nz, :-

    ;Return
    ret 
;



; Detect if current hardware is GBC compatible or not.
; Lives in ROM0.
; 
; Returns:
; - `a`: result (0 = not CGB compatible)
; - `fZ`: result (0 = CGB compatible)
; - `fC`: result (1 = CGB compatible)
;
; Saves: none
detect_gbc::
    ld hl, _RAMBANK
    ld c, low(rSVBK)

    ;Save bank page
    ldh a, [c]
    ld b, a

    ;Overwrite byte 1
    ld a, 1
    ldh [c], a
    ld d, [hl]
    ld [hl], a

    ;Overwrite byte 2
    inc a
    ldh [c], a
    ld e, [hl]
    ld [hl], a

    ;Compare
    dec a
    ldh [c], a
    ld a, [hl]
    sub a, 2

    ;Restore without altering flags
    ld [hl], d
    ld d, a
    ld a, 1
    ldh [c], a
    ld [hl], e
    ld a, b
    ld [c], a

    ;Return
    ld a, d
    ret
;



; Set a CGB palette using a DMG value.
;
; Input:
; - `1`: DMG register
; - `2`: CGB palette specify register
; - `3`: CGB palette index (0/1)
MACRO set_palette
    ldh [\1], a
    ldh a, [h_is_color]
    or a, a
    ldh a, [\1]
    ret z

    ;CGB time
    push bc
    push hl

    ;Prepare data transfer
    ld b, a
    ld c, low(\2)
    ld a, BCPSF_AUTOINC | (\3 * 8)
    ldh [c], a
    inc c
    ld hl, w_cgb_palette

    ;Start
    REPT 4
        ld a, b
        and a, %00000011
        add a, a
        add a, low(w_cgb_palette)
        ld l, a

        ;Copy color
        ld a, [hl+]
        ldh [c], a
        ld a, [hl+]
        ldh [c], a

        ;End of loop
        rrc b
        rrc b
    ENDR

    ;Return
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
set_palette_bgp::
    ld [w_bgp], a
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
set_palette_obp0::
    ld [w_obp0], a
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
set_palette_obp1::
    ld [w_obp1], a
    set_palette rOBP1, rOCPS, 1
;



; Converts a binary value to BCD.  
; Lives in ROM0.
;
; Input:
; - `a`: Binary value
;
; Returns:
; - `a`: BCD value
;
; Destroys: `f`
bin2bcd::
    cp a, 10
    ret c

    ;Do the conversion
    push bc
    ld b, $FF
    .loop
        inc b
        sub a, 10
        jr nc, .loop
    ;

    ;Aaand we are done here
    add a, 10
    swap b
    or a, b
    pop bc
    ret
;



; Converts a BCD value to binary.  
; Lives in ROM0.
;
; Input:
; - `a`: BCD value
;
; Returns:
; - `a`: Binary value
;
; Destroys: `f`, `bc`
bcd2bin::
    ld c, a
    swap a
    and a, %00001111
    jr z, .quick
    ld b, a
    ld a, c
    and a, %00001111

    .loop1
        add a, 10
        dec b
        jr nz, .loop1
    :

    ret

    ;This is all we need
    .quick
    ld a, c
    and a, %00001111
    ret
;



; Call anything from anywhere.  
; Use with `farcall_x` macro in `macro/farcall.inc`.  
; Lives in ROM0.
;
; Input:
; - `a`: Bank to switch to
; - `hl`: Address in bank
;
; Destroys: `a`, ``
farcall_handler_x::
    ld [rROMB0], a
    ldh a, [h_bank_number]
    push af
    call _hl_
    pop af
    ld [rROMB0], a
    ret
;
