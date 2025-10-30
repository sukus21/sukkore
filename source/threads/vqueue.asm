INCLUDE "hardware.inc/hardware.inc"
INCLUDE "threads/threads.inc"
INCLUDE "threads/thread_pool.inc"
INCLUDE "threads/vqueue.inc"
INCLUDE "config.inc"
INCLUDE "macro/lyc.inc"
INCLUDE "macro/memcpy.inc"
INCLUDE "macro/relpointer.inc"
INCLUDE "utils.inc"


SECTION "VQUEUE THREADS", ROM0

    ; Initializes the VQueue component.  
    ; Assumes threads have already been initialized (see `ThreadsInit`).  
    ; Lives in ROM0.
    ;
    ; Destroys: all
    VQueueInit::
        xor a
        ld [wVQueuePool], a
        ret
    ;



    ; Create a VQueue thread.
    ; The thread pointer will have its data initialized,
    ; to prevent uninitialized memory access.  
    ; Lives in ROM0.
    ;
    ; Input:
    ; - `de`: Routine address
    ; - `b`: Routine bank
    ;
    ; Returns:
    ; - `hl`: `THREAD_T` pointer, at `THREAD_REGISTER_BC`
    ;
    ; Saves: `de`
    VQueueGet::
        ; Always initialize bottom of stack first
        ld hl, wVQueueReturn
        write_n16 ThreadReturn

        ; Allocate thread for VQueue job
        push de
        ld de, wVQueuePool
        thread_pool_allocate
        pop de
        ld c, l
        relpointer_init l

        ; Write specified ROMX bank
        IF CONFIG_BANKABLE_ROMX
            relpointer_move THREAD_BANK_ROMX
            ld a, b
            ld [hl+], a
            relpointer_add 1
        ENDC

        ; Zero out the rest of the banks
        relpointer_move THREAD_BANK_SRAM
        xor a
        ld [hl+], a
        ld [hl+], a
        ld [hl+], a
        relpointer_add 3

        ; Write specified program counter
        relpointer_assert THREAD_REGISTER_PC
        write_n16 de
        relpointer_add 2

        ; Write default stack pointer
        relpointer_assert THREAD_REGISTER_SP
        write_n16 wVQueueStack

        ; Ok, now zero out the rest of the registers
        xor a
        ld c, l
        REPT THREAD_T - __RELPOINTER_POSITION
            ld [hl+], a
        ENDR

        ; Squeaky clean, return thread pointer
        relpointer_destroy
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
        thread_pool_empty wVQueuePool
        ret
    ;



    ; Executes jobs from the VRAM queue until the end of VBlank.  
    ; Lives in ROM0.
    ;
    ; Destroys: all
    VQueueExecute::

        ; Set up LYC interrupt
        LYC_set_jumppoint ThreadInterrupt
        ld a, STATF_LYC
        ldh [rSTAT], a
        ld a, IEF_STAT
        ldh [rIE], a
        xor a
        ldh [rLYC], a
        ldh [rIF], a

        ld hl, wVQueuePool
        .loop
            ; Are there any jobs left?
            thread_pool_empty hl+
            ret z

            ; Do we have TIME to start a thread?
            ldh a, [rLY]
            cp a, $98
            ret z

            ; Yes we have, execute it!
            ld l, [hl]
            call ThreadRun
            ret nz ; thread interrupted, return

            ; Thread finished, free thread
            ld hl, wVQueuePool
            thread_pool_free
            ret
        ;
    ;

ENDSECTION



SECTION "VQUEUE THREAD VARIABLES", WRAM0

    ; Top of the VQueue stack.
    ; See `wVQueueStack`.
    wVQueueStackBegin: ds VQUEUE_STACK_SIZE

    ; Dedicated stack for use with VQueue jobs.
    wVQueueStack:

    ; The bottom of the VQueue stack.
    ; Holds the address all jobs will return to when complete.
    wVQueueReturn: dw

    ; All current VQueue threads.
    ; This is a thread pool.
    wVQueuePool: ds 16

ENDSECTION
