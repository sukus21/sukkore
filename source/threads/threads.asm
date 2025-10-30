INCLUDE "hardware.inc/hardware.inc"
INCLUDE "threads/threads.inc"
INCLUDE "config.inc"
INCLUDE "macro/lyc.inc"
INCLUDE "macro/memcpy.inc"
INCLUDE "macro/relpointer.inc"
INCLUDE "utils.inc"


SECTION "THREADS", ROM0

    ; Initializes the threads component.  
    ; Lives in ROM0.
    ;
    ; Destroys: all
    ThreadsInit::
        IF CONFIG_BANKABLE_ROMX
            ld a, bank(ThreadsRamcode)
            ld [rROMB0], a
        ENDC

        ; Copy RAM code routines
        memcpy_label ThreadsRamcode, wThreadsRamcode

        ; Initialize variables
        xor a
        ld hl, wThreadFree
        ASSERT wThreadCurrent == wThreadFree + 1
        ld [hl+], a ; hl = wThreadFree
        ld [hl+], a ; hl = wThreadCurrent

        ; Zero out the bank for all threads
        ld hl, wThread
        ld bc, $10_00
        :
            ld [hl], c
            ld a, l
            add a, b
            ld l, a
            jr nz, :-
        ;

        ; We are done here
        ret
    ;

    

    ; Get a thread pointer.
    ; The given thread is not initialized at all, that must be done manually,
    ; to prevent reading uninitialized memory when executing it.  
    ; Lives in ROM0.
    ;
    ; Returns:
    ; - `hl`: `THREAD_T` pointer
    ;
    ; Saves: `b`, `de`
    ThreadAllocate::
        ld a, [wThreadFree]
        ld c, a
        ld l, a
        ld h, high(wThread)

        ; Find free thread
        .loop

            ; Is thread free?
            ld a, [hl]
            or a, a
            jr z, .foundThread

            ; Thread is not free, loop around
            ld a, l
            add a, THREAD_T
            ld l, a
            cp a, c
            jr nz, .loop

            ; Ok, we are officially out of thread slots...
            ; Cause a crash
            ld hl, ErrorThreadOverflow
            rst VecError
        ;

        ; We found a thread slot!
        .foundThread
            ld a, l
            add a, THREAD_T
            ld [wThreadFree], a
            ret
        ;
    ;

ENDSECTION



SECTION "THREADS RAMCODE DATA", ROMX

    ; Contains all the ramcode for the threading system.
    ThreadsRamcode:
    LOAD "THREADS RAMCODE", WRAM0
        wThreadsRamcode:

        ; Run a thread until interrupted, or until thread returns.  
        ; Lives in WRAM0.
        ;
        ; Input:
        ; - `l`: Low-pointer to `THREAD_T`
        ;
        ; Returns:
        ; - `fZ`: z = thread completed, nz = thread interrupted
        ;
        ; Destroys: all
        ThreadRun::
            ld [wThreadSP], sp
            ld a, l
            ld [wThreadCurrent], a

            ld h, high(wThread)
            relpointer_init l

            ; Switch all the banks!
            IF CONFIG_BANKABLE_ROMX
                relpointer_move THREAD_BANK_ROMX
                ld a, [hl+]
                ld [rROMB0], a
                relpointer_add 1
            ENDC
            IF CONFIG_BANKABLE_SRAM
                relpointer_move THREAD_BANK_SRAM
                ld a, [hl+]
                ld [rRAMB], a
                relpointer_add 1
            ENDC
            IF CONFIG_BANKABLE_WRAMX
                relpointer_move THREAD_BANK_WRAMX
                ld a, [hl+]
                ldh [rSVBK], a
                relpointer_add 1
            ENDC
            IF CONFIG_BANKABLE_VRAM
                relpointer_move THREAD_BANK_VRAM
                ld a, [hl+]
                ldh [rVBK], a
                relpointer_add 1
            ENDC

            ; Prepare program counter
            relpointer_move THREAD_REGISTER_PC
            ld a, [hl+]
            ld [.setPC + 1], a
            ld a, [hl+]
            ld [.setPC + 2], a
            relpointer_add 2

            ; Prepare stack pointer
            relpointer_assert THREAD_REGISTER_SP
            ld a, [hl+]
            ld [.setSP + 1], a
            ld a, [hl+]
            ld [.setSP + 2], a
            relpointer_destroy

            ; Prepare all other registers
            ld [ThreadReturn.restoreSP + 1], sp
            ld sp, hl
            pop bc
            pop de
            pop hl
            pop af

            ; Prepare for the jump
            .setSP ld sp, $0000
            ei
            .setPC jp $0000

            ; Eventually falls into `ThreadReturn` whenever thread returns
        ;



        ; Jump/call to this address whenever a thread should stop execution.  
        ; Does not return.  
        ; Lives in WRAM0.
        ;
        ; Returns:
        ; - `fZ`: z (indicating thread finished)
        ;
        ; Destroys: all
        ThreadReturn::
            di
            .restoreSP ld sp, $0000

            ; Mark thread as free
            ld a, [wThreadCurrent]
            ld l, a
            ld h, high(wThread)
            STATIC_ASSERT THREAD_BANK_ROMX == 0
            xor a ; sets Z flag
            ld [hl], a

            ; Return
            ret
        ;



        ; Used whenever a thead should be interrupted.  
        ; State of the thread is saved, and execution can continue later.  
        ; Lives in WRAM0.
        ;
        ; Input:
        ; - `all`: any
        ;
        ; Returns:
        ; - `fZ`: nz (indicating thread was interrupted)
        ThreadInterrupt::
            ; Store registers temporarily, without altering the flags
            ld [.setSP + 1], sp
            push af

            ; Read thread pointer -> sp
            ld a, [wThreadCurrent]
            add a, THREAD_T
            ld [.restoreSP + 1], a
            ld a, high(wThread)
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
                relpointer_move THREAD_BANK_ROMX
                ld a, [rRomXBank]
                ld [hl+], a
                relpointer_add 1
            ENDC
            IF CONFIG_BANKABLE_SRAM
                relpointer_move THREAD_BANK_SRAM
                ld a, [rSramBank]
                ld [hl+], a
                relpointer_add 1
            ENDC
            IF CONFIG_BANKABLE_WRAMX
                relpointer_move THREAD_BANK_WRAMX
                ldh a, [rSVBK]
                ld [hl+], a
                relpointer_add 1
            ENDC
            IF CONFIG_BANKABLE_VRAM
                relpointer_move THREAD_BANK_VRAM
                ldh a, [rVBK]
                ld [hl+], a
                relpointer_add 1
            ENDC
            relpointer_destroy

            ; Restore SP and PC (return)
            ld hl, wThreadSP
            ld a, [hl+]
            ld h, [hl]
            ld l, a
            ld sp, hl

            ; Resets the Z flag.
            ; Assumes the high-byte of the stack pointer was NOT $00.
            ; If the stack pointer WAS $00, something else has gone wrong.
            or a, h
            ret
        ;
    ENDL
    .end
ENDSECTION



SECTION "THREAD DATA", WRAM0, ALIGN[8]

    ; Pre-allocated thread slots.
    wThread: ds 0
    FOR THREAD_ENTRY, 16
        .sourceBank{d:THREAD_ENTRY}: ds 1
        .destinationBank{d:THREAD_ENTRY}: ds 1
        .registerPC{d:THREAD_ENTRY}: ds 2
        .registerSP{d:THREAD_ENTRY}: ds 2
        .registerBC{d:THREAD_ENTRY}: ds 2
        .registerDE{d:THREAD_ENTRY}: ds 2
        .registerHL{d:THREAD_ENTRY}: ds 2
        .registerAF{d:THREAD_ENTRY}: ds 2
        .writeback{d:THREAD_ENTRY}: ds 2
    ENDR
    .end:

    ; Stack pointer backup.
    wThreadSP: dw

    ; Latest known free thread
    wThreadFree: db

    ; Low pointer to the currently running thread.  
    ; Reading this value is undefined for the main thread.
    wThreadCurrent: db

ENDSECTION



SECTION "THREAD VARIABLES", HRAM

ENDSECTION
