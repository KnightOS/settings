setDateTime:
    
    ; get the current time (for the default value)
    ; as in Tue 2014-11-11 15:04:32
    ;        A   IX  L  H  B  C  D
    pcall(getTime)
    
    ; to test the code path for calculators with no clocks:
    ;ld a, errUnsupported
    cp errUnsupported
    kjp(z, unsupported)
    
    kld((selected_year), ix)
    ld a, l
    kld((selected_month), a)
    ld a, h
    kld((selected_day), a)
    ld a, b
    kld((selected_hour), a)
    ld a, c
    kld((selected_minute), a)
    ld a, d
    kld((selected_second), a)
    
    pcall(clearBuffer)

    kld(hl, windowTitle)
    xor a
    corelib(drawWindow)
    
    ; draw the date/time
    .drawDate:
    
    ; first, draw the year (that is actually pretty complicated since drawDecHL
    ; is not implemented yet)
    
    push hl
        kld(hl, (selected_year))
        
        ; subtract 1900 from it and put the result in a
        ld de, -1900
        add hl, de
        ld a, l
        
        ; if a >= 100 we have year "20.."
        cp 100
        ld de, 0x0208
        jr nc, .drawYear2000

.drawYear1900:
        ld de, 0x0a08
        kcall(drawDecAPadded)
        
        ; "19"
        ld a, '1'
        ld de, 0x0208
        pcall(drawChar)
        ld a, '9'
        ld de, 0x0608
        pcall(drawChar)
        
        jr .endDrawYear

.drawYear2000:
        sub 100
        ld de, 0x0a08
        kcall(drawDecAPadded)
        
        ; "20"
        ld a, '2'
        ld de, 0x0208
        pcall(drawChar)
        ld a, '0'
        ld de, 0x0608
        pcall(drawChar)

.endDrawYear:
    pop hl
    
    ; now, draw the month and day
    kld(a, (selected_month))
    inc a
    ld de, 0x1608
    kcall(drawDecAPadded)
    kld(a, (selected_day))
    inc a
    ld de, 0x2208
    kcall(drawDecAPadded)
    
    ; the dashes
    ld a, '-'
    ld de, 0x1208
    pcall(drawChar)
    ld de, 0x1e08
    pcall(drawChar)

.drawTime:
    kld(a, (selected_hour))
    ld de, 0x0210
    kcall(drawDecAPadded)
    kld(a, (selected_minute))
    ld de, 0x0c10
    kcall(drawDecAPadded)
    kld(a, (selected_second))
    ld de, 0x1610
    kcall(drawDecAPadded)
    
    ; the colons
    ld a, ':'
    ld de, 0x0a10
    pcall(drawChar)
    ld de, 0x1410
    pcall(drawChar)
    
    kld(hl, backStr)
    ld de, 0x0632
    push de
        pcall(drawStr)
    pop de
    ld d, 2
    ld b, 5
    kld(hl, caretIcon)
    pcall(putSpriteOR)

_:  pcall(fastCopy)
    pcall(flushKeys)
    corelib(appWaitKey)
    jr nz, -_
    ret

unsupported:
    
    kld(hl, clock_unsupported_message)
    kld(de, clock_unsupported_options)
    ld a, 0
    ld b, 0
    corelib(showMessage)
    
    ret

; Draws A (assumed < 100) as a decimal number, padded with a leading zero if it
; is < 10.
drawDecAPadded:
    
    cp 10
    jr nc, .noPadding
    
    ; do padding
    push af
        ld a, '0'
        pcall(drawChar)
    pop af

.noPadding:
    pcall(drawDecA)
    ret

; variables
selected_year:
    .db 0, 0
selected_month:
    .db 0
selected_day:
    .db 0
selected_hour:
    .db 0
selected_minute:
    .db 0
selected_second:
    .db 0

clock_unsupported_message:
    .db "Clock isn't sup-\nported on this\ncalculator.", 0
clock_unsupported_options:
    .db 1
    .db "Quit program", 0
