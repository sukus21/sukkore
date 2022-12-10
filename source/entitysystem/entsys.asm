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
