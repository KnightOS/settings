setDateTime:
    pcall(clearBuffer)
    
    kld(hl, windowTitle)
    xor a
    corelib(drawWindow)
    
    kld(hl, backStr)
    ld de, 0x0632
    push de
        pcall(drawStr)
    pop de
    ld d, 2
    kld(hl, caretIcon)
    pcall(putSpriteOR)

_:  pcall(fastCopy)
    pcall(flushKeys)
    corelib(appWaitKey)
    jr nz, -_
    ret
