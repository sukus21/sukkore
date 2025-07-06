

SECTION "FONT TEST", ROM0, ALIGN[8]

; Test font :D
FontTest::

    ; Glyph pixel widths
    .widths
    db 4 ; A
    db 4 ; B
    db 4 ; C
    db 4 ; D
    db 4 ; E
    db 4 ; F
    db 4 ; G
    db 4 ; H
    db 4 ; I
    db 4 ; J
    db 4 ; K
    db 4 ; L
    db 6 ; M
    db 5 ; N
    db 4 ; O
    db 4 ; P
    db 4 ; Q
    db 4 ; R
    db 4 ; S
    db 4 ; T
    db 4 ; U
    db 4 ; V
    db 6 ; W
    db 4 ; X
    db 4 ; Y
    db 4 ; Z
    db 2 ; .
    db 2 ; !
    db 4 ; ?

    ; Padding to page boundary
    .padding
    ds $100 - (@ - FontTest)
    ASSERT @ - FontTest == $100

; Font pixel data
FontTestTls: INCBIN "draw/font_test.1bpp"
