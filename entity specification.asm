; Mandatory entity information:
; 10 bytes for vars
; 1 byte for collision mask
; 3 bytes for extended data pointer
; 2 bytes for step function

; Mandatory information layout:
; 	0x00 Extended data pointer bank (null with 0x00 or 0xFF, discuss!!!)
;	0x01: Relpointer to next used entity
;	If in use:
;		0x02-0x03: Step function pointer
;	If free:
;		0x02-0x03: Relpointer to next free slot with same size



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

