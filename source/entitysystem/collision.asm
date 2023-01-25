

SECTION "ENTSYS COLLISION", ROM0

; Checks for collision between two rectangles.
; Always assumes second x2 >= x1 and y2 >= y1 for both boxes.
; Expects 2-bit alignment on `bc` and `de`.
; Lives in ROM0.
;
; Input:
; - `bc`: rect 1 ptr [XxYy]
; - `de`: rect 2 ptr [XxYy]
;
; Returns:
; - `a`: collision or not (true/false)
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
        ld d, [hl]
        cp a, d

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
; Always assumes second x2 >= x1 and y2 >= y1 for both boxes.
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
; Always assumes second x2 >= x1 and y2 >= y1 for the rectangle.
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