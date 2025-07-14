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
    ld hl, wYellerStates + YELLER_SIZE * (MAX_NUM_YELLERS - 2)
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

PlayMusic::
    ; Load music yeller address into hl
    ld hl, wYellerStates + YELLER_SIZE * (MAX_NUM_YELLERS - 1)

    ; Get music yeller flags
    ld d, [hl]
    
    ; Stop audio channels used by music yeller
    ; Probably not the best way to do this, as it may distrupt sound effects, but whatever.
    xor a
    bit YELLER_FLAGB_USES_CH1, d
    jr z, :+
        ldh [rNR12], a
    :
    bit YELLER_FLAGB_USES_CH2, d
    jr z, :+
        ldh [rNR22], a
    :
    bit YELLER_FLAGB_USES_CH3, d
    jr z, :+
        ldh [rNR30], a
    :
    bit YELLER_FLAGB_USES_CH4, d
    jr z, :+
        ldh [rNR42], a
    :

    ; (Re-)initialize yeller
    ; Set new yeller flags
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
SECTION "SOUND EVALUATION", ROMX, ALIGN[8]

YellerOpJumpTable:
    dw YellerOpInvalid
    dw YellerOpTerminate
    dw YellerOpJump
    
    REPT 1
        dw YellerOpInvalid
    ENDR

    dw YellerOpPlaySquare1
    dw YellerOpPlaySquare2
    dw YellerOpPlayWave
    dw YellerOpPlayNoise

    dw YellerOpStopSquare1
    dw YellerOpStopSquare2
    dw YellerOpStopWave
    dw YellerOpStopNoise

    REPT ($100 - (@ - YellerOpJumpTable)) / 2
        dw YellerOpInvalid
    ENDR

    ASSERT (@ % $100) == 0
WaveTable:
    INCBIN "WaveTable.bin"

YellerOpInvalid:
    ld hl, ErrorInvalidYellerOpcode
    rst VecError

YellerOpTerminate:
    ; Stop all audio channels used by this yeller
    xor a
    bit YELLER_FLAGB_USES_CH1, d
    jr z, :+
        ldh [rNR12], a
    :
    bit YELLER_FLAGB_USES_CH2, d
    jr z, :+
        ldh [rNR22], a
    :
    bit YELLER_FLAGB_USES_CH3, d
    jr z, :+
        ldh [rNR30], a
    :
    bit YELLER_FLAGB_USES_CH4, d
    jr z, :+
        ldh [rNR42], a
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
    jp UpdateAudio.YellerLoopCondEarly

YellerOpJump:
    ; Skip if YELLER_FLAGF_BREAK_LOOP is set
    bit YELLER_FLAGB_BREAK_LOOP, c
    jr z, :+
        ; Skip step params
        ld hl, 3
        add hl, bc

        ; Continue step loop
        jp UpdateAudio.YellerStepLoop
    :

    ; Move bc to hl
    ld h, b
    ld l, c

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
    jp UpdateAudio.YellerStepLoop

YellerOpPlaySquare1:
    bit YELLER_FLAGB_USES_CH1, e
    jr z, :+
        ; Skip parameters
        ld hl, 3
        add hl, bc

        jp UpdateAudio.YellerStepLoop
    :

    set YELLER_FLAGB_USES_CH1, d

    ; Move bc to hl
    ld h, b
    ld l, c

    ; Set sweep
    xor a
    ldh [rNR10], a

    ; Get duty and high period bits
    ld a, [hl+]
    ld b, a
    and a, $07
    ld c, a
    xor b

    ; Set duty
    ldh [rNR11], a

    ; Set envelope
    ld a, [hl+]
    ldh [rNR12], a

    ; Set frequency and trigger
    ld a, [hl+]
    ldh [rNR13], a
    ld a, $80
    or c
    ldh [rNR14], a

    jp UpdateAudio.YellerStepLoop

YellerOpPlaySquare2:
    bit YELLER_FLAGB_USES_CH2, e
    jr z, :+
        ; Skip parameters
        ld hl, 3
        add hl, bc

        jp UpdateAudio.YellerStepLoop
    :

    set YELLER_FLAGB_USES_CH2, d

    ; Move bc to hl
    ld h, b
    ld l, c

    ; Get duty and high period bits
    ld a, [hl+]
    ld b, a
    and a, $07
    ld c, a
    xor b

    ; Set duty
    ldh [rNR21], a

    ; Set envelope
    ld a, [hl+]
    ldh [rNR22], a

    ; Set frequency and trigger
    ld a, [hl+]
    ldh [rNR23], a
    ld a, $80
    or c
    ldh [rNR24], a
    
    jp UpdateAudio.YellerStepLoop

YellerOpPlayWave:
    bit YELLER_FLAGB_USES_CH3, e
    jr z, :+
        ld hl, 3
        add hl, bc

        jp UpdateAudio.YellerStepLoop
    :

    set YELLER_FLAGB_USES_CH3, d

    ; Get wave pointer
    ld a, [bc]
    and a, $F0
    ld l, a
    ld a, [bc]
    xor l
    add HIGH(WaveTable)
    ld h, a

    ; Turn off DAC while loading
    xor a
    ldh [rNR30], a

    ; Load wave pointer
    FOR WAVE_IT, 0, 15
        ld a, [hl+]
        ldh [_AUD3WAVERAM + WAVE_IT], a
    ENDR

    ; Increment bc and move to hl
    inc bc
    ld h, b
    ld l, c

    ; Set low period byte
    ld a, [hl+]
    ldh [rNR33], a

    ; Get volume and high frequency bits
    ld a, [hl+]
    
    ; Set volume
    ldh [rNR32], a
    
    ; Turn on DAC and trigger
    ; Assume that the top bit of a is set
    and $87
    ldh [rNR30], a ; We only care about the top bit of this register, which happens to be set in a.
    ldh [rNR34], a
    
    jp UpdateAudio.YellerStepLoop

YellerOpPlayNoise:
    bit YELLER_FLAGB_USES_CH4, e
    jr z, :+
        ld hl, 2
        add hl, bc

        jp UpdateAudio.YellerStepLoop
    :

    set YELLER_FLAGB_USES_CH4, d

    ; Move bc to hl
    ld h, b
    ld l, c

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
    
    jp UpdateAudio.YellerStepLoop

YellerOpStopSquare1:
    bit YELLER_FLAGB_USES_CH1, d
    jr z, :+
        xor a
        ldh [rNR12], a
        
        res YELLER_FLAGB_USES_CH1, d
    :
    
    ld h, b
    ld l, c

    jp UpdateAudio.YellerStepLoop

YellerOpStopSquare2:
    bit YELLER_FLAGB_USES_CH2, d
    jr z, :+
        xor a
        ldh [rNR22], a
        
        res YELLER_FLAGB_USES_CH2, d
    :
    
    ld h, b
    ld l, c

    jp UpdateAudio.YellerStepLoop

YellerOpStopWave:
    bit YELLER_FLAGB_USES_CH3, d
    jr z, :+
        xor a
        ldh [rNR30], a
        
        res YELLER_FLAGB_USES_CH3, d
    :
    
    ld h, b
    ld l, c

    jp UpdateAudio.YellerStepLoop

YellerOpStopNoise:
    bit YELLER_FLAGB_USES_CH4, d
    jr z, :+
        xor a
        ldh [rNR42], a
        
        res YELLER_FLAGB_USES_CH4, d
    :
    
    ld h, b
    ld l, c

    jp UpdateAudio.YellerStepLoop

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
    .YellerLoopStart:
        ; Get yeller flags
        ld a, [hl+]

        ; If yeller is vacant, then skip
        or a
        jp z, .YellerLoopCondEarly

        ; Decrease next step delay
        dec [hl]

        ; If delay is non-zero, then proceed to the next yeller
        jr z, :+
            ; Update used channels bitfield
            or e
            ld e, a

            jp .YellerLoopCondEarly
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
        .YellerStepLoop:
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

            ; End if this is a delay op
            bit 0, a
            jr nz, .EndStepLoop

            ; Move hl to bc
            ld b, h
            ld c, l

            ; Translate opcode to jump table pointer
            ; Since odd numbers indicate delays, all other opcodes are even.
            ; This is convenient since jump addresses occupy two bytes, each.
            ASSERT LOW(YellerOpJumpTable) == 0
            ld l, a
            ld h, HIGH(YellerOpJumpTable)

            ; Load jump pointer
            ld a, [hl+]
            ld h, [hl]
            ld l, a

            jp hl

        .EndStepLoop:

        ; Halve delay value
        srl a

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
        jr z, .YellerLoopEnd

        ; Continue loop
        inc l
        jp .YellerLoopStart

    .YellerLoopCondEarly:
        ; There are probably more efficient places to put this. May optimize later.

        ld a, l
        
        ; Terminate loop if this is the last yeller
        cp LOW(wYellerStates + YELLER_SIZE * MAX_NUM_YELLERS - 3)
        jr z, .YellerLoopEnd

        ; Otherwise, update the pointer and process the next yeller
        add a, 3
        ld l, a
        jp .YellerLoopStart

    .YellerLoopEnd:

    ret

; Some epic test sounds
EpicTestSoundOne::
    db YELLER_OPS_PLAY_SQUARE_WAVE
    db $06
    db $F3
    db 214

    YELLER_DELAY_OP 4

    db YELLER_OPS_PLAY_SQUARE_WAVE
    db $07
    db $F3
    db 14

    YELLER_DELAY_OP 16
    
    db YELLER_OPS_TERMINATE

EpicTestSoundTwo::
    db YELLER_OPS_PLAY_NOISE_WAVE
    db $F1
    db $27

    YELLER_DELAY_OP 16
    
    db YELLER_OPS_TERMINATE

MiiChannelSong::
    INCBIN "MiiChannel.yellercode"
SchombatSong::
    INCBIN "Schombat.yellercode"
HisWorldSong::
    INCBIN "HisWorld.yellercode"
WheelOfMisfortuneSong::
    INCBIN "WheelOfMisfortune.yellercode"

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
