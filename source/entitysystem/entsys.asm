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

; Address of new entity is stored in BC.
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
    ld e, a
    ld d, [hl]

    ;Save next free slot for next allocation
    ld hl, w_entsys_first16
    ld [hl+], e
    ld [hl], d

    ret

    .out_of_16
        call entsys_new32
        
        ;Save buddy for next allocation
        ld hl, w_entsys_first16
        ld a, c
        ld [hl+], a
        ld [hl], b

        ;Make buddy a single-chunk slot
        ld h, b
        ld l, c
        inc l
        ld [hl] $10
        set 1, l
        ld [hl] $00

        ;Get new slot
        add a, $11
        ld c, a

        ;Make new slot a single-chunk slot
        ld l, c
        ld [hl] $10

        dec c
        ret
        
; Address of new entity is stored in BC.
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
    ld e, a
    ld d, [hl]

    ;Save next free slot for next allocation
    ld hl, w_entsys_first32
    ld [hl+], e
    ld [hl], d

    ret

    .out_of_32
        call entsys_new64
        
        ;Save buddy for next allocation
        ld hl, w_entsys_first32
        ld a, c
        ld [hl+], a
        ld [hl], b

        ;Make buddy a single-chunk slot
        ld h, b
        ld l, c
        inc l
        ld [hl] $20
        set 1, l
        ld [hl] $00

        ;Get new slot
        add a, $21
        ld c, a

        ;Make new slot a single-chunk slot
        ld l, c
        ld [hl] $20

        dec c
        ret

