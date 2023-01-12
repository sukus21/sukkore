SECTION "RNG", ROM0

; RNG routine. Produces one output. 
; More or less copied from SMW lol.
; Lives in ROM0.
; 
; Returns:
; - `a`: Random value
;
; Destroys: `f`
rng_run_single::
    
    ;Save HL
    push hl
    
    ;Initialize RNG pointer
    ld hl, h_rng_seed

    ;Call RNG routine
    call rng_tick

    ;Return
    pop hl
    ret 
;



; RNG routine. Produces 2 outputs.
; More or less copied from SMW lol.
; Lives in ROM0.
; 
; Returns:
; - `de`: Random values
; - `a`: Mirror of `d`
;
; Destroys: `f`
rng_run::
    
    push hl

    ;Initialize RNG pointer
    ld hl, h_rng_seed

    ;Tick the first byte and store in E
    call rng_tick
    ld e, a

    ;Tick the second byte and store in D
    call rng_tick
    ld d, a

    ;Store these
    inc l
    inc l
    ld [hl+], a
    ld [hl], e

    ;Return
    pop hl
    ret
;



; Subroutine for RNG.
; Lives in ROM0.
; REQUIRES HL TO BE SET TO h_rng_seed!!!
;
; Returns:
; - `a`: Random value
;
; Destroys: `f`
rng_tick:
    
    ;Shift left
    ld a, [hl]
    sla a
    sla a

    ;Add this value to its old self
    scf 
    adc a, [hl]
    ld [hl+], a

    ;Shift this value a and and it with $20
    sla [hl]
    ld a, $20
    and a, [hl]

    ;Intense jumping shenanigans
    jr nc, :+
    jr z, :+++
    jr nz, :++
    :
    jr nz, :++
    :
    inc [hl]
    :

    ;Finish and return
    ld a, [hl-]
    xor a, [hl]
    ret
;
