INCLUDE "hardware.inc/hardware.inc"
INCLUDE "vqueue/vqueue.inc"
INCLUDE "config.inc"
INCLUDE "macro/lyc.inc"
INCLUDE "macro/memcpy.inc"
INCLUDE "macro/relpointer.inc"
INCLUDE "utils.inc"


SECTION "VQUEUE", ROM0

; Initializes the VRAM queue.  
; Lives in ROM0.
;
; Destroys: all
VQueueInit::
    IF CONFIG_BANKABLE_ROMX
        ld a, bank(VQueueRamcode)
        ld [rROMB0], a
    ENDC

    ; Copy RAM code routines
    memcpy_label VQueueRamcode, wVQueueRamcode

    ; Initialize variables
    xor a
    ld hl, wVQueueFree
    ld [hl+], a ; hl = wVQueueFree
    ld [hl+], a ; hl = wVQueueCurrent

    ; Set job return address
    ld hl, wVQueueReturn
    ld a, low(VQueueRun.returnAddress)
    ld [hl+], a
    ld [hl], high(VQueueRun.returnAddress)

    ; We are done here
    ret
;



; Get a VQueue slot pointer.
; The given pointer is not initialized at all, that must be done manually,
; to prevent reading uninitialized memory.  
; Lives in ROM0.
;
; Returns:
; - `hl`: `VQUEUE_T` pointer
;
; Saves: `b`, `de`
VQueueGetRaw::

    ; Read VQueue entry into C and increment
    ld hl, wVQueueFree
    ld a, [hl]
    ld c, a
    add a, VQUEUE_T
    ld [hl+], a

    ; Are we out of slots?
    cp a, [hl] ; hl = wVQueueCurrent
    jr nz, :+
        ld hl, ErrorVQueueOverflow
        rst VecError
    :

    ; VQueue pointer -> HL
    ld l, c
    ld h, high(wVQueue)
    ret
;



; Get a VQueue slot pointer.
; The slot pointer will have its data initialized,
; to prevent uninitialized memory access.  
; Lives in ROM0.
;
; Input:
; - `de`: Routine address
; - `b`: Routine bank
;
; Returns:
; - `hl`: `VQUEUE_T` pointer, at `VQUEUE_REGISTER_BC`
;
; Saves: `de`
VQueueGet::
    call VQueueGetRaw
    ld c, l
    relpointer_init l

    ; Write specified ROMX bank
    IF CONFIG_BANKABLE_ROMX
        relpointer_move VQUEUE_BANK_ROMX
        ld a, b
        ld [hl+], a
        relpointer_add 1
    ENDC

    ; Zero out the rest of the banks
    relpointer_move VQUEUE_BANK_SRAM
    xor a
    ld [hl+], a
    ld [hl+], a
    ld [hl+], a
    relpointer_add 3

    ; Write specified program counter
    relpointer_assert VQUEUE_REGISTER_PC
    write_n16 de
    relpointer_add 2

    ; Write default stack pointer
    relpointer_assert VQUEUE_REGISTER_SP
    write_n16 wVQueueStack

    ; Ok, now zero out the rest of the registers
    xor a
    ld c, l
    REPT VQUEUE_T - __RELPOINTER_POSITION
        ld [hl+], a
    ENDR

    ; Squeaky clean, return
    relpointer_destroy
    ld h, high(wVQueue)
    ld l, c
    ret
;



; Checks if vqueue is empty.  
; Lives in ROM0.
;
; Returns:
; - `fZ`: is empty (z = yes)
;
; Destroys: `af`
VQueueEmpty::
    push hl
    ld hl, wVQueueFree
    ld a, [hl+]
    cp a, [hl]
    pop hl
    ret
;



; Executes jobs from the VRAM queue until the end of VBlank.  
; Lives in ROM0.
;
; Destroys: all
VQueueExecute::
    ld [wVQueueSP], sp

    ; Set up LYC interrupt
    LYC_set_jumppoint VQueueInterrupt
    ld a, STATF_LYC
    ldh [rSTAT], a
    ld a, IEF_STAT
    ldh [rIE], a
    xor a
    ldh [rLYC], a
    ldh [rIF], a

    ld h, high(wVQueue)
    ld a, [wVQueueCurrent]
    ld l, a
    .loop
        ; Are there any jobs left?
        ld a, [wVQueueFree]
        cp a, l
        ret z

        ; Do we have TIME for a job?
        ldh a, [rLY]
        cp a, $98
        ret z

        ; Yes there are, execute it!
        call VQueueRun
        jr .loop
    ;
;



SECTION "VQUEUE RAMCODE DATA", ROMX

VQueueRamcode:
LOAD "VQUEUE RAMCODE", WRAM0
    wVQueueRamcode:

    ; Input:
    ; - `hl`: VQueue job pointer
    ;
    ; Returns:
    ; - `l`: `wVQueueCurrent`
    VQueueRun::
        relpointer_init l

        ; Switch all the banks!
        IF CONFIG_BANKABLE_ROMX
            relpointer_move VQUEUE_BANK_ROMX
            ld a, [hl+]
            ld [rROMB0], a
            relpointer_add 1
        ENDC
        IF CONFIG_BANKABLE_SRAM
            relpointer_move VQUEUE_BANK_SRAM
            ld a, [hl+]
            ld [rRAMB], a
            relpointer_add 1
        ENDC
        IF CONFIG_BANKABLE_WRAMX
            relpointer_move VQUEUE_BANK_ROMX
            ld a, [hl+]
            ldh [rSVBK], a
            relpointer_add 1
        ENDC
        IF CONFIG_BANKABLE_VRAM
            relpointer_move VQUEUE_BANK_ROMX
            ld a, [hl+]
            ldh [rVBK], a
            relpointer_add 1
        ENDC

        ; Prepare program counter
        relpointer_move VQUEUE_REGISTER_PC
        ld a, [hl+]
        ld [.setPC + 1], a
        ld a, [hl+]
        ld [.setPC + 2], a
        relpointer_add 2

        ; Prepare stack pointer
        relpointer_assert VQUEUE_REGISTER_SP
        ld a, [hl+]
        ld [.setSP + 1], a
        ld a, [hl+]
        ld [.setSP + 2], a
        relpointer_destroy

        ; Prepare all other registers
        ld [.restoreSP + 1], sp
        ld sp, hl
        pop bc
        pop de
        pop hl
        pop af

        ; Prepare for the jump
        .setSP ld sp, $0000
        ei
        .setPC jp $0000

        ; If you're here, that means the job has completed!
        .returnAddress::
        di
        .restoreSP ld sp, $0000

        ; Increment `wVQueueCurrent`
        ld bc, wVQueueCurrent
        ld a, [bc]
        add a, VQUEUE_T
        ld [bc], a

        ; Return
        ld h, high(wVQueue)
        ld l, a
        ret
    ;



    ; Input:
    ; - `all`: any
    VQueueInterrupt::
        ; Store registers temporarily, without altering the flags
        ld [.setSP + 1], sp
        push af

        ; Read job pointer -> sp
        ld a, [wVQueueCurrent]
        add a, VQUEUE_T
        ld [.restoreSP + 1], a
        ld a, high(wVQueue)
        ld [.restoreSP + 2], a
        pop af
        .restoreSP ld sp, $0000

        ; Save general purpose register pairs
        push af
        push hl
        push de
        push bc

        ; Save job SP and PC
        .setSP ld hl, $0000
        ld a, [hl+]
        ld c, a
        ld a, [hl+]
        ld b, a
        push hl
        push bc

        ; Save mapped banks
        relpointer_init l
        ld hl, sp - 4
        IF CONFIG_BANKABLE_ROMX
            relpointer_move VQUEUE_BANK_ROMX
            ld a, [rRomXBank]
            ld [hl+], a
            relpointer_add 1
        ENDC
        IF CONFIG_BANKABLE_SRAM
            relpointer_move VQUEUE_BANK_SRAM
            ld a, [rSramBank]
            ld [hl+], a
            relpointer_add 1
        ENDC
        IF CONFIG_BANKABLE_WRAMX
            relpointer_move VQUEUE_BANK_WRAMX
            ldh a, [rSVBK]
            ld [hl+], a
            relpointer_add 1
        ENDC
        IF CONFIG_BANKABLE_VRAM
            relpointer_move VQUEUE_BANK_VRAM
            ldh a, [rVBK]
            ld [hl+], a
            relpointer_add 1
        ENDC
        relpointer_destroy

        ; Restore REAL program counter
        ld hl, wVQueueSP
        ld a, [hl+]
        ld h, [hl]
        ld l, a
        ld sp, hl
        ret
    ;
ENDL
.end



SECTION "VQUEUE DATA", WRAM0, ALIGN[8]

    ; The VRAM job queue.
    wVQueue:: ds 0
    FOR VQUEUE_ENTRY, 16
        .sourceBank{d:VQUEUE_ENTRY}: ds 1
        .destinationBank{d:VQUEUE_ENTRY}: ds 1
        .registerPC{d:VQUEUE_ENTRY}: ds 2
        .registerSP{d:VQUEUE_ENTRY}: ds 2
        .registerBC{d:VQUEUE_ENTRY}: ds 2
        .registerDE{d:VQUEUE_ENTRY}: ds 2
        .registerHL{d:VQUEUE_ENTRY}: ds 2
        .registerAF{d:VQUEUE_ENTRY}: ds 2
        .writeback{d:VQUEUE_ENTRY}: ds 2
    ENDR
    .end::

    ; Top of the VQueue stack.
    ; See `wVQueueStack`.
    wVQueueStackBegin: ds VQUEUE_STACK_SIZE

    ; Dedicated stack for use with VQueue jobs.
    wVQueueStack::

    ; The bottom of the VQueue stack.
    ; Holds the address all jobs will return to when complete.
    wVQueueReturn: dw

    ; Stack pointer backup.
    wVQueueSP: dw

    ; Low pointer to the first free VQueue entry.
    wVQueueFree:: db

    ; Low pointer to the VQueue entry currently being executed.
    wVQueueCurrent:: db

ENDSECTION
