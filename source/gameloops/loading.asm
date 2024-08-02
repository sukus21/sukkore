INCLUDE "hardware.inc"
INCLUDE "macros/color.inc"

SECTION "GAMELOOP LOADING", ROM0

; This gameloop keeps the screen on, while doing vqueue transfers in V-blank.  
; Exits once the vqueue is empty.  
; Assumes LCD is turned on.  
; Disables interrupts.  
; Lives in ROM0.
gameloop_loading::
    di

    ;Enable only V-blank
    ld a, IEF_VBLANK
    ldh [rIE], a
    
    .loop
        xor a
        ldh [rIF], a
        halt
        nop

        ;Now in V-blank
        call vqueue_execute
        call vqueue_empty
        jr nz, .loop
    ;

    ;Return
    ret
;



; Sets up DMG fading.  
; Lives in ROM0.
;
; Input:
; - `a`: Fade state (`COLOR_FADESTATE_*`)
;
; Destroys: all
transition_fade_init::

    ;Set new state and reset timer
    and a, COLOR_FADEM_STATE
    ld b, a
    ld hl, w_fade_state
    ld a, [hl]
    and a, COLOR_FADEM_STEP ;this resets timer
    or a, b
    ld [hl], a

    ;Yup, that should do it
    ret
;



; Run DMG fade routine.  
; Assumes palette access.  
; Lives in ROM0.
transition_fade_step::
    ld hl, w_fade_state
    bit COLOR_FADEB_RUNNING, [hl]
    ret z

    ;Increment timer
    ld a, [hl]
    inc a
    ld [hl], a
    bit 2, a
    ret z
    and a, %11110000
    ld [hl], a

    ;What direction to fade?
    bit COLOR_FADEB_DIRECTION, a
    jr z, transition_fade_in
    jr transition_fade_out
;



; Fade palettes to black.  
; Assumes palette access.  
; Lives in ROM0.
;
; Input:
; - `a`: @`w_fade_state`
; - `hl`: `w_fade_state`
transition_fade_out::
    
    ;Update this
    and a, COLOR_FADEM_STEP
    ret z
    ld a, [hl]
    sub a, 16
    ld [hl], a

    ;Finish after this step?
    and a, COLOR_FADEM_STEP
    jr nz, :+
        res COLOR_FADEB_RUNNING, [hl]
    :

    ;Some very nice values
    ld de, %01000000_11000000

    ;Fade out BGP
    ld a, [w_bgp]
    call .helper
    call set_palette_bgp

    ;Fade out OBP0
    ld a, [w_obp0]
    call .helper
    call set_palette_obp0

    ;Fade out OBP1
    ld a, [w_obp1]
    call .helper
    call set_palette_obp1

    ;Return
    ret

    ; Having this here saves a little bit of ROM usage.
    ; Just a little bit.
    .helper
        REPT 4
            add a, d
            jr nc, :+
                or a, e
            :
            rlca
            rlca
        ENDR
        ret
    ;
;



; Fade from black to the target.  
; Assumes palette access.  
; Lives in ROM0.
;
; Input:
; - `a`: @`w_fade_state`
; - `hl`: `w_fade_state`
transition_fade_in::
    
    ;Update this
    and a, COLOR_FADEM_STEP
    cp a, COLOR_FADEM_STEP
    ret z
    ld a, [hl]
    add a, 16
    ld [hl], a
    
    ;End after this iteration?
    and a, COLOR_FADEM_STEP
    cp a, COLOR_FADEM_STEP
    jr nz, :+
        res COLOR_FADEB_RUNNING, [hl]
    :

    ;Get current step -> D
    ld e, %00000011
    swap a
    and a, e
    ld d, a

    ;This is a surprise tool that will help us later ;)
    ld hl, w_obp1+1

    ;Fade OBP1
    ld a, [hl-]
    call .helper
    ld a, [hl-]
    sub a, c
    call set_palette_obp1

    ;Fade OBP0
    ld a, [hl-]
    call .helper
    ld a, [hl-]
    sub a, c
    call set_palette_obp0

    ;Fade BGP
    ld a, [hl-]
    call .helper
    ld a, [hl-]
    sub a, c
    call set_palette_bgp

    ;Return
    ret

    .helper
        ld b, a
        ld c, 0

        ;Do ONE color
        and a, e
        cp a, d
        jr nc, :+
            set 0, c
        :

        ;Do another
        ld a, b
        rrca
        rrca
        ld b, a
        and a, e
        cp a, d
        jr nc, :+
            set 2, c
        :

        ;Do another
        ld a, b
        rrca
        rrca
        ld b, a
        and a, e
        cp a, d
        jr nc, :+
            set 4, c
        :

        ;Do another
        ld a, b
        rrca
        rrca
        and a, e
        cp a, d
        jr nc, :+
            set 6, c
        :

        ;Yup, that's it
        ret
    ;
;
