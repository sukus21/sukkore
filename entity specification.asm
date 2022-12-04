; Mandatory entity information:
; 10 bytes for vars
; 1 byte for collision mask
; 3 bytes for extended data pointer
; 2 bytes for step function

; Mandatory information layout:
; 	0x00 Extended data pointer bank (null with 0x00 or 0xFF, discuss!!!)
;	If in use:
;		0x01: Relpointer to next used entity
;		0x02-0x03: Step function pointer
;	If free:
;		0x01: Free slot size/relpointer to next used
;		0x03: Relpointer to next free slot with same size



ld a, c
swap a
sub a, c
ld b, a

; mov b to a
; swap b
; sub a from b
; set c to a


; Entity sizes:
; half-size: 16-bytes
; full-size: 32-bytes
; double-size: 64 bytes

; Per-entity fields:
; * Damage
; * Damage 2
; * Also damage
; * Colour (aka Damage)
; * Ouchiness
; * Agony
; * Damage
; * Paininess



; Allocation:
;	Get next slot of appropiate size by reading pointer
;		If none are free, split one of next size, and set first-pointer to other half
;		Otherwise, set first-pointer to next-pointer of taken slot

;Set if null-bank should be $FF, purge it for $00
DEF NULLBANK

; Execution code prototyping.
; TODO: what happens on the last entity?
entsys_execute::
	ld hl, w_entsys
	.loop
		
		;Is this entity in use or not?
		ld a, [hl+]
		IF DEF(NULLBANK)
			inc a
		ELSE
			or a, a
		ENDC

		;Entity is not allocated, go to next entity in line
		jr z, .gonext

		;Entity is in use, apply bank and read pointer
		ld [$2000], a
		push hl ;Save pointer to relative pointer to next
		inc hl
		ld a, [hl+]
		ld h, [hl]
		ld l, a
		call _hl_

		;Go to next entity
		.gonext
		pop hl
		ld a, [hl-]
		add a, l
		jr nc, .loop
		inc h
		jr .loop
	;
;
