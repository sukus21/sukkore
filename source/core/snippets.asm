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
Memcpy::

    ; Copy the data
    ld a, [bc]
    ld [hl+], a
    inc bc
    dec de

    ; Check byte count
    ld a, d
    or e
    jr nz, Memcpy

    ; Return
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
MemcpyShort::

    ; Copy the data
    ld a, [bc]
    ld [hl+], a
    inc bc

    ; Check byte count
    dec d
    jr nz, MemcpyShort

    ; Return
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
Memset::

    ; Fill data
    ld a, b
    ld [hl+], a
    dec de

    ; Check byte count
    ld a, d
    or e
    jr nz, Memset

    ; Return
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
MemsetShort::

    ; Fill data
    ld a, b
    ld [hl+], a
    dec c

    ; Check byte count
    jr nz, MemsetShort

    ; Return
    ret
;



; Same as Memcpy, but only stops once 0 is seen.
; Made specifically to copy text.  
; Lives in ROM0.
;
; Input:
; - `hl`: Destination
; - `bc`: Source
;
; Saves: `de`
Strcpy::

    ; Read character from stream
    ld a, [bc]
    inc bc

    ; If character is null, return
    or a, a
    ret z

    ; Write character to output and continue
    ld [hl+], a
    jr Strcpy
;



; Compares two strings.
; Strings are assumed to be 0-terminated.  
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
Strcomp::

    ; Compare values, return if they don't match
    ld a, [de]
    cp a, [hl]
    ret nz

    ; Return if [hl] == 0
    inc de
    ld a, [hl+]
    cp a, 0
    ret z

    ; Keep going
    jr Strcomp
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
WaitScanline::

    ; Wait for scanline
    dec c
    ld hl, rLY
    ld a, c
    :
    cp a, [hl]
    jr nz, :-

    ; Scanline has been hit, wait for mode 0
    ld l, low(rSTAT) ; h was set to $FF previously
    ld b, STATF_LCD
    :
    ld a, [hl]
    and a, b
    jr nz, :-

    ; Return
    ret 
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
BinToBcd::
    cp a, 10
    ret c

    ; Do the conversion
    push bc
    ld b, $FF
    .loop
        inc b
        sub a, 10
        jr nc, .loop
    ;

    ; Aaand we are done here
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
BcdToBin::
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

    ; This is all we need
    .quick
    ld a, c
    and a, %00001111
    ret
;
