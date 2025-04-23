INCLUDE "hardware.inc/hardware.inc"
INCLUDE "entsys/entsys.inc"
INCLUDE "vqueue/vqueue.inc"

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
