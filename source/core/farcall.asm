INCLUDE "hardware.inc/hardware.inc"



SECTION "FARCALL", ROM0

; Switches bank and calls a given address.
; Usefull when bankjumping from a non-bankable area.  
; Does NOT switch banks back after returning.  
; Lives in ROM0.
;
; Input:
; - `b`: ROM bank number
; - `hl`: Address to jump to
;
; Destroys: `a`, unknown
Farcall0::

    ; Switch banks
    ld a, b
    ldh [hBankNumber], a
    ld [rROMB0], a

    ; Jump
    jp hl
;



; Switches bank and calls a given address.  
; Switches banks back after returning.  
; Lives in ROM0.
;
; Input:
; - `b`: ROM bank number
; - `hl`: Address to jump to
;
; Destroys: `a`, unknown
; Saves: `rROMB0`
FarcallX::

    ; Set up things for returning
    ldh a, [hBankNumber]
    push af

    ; Switch banks
    ld a, b
    ldh [hBankNumber], a
    ld [rROMB0], a

    ; Jump
    call _hl_

    ; Returning after jump, reset bank number
    pop af
    ldh [hBankNumber], a
    ld [rROMB0], a

    ; Return
    ret
;



; Switches bank and calls a given address.  
; Switches banks back after returning.  
; Lives in ROM0.
;
; Input:
; - `d`: ROM bank number
; - `hl`: Address to jump to
;
; Destroys: `a`, unknown
; Saves: `rROMB0`
FarcallXD::

    ; Store current bank number
    ldh a, [hBankNumber]
    push af

    ; Switch banks
    ld a, d
    ldh [hBankNumber], a
    ld [rROMB0], a

    ; Jump
    call _hl_

    ; Returning after jump, reset banks
    pop af
    ldh [hBankNumber], a
    ld [rROMB0], a

    ; Return
    ret 
;



; Call anything from anywhere.  
; Use with `farcall_x` macro in `macro/farcall.inc`.  
; Lives in ROM0.
;
; Input:
; - `a`: Bank to switch to
; - `hl`: Address in bank
;
; Destroys: `a`, unknown
FarcallHandlerX::
    ld [rROMB0], a
    ldh a, [hBankNumber]
    push af
    call _hl_
    pop af
    ld [rROMB0], a
    ret
;
