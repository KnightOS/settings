receiveOS:
    pcall(clearBuffer)
    
    kld(hl, windowTitle)
    xor a
    corelib(drawWindow)

    ld de, 0x0208
    ld b, 2
    kld(hl, confirmUpgradeStr)
    pcall(drawStr)

    xor a
    kld((.cursor), a)
    kcall(.invertCursor)
.loop:
    pcall(fastCopy)
    pcall(flushKeys)
    pcall(waitKey)
    cp kDown
    jr z, .handleDown
    cp kUp
    jr z, .handleUp
    cp kEnter
    jr z, .handleSelect
    cp k2nd
    jr z, .handleSelect
    cp kClear
    ret z
    jr .loop

.handleDown:
    kld(a, (.cursor))
    cp 1
    jr z, .loop
    kcall(.invertCursor)
    inc a
    kcall(.invertCursor)
    kld((.cursor), a)
    jr .loop

.handleUp:
    kld(a, (.cursor))
    or a
    jr z, .loop
    kcall(.invertCursor)
    dec a
    kcall(.invertCursor)
    kld((.cursor), a)
    jr .loop

.handleSelect:
    kld(a, (.cursor))
    or a
    ret z
    ; Here goes nothing
    kjp(bootCodeReceiveOS)

.cursor:
    .db 0

.invertCursor:
    push af
        kld(hl, caretIcon)
        ld de, 0x0220
        add a, a \ ld b, a \ add a, a \ add a, b ; A *= 6
        add a, e
        ld e, a
        ld b, 5
        pcall(putSpriteXOR)
    pop af
    ret

; From UOSRECV
; TODO: Fully port UOSRECV including unsigned patches
bootCodeReceiveOS:
    di
    pcall(unlockFlash)
    pcall(colorSupported)
    jr nz, .notColor
    pcall(getBootPage)
    and 0x7F
    out (0x06), a
    ld a, 1
    out (0x0E), a
    jr .color
.notColor:
    pcall(getBootPage)
    out (0x06), a
.color:
    kld(ix, jumpPointPattern)
    ld de, 0x4000
    kcall(findPattern)
    jr nz, _
    kld(hl, (foundAddress))
    ld a, h
    cp 0x80
    jr nc, _
    ld bc, jumpPointPatternEnd - jumpPointPattern
    add hl, bc
    ; Off to the boot code!
    jp (hl)
_:  ; Error
    ei
    kld(hl, .errorText)
    kld(de, .errorOptions)
    xor a
    ld b, a
    corelib(showMessage)
    ret
.errorText:
    .db "An error occured.\n"
    .db "Upgrade manually.", 0
.errorOptions:
    .db 1
    .db "Ok", 0

foundAddress:
    .dw 0

dummyRet:
    ret

jumpPointPattern:
    ld hl, (0x0056)
    ld bc, 0x0A55A
    or a
    sbc hl, bc
    jp z, 0x0053
jumpPointPatternEnd:
    .db 0xFF

findPattern:
;Pattern in IX, starting address in DE
;Returns NZ if pattern not found
;(foundAddress) contains the address of match found
;Search pattern:    terminated by 0FFh
;                    0FEh is ? (one-byte wildcard)
;                    0FDh is * (multi-byte wildcard)
    kld(hl, dummyRet)
    push hl
    dec de
searchLoopRestart:
    inc de
    kld((foundAddress), de)
    push ix
    pop hl
searchLoop:
    ld b, (hl)
    ld a, b
    inc a
    or a
    ret z
    inc de
    inc a
    jr z, matchSoFar
    dec de
    inc a
    ld c, a
    ;At this point, we're either the actual byte (match or no match) (C != 0)
    ;  or * wildcard (keep going until we find our pattern byte) (C == 0)
    or a
    jr nz, findByte
    inc hl
    ld b, (hl)
findByte:
    ld a, (de)
    inc de
    bit 7, d
    ret nz
    cp b
    jr z, matchSoFar
    ;This isn't it; do we start over at the beginning of the pattern,
    ;  or do we keep going until we find that byte?
    inc c
    dec c
    jr z, findByte
    kld(de, (foundAddress))
    jr searchLoopRestart
matchSoFar:
    inc hl
    jr searchLoop
