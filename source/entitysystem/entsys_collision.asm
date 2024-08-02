INCLUDE "entsys.inc"
INCLUDE "macros/relpointer.inc"

SECTION "ENTSYS COLLISION", ROM0

; Checks for collision between two rectangles.  
; Always assumes x2 >= x1 and y2 >= y1 for both boxes.  
; Expects 2-bit alignment on `bc` and `de`.  
; Lives in ROM0.
;
; Input:
; - `bc`: Rect 1 ptr [XxYy]
; - `de`: Rect 2 ptr [XxYy]
;
; Returns:
; - `fZ`: Collision or not (z = no, nz = yes)
; - `a`: Collision or not (true/false)
entsys_collision_rr8::
    ld h, d
    ld l, e

    ;if(rect1.X < rect2.X)
    ld a, [bc]
    cp a, [hl]

    jr nc, .higherX

        ;if(rect1.x < rect2.X)
        inc c
        ld a, [bc]
        inc c
        ld d, [hl]
        inc l
        inc l
        cp a, d
        
        jr nc, .ycheck
        xor a
        ret 

    .higherX

        ;if(rect1.X > rect2.x)
        ld d, a
        inc c
        inc c
        inc l
        ld a, [hl+]
        cp a, d

        jr nc, .ycheck
        xor a
        ret 
    ;

    .ycheck

    ;if(rect1.Y < rect2.Y)
    ld a, [bc]
    cp a, [hl]

    jr nc, .higherY

        ;if(rect1.y < rect2.Y)
        inc c
        ld a, [bc]
        cp a, [hl]

        ld a, 0 ;does not change flags
        adc a, a
        ret 

    .higherY

        ;if(rect1.Y > rect2.y)
        ld a, [bc]
        ld d, a
        inc l
        ld a, [hl+]
        cp a, d

        ccf
        ld a, 0 ;does not change flags
        adc a, a
        ret 
    ;
;



; Checks for collision between two rectangles.  
; Input should be placed at `h_colbuf`, in the following format: `[x1 x2 y1 y2], [x1 x2 y1 y2]`  
; Always assumes x2 >= x1 and y2 >= y1 for both boxes.  
; Lives in ROM0.
;
; Returns:
; - `fZ`: Collision or not (z = no, nz = yes)
; - `a`: Collision or not (true/false)
entsys_collision_rr8f::
    ld hl, h_colbuf2

    ;rect1.x1 < rect2.x1
    ld a, [h_colbuf1+0]
    cp a, [hl]
    jr nc, .higherX

        ;rect1.x2 < rect2.x1
        ld a, [h_colbuf1+1]
        cp a, [hl]
        inc l
        inc l
        jr nc, .ycheck
        xor a
        ret

    .higherX

        ;rect1.x1 > rect2.x2
        inc l
        cp a, [hl]
        inc l
        jr c, .ycheck
        xor a
        ret
    ;

    .ycheck

    ;rect1.y1 < rect2.y1
    ldh a, [h_colbuf1+2]
    cp a, [hl]
    jr nc, .higherY

        ;rect1.y2 < rect2.y1
        ldh a, [h_colbuf1+3]
        cp a, [hl]
        ccf
        sbc a, a ;turns nc into z
        ret 

    .higherY

        ;rect1.y1 > rect2.y2
        inc l
        cp a, [hl]
        sbc a, a ;turns nc into z
        ret 
    ;
;



; Checks for collision between two rectangles.  
; Always assumes x2 >= x1 and y2 >= y1 for both boxes.  
; Expects 3-bit alignment on `bc` and `de`.  
; Lives in ROM0.
;
; Input:
; - `bc`: rect 1 ptr [XXxxYYyy]
; - `de`: rect 2 ptr [XXxxYYyy]
;
; Returns:
; - `a`: collision or not (true/false)
entsys_collision_rr16::
    ld h, d
    ld l, e

    ;if(rect1.X < rect2.X)
    ld a, [bc]
    inc c
    cp a, [hl]
    inc hl ;does not change flags

    ;High bytes were the same, compare low bytes
    jr nz, :+
        ld a, [bc]
        cp a, [hl]
    :
    jr nc, .higherX

        ;if(rect1.x < rect2.X)
        ld d, [hl]
        dec l
        inc c
        ld a, [bc]
        cp a, [hl]

        ;High bytes were the same, compare low bytes
        jr nz, :+
            inc c
            ld a, [bc]
            cp a, d
        :
        
        jr nc, .ycheck
        xor a
        ret 

    .higherX

        ;if(rect1.X > rect2.x)
        inc l
        dec c
        ld a, [bc]
        ld d, a
        ld a, [hl+]
        cp a, d

        ;High bytes were the same, compare low bytes
        jr nz, :+
            inc c
            ld a, [bc]
            ld d, a
            ld a, [hl]
            cp a, d
        :

        jr nc, .ycheck
        xor a
        ret 
    ;

    .ycheck

    ;Align to Y-values
    ld a, l
    or a, %00000011
    inc a
    ld l, a
    ld a, c
    or a, %00000011
    inc a
    ld c, a

    ;if(rect1.Y < rect2.Y)
    ld a, [bc]
    inc c
    cp a, [hl]
    inc hl ;does not change flags

    ;High bytes were the same, compare low bytes
    jr nz, :+
        ld a, [bc]
        cp a, [hl]
    :
    jr nc, .higherY

        ;if(rect1.y < rect2.Y)
        ld d, [hl]
        dec l
        inc c
        ld a, [bc]
        cp a, [hl]

        ;High bytes were the same, compare low bytes
        jr nz, :+
            inc c
            ld a, [bc]
            cp a, d
        :

        ld a, 0 ;does not change flags
        adc a, a
        ret 

    .higherY

        ;if(rect1.Y > rect2.y)
        inc l
        dec c
        ld a, [bc]
        ld d, a
        ld a, [hl+]
        cp a, d

        ;High bytes were the same, compare low bytes
        jr nz, :+
            inc c
            ld a, [bc]
            ld d, a
            ld a, [hl]
            cp a, d
        :

        ccf
        ld a, 0 ;does not change flags
        adc a, a
        ret 
    ;
;



; Checks for collision between a point and a rectangle.
; Always assumes x2 >= x1 and y2 >= y1 for the rectangle.
; Expects 3-bit alignment on `de`.
; Lives in ROM0.
;
; Input:
; - `bc`: point ptr [XXYY]
; - `de`: rect ptr [XXxxYYyy]
;
; Returns:
; - `a`: collision or not (true/false)
entsys_collision_pr16::
    ld h, d
    ld l, e

    ;if(point.X < rect.X)
    ld a, [bc]
    ld e, a ;save point high X in e
    inc bc
    cp a, [hl]
    inc hl ;does not change flags

    ;High bytes were the same, compare low bytes
    jr nz, :+
        ld a, [bc]
        cp a, [hl]
    :
    jr nc, .higherX
        xor a
        ret

    .higherX

        ;if(point.X > rect.x)
        inc l
        ld a, [hl+]
        cp a, e

        ;High bytes were the same, compare low bytes
        jr nz, :+
            ld a, [bc]
            ld d, a
            ld a, [hl]
            cp a, d
        :

        jr nc, .ycheck
        xor a
        ret 
    ;

    .ycheck

    ;Align to Y-values
    ld a, l
    or a, %00000011
    inc a
    ld l, a
    inc bc

    ;if(point.Y < rect.Y)
    ld a, [bc]
    ld e, a ;save point high Y in e
    inc bc
    cp a, [hl]
    inc hl ;does not change flags

    ;High bytes were the same, compare low bytes
    jr nz, :+
        ld a, [bc]
        cp a, [hl]
    :
    jr nc, .higherY
        xor a
        ret 

    .higherY

        ;if(point.Y > rect.y)
        inc l
        ld a, [hl+]
        cp a, e

        ;High bytes were the same, compare low bytes
        jr nz, :+
            ld a, [bc]
            ld d, a
            ld a, [hl]
            cp a, d
        :

        ;Final result
        ccf 
        ld a, 0 ;does not change flags
        adc a, a
        ret 
    ;
;



; Creates code for initializing rectangles from entities.
;
; Input:
; - `1`: HRAM location to use (label/address/n8)
MACRO prepare
    push bc
    push hl

    ;This ONLY WORKS under these conditions:
    STATIC_ASSERT ENTVAR_YPOS+2 == ENTVAR_XPOS
    STATIC_ASSERT ENTVAR_XPOS+2 == ENTVAR_HEIGHT
    STATIC_ASSERT ENTVAR_HEIGHT+1 == ENTVAR_WIDTH

    ;Start
    entsys_relpointer_init ENTVAR_YPOS+1, $F0
    relpointer_destroy

    ;Y-position
    ld a, [hl+]
    inc l
    ld c, a
    ldh [\1+3], a

    ;X-position
    ld a, [hl+]
    ld b, a
    ldh [\1+0], a

    ;Subtract height
    ld a, c
    sub a, [hl]
    inc l
    ldh [\1+2], a

    ;Add width
    ld a, b
    add a, [hl]
    ldh [\1+1], a

    ;Return
    pop hl
    pop bc
ENDM



; Write a collision-enabled entity's collision data into buffer.
; This only writes the high-byte of the position, not the low-byte.  
; Always writes to `h_colbuf1`. Use `entsys_collision_prepare2` to use `h_colbuf2`.  
; Lives in ROM0.
;
; Input:
; - `hl`: Entity pointer (anywhere)
;
; Saves: `hl`, `bc`, `de`  
; Destroys: `af`
entsys_collision_prepare1::
    prepare h_colbuf1
    ;call entsys_boundsdraw1
    ret
;



; Write a collision-enabled entity's collision data into buffer.
; This only writes the high-byte of the position, not the low-byte.  
; Always writes to `h_colbuf2`. Use `entsys_collision_prepare1` to use `h_colbuf1`.  
; Lives in ROM0.
;
; Input:
; - `hl`: Entity pointer (anywhere)
;
; Saves: `hl`, `bc`, `de`  
; Destroys: `af`
entsys_collision_prepare2::
    prepare h_colbuf2
    ;call entsys_boundsdraw2
    ret
;



; Draw a test rectangle.  
; Assumes rectangle tiles are loaded.  
; Lives in ROM0.
;
; Saves: `bc`, `de`
entsys_boundsdraw1::
    push bc
    push de

    ;Adjust X-coordinates
    ld a, [w_camera_xpos+1]
    ld h, a
    ldh a, [h_colbuf1+0]
    sub a, h
    ld b, a
    ldh a, [h_colbuf1+1]
    sub a, h
    ld d, a
    ldh a, [h_colbuf1+2]
    ld c, a
    ldh a, [h_colbuf1+3]
    ld e, a

    ;Draw thing
    ld h, high(w_oam)
    call rectangle_points_draw

    ;Return
    pop de
    pop bc
    ret
;



; Draw a test rectangle.  
; Assumes rectangle tiles are loaded.  
; Lives in ROM0.
;
; Saves: `bc`, `de`
entsys_boundsdraw2::
    push bc
    push de

    ;Adjust X-coordinates
    ld a, [w_camera_xpos+1]
    ld h, a
    ldh a, [h_colbuf2+0]
    sub a, h
    ld b, a
    ldh a, [h_colbuf2+1]
    sub a, h
    ld d, a
    ldh a, [h_colbuf2+2]
    ld c, a
    ldh a, [h_colbuf2+3]
    ld e, a

    ;Draw thing
    ld h, high(w_oam)
    call rectangle_points_draw

    ;Return
    pop de
    pop bc
    ret
;
