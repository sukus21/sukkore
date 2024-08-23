INCLUDE "hardware.inc/hardware.inc"

SECTION "BENCHMARK", ROM0

; Begins a benchmark.  
; Overwrites timer registers `rTIMA`, `rTMA`, `rTAC`.  
; Overwrites `rIE`, enables timer interrupt.  
; Sets IME.  
; Lives in ROM0.
;
; Destroys: `af`
benchmark_start::
    ld a, TACF_STOP
    ldh [rTAC], a

    ;Reset timers and benchmark variable
    xor a
    ldh [rTIMA], a
    ldh [rTMA], a
    ldh [h_benchmark], a

    ;Enable timer interrupt
    ldh a, [rIE]
    or a, IEF_TIMER
    ldh [rIE], a
    ei

    ;Start timer and return
    ld a, TACF_262KHZ | TACF_START
    ldh [rTAC], a
    ret
;



; Call this to stop benchmarking.  
; Clears IME.  
; Lives in ROM0.
;
; Returns:
; - `bc`: number of cycles / 4
;
; Destroys: `af`, `d`  
; Saves: `e`, `hl`
benchmark_stop::
    ld a, TACF_STOP
    ldh [rTAC], a

    ;Stop timer interrupts
    di
    ldh a, [rIE]
    and a, !IEF_TIMER
    ldh [rIE], a

    ;Ok, how long was that?
    ldh a, [h_benchmark]
    ld b, a
    ld c, a
    ldh a, [rTIMA]

    ;Subtract benchmark routine overhead
    sub a, 4
    jr nc, :+
    dec b
    :

    ;For every timer interrupt, subtract some more
    ld d, 6
    inc c
    dec c
    jr z, .noloop
    .loop
        sub a, d
        jr nc, :+
        dec b
        :
        dec c
        jr nz, .loop
    .noloop

    ;Return this in BC
    ld c, a
    ret
;
