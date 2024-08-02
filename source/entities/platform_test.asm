INCLUDE "hardware.inc"
INCLUDE "entsys.inc"
INCLUDE "struct/vqueue.inc"

SECTION "ENTITY PLATFORM TEST", ROMX

; Entity used exclusively for testing platform behaviour.,
;
; Input:
; - `de`: Entity pointer
;
; Destroys: all
entity_platform_test::
    ;Do nothing
    ret
;
