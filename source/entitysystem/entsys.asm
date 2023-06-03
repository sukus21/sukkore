INCLUDE "hardware.inc"

SECTION "ENTSYS", ROM0

; Execution code prototyping.
; Passed entity pointer in DE to step functions.
; Lives in ROM0.
; 
; Destroys: all
entsys_step::
    ld hl, w_entsys
    .loop

        ;Is this entity in use or not?
        ld d, h
        ld e, l
        ld a, [hl+] ;Entity ROM bank
        or a, a

        ;Entity is not allocated, go to next entity in line
        jr z, .proceed

            ;Entity is in use, apply bank and read pointer
            push hl
            ld [rROMB0], a
            inc hl
            ld a, [hl+] ;Step function pointer
            ld h, [hl]
            ld l, a
            call _hl_
            pop hl
        ;

        ;Go to next entity
        .proceed
        ld a, [hl-] ;Distance to next entity -> entity bank ID
        add a, l
        ld l, a
        jr nc, .loop
        inc h
        ld a, h
        cp a, $E0 ;ERAM
        jr nz, .loop
        ret
    ;
;



; Allocates a new entity.
; Entity size is 1 chunk, or 16 bytes.
; Lives in ROM0.
;
; Returns:
; - `bc`: Entity pointer
;
; Destroys: all
entsys_new16::
    
    ;Load next free slot to HL
    ld hl, w_entsys_first16
    ld a, [hl+]
    ld h, [hl]
    ld l, a

    ;Jump to different path if we're out of 16-bit slots
    bit 7, h
    jr z, .out_of_16

    ;Store allocated slot in BC
    ld b, h
    ld c, l

    ;Load next free slot into DE
    set 1, l
    ld a, [hl+]
    ld d, [hl]

    ;Save next free slot for next allocation
    ld hl, w_entsys_first16
    ld [hl+], a
    ld [hl], d

    ;Return
    ret

    .out_of_16
    call entsys_new32

    ;Save buddy for next allocation
    ld hl, w_entsys_first16
    ld a, c
    set 4, a
    ld [hl+], a
    ld [hl], b

    ;Make buddy a single-chunk slot
    ld h, b
    ld l, c
    inc l
    ld a, $10
    ld [hl], a ;Write entity size

    ;Get buddy slot
    set 4, l

    ;Make new slot a single-chunk slot
    ld [hl-], a ;Write buddy size
    ld [hl], $00 ;Reset buddy bank

    ;Return
    ret
;



; Allocates a new entity.
; Entity size is 2 chunks, or 32 bytes.
; Lives in ROM0.
;
; Returns:
; - `bc`: Entity pointer
;
; Destroys: all
entsys_new32::

    ;Load next free slot to HL
    ld hl, w_entsys_first32
    ld a, [hl+]
    ld h, [hl]
    ld l, a

    ;Jump to different path if we're out of 16-bit slots
    bit 7, h
    jr z, .out_of_32

    ;Store allocated slot in BC
    ld b, h
    ld c, l

    ;Load next free slot into DE
    set 1, l
    ld a, [hl+]
    ld d, [hl]

    ;Save next free slot for next allocation
    ld hl, w_entsys_first32
    ld [hl+], a
    ld [hl], d

    ;Return
    ret

    .out_of_32
    call entsys_new64

    ;Save buddy for next allocation
    ld hl, w_entsys_first32
    ld a, c
    set 5, a
    ld [hl+], a
    ld [hl], b

    ;Make buddy a double-chunk slot
    ld h, b
    ld l, c
    inc l
    ld a, $20
    ld [hl], a ;Write entity size

    ;Get buddy slot
    set 5, l

    ;Make new slot a single-chunk slot
    ld [hl-], a ;Write buddy size
    ld [hl], $00 ;Reset buddy bank

    ;Return
    ret
;



; Allocates a new entity.
; Entity size is 4 chunks, or 64 bytes.
; Lives in ROM0.
;
; Returns:
; - `bc`: Entity pointer
;
; Destroys: all
entsys_new64::

    ;Load next free slot to HL and BC
    ld hl, w_entsys_first64
    ld a, [hl+]
    ld h, [hl]
    ld l, a
    ld b, h
    ld c, l
    inc l

    ;Find next free slot
    .loop
        ld a, l
        add a, 63
        ld l, a
        jr nc, :+
            inc h
        :

        ;OOB check
        bit 5, h
        jr z, :+
            ld hl, error_entityoverflow
            rst v_error
        :

        ;Make sure bank is empty
        ld a, [hl+]
        or a, a
        jr nz, .loop

        ;Check size of element
        ld a, $40
        cp a, [hl]
        jr nz, .loop
        dec l
    ;

    ;Save next free slot for next allocation
    ld d, h
    ld a, l
    ld hl, w_entsys_first64
    ld [hl+], a
    ld [hl], d

    ;Return
    ret
;
