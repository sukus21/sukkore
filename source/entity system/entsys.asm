INCLUDE "hardware.inc"

SECTION "ENTSYS", ROM0

;Set if null-bank should be $FF, purge it for $00
DEF NULLBANK

; Execution code prototyping.
; 
; Destroys: all
entsys_execute::
	ld hl, w_entsys
	.loop
		
		;Is this entity in use or not?
		ld a, [hl+] ;Entity ROM bank
		IF DEF(NULLBANK)
			inc a
		ELSE
			or a, a
		ENDC

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
		jr nc, .loop
		inc h
        ld a, h
        cp a, $E0 ;ERAM
		jr nz, .loop
        ret
	;
;
