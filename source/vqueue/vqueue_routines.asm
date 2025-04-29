

SECTION "VQUEUE ROUTINES", ROM0

; Copies data in chunks of 16 bytes.
; Ideal for 2BPP tileset transfers using the VQueue.  
; A transfer length of 0 wraps around to 256.  
; Lives in ROM0.
;
; Input:
; - `hl`: Destination
; - `bc`: Source
; - `d`: Tile count
;
; Returns:
; - `hl`: Destination + Tile count * 16
; - `bc`: Source + Tile count * 16
;
; Saves: `e`
MemcpyTile2BPP::
    REPT 16
        ld a, [bc]
        inc bc
        ld [hl+], a
    ENDR
    dec d
    jr nz, MemcpyTile2BPP
    ret
;



; Copies data in chunks of 8 bytes.
; Ideal for 1BPP tileset transfers using the VQueue.  
; A transfer length of 0 wraps around to 256.  
; Lives in ROM0.
;
; Input:
; - `hl`: Destination
; - `bc`: Source
; - `d`: Tile count
;
; Returns:
; - `hl`: Destination + Tile count * 16
; - `bc`: Source + Tile count * 8
;
; Saves: `e`
MemcpyTile1BPP::
    REPT 8
        ld a, [bc]
        inc bc
        ld [hl+], a
        ld [hl+], a
    ENDR
    dec d
    jr nz, MemcpyTile1BPP
    ret
;



; Fills a memory region with a single value, 16 bytes at a time.  
; A transfer length of 0 wraps around to 256.  
; Lives in ROM0.
;
; Input:
; - `hl`: Destination
; - `b`: Fill byte
; - `c`: Chunk count
;
; Returns:
; - `hl`: Destination + Chunk count * 16
; - `c`: `$00`
;
; Destroys: `af`  
; Saves: `de`
MemsetChunked::
    ld a, b
    
    ; Fill data
    .loop
    REPT 16
        ld [hl+], a
    ENDR

    ; Check chunk count
    dec c
    jr nz, .loop

    ; Return
    ret
;



; Small custom memory copier.
; Copies 20*18 (360) bytes, enough to fill the screen.  
; Every 20 copied bytes, 12 bytes are skipped.  
; Good for use with the VQueue.  
; Lives in ROM0.
;
; Input:
; - `hl`: Destination
; - `bc`: Source
;
; Destroys: `e`
MemcpyScreen::
    ld e, 18

    .loop
        ; Copy tilemap to screen, 20 tiles at a time
        REPT 20
            ld a, [bc]
            inc bc
            ld [hl+], a
        ENDR

        ; Skip data pointer ahead
        ld a, l
        add a, 32 - 20
        jr nc, :+
            inc h
        :
        ld l, a

        ; End of loop
        dec e
        jr nz, .loop
    ;

    ; Return
    ret
;
