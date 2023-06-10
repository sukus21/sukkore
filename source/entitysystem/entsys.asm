INCLUDE "hardware.inc"

SECTION "ENTSYS", ROM0

; Execution code prototyping.
; Passed entity pointer in DE to step functions.
; Lives in ROM0.
; 
; Destroys: all
entsys_step::
    ld hl, w_entsys
    .loop

        ;Is this entity in use or not?
        ld d, h
        ld e, l
        ld a, [hl+] ;Entity ROM bank
        or a, a

        ;Entity is not allocated, go to next entity in line
        jr z, .proceed

            ;Entity is in use, apply bank and read pointer
            push hl
            ld [rROMB0], a
            inc hl
            ld a, [hl+] ;Step function pointer
            ld h, [hl]
            ld l, a
            call _hl_
            pop hl
        ;

        ;Go to next entity
        .proceed
        ld a, [hl-] ;Distance to next entity -> entity bank ID
        add a, l
        ld l, a
        jr nc, .loop
        inc h
        ld a, h
        cp a, $E0 ;ERAM
        jr nz, .loop
        ret
    ;
;



; Allocates a new entity.
; Entity size is 1 chunk, or 16 bytes.
; Lives in ROM0.
;
; Returns:
; - `bc`: Entity pointer
;
; Destroys: all
entsys_new16::
    
    ;Load next free slot to HL
    ld hl, w_entsys_first16
    ld a, [hl+]
    ld h, [hl]
    ld l, a

    ;Jump to different path if we're out of 16-bit slots
    bit 7, h
    jr z, .out_of_16

    ;Store allocated slot in BC
    ld b, h
    ld c, l

    ;Load next free slot into DE
    set 1, l
    ld a, [hl+]
    ld d, [hl]

    ;Save next free slot for next allocation
    ld hl, w_entsys_first16
    ld [hl+], a
    ld [hl], d

    ;Return
    ret

    .out_of_16
    call entsys_new32

    ;Save buddy for next allocation
    ld hl, w_entsys_first16
    ld a, c
    set 4, a
    ld [hl+], a
    ld [hl], b

    ;Make buddy a single-chunk slot
    ld h, b
    ld l, c
    inc l
    ld a, $10
    ld [hl], a ;Write entity size

    ;Get buddy slot
    set 4, l

    ;Make new slot a single-chunk slot
    ld [hl-], a ;Write buddy size
    ld [hl], $00 ;Reset buddy bank

    ;Return
    ret
;



; Allocates a new entity.
; Entity size is 2 chunks, or 32 bytes.
; Lives in ROM0.
;
; Returns:
; - `bc`: Entity pointer
;
; Destroys: all
entsys_new32::

    ;Load next free slot to HL
    ld hl, w_entsys_first32
    ld a, [hl+]
    ld h, [hl]
    ld l, a
    ld [hl], $FF ;mark this slot as occupied

    ;Jump to different path if we're out of 2-chunk slots
    bit 7, h
    jr z, .out_of_32

    ;Move 1-chunk pointer?
    push hl
    ld a, [w_entsys_first16+1]
    or a, a ;cp a, 0
    jr nz, .no16
        ld c, $10
        call entsys_find_free
        ld a, l
        ld [w_entsys_first16], a
        ld a, h
        ld [w_entsys_first16+1], a

        ;Can this be used for 2-chunk entity?
        or a, a ;cp a, 0
        jr nz, .new32
        ld a, b
        cp a, $20
        jr nz, .store32
        ld a, e
        jr .store32_2
    .new32
    pop hl
    push hl
    .no16

    ;Find next free slot
    ld c, $20
    call entsys_find_free
    .store32
    ld a, l
    ld d, h
    .store32_2
    ld hl, w_entsys_first32
    ld [hl+], a
    ld [hl], d

    ;Return
    pop bc
    ret

    ;Allocate a 4-chunk and split it
    .out_of_32
    call entsys_new64

    ;Save buddy for next allocation
    ld hl, w_entsys_first32
    ld a, c
    set 5, a
    ld [hl+], a
    ld [hl], b

    ;Set entity size
    ld h, b
    ld l, c
    inc l
    ld a, $20
    ld [hl], a ;Write entity size

    ;Reset buddy slot
    set 5, l
    ld [hl-], a ;Write buddy size
    ld [hl], $00 ;Reset buddy bank

    ;Return
    ret
;



; Allocates a new entity.
; Entity size is 4 chunks, or 64 bytes.
; Lives in ROM0.
;
; Returns:
; - `bc`: Entity pointer
;
; Destroys: all
entsys_new64::

    ;Load next free slot to HL and BC
    ld hl, w_entsys_first64
    ld a, [hl+]
    ld h, [hl]
    ld l, a
    ld [hl], $FF ;mark this slot as occupied
    push hl

    ;Move 1-chunk pointer?
    ld a, [w_entsys_first16+1]
    cp a, 0
    jr nz, .no16
    ld a, [w_entsys_first32+1]
    cp a, 0
    jr nz, .no16
        ld c, $10
        call entsys_find_free
        ld a, l
        ld [w_entsys_first16], a
        ld a, h
        ld [w_entsys_first16+1], a

        ;Can this be used for 2-chunk entity?
        or a, a ;cp a, 0
        jr nz, .new32
        ld a, b
        cp a, $20
        ld a, l
        jr nz, .store32
        ld h, d
        ld a, e
        jr .store32
    .no16

    ;Move 2-chunk pointer?
    ld a, [w_entsys_first32+1]
    cp a, 0
    jr nz, .no32
    .new32
        ;Find new 2-chunk entity
        pop hl
        push hl
        ld c, $20
        call entsys_find_free
        ld a, e

        ;Store found 2-chunk entity
        .store32
        ld [w_entsys_first32], a
        ld a, h
        ld [w_entsys_first32+1], a

        ;Can this be used for the 4-chunk entity?
        cp a, 0
        jr nz, .new64
        ld a, e
        jr .store64
    .new64
    pop hl
    push hl
    .no32

    ;Find next free slot
    ld c, $40
    call entsys_find_free
    ld a, l
    ld d, h

    ;Save next free slot for next allocation
    .store64
    ld hl, w_entsys_first64
    ld [hl+], a
    ld [hl], d

    ;Return
    pop bc
    ret
;



; Free an entity slot.
; Size is figured out automatically.
; Lives in ROM0.
;
; Input:
; - `hl`: Entity slot pointer
;
; Saves: none
entsys_free::
    ;Clear bank and get size
    xor a
    ld [hl+], a
    ld a, [hl-]

    ;Get first-pointer of this size in DE
    cp a, $10
    jp z, entsys_free16
    cp a, $20
    jp z, entsys_free32
    cp a, $40
    jp z, entsys_free64

    ;We should never get here, but just in case
    ret
;



; Helper routine for freeing 1-chunk entities.
; Input entity is assumed to be 1-chunk.
; Lives in ROM0.
;
; Input:
; - `hl`: Entity slot pointer
;
; Saves: none
entsys_free16:
    ;Get buddy chunk
    ld c, l
    ld a, l
    xor a, %00010000
    ld l, a
    ld a, [hl+]
    ld b, a
    ld a, [hl-]

    ;Is this my buddy, and is it free?
    cp a, $10
    jr nz, .no_buddy
    ld a, b
    cp a, $00
    jr nz, .no_buddy ;This is a buddy, and its free
        res 4, l
        inc l
        ld [hl], $20
        ld l, c

        ;Do we need to find a new first pointer for buddy?
        ld a, [w_entsys_first16]
        xor a, %00010000
        cp a, l
        jr nz, .buddy_not_first
        ld a, [w_entsys_first16+1]
        sub a, h ;cp a, h -> xor a
        jr nz, .buddy_not_first

        ;Since these slots are combining,
        ;and no slots are available lower,
        ;this slot can be split.
        ld [w_entsys_first16], a
        ld [w_entsys_first16+1], a

        ;Call free on this slot
        .buddy_not_first
        res 4, l
        jp entsys_free32 ;return from there
    .no_buddy
    ld l, c

    ;Get first-pointer in BC
    ld de, w_entsys_first16
    ld a, [de]
    inc de
    ld c, a
    ld a, [de]
    ld b, a

    ;Replace first-pointer?
    bit 7, a
    jr z, .replace
    cp a, h
    ret c
        
    jr nz, .replace
    ld a, c
    cp a, l
    ret c

    ;Replace first-pointer
    .replace
    ld a, h
    ld [de], a
    dec de
    ld a, l
    ld [de], a

    ;Return
    ret
;



; Helper routine for freeing 2-chunk entities.
; Input entity is assumed to be 2-chunk.
; If needed, updates `w_entsys_first16`.
; Lives in ROM0.
;
; Input:
; - `hl`: Entity slot pointer
;
; Saves: none
entsys_free32:
    ;Get buddy chunk
    ld c, l
    ld a, l
    xor a, %00100000
    ld l, a
    ld a, [hl+]
    ld b, a
    ld a, [hl-]

    ;Is this my buddy, and is it free?
    cp a, $20
    jr nz, .no_buddy
    ld a, b
    cp a, $00
    jr nz, .no_buddy ;This is a buddy, and its free
        res 5, l
        inc l
        ld [hl], $40
        ld l, c

        ;Do we need to find a new first pointer for buddy?
        ld a, [w_entsys_first32]
        xor a, %00100000
        cp a, l
        jr nz, .buddy_not_first
        ld a, [w_entsys_first32+1]
        cp a, h
        jr nz, .buddy_not_first

        ;This gets turned into a 4-chunk which can be split up
        xor a
        ld [w_entsys_first32], a
        ld [w_entsys_first32+1], a

        ;Call free on this slot
        .buddy_not_first
        res 5, l
        jp entsys_free64 ;return from there
    .no_buddy
    ld l, c

    ;Get first-pointer in BC
    ld de, w_entsys_first32
    ld a, [de]
    inc de
    ld c, a
    ld a, [de]
    ld b, a

    ;Replace first-pointer?
    bit 7, a
    jr z, .replace
    cp a, h
    ret c
        
    jr nz, .replace
    ld a, c
    cp a, l
    ret c

    ;Replace first-pointer
    .replace
    ld a, h
    ld [de], a
    dec de
    ld a, l
    ld [de], a

    ;Return
    ret
;



; Helper method for freeing 4-chunk entities.
; Input entity is assumed to be 4-chunk.
; Might update `w_entsys_first32` and `w_entsys_first16`.
; Lives in ROM0.
;
; Input:
; - `hl`: Entity slot pointer
;
; Saves: none
entsys_free64:
    ;Get first-pointer in BC
    ld de, w_entsys_first64
    ld a, [de]
    inc de
    ld c, a
    ld a, [de]
    ld b, a

    ;Replace first-pointer?
    bit 7, a
    jr z, .replace
    cp a, h
    ret c
        
    jr nz, .replace
    ld a, c
    cp a, l
    ret c

    ;Replace first-pointer
    .replace
    ld a, h
    ld [de], a
    dec de
    ld a, l
    ld [de], a

    ;Return
    ret
;



; Find a free slot of a given size.
; Returns `null` if first available slot is bigger.
; Lives in ROM0.
;
; Input:
; - `c`: Size in bytes
; - `hl`: Point to search from (exclusive)
;
; Returns:
; - `hl`: Entity slot pointer
; - `de`: Last slot searched
; - `b`: Size of found slot
;
; Saves: `c`
entsys_find_free:
    inc l
    ld a, [hl-]
    ld b, a ;size of slot

    .continue
        ;Add MAX(target_size, entity_size) to HL
        ld a, c
        cp a, b
        jr nc, :+
            ld a, b
        :
        add a, l
        ld l, a
        jr nc, .loop

        ;OOB check
        inc h
        ld a, h
        cp a, high(w_entsys_end)
        jr nz, .loop

        ;Set output and return
        ld d, h
        ld e, l
        ld hl, $0000
        ret
    ;

    .loop
        ;Get bank and size
        ld a, [hl+]
        ld b, [hl]
        dec l

        ;Is this slot available?
        cp a, 0
        jr nz, .continue

        ;Is this slot my size?
        ld a, b
        cp a, c
        ret z

        ;Is it bigger than me?
        jr c, .continue
        ld d, h
        ld e, l
        ld hl, $0000
        ret
    ;
;
