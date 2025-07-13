; MECHANISM:
;   Four yellers are available. Each yeller can be allocated and set to play a sound effect.
;   Each yeller stores the address of a step within a sequence. Each step is like an instruction
;   for the audio engine, which either orders a specific sound from a specific channel or ends
;   the sound, vacating the yeller. The yeller also stores a bitfield of the channels that it
;   uses, as well as the time at which it began playing the sound.
;   
;   As an optimization, all times are stored modulo 256, which simplifies comparisons. The only
;   consequence of this is that delays of more than 255 frames between two consecutive steps can
;   not be handled correctly. However, we expect these long delays to be rare in practice, and
;   even if they do appear, the delay can simply be extended with a no-op step. Notably, since
;   steps are evaluated sequentially, any delay below 256 is still valid.
;   

; FURTHER IDEAS:
; - Change delays to be their own operation.
;   Reserve half of opcodes to delays to minimize cost.
;   This could reduce the total size of the yeller code by eliminating zero-delays.
; - Pack certain parameters of channel-triggering operations.
;   Some parameters are either unused or constant, and do not need to be stored in the yeller code.
;   Many of these parameters occupy different sets of bits, so bitshifts will not be needed.
;   This could save one or two bytes on certain common operations.
; - Add operation variants with more parameters.
;   Some parameters, such as channel 1 sweep, are often unused in practice, but may still be
;   valuable for certain effects.
; - Switch to jump table.
;   This should allow for a larger set of operations without too much overhead, allowing for
;   more specific operations that occupy less space in ROM.

INCLUDE "hardware.inc/hardware.inc"

INCLUDE "core/sound.inc"

DEF YELLER_SIZE EQU 4
DEF MAX_NUM_YELLERS EQU 4

; Contains all functions used for interfacing with the sound system from the outside.
; Resides in bank 0 for easy access.
SECTION "SOUND INTERFACE", ROM0

; Allocates a yeller and initializes it to play the sound effect starting at the specified address.
; 
; Input:
;   - `bc`: Address of sound effect. Expected to be in the same ROM bank as the sound playback engine.
; 
; Returns:
;   - `l`: Yeller handle
; 
; Destroys: all
PlaySound::
    ; Find available yeller
    ld hl, wYellerStates + YELLER_SIZE * (MAX_NUM_YELLERS - 1)
    :
        ; Check if this yeller is vacant
        ld a, [hl]
        or a
        jr z, :+

        ; Iterate to next yeller, or return if this is the last
        ld a, l
        sub a, YELLER_SIZE
        ret z
        ld l, a 
        jr :-
    :

    ; Initialize yeller
    ; Set yeller flags
    ld a, YELLER_FLAGF_IS_OCCUPIED
    ld [hl+], a

    ; Set next step delay to one, causing the first step to be taken immediately on the next
    ; yeller tick.
    ; ld a, 1 ; Already set, since YELLER_FLAGF_IS_OCCUPIED happens to be 1.
    ld [hl+], a

    ; Set pointer
    ld a, c
    ld [hl+], a
    ld a, b
    ld [hl+], a

    ret

; This section contains everything sound-related, including both the sound effects and the
; code for playing them.
; 
; PLANNED: Sound effects will be coded in a dedicated format and compiled at build time.
; They will then be embedded into this section.
; 
; Placing the sound effects in the same bank as the sound system lets us avoid switching
; banks while playing them.
; 
; Resides in a switchable bank, since it is largely self-contained and is only needed during
; sound evaluation.
SECTION "SOUND EVALUATION", ROMX ALIGN(256)

; Initializes all memory used by the audio system.
; 
; I don't know best practice for where to put this, so I'm putting it in a function for now.
; I'll let Sukus decide a more permanent location for this procedure. -tecanec
; 
; Destroys: all
InitAudio::
    ; Initialize frame counter
    xor a
    ld hl, wFrameCounter
    REPT 4
    ld [hl+], a
    ENDR

    ; Mark all yeller states as vacant
    ; Assumes that a = 0 and hl = wYellerStates, which should be the case after initializing the frame counter.
    REPT MAX_NUM_YELLERS - 1
    ld [hl+], a
    inc l
    inc l
    inc l
    ENDR
    ld [hl], a

    ; Turn on audio on both ears for all channels
    ld a, $FF
    ldh [rNR51], a

    ret

; Performs all audio processing for one frame.
; 
; Should be called once per frame from the game loop.
; 
; Destroys: all
UpdateAudio::
    ; Update frame counter. (This can also be moved to a different place if we want to globalize the frame counter.)
    ld b, 0 ; We're doing three carry additions with 0, so using a register over an immediate saves one cycle. 
    ld hl, wFrameCounter
    ld a, [hl]
    add a, 1
    ld [hl+], a
    REPT 3
    ld a, [hl]
    adc a, b
    ld [hl+], a
    ENDR

    ; Clear register e, which will be used to keep track of used channels.
    ld e, 0

    ; Process all yellers
    ; `b` is now a bitfield of used channels.
    UpdateAudio_YellerLoopStart:
        ; Get yeller flags
        ld a, [hl+]

        ; If yeller is vacant, then skip
        or a
        jp z, UpdateAudio_YellerLoopCondEarly

        ; Decrease next step delay
        dec [hl]

        ; If delay is non-zero, then proceed to the next yeller
        jr z, :+
            ; Update used channels bitfield
            or e
            ld e, a

            jp UpdateAudio_YellerLoopCondEarly
        :

        ; Save yeller flags in `d`
        ld d, a

        ; Save `hl` to stack and fetch the step pointer.
        push hl
        inc l
        ld a, [hl+]
        ld h, [hl]
        ld l, a

        ; This is a loop, since multiple steps may take place on the same frame if they have delays of 0.
        UpdateAudio_StepLoopStart:
            ; Loop variables:
            ; - `d` contains the state flags of the yeller.
            ; - `e` contains the union of the state flags of all higher-priority yellers.
            ;       This lets us know what sound channels we can't use.
            ; - `hl` contains the address of the next step.
            ; - `a`, `b`, and `c` are undefined.
            ; - The address of the second byte of the yeller is at the top of the stack.
            ;       Note that all of the yeller's state is either already in registers or known implicitly.

            ; Fetch step code
            ld a, [hl+]

            ; YELLER_OPS_NOP
            or a
            jp z, UpdateAudio_StepLoopCond

            ; YELLER_OPS_TERMINATE
            dec a
            jr nz, .YellerOpsTerminateEnd
                ; Stop all audio channels used by this yeller
                bit YELLER_FLAGB_USES_CH1, d
                jr z, :+
                    ld a, 0
                    ldh [rNR12], a
                :

                ; Since we know this is the final step in the sequence, we can terminate the loop early.
                ; Terminator steps also aren't followed by a delay value.

                ; Recover yeller iterator pointer from stack
                pop hl

                ; Clear all flags
                dec l
                xor a
                ld [hl+], a

                ; Jump straight to the check of the yeller loop, skipping right past the usual yeller state update.
                jp UpdateAudio_YellerLoopCondEarly
            .YellerOpsTerminateEnd

            ; YELLER_OPS_JUMP
            dec a
            jr nz, :+
                ; Get destination address
                ld a, [hl+]
                ld b, a
                ld a, [hl+]
                ld c, a

                ; Get delay
                ld a, [hl+]

                ; Apply destination address
                ld l, c
                ld h, b

                ; Continue step loop
                jp UpdateAudio_StepLoopCondWithDelay
            :

            ; YELLER_OPS_JUMP_UNLESS_SIGNAL
            dec a
            jr nz, :++
                ; Skip if YELLER_FLAGF_BREAK_LOOP is set
                bit YELLER_FLAGB_BREAK_LOOP, c
                jr z, :+
                    ; Skip step params
                    ld de, 3
                    add hl, de

                    ; Continue step loop
                    jp UpdateAudio_StepLoopCond
                :

                ; Get destination offset
                ld a, [hl+]
                ld c, a
                ld a, [hl+]
                ld b, a

                ; Get delay
                ld a, [hl+]

                ; Apply destination address
                add hl, bc

                ; Continue step loop
                jp UpdateAudio_StepLoopCondWithDelay
            :

            ; YELLER_OPS_SET_WAVE_PATTERN
            dec a
            jr nz, :++
                ; Load source address
                

                push hl

                ; Perform the copy
                :
                    ; Partially unrolled; Amount can be adjusted, but must be a power of two and no more than 16.
                    REPT 4
                    ld a, [hl+]
                    ldh [c], a
                    inc c
                    ENDR

                    ; Range goes from FF30 to FF3F, so we know we're finished when bit 4 of c is cleared.
                    bit 4, c
                    jr nz, :-
                ;

                pop hl
            :

            ; YELLER_OPS_BASIC_SQUAVE
            dec a
            jr nz, :+
                bit YELLER_FLAGB_USES_CH1, e
                jr nz, UpdateAudio_StepLoopCond

                set YELLER_FLAGB_USES_CH1, d
            
                ; Set sweep
                ld a, 0 ; No sweep
                ldh [rNR10], a

                ; Set duty
                ld a, AUDLEN_DUTY_12_5
                ldh [rNR11], a

                ; Set envelope
                ld a, $F0
                ldh [rNR12], a

                ; Set frequency and trigger
                ld a, LOW(1750)
                ldh [rNR13], a
                ld a, HIGH(1750) | AUDHIGH_RESTART
                ldh [rNR14], a
            :

            ; YELLER_OPS_PLAY_SQUARE_WAVE
            dec a
            jr nz, .YellerOpsPlaySquareWaveEnd
                bit YELLER_FLAGB_USES_CH1, e
                jr z, :+
                    ; Skip parameters
                    ld bc, 5
                    add hl, bc

                    jr UpdateAudio_StepLoopCond
                :

                set YELLER_FLAGB_USES_CH1, d

                ; Set sweep
                ld a, [hl+]
                ldh [rNR10], a

                ; Set duty
                ld a, [hl+]
                ldh [rNR11], a

                ; Set envelope
                ld a, [hl+]
                ldh [rNR12], a

                ; Set frequency and trigger
                ld a, [hl+]
                ldh [rNR13], a
                ld a, [hl+]
                ldh [rNR14], a
            .YellerOpsPlaySquareWaveEnd

            ; YELLER_OPS_PLAY_SQUARE_WAVE_2
            dec a
            jr nz, .YellerOpsPlaySquareWave2End
                bit YELLER_FLAGB_USES_CH2, e
                jr z, :+
                    ld bc, 4
                    add hl, bc

                    jr UpdateAudio_StepLoopCond
                :

                set YELLER_FLAGB_USES_CH2, d

                ; Set duty
                ld a, [hl+]
                ldh [rNR21], a

                ; Set envelope
                ld a, [hl+]
                ldh [rNR22], a

                ; Set frequency and trigger
                ld a, [hl+]
                ldh [rNR23], a
                ld a, [hl+]
                ldh [rNR24], a
            .YellerOpsPlaySquareWave2End

            dec a

            dec a
            jr nz, .YellerOpsPlayNoiseWaveEnd
                bit YELLER_FLAGB_USES_CH4, e
                jr z, :+
                    ld bc, 4
                    add hl, bc

                    jr UpdateAudio_StepLoopCond
                :

                set YELLER_FLAGB_USES_CH2, d

                ; Set timer
                xor a
                ldh [rNR41], a

                ; Set envelope
                ld a, [hl+]
                ldh [rNR42], a

                ; Set frequency and state size
                ld a, [hl+]
                ldh [rNR43], a

                ; Set trigger
                ld a, $80
                ldh [rNR44], a
            .YellerOpsPlayNoiseWaveEnd

        UpdateAudio_StepLoopCond:
            ; Get next delay
            ld a, [hl+]

        UpdateAudio_StepLoopCondWithDelay:
            ; Continue loop if delay is zero
            or a
            jp z, UpdateAudio_StepLoopStart

        UpdateAudio_StepLoopEnd:

        ; Recover yeller iterator pointer from stack
        ld b, h
        ld c, l
        pop hl

        ; Set next step delay in yeller's state
        ld [hl-], a

        ; Update used channels bitfield
        ld a, e
        or d
        ld e, a

        ; Update yeller flags
        ld a, d
        ld [hl+], a

        ; Update yeller's step pointer
        inc l
        ld a, c
        ld [hl+], a
        ld [hl], b

        ; Terminate loop if this was the final yeller
        ld a, l
        cp a, LOW(wYellerStates + YELLER_SIZE * MAX_NUM_YELLERS - 1)
        jr z, UpdateAudio_YellerLoopEnd

        ; Continue loop
        inc l
        jp UpdateAudio_YellerLoopStart

    UpdateAudio_YellerLoopCondEarly:
        ; There are probably more efficient places to put this. May optimize later.

        ld a, l
        
        ; Terminate loop if this is the last yeller
        cp LOW(wYellerStates + YELLER_SIZE * MAX_NUM_YELLERS - 3)
        jr z, UpdateAudio_YellerLoopEnd

        ; Otherwise, update the pointer and process the next yeller
        add a, 3
        ld l, a
        jp UpdateAudio_YellerLoopStart

    UpdateAudio_YellerLoopEnd:

    ret

; Some epic test sounds
EpicTestSoundOne::
    db YELLER_OPS_BASIC_SQUAVE
    db 4

    db YELLER_OPS_PLAY_SQUARE_WAVE
    db $1C
    db $00
    db $F3
    db 214
    db $86
    db 16
    
    db YELLER_OPS_TERMINATE

MiiChannelSong::
    INCBIN "MiiChannel.yellercode"
SchombatSong::
    INCBIN "Schombat.yellercode"

; This section contains all state related to sound playback (which isn't much).
SECTION "SOUND STATE", wram0, align[8]

; Frame counter
; 
; Sound system only uses lowest byte, but we might also start using this elsewhere,
; so may as well have a full-sized frame counter.
wFrameCounter::
    ds 4

; Structure of yellers:
; - Flags:              1 byte
; - Next step delay:    1 byte
; - Step pointer:       2 bytes
; 
; The flags are:
; - bit 0: Clear if vacant.
; - bits 1-3: Unused
; - bit 4: Set if yeller uses the first square wave channel
; - bit 5: Set if yeller uses the second square wave channel
; - bit 6: Set if yeller uses the waveform channel
; - bit 7: Set if yeller uses the noise channel
; 
; Start address must be four bytes after a 256-byte alignment.
wYellerStates::
    ds YELLER_SIZE * MAX_NUM_YELLERS
