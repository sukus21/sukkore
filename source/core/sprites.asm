INCLUDE "hardware.inc"

SECTION "SPRITES", ROM0

; DMA routune to be copied to HRAM.
; Kept here for the sake of the error handler.
; Lives in ROM0.
;
; DO NOT CALL!!!
dma_routine:
    
    ;Initialize OAM DMA
    ld a, HIGH(w_oam_mirror)
    ldh [rDMA], a

    ;Wait until transfer is complete
    ld a, 40
    .wait
        dec a
        jr nz, .wait
    ;

    ;Return
    ret
;



; Copy the DMA routine to HRAM.
; Kept here for the sake of the error handler.
; Lives in ROM0.
;
; Destroys: all
sprite_setup::
    
    ;Copy DMA routine to HRAM
    ld hl, h_dma_routine
    ld bc, dma_routine
    ld de, 10
    call memcopy

    ;Clear shadow OAM
    ld hl, w_oam_mirror
    ld b, 0
    ld de, $9F
    call memfill

    ;Return
    ret
;



; Get one or multiple sprites.
; Lives in ROM0.
; 
; Input:
; - `b`: Sprite count * 4
;
; Output:
; - `a`: lower sprite address byte
sprite_get::

    ;Allocate B amount of sprites
    ldh a, [h_sprite_slot]
    add a, b
    ldh [h_sprite_slot], a

    ;Get index allocation started at
    sub a, b
    ret 
;



; Clear remaining sprite slots.
; Lives in ROM0.
;
; Destroys: `hl`
sprite_finish::

    ;Get pointer to first unused sprite
    ldh a, [h_sprite_slot]
    ld l, a
    ld h, high(w_oam_mirror)

    ;Clear out memory
    ld a, $A0
    :
        ld [hl], 0
        inc l
        cp a, l
        jr nz, :-
    
    ;Reset sprite count and return
    xor a
    ldh [h_sprite_slot], a
    ret 
;