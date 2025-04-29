SECTION "RNG", ROM0

; RNG routine. Produces one output.  
; Lives in ROM0.
; 
; Returns:
; - `a`: Random value
;
; Destroys: `f`  
; Saves: `bc`, `de`, `hl`
GetSingleRNG::
    push hl

    ; Call RNG routine
    ld hl, hRNGSeed
    call TickRNG

    ; Return
    pop hl
    ret 
;



; RNG routine. Produces 2 outputs.  
; Lives in ROM0.
; 
; Returns:
; - `de`: Random values
;
; Destroys: `af`  
; Saves: `bc`, `d`, `hl`
GetDoubleRNG::
    push hl

    ; Tick RNG twice
    ld hl, hRNGSeed
    call TickRNG
    ld e, a
    call TickRNG

    ; Store result
    inc l
    inc l
    ld [hl+], a
    ld [hl], e

    ; Return
    pop hl
    ret
;



; RNG subroutine.  
; Lives in ROM0.
;
; Input:
; - `hl`: pointer to seed (`hRNGSeed`)
;
; Returns:
; - `a`: Random value
;
; Destroys: `f`
; Saves: `bc`, `de`
TickRNG:

    ; Shift left
    ld a, [hl]
    sla a
    sla a

    ; Add this value to its old self
    scf 
    adc a, [hl]
    ld [hl+], a

    ; Shift this value a and and it with $20
    sla [hl]
    ld a, $20
    and a, [hl]

    ; Intense jumping shenanigans
    jr nc, :+
    jr z, :+++
    jr nz, :++
    :
    jr nz, :++
    :
    inc [hl]
    :

    ; Finish and return
    ld a, [hl-]
    xor a, [hl]
    ret
;



SECTION "RNG VARIABLES", HRAM

    ; RNG variables.
    hRNG::

    ; Seed for the next RNG value.
    hRNGSeed:: ds 2

    ; Last RNG output.
    hRNGOut:: ds 2
;
