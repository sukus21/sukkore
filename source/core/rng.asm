SECTION "RNG", ROM0

; RNG routine. Produces one output. 
; More or less copied from SMW lol.
; Lives in ROM0.
; 
; Returns:
; - `a`: Random value
;
; Destroys: `f`
; Saves: `bc`, `de`, `hl`
rng_run_single::
    push hl
    
    ;Call RNG routine
    ld hl, h_rng_seed
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
; Saves: `bc`, `d`, `hl`
rng_run::
    push hl

    ;Tick RNG twice
    ld hl, h_rng_seed
    call rng_tick
    ld e, a
    call rng_tick

    ;Store result
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
;
; Input:
; - `hl`: pointer to seed (`h_rng_seed`)
;
; Returns:
; - `a`: Random value
;
; Destroys: `f`
; Saves: `bc`, `de`
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
