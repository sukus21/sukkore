

SECTION "TEST ENTITY", ROMX

; Test entity step function.
;
; Input:
; - `de`: Pointer to entity
;
; Destroys: 
testent_step::
    ld hl, w_buffer
    inc [hl]
    ret 
;
