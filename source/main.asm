INCLUDE "hardware.inc/hardware.inc"
INCLUDE "macro/farcall.inc"
INCLUDE "config.inc"


SECTION "NOTICE", ROM0[$0000]
RomMessage:
    db "sukkore", 0
;


SECTION "ENTRY POINT", ROM0[$0100]

; Entrypoint of the program.  
; Do not call manually.  
; Lives in ROM0.
Entrypoint:
    ; Disable interupts and jump
    di
    jp Main

    ; Space reserved for the header
    ds $4C, $00
;



SECTION "VBLANK INTERRUPT", ROM0[INT_HANDLER_VBLANK]

; Vblank interrupt vector.
; Does nothing, as this is not how I detect Vblank.  
; Does NOT set IME when returning.  
; Lives in ROM0.
VecVblank::
    ret
;



SECTION "STAT INTERRUPT", ROM0[INT_HANDLER_STAT]

; Stat interrupt vector.
; Always assumed to be triggered by LY=LYC.
; Jumps to the routine at `hLYC`.  
; Lives in ROM0.
VecSTAT::
    jp hLYC
;



SECTION "TIMER INTERRUPT", ROM0[INT_HANDLER_TIMER]

; Timer interrupt handler.
; Assumed to only be used for benchmarking.  
; Lives in ROM0.
VecTimer::
    push af
    ldh a, [hBenchmark]
    inc a
    ldh [hBenchmark], a
    pop af
    reti
;



SECTION "METADATA", ROM0

; Contains information about the current build.  
; Lives in ROM0.
MetaVersionString:: db "{__RGBDS_VERSION__}"
MetaBuildTimeLocal:: db __ISO_8601_LOCAL__
MetaBuildTimeUTC:: db __ISO_8601_UTC__



SECTION "MAIN", ROM0

; Entrypoint of game code, jumped to after setup is complete.  
; Lives in ROM0.
Main::

    ; Check that all ROMX banks have their bank number set
    IF CONFIG_DEV
        ld bc, rROMB0
        ld hl, rRomXBank
        
        ; Get number of banks -> D
        ld a, [$0148] ; ROM size
        inc a
        add a, a
        ld d, a

        ; Ensure calculated and specified bank number is the same
        cp a, CONFIG_ROM_BANK_COUNT
        jr z, :+
            ld hl, ErrorRomXBankCount
            rst VecError
        :

        ; Start looping
        ld a, 1
        .bankCheckLoop
            ld [bc], a
            cp a, [hl]
            jr z, :+
                ld hl, ErrorRomXBankMarker
                rst VecError
            :

            inc a
            cp a, d
            jr nz, .bankCheckLoop
        ;
    ENDC

    ; Write bank indicator to all SRAM banks
    IF CONFIG_BANKABLE_SRAM
        ld a, CART_SRAM_ENABLE
        ld [rRAMG], a

        ; Get number of SRAM banks -> D
        ld a, [$0149]
        sub a, 2
        ld d, a
        ld a, 1
        jr z, :++
        :   add a, a
            add a, a
            dec d
            jr nz, :-
        :
        ld d, a

        ; Ensure SRAM bank count in ROM header and config match
        IF CONFIG_DEV
            cp a, CONFIG_SRAM_BANK_COUNT
            jr z, :+
                ld hl, ErrorSramBankCount
                rst VecError
            :
        ENDC

        ; Write indicator to all banks
        xor a
        ld bc, rRAMB
        ld hl, rSramBank
        .sramBankLoop
            ld [bc], a
            ld [hl], a
            dec d
            jr nz, .sramBankLoop
        ;

        ; Disable SRAM again
        ld a, CART_SRAM_DISABLE
        ld [rRAMG], a
    ENDC

    ; Reset stack
    ld sp, wStack
    call DetectCGB

    ; Does game require GBC functionality?
    ld a, [$0143]
    cp a, CART_COMPATIBLE_GBC
    jr nz, :+

        ; Game DOES require GBC functionality
        ld a, [wIsCGB]
        cp a, 0
        jr nz, :+
        ld hl, ErrorColorRequired
        rst VecError
    :

    ; Wait for Vblank and turn all features off
    call WaitVBlank
    ld a, LCDCF_ON
    ldh [rLCDC], a

    ; Initialize ALL the things
    call OamDmaInit
    call VQueueInit
    call EntsysInit
    call ColorInit
    ld hl, wOAM
    call SpriteInit

    ; Do my intro with the logo
    farcall Intro

    ; Enable LCD with a few flags
    ld a, LCDCF_ON | LCDCF_BLK21 | LCDCF_BGON | LCDCF_WINON
    ldh [rLCDC], a
    
    ; Go to gameloop
    jp GameloopTest
;



; Write bank number indicator to every ROMX bank
FOR N, 1, CONFIG_ROM_BANK_COUNT
    SECTION "ROM BANK NUMBER {d:N}", ROMX[$7FFF], BANK[N]
    IF N == 1
        ; Read-only pseudo-register, indicating which ROMX bank is currently mapped.
        ; Exists in every ROMX bank at the same address.
        rRomXBank::
    ENDC
    db N
ENDR



; Allocate space for bank number indicator in every SRAM bank
SECTION "SRAM BANK NUMBER", SRAM[$BFFF]
    
; Read-only pseudo-register, indicating which SRAM bank is currently mapped.
; Exists in every SRAM bank at the same address.
rSramBank::

FOR N, CONFIG_SRAM_BANK_COUNT
    SECTION "SRAM BANK NUMBER {d:N}", SRAM[$BFFF], BANK[N]
    ds 1
ENDR



; Allocate 256 bytes for the stack, just to be safe
DEF STACK_SIZE EQU $100
SECTION "STACK", WRAM0[_RAMBANK - STACK_SIZE]
    ; Top of stack.
    wStackBegin:: ds STACK_SIZE

    ; Base of stack.
    wStack:: ds $00

    ; Make sure things work out
    ASSERT wStackBegin + STACK_SIZE == _RAMBANK
;
