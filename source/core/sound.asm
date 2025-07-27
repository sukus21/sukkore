; MECHANISM:
;   Four yellers are available. Each yeller can be allocated and set to play a sound effect.
;   Each yeller stores the address of a step within a sequence. Each step is like an instruction
;   for the audio engine, which may order a specific sound from a specific channel, delay the execution
;   of further steps, cause the sound to loop, or end the sound, vacating the yeller. The yeller also
;   stores a bitfield of the channels that it
;   uses, as well as the time at which it began playing the sound.
;   
;   There is also a fifth yeller, which is specialized in music. Although it executes (mostly) the same
;   code as the other yellers, it is otherwise build very differently; Unlike the other yellers, which
;   read the sound data directly from ROM, the fifth yeller uses a streaming decompressor.
;
;   The streaming decompressor uses a LZ scheme with a window size of 256 bytes and a maximum copy length of
;   64 bytes. It is configured to guarantee that at least 32 bytes of music data are ready for playback
;   right before evaluation.
;   The window size of 256 bytes, while small, is enough to provide a significant compression ratio.
;   

INCLUDE "hardware.inc/hardware.inc"

INCLUDE "core/sound.inc"

DEF YELLER_SIZE EQU 4
DEF MAX_NUM_YELLERS EQU 4

DEF AUDIO_ROMX_BANK EQU 2

; Contains all functions used for interfacing with the sound system from the outside.
; Resides in bank 0 for easy access.
SECTION "SOUND INTERFACE", ROM0

; Allocates a yeller and initializes it to play the sound effect starting at the specified address.  
; Lives in ROM0.
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
    ld hl, wYellerStates
    .findYeller
        ; Check if this yeller is vacant
        bit YELLER_FLAGB_IS_OCCUPIED, [hl]
        jr z, .foundYeller

        ; Iterate to next yeller, or return if this is the last
        ld a, l
        add a, YELLER_SIZE
        cp a, low(wYellerStates.end)
        ret z
        ld l, a 
        jr .findYeller
    ;

    ; Initialize yeller
    ; Set yeller flags
    .foundYeller
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
;



; Resets the music yeller and sets it to play the requested music.  
; Lives in ROM0.
; 
; Input:
;   - `bc`: Address of music data. Expected to be in the same ROM bank as the sound playback engine.
; 
; Destroys: all
PlayMusic::
    ; Load music yeller address into hl
    ld hl, wStreamingYellerState

    ; Get music yeller flags
    ld a, [wStreamingYellerState.flags]
    ld d, a
    
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
    ; Set decompression state
    ld [hl+], a
    ld [hl+], a

    ; Set pointer
    ld a, c
    ld [hl+], a
    ld a, b
    ld [hl+], a

    ; Set new yeller flags
    ld a, YELLER_FLAGF_IS_OCCUPIED
    ld [hl+], a

    ; Set next step delay to one, causing the first step to be taken immediately on the next
    ; yeller tick.
    ; ld a, 1 ; Already set, since YELLER_FLAGF_IS_OCCUPIED happens to be 1.
    ld [hl+], a

    ; Reset compression distance
    xor a
    ld [hl+], a

    ; And we done
    ret
;



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
SECTION "SOUND EVALUATION", ROMX, BANK[AUDIO_ROMX_BANK], ALIGN[8]


; Jump table for yeller instructions.
; All functions in this table have the following signature:
;
; Input:
; - `bc`: Yellercode instruction pointer
; - `d`: Yeller state flags
; - `e`: Yeller state flags of higher priority yellers
;
; Returns:
; - `bc`: Yellercode instruction pointer
YellerOpJumpTable:
    dw YellerOpInvalid
    dw YellerOpTerminate
    dw YellerOpJump

    dw YellerOpInvalid

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
;



; Contain the different waves used for the wave channel, all in one place.
WaveTable:
    ASSERT low(@) == 0
    INCBIN "WaveTable.bin"
;



; NOTE: Because the streaming yeller uses a 256-byte ring buffer to store decompressed music data,
; we need pointer increments to only apply to the lower 8 bits. Therefore, we can not use reads with
; post-increment to read the yeller steps.



; Lives in ROM0.
;
; Input:
; - `bc`: Yellercode instruction pointer
; - `d`: Yeller state flags
; - `e`: Yeller state flags of higher priority yellers
;
; Returns:
; - `bc`: Yellercode instruction pointer
YellerOpInvalid:
    ld hl, ErrorInvalidYellerOpcode
    rst VecError
;



; Lives in ROM0.
;
; Input:
; - `bc`: Yellercode instruction pointer
; - `d`: Yeller state flags
; - `e`: Yeller state flags of higher priority yellers
;
; Returns:
; - `bc`: Yellercode instruction pointer
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

    ; Discard return
    inc sp
    inc sp

    ; Recover yeller iterator pointer from stack
    pop hl

    ; Clear all flags
    dec l
    xor a
    ld [hl+], a

    ; Jump straight to the check of the yeller loop, skipping right past the usual yeller state update.
    jp UpdateAudio.YellerLoopCondEarly
;



; Lives in ROM0.
;
; Input:
; - `bc`: Yellercode instruction pointer
; - `d`: Yeller state flags
; - `e`: Yeller state flags of higher priority yellers
;
; Returns:
; - `bc`: Yellercode instruction pointer
YellerOpJump:
    ; Skip if YELLER_FLAGF_BREAK_LOOP is set
    bit YELLER_FLAGB_BREAK_LOOP, d
    jr z, :+
        ; Skip step params
        inc c
        inc c
        inc c

        ; Continue step loop
        jp PerformYellerSteps
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

    ; Move hl back into dc
    ld b, h
    ld c, l

    ; Continue step loop
    jp PerformYellerSteps
;



; Lives in ROM0.
;
; Input:
; - `bc`: Yellercode instruction pointer
; - `d`: Yeller state flags
; - `e`: Yeller state flags of higher priority yellers
;
; Returns:
; - `bc`: Yellercode instruction pointer
YellerOpPlaySquare1:
    bit YELLER_FLAGB_USES_CH1, e
    jr z, :+
        ; Skip parameters
        inc c
        inc c
        inc c

        jp PerformYellerSteps
    :

    set YELLER_FLAGB_USES_CH1, d

    ; Set sweep
    xor a
    ldh [rNR10], a

    ; Get duty and high period bits
    ld a, [bc]
    inc c
    ld h, a
    and a, $07
    ld l, a
    xor h

    ; Set duty
    ldh [rNR11], a

    ; Set envelope
    ld a, [bc]
    inc c
    ldh [rNR12], a

    ; Set frequency and trigger
    ld a, [bc]
    inc c
    ldh [rNR13], a
    ld a, $80
    or l
    ldh [rNR14], a

    jp PerformYellerSteps
;



; Lives in ROM0.
;
; Input:
; - `bc`: Yellercode instruction pointer
; - `d`: Yeller state flags
; - `e`: Yeller state flags of higher priority yellers
;
; Returns:
; - `bc`: Yellercode instruction pointer
YellerOpPlaySquare2:
    bit YELLER_FLAGB_USES_CH2, e
    jr z, :+
        ; Skip parameters
        inc c
        inc c
        inc c

        jp PerformYellerSteps
    :

    set YELLER_FLAGB_USES_CH2, d

    ; Get duty and high period bits
    ld a, [bc]
    inc c
    ld h, a
    and a, $07
    ld l, a
    xor h

    ; Set duty
    ldh [rNR21], a

    ; Set envelope
    ld a, [bc]
    inc c
    ldh [rNR22], a

    ; Set frequency and trigger
    ld a, [bc]
    inc c
    ldh [rNR23], a
    ld a, $80
    or l
    ldh [rNR24], a
    
    jp PerformYellerSteps
;



; Lives in ROM0.
;
; Input:
; - `bc`: Yellercode instruction pointer
; - `d`: Yeller state flags
; - `e`: Yeller state flags of higher priority yellers
;
; Returns:
; - `bc`: Yellercode instruction pointer
YellerOpPlayWave:
    bit YELLER_FLAGB_USES_CH3, e
    jr z, :+
        inc c
        inc c
        inc c
        jp PerformYellerSteps
    :

    set YELLER_FLAGB_USES_CH3, d

    ; Get wave pointer
    ld a, [bc]
    and a, $F0
    ld l, a
    ld a, [bc]
    inc c
    and a, $0F
    add a, HIGH(WaveTable)
    ld h, a

    ; Turn off DAC while loading
    xor a
    ldh [rNR30], a

    ; Load wave pointer
    FOR WAVE_IT, 0, 15
        ld a, [hl+]
        ldh [_AUD3WAVERAM + WAVE_IT], a
    ENDR

    ; Set low period byte
    ld a, [bc]
    inc c
    ldh [rNR33], a

    ; Get volume and high frequency bits
    ld a, [bc]
    inc c
    
    ; Set volume
    ldh [rNR32], a
    
    ; Turn on DAC and trigger
    ; Assume that the top bit of a is set
    and a, $87
    ldh [rNR30], a ; We only care about the top bit of this register, which happens to be set in a.
    ldh [rNR34], a
    
    jr PerformYellerSteps
;



; Lives in ROM0.
;
; Input:
; - `bc`: Yellercode instruction pointer
; - `d`: Yeller state flags
; - `e`: Yeller state flags of higher priority yellers
;
; Returns:
; - `bc`: Yellercode instruction pointer
YellerOpPlayNoise:
    bit YELLER_FLAGB_USES_CH4, e
    jr z, :+
        inc c
        inc c

        jr PerformYellerSteps
    :

    set YELLER_FLAGB_USES_CH4, d

    ; Set timer
    xor a
    ldh [rNR41], a

    ; Set envelope
    ld a, [bc]
    inc c
    ldh [rNR42], a

    ; Set frequency and state size
    ld a, [bc]
    inc c
    ldh [rNR43], a

    ; Set trigger
    ld a, $80
    ldh [rNR44], a
    
    jr PerformYellerSteps
;



; Lives in ROM0.
;
; Input:
; - `bc`: Yellercode instruction pointer
; - `d`: Yeller state flags
; - `e`: Yeller state flags of higher priority yellers
;
; Returns:
; - `bc`: Yellercode instruction pointer
YellerOpStopSquare1:
    bit YELLER_FLAGB_USES_CH1, d
    jr z, PerformYellerSteps

    xor a
    ldh [rNR12], a
    res YELLER_FLAGB_USES_CH1, d

    jr PerformYellerSteps
;



; Lives in ROM0.
;
; Input:
; - `bc`: Yellercode instruction pointer
; - `d`: Yeller state flags
; - `e`: Yeller state flags of higher priority yellers
;
; Returns:
; - `bc`: Yellercode instruction pointer
YellerOpStopSquare2:
    bit YELLER_FLAGB_USES_CH2, d
    jr z, PerformYellerSteps

    xor a
    ldh [rNR22], a
    res YELLER_FLAGB_USES_CH2, d

    jr PerformYellerSteps
;



; Lives in ROM0.
;
; Input:
; - `bc`: Yellercode instruction pointer
; - `d`: Yeller state flags
; - `e`: Yeller state flags of higher priority yellers
;
; Returns:
; - `bc`: Yellercode instruction pointer
YellerOpStopWave:
    bit YELLER_FLAGB_USES_CH3, d
    jr z, PerformYellerSteps

    xor a
    ldh [rNR30], a
    res YELLER_FLAGB_USES_CH3, d

    jr PerformYellerSteps
;



; Lives in ROM0.
;
; Input:
; - `bc`: Yellercode instruction pointer
; - `d`: Yeller state flags
; - `e`: Yeller state flags of higher priority yellers
;
; Returns:
; - `bc`: Yellercode instruction pointer
YellerOpStopNoise:
    bit YELLER_FLAGB_USES_CH4, d
    jr z, PerformYellerSteps

    xor a
    ldh [rNR42], a
    res YELLER_FLAGB_USES_CH4, d

    jr PerformYellerSteps
;



; Lives in ROM0.
;
; Input:
; - `bc`: Address of the next step
; - `d`: Yeller state flags
; - `e`: Yeller state flags of higher priority yellers
;
; Returns:
; - `a`: Delay before next instruction
PerformYellerSteps:
    ; Fetch step code
    ld a, [bc]
    inc c

    ; End if this is a delay op
    bit 0, a
    jr nz, .EndStepLoop

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

    ret
;



; Initializes all memory used by the audio system.  
; Lives in ROM0.
; 
; I don't know best practice for where to put this, so I'm putting it in a function for now.
; I'll let Sukus decide a more permanent location for this procedure. -tecanec
; 
; Destroys: all
InitAudio::
    ; Set a to zero so we can write a lot of zeroes
    xor a

    ; Initialize frame counter
    ld hl, wFrameCounter
    REPT 4
    ld [hl+], a
    ENDR

    ; Mark all yeller states as vacant
    ; Assumes that a = 0 and hl = wYellerStates, which should be the case after initializing the frame counter.
    ld hl, wYellerStates
    REPT MAX_NUM_YELLERS
    ld [hl+], a
    inc l
    inc l
    inc l
    ENDR

    ; Clear streaming yeller state
    ld hl, wStreamingYellerState
    ld [hl+], a
    ld [hl+], a
    inc l
    inc l
    ld [hl+], a

    ; Turn on audio on both ears for all channels
    cpl ; a is zero, so this changes it to $FF
    ldh [rNR51], a

    ret
;



; Performs all audio processing for one frame.
; Should be called once per frame from the game loop.  
; Switches WRAMX banks.
; 
; 
; Destroys: all
UpdateAudio::
    ; Update frame counter. (This can also be moved to a different place if we want to globalize the frame counter.)
    ld hl, wFrameCounter
    REPT 4
        inc [hl]
        jr nz, :+
        inc hl
    ENDR
    :

    ; Clear register e, which will be used to keep track of used channels.
    ld e, 0

    ; Process all yellers
    ld hl, wYellerStates
    .YellerLoopStart:
        ; Get yeller flags
        ld a, [hl+]

        ; If yeller is vacant, then skip
        or a, a
        jp z, .YellerLoopCondEarly

        ; Decrease next step delay
        dec [hl]

        ; If delay is non-zero, then proceed to the next yeller
        jr z, :+
            ; Update used channels bitfield
            or a, e
            ld e, a

            jr .YellerLoopCondEarly
        :

        ; Save yeller flags in `d`
        ld d, a

        ; Save yeller pointer to stack
        push hl
        inc l

        ; Fetch the step pointer
        ld a, [hl+]
        ld b, [hl]
        ld c, a
        call PerformYellerSteps

        ; Recover yeller iterator pointer from stack
        pop hl

        ; Set next step delay in yeller's state
        ld [hl-], a

        ; Update yeller flags
        ld a, d
        ld [hl+], a

        ; Update used channels bitfield
        or a, e
        ld e, a

        ; Update yeller's step pointer
        inc l
        ld a, c
        ld [hl+], a
        ld [hl], b

        ; Terminate loop if this was the final non-music yeller
        ld a, l
        cp a, low(wYellerStates.end - 1)
        jr z, .YellerLoopEnd

        ; Continue loop
        inc l
        jp .YellerLoopStart
    ;

    .YellerLoopCondEarly:
        ; There are probably more efficient places to put this. May optimize later.
        
        ; Terminate loop if this is the last non-music yeller
        ld a, l
        cp a, low(wYellerStates.end - 3)
        jr z, .YellerLoopEnd

        ; Otherwise, update the pointer and process the next yeller
        add a, 3
        ld l, a
        jp .YellerLoopStart
    ;

    .YellerLoopEnd:

    ; Update streaming yeller

    ; Return immediately if streaming yeller isn't even active
    ld a, [wStreamingYellerState.flags]
    bit YELLER_FLAGB_IS_OCCUPIED, a
    ret z

    ; Prepare for decompression

    ; Fix hl
    ld l, LOW(wStreamingYellerState)
    
    ; Get decompression index and current amount of decoded data waiting to be played
    ld a, [hl+]
    ld c, a
    ld a, [hl+]
    ld d, a
    sub a, c

    ; Push accumulated yeller flags
    push de

    ; If we need to decompress more data, get the required amount and decompress
    cpl
    inc a
    sub a, 32
    jr nc, .DecompressionEnd
        ld e, a

        ; Set WRAM bank
        ld a, BANK(wMusicDecompressionBuffer)
        ldh [rSVBK], a

        ; Load source pointer
        ld a, [hl+]
        ld h, [hl]
        ld l, a

        ; Load previous copy distance
        ld a, [wStreamingYellerState.lastCopyDistance]
        ld d, a

        ; Perform decompression steps
        .DecompressionLoop:
            ; Loop variables:
            ; - c is the current index into the ring buffer
            ; - d is last copy distance
            ; - e is negative of the amount of data that needs to be decoded
            ; - hl is source pointer

            ; Get first byte of next decode step tag
            ld a, [hl+]

            ; If lowest bit is set, then this is a copy operation.
            sra a
            jr c, .DecompressionCopy

            ; Otherwise, if second lowest bit is set, this is a raw input operation.
            sra a
            jr c, .DecompressionReadSource

            ; Otherwise, if the third last bit is set, then this is a source jump.
            sra a
            jr c, .DecompressionSourceJump

            ; Otherwise, if all bits are zero, then this is an EOS
            or a, a
            jr c, .DecompressionEos

            ; Otherwise... something's definitely wrong
            ld hl, ErrorInvalidGameData
            rst VecError

            .DecompressionCopy:
                ; If the next lowest bit is set, then the distance must be updated.
                sra a
                jr nc, :+
                    ld b, a
                    ld a, [hl+]
                    ld d, a
                    ld a, b
                :
                
                ; Treat amount as unsigned by clearing the upper two bits.
                and a, $3F

                ; Apply bias to amount
                inc a

                ; Move amount into a non-accumulator register
                ld b, a

                ; Reduce amount that needs to be decoded by amount we're about to decode
                ld a, e
                add a, b
                ld e, a

                ; We won't be reading from source while copying, and we need more registers.
                push hl

                ; Turn hl into a pointer into the ring buffer.
                ld h, HIGH(wMusicDecompressionBuffer)

                ; a will store the low byte of the pointer so we can easily add and subtract.
                ld a, c

                ; Perform the actual copy
                :
                    ; Read copied byte
                    sub a, d
                    ld l, a
                    ld c, [hl]

                    ; Write copied byte at new location
                    add a, d
                    ld l, a
                    ld [hl], c

                    ; Advance
                    inc a
                    dec b
                    jr nz, :-
                ;

                ; Move the ring buffer index back into c
                ld c, a

                ; We can now pop our source pointer back into hl.
                pop hl

                ; Continue decompressing if we still need more data.
                ; Since we can only decode 64 bytes per step, we don't have to worry about
                ; signed overflow, as -32 <= e <= 63 is guarranteed.
                bit 7, e
                jr nz, .DecompressionLoop
                jr .DecompressionLoopEnd
            ;

            .DecompressionReadSource:
                ; Treat amount as unsigned by clearing the upper two bits.
                and a, $3F

                ; Apply bias to amount
                inc a

                ; Move amount into a non-accumulator register
                ld b, a

                ; Reduce amount that needs to be decoded by amount we're about to decode
                ld a, e
                add b
                ld e, a

                ; We won't need copy distance or required amount to be decoded for a while.
                push de

                ; Create pointer into ring buffer
                ld e, c
                ld d, HIGH(wMusicDecompressionBuffer)

                ; Perform the read operation
                :
                    ld a, [hl+]
                    ld [de], a
                    inc e
                    dec b
                    jr nz, :-
                ;

                ; Move the ring buffer index back into c
                ld c, e

                ; Pop copy distance and required amount to be decoded
                pop de

                ; Continue decompressing if we still need more data.
                ; Since we can only decode 64 bytes per step, we don't have to worry about
                ; signed overflow, as -32 <= e <= 63 is guarranteed.
                bit 7, e
                jr nz, .DecompressionLoop
                jr .DecompressionLoopEnd
            ;

            .DecompressionSourceJump:
                ; Store relative address in `bc`
                or $E0
                ld b, a
                ld a, c ; Yes, we're seriously using `a` to make room in `c`.
                ld c, [hl]

                ; Apply relative address
                add hl, bc
                
                ; Get the ring buffer index back from (ahem) `a`
                ld c, a

                jr .DecompressionLoop
            ;

            .DecompressionEos:
                ; Make it so that we'll keep hitting the same EOS marker when trying again
                dec hl

                ; Exit the decompression loop without decompressing the full amount
            ;
        .DecompressionLoopEnd:

        ; Save copy distance
        ld a, d
        ld [wStreamingYellerState.lastCopyDistance], a

        ; Move source pointer to make room in hl
        ld d, h
        ld e, l

        ; Load streaming yeller state pointer into hl
        ld hl, wStreamingYellerState

        ; Save decompression index and source pointer
        ld a, c
        ld [hl+], a
        inc hl
        ld a, e
        ld [hl+], a
        ld a, d
        ld [hl+], a
    .DecompressionEnd:

    ; Pop playback index and accumulated yeller flags
    pop de

    ; Move playback index into c
    ld c, d

    ; Correct hl
    ld l, LOW(wStreamingYellerState.flags)

    ; Get streaming yeller flags
    ld a, [hl+]
    ld d, a

    ; Decrease delay
    dec [hl]

    ; If delay is non-zero, return immediately
    ret nz

    ; Set high byte of yeller code pointer
    ld b, HIGH(wMusicDecompressionBuffer)

    call PerformYellerSteps

    ; Set hl back
    ld hl, wStreamingYellerState.delay

    ; Store delay
    ld [hl-], a

    ; Store flags
    ld [hl], d

    ; Store playback index
    ld a, c
    ld [wStreamingYellerState.playbackIndex], a

    ret
;

SECTION "SOUND DATA", ROMX, BANK[AUDIO_ROMX_BANK], ALIGN[8]
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
;

EpicTestSoundTwo::
    db YELLER_OPS_PLAY_NOISE_WAVE
    db $F1
    db $27

    YELLER_DELAY_OP 16
    
    db YELLER_OPS_TERMINATE
;



MiiChannelSong:: INCBIN "sound/music/Mii Channel.yellercode"
SchombatSong:: INCBIN "sound/music/Schombat.yellercode"
HisWorldSong:: INCBIN "sound/music/His World.yellercode"
WheelOfMisfortuneSong:: INCBIN "sound/music/Wheel of Misfortune.yellercode"
SocialAxhogSong:: INCBIN "sound/music/Social Axhog.yellercode"
ExpiredMilkSong:: INCBIN "sound/music/Expired Milk v2.yellercode"



; This section contains all state related to sound playback (which isn't much).
SECTION "SOUND STATE", WRAM0, ALIGN[8]

; Frame counter
; 
; Sound system only uses lowest byte, but we might also start using this elsewhere,
; so may as well have a full-sized frame counter.
wFrameCounter:: ds 4

; States of the different yellers.
wYellerStates::
FOR N, MAX_NUM_YELLERS
    .flags_{d:N} ds 1
    .nextStepDelay_{d:N} ds 1
    .stepPointer_{d:N} ds 2
ENDR
.end::

; Special streaming yeller, for compressed music.
wStreamingYellerState::
    ; The index into `wMusicDecompressionBuffer` marking the end of currently
    ; decompressed data.
    .decompressionIndex: ds 1

    ; The index into `wMusicDecompressionBuffer` from which music is being read.
    .playbackIndex: ds 1

    .sourcePtr: ds 2

    .flags: ds 1

    .delay: ds 1

    ; The distance of the last copy operation.
    ; 
    ; LZ copy operations can forego specifying a distance and instead use the
    ; same distance as the previous copy operation, hence this variable.
    .lastCopyDistance: ds 1
;



; This section contains memory used internally by the sound system.
SECTION "SOUND INTERNAL", WRAMX, ALIGN[8]

; A 256-byte ring buffer for streamed music.
; Written to and read from by the LZ77 decompression system.
; Also read from by the playback mechanism.
wMusicDecompressionBuffer: ds 256
