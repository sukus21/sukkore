INCLUDE "hardware.inc/hardware.inc"
INCLUDE "vqueue/vqueue.inc"
INCLUDE "config.inc"
INCLUDE "macro/lyc.inc"
INCLUDE "macro/memcpy.inc"

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
; Lives in ROM0.
;
; Returns:
; - `hl`: `VQUEUE_T` pointer
;
; Saves: `bc`, `de`
VQueueGet::
    push bc

    ; Read into B and increment
    ld hl, wVQueueFree
    ld a, [hl]
    ld b, a
    add a, VQUEUE_T
    ld [hl+], a

    ; Are we out of slots?
    cp a, [hl] ; hl = wVQueueCurrent
    jr nz, :+
        ld hl, ErrorVQueueOverflow
        rst vError
    :

    ; Yes, good, return
    ld l, b
    ld h, high(wVQueue)
    pop bc
    ret
;



; Enqueues multiple prepared vqueue transfers,
; stored one after the other in memory.  
; Assumes correct ROM-bank is switched in.  
; Lives in ROM0.
;
; Input:
; - `de`: Prepared transfers
; - `b`: Number of transfers
;
; Destroys: all
VQueueEnqueueMulti::
    ld a, b
    or a, a
    ret z

    ; Start loopin' away
    .loop
    call VQueueGet
    ld c, VQUEUE_T
    memcpy_custom hl, de, c
    dec b
    jr nz, .loop
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
    VQueueRun::

        ; Switch source bank
        ld a, [hl+]
        IF CONFIG_BANKABLE_ROMX
            ld [rROMB0], a
        ENDC
        IF CONFIG_BANKABLE_SRAM
            ld [rRAMB], a
        ENDC
        IF CONFIG_BANKABLE_WRAMX
            ldh [rSVBK], a
        ENDC

        ; Switch destination bank
        ld a, [hl+]
        IF CONFIG_BANKABLE_VRAM
            ldh [rVBK], a
        ENDC

        ; Prepare program counter
        ld a, [hl+]
        ld [.setPC + 1], a
        ld a, [hl+]
        ld [.setPC + 2], a

        ; Prepare stack pointer
        ld a, [hl+]
        ld [.setSP + 1], a
        ld a, [hl+]
        ld [.setSP + 2], a

        ; Prepare all other registers
        ld [.restoreSP + 1], sp
        ld sp, hl
        pop bc
        pop de
        pop hl
        pop af
        ld [.restoreHL + 1], sp

        ; Prepare for the jump
        .setSP ld sp, $0000
        ei
        .setPC jp $0000

        ; If you're here, that means the job has completed!
        .returnAddress::
        di
        .restoreHL ld hl, $0000
        .restoreSP ld sp, $0000

        ; Read writeback pointer
        ld a, [hl+]
        ld b, [hl]
        inc l ; explicitly ignore carry to loop queue around

        ; Do we perform writeback?
        or a, a
        jr z, :+

            ; Perform writeback
            ld c, a
            ld a, [bc]
            dec a
            ld [bc], a
        :

        ; Increment `wVQueueCurrent`
        ld bc, wVQueueCurrent
        ld a, [bc]
        add a, VQUEUE_T
        ld [bc], a

        ; Return
        ret
    ;



    ; Input:
    ; - `all`: any
    VQueueInterrupt::
        ; Store registers temporarily, without altering the flags
        ld [.setA + 1], a
        ld [.setSP + 1], sp

        ; Read job pointer -> sp
        ld a, [VQueueRun.restoreHL + 1]
        ld [.restoreSP + 1], a
        ld a, [VQueueRun.restoreHL + 2]
        ld [.restoreSP + 2], a
        .restoreSP ld sp, $0000

        ; Save general purpose register pairs
        .setA ld a, $00
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
