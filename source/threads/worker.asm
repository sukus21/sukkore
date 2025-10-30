INCLUDE "hardware.inc/hardware.inc"
INCLUDE "threads/threads.inc"
INCLUDE "threads/thread_pool.inc"
INCLUDE "threads/worker.inc"
INCLUDE "config.inc"
INCLUDE "macro/lyc.inc"
INCLUDE "macro/memcpy.inc"
INCLUDE "macro/relpointer.inc"
INCLUDE "utils.inc"


SECTION "WORKER THREADS", ROM0

    ; Initializes worker threads.  
    ; Assumes threads have already been initialized (see `ThreadsInit`).  
    ; Lives in ROM0.
    ;
    ; Destroys: all
    WorkerInit::
        xor a
        ld [wWorkerPool], a
        ret
    ;



    ; Create a worker thread.
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
    WorkerGet::
        ; Always initialize bottom of stack first
        ld hl, wWorkerReturn
        write_n16 ThreadReturn

        ; Allocate the worker thread
        push de
        ld de, wWorkerPool
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
        write_n16 wWorkerStack

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



    ; Checks if worker thread pool is empty.  
    ; Lives in ROM0.
    ;
    ; Returns:
    ; - `fZ`: is empty (z = yes)
    ;
    ; Destroys: `af`
    WorkerEmpty::
        thread_pool_empty wWorkerPool
        ret
    ;



    ; Executes jobs from the worker thread pool until VBlank.  
    ; Lives in ROM0.
    ;
    ; Destroys: all
    WorkerExecute::

        ; Set up VBlank interrupt
        LYC_set_jumppoint ThreadInterrupt
        ldh a, [rIE]
        or a, IEF_VBLANK
        ldh [rIE], a
        xor a
        ldh [rIF], a

        ld hl, wWorkerPool
        .loop
            ; Are there any jobs left?
            thread_pool_empty hl+
            ret z

            ; Do we have TIME to start a thread?
            ldh a, [rLY]
            cp a, $8D
            ret z

            ; Yes we have, execute it!
            ld l, [hl]
            call ThreadRun
            ret nz ; thread interrupted, return

            ; Thread finished, free thread
            ld hl, wWorkerPool
            thread_pool_free
            ret
        ;
    ;

ENDSECTION



SECTION "WORKER THREAD VARIABLES", WRAM0

    ; Top of the worker thread stack.
    ; See `wWorkerStack`.
    wWorkerStackBegin: ds WORKER_STACK_SIZE

    ; Dedicated stack for use with worker threads.
    wWorkerStack:

    ; The bottom of the worker thread stack.
    ; Holds the address all threads will return to when complete.
    wWorkerReturn: dw

    ; All current worker threads.
    ; This is a thread pool.
    wWorkerPool: ds 16

ENDSECTION
