INCLUDE "hardware.inc/hardware.inc"
INCLUDE "entsys.inc"
INCLUDE "struct/vqueue.inc"

SECTION "ENTITY PLATFORM TEST", ROMX

; Entity used exclusively for testing platform behaviour.
;
; Input:
; - `de`: Entity pointer
;
; Destroys: all
EntityPlatformTest::
    ; Do nothing
    ret
;
