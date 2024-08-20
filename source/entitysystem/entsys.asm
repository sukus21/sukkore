INCLUDE "hardware.inc/hardware.inc"
INCLUDE "entsys.inc"

SECTION "ENTSYS", ROM0

; Execute code for all active entities.  
; Passes entity pointer in DE to step functions.  
; Lives in ROM0.
; 
; Destroys: all
entsys_step::
    push af
    ld [w_entsys_exit], sp
    pop af

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
            .exited
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
        cp a, high(w_entsys_end)
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
    ld b, ENTSYS_CLUSTER_COUNT+1
    ld hl, w_entsys_clusters

    .cluster_loop
        dec b
        jr z, .overflow

        ;Read new cluster mask
        ld a, [hl+]
        ld c, a

        ;Check if chunk is completely occupied
        inc a ;cp a, $FF
        jr z, .cluster_loop

        ;It is not, go through cluster
        scf ;set carry flag, so first iteration results in d = 1
        ld de, $00FF
        .chunk_loop
            inc e ;does not change c flag
            rl d
            jr c, .cluster_loop

            ld a, d
            and a, c ;clears c flag for remaining iterations
            jr nz, .chunk_loop
        ;
    ;

    ;Found entity, mark as occupied in cluster
    dec hl
    ld a, d
    or a, [hl]
    ld [hl], a

    ;Get entity ID
    ld a, ENTSYS_CLUSTER_COUNT
    sub a, b
    add a, a
    add a, a
    add a, a
    add a, e

    ;Convert ID to pointer
    swap a
    ld c, a
    and a, %00001111
    add a, high(w_entsys)
    ld b, a
    ld a, c
    and a, %11110000
    ld c, a
    
    ;Write size
    inc c
    ld a, $10
    ld [bc], a
    dec c

    ;Return
    ret 

    ;No chunks available
    .overflow
        ld hl, error_entityoverflow
        rst v_error
    ;
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
    ld b, ENTSYS_CLUSTER_COUNT+1
    ld hl, w_entsys_clusters

    .cluster_loop
        dec b
        jr z, .overflow

        ;Read new cluster mask
        ld a, [hl+]
        ld c, a

        ;Check if chunk is completely occupied
        inc a ;cp a, $FF
        jr z, .cluster_loop

        ;It is not, go through cluster
        ld de, $0300
        .chunk_loop
            ld a, d
            and a, c ;clears c flag for remaining iterations
            jr z, .found

            inc e
            ld a, d
            rla
            rla
            ld d, a
            jr nc, .chunk_loop
            jr .cluster_loop
        ;
    ;

    ;Found entity, mark as occupied in cluster
    .found
    dec hl
    ld a, d
    or a, [hl]
    ld [hl], a

    ;Get entity ID
    ld a, ENTSYS_CLUSTER_COUNT
    sub a, b
    add a, a
    add a, a
    add a, a
    sla e
    add a, e

    ;Convert ID to pointer
    swap a
    ld c, a
    and a, %00001111
    add a, high(w_entsys)
    ld b, a
    ld a, c
    and a, %11110000
    ld c, a
    
    ;Write size
    inc c
    ld a, $20
    ld [bc], a
    dec c

    ;Return
    ret 

    ;No chunks available
    .overflow
        ld hl, error_entityoverflow
        rst v_error
    ;
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
    ld bc, (ENTSYS_CLUSTER_COUNT+1) << 8
    ld hl, w_entsys_clusters

    .cluster_loop
        dec b
        jr z, .overflow

        ;Read new cluster mask
        ld a, [hl+]
        ld d, a

        ;It is not, go through cluster
        and a, $0F
        jr z, .found
        ld a, $F0
        and a, d
        jr nz, .cluster_loop
        ld c, 4
        ld a, $F0
        or a, a ;unset Z flag
    ;

    ;Found entity, mark as occupied in cluster
    .found
    jr nz, :+
        ld a, $0F
    :
    dec hl
    or a, [hl]
    ld [hl], a

    ;Get entity ID
    ld a, ENTSYS_CLUSTER_COUNT
    sub a, b
    add a, a
    add a, a
    add a, a
    add a, c

    ;Convert ID to pointer
    swap a
    ld c, a
    and a, %00001111
    add a, high(w_entsys)
    ld b, a
    ld a, c
    and a, %11110000
    ld c, a
    
    ;Write size
    inc c
    ld a, $40
    ld [bc], a
    dec c

    ;Return
    ret 

    ;No chunks available
    .overflow
        ld hl, error_entityoverflow
        rst v_error
    ;
;



; Free an entity slot.
; Size is figured out automatically.
; Lives in ROM0.
;
; Input:
; - `hl`: Entity slot pointer
;
; Saves: `de`
entsys_free::
    ;Clear bank and get bitmask from size -> B
    xor a
    ld [hl+], a
    ld a, [hl-]
    swap a
    ld b, 0
    .bitmask_loop
        sla b
        inc b
        dec a
        jr nz, .bitmask_loop
    ;

    ;Get entity ID from pointer -> C
    ld a, h
    sub a, high(w_entsys)
    or a, l
    swap a

    ;Shift bitmask based on ID
    rrca
    jr nc, :+
        rlc b
    :
    rrca
    jr nc, :+
        rlc b
        rlc b
    :
    rrca
    jr nc, :+
        swap b
    :
    and a, %00011111

    ;Mark as available in cluster
    ld hl, w_entsys_clusters
    add a, l
    ld l, a
    ld a, b
    cpl
    and a, [hl]
    ld [hl], a

    ;That should be it
    ret
;



; Clears the entire entity system.  
; Lives in ROM0.
;
; Saves: `de`
entsys_clear::
    ;Initialize entity system
    ld hl, w_entsys
    xor a
    ld b, ENTSYS_CHUNK_COUNT
    .entsys_loop
        ld [hl+], a     ;entity bank
        ld [hl], $40    ;slot size
        inc l
        ld [hl+], a     ;step function pointer, low
        ld [hl+], a     ;step function pointer, high
        REPT 12
            ld [hl+], a ;unassigned data
        ENDR
        dec b
        jr nz, .entsys_loop
    ;

    ld hl, w_entsys_clusters
    ld bc, ENTSYS_CLUSTER_COUNT
    call memset_short

    ;Return
    ret
;



; This entity is destroyed, stop executing its code.  
; Does not return.  
; Lives in ROM0.
entsys_exit::
    
    ;Restore stack position
    ld hl, w_entsys_exit
    ld a, [hl+]
    ld h, [hl]
    ld l, a
    ld sp, hl

    ;Jump back to entity loop
    jp entsys_step.exited
;



; Check if a (collision enabled) entity is out of bounds.  
; Lives in ROM0.
;
; Input:
; - `hl`: Entity pointer (0)
;
; Returns:
; - `fZ`: OOB or not (z = no, nz = yes)
;
; Saves: `hl`
entsys_oob::
    ld e, l
    relpointer_init l
    relpointer_move ENTVAR_XPOS+1
    ld a, [w_camera_xpos+1]
    cpl
    add a, [hl]
    cp a, 160
    jr c, .checky

    ;Getting warmer
    cp a, 240
    jr nc, .checky

    ;Yup, destroy this one
    .destroy
    ld l, e
    or a, h
    ret

    ;Check Y-position
    .checky
    relpointer_move ENTVAR_YPOS+1
    ld a, [hl]
    cp a, 160
    jr nc, .destroy

    ;Nah, we good
    relpointer_destroy
    ld l, e
    xor a
    ret
;
