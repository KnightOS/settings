setDateTime:
    
    ; get the current time (for the default value)
    ; as in Tue 2014-11-11 15:04:32
    ;        A   IX  L  H  B  C  D
    pcall(getTime)
    
    ; to test the code path for calculators with no clocks:
    ;ld a, errUnsupported
    cp errUnsupported
    kjp(z, unsupported)
    
    kld((current_year), ix)
    ld a, l
    kld((current_month), a)
    ld a, h
    kld((current_day), a)
    ld a, b
    kld((current_hour), a)
    ld a, c
    kld((current_minute), a)

.redraw:
    pcall(clearBuffer)

    kld(hl, windowTitle)
    xor a
    corelib(drawWindow)
    
    ; draw the instruction message
    ld de, 0x0208
    ld b, 2

    kld(hl, instruction_message)
    pcall(drawStr)
    
    ; draw the date/time
    .drawDate:
    
    ; first, draw the year (that is actually pretty complicated since drawDecHL
    ; is not implemented yet)
    
    push hl
        kld(hl, (current_year))
        
        ; subtract 1900 from it and put the result in a
        ld de, -1900
        add hl, de
        ld a, l
        
        ; if a >= 100 we have year "20.."
        cp 100
        jr nc, .drawYear2000

.drawYear1900:
        ld de, 0x1724
        kcall(drawDecAPadded)
        
        ; "19"
        ld a, '1'
        ld de, 0x0f24
        pcall(drawChar)
        ld a, '9'
        ld de, 0x1324
        pcall(drawChar)
        
        jr .endDrawYear

.drawYear2000:
        sub 100
        ld de, 0x1724
        kcall(drawDecAPadded)
        
        ; "20"
        ld a, '2'
        ld de, 0x0f24
        pcall(drawChar)
        ld a, '0'
        ld de, 0x1324
        pcall(drawChar)

.endDrawYear:
    pop hl
    
    ; now, draw the month and day
    kld(a, (current_month))
    inc a
    ld de, 0x2324
    kcall(drawDecAPadded)
    kld(a, (current_day))
    inc a
    ld de, 0x2f24
    kcall(drawDecAPadded)
    
    ; the dashes
    ld a, '-'
    ld de, 0x1f24
    pcall(drawChar)
    ld de, 0x2b24
    pcall(drawChar)

.drawTime:
    kld(a, (current_hour))
    ld de, 0x3f24
    kcall(drawDecAPadded)
    kld(a, (current_minute))
    ld de, 0x4924
    kcall(drawDecAPadded)
    
    ; the colon
    ld a, ':'
    ld de, 0x4724
    pcall(drawChar)
    
.drawSelection:
    kld(hl, selected_field_indicator_x)
    kld(a, (selected_field))
    ld d, 0
    ld e, a
    add hl, de
    ld d, (hl)
    ld e, 0x20
    ld b, 3
    kld(hl, caretUpIcon)
    pcall(putSpriteOR)
    ld e, 0x2a
    ld b, 3
    kld(hl, caretDownIcon)
    pcall(putSpriteOR)
    
    pcall(fastCopy)
    
.waitForKey:
    pcall(flushKeys)
    corelib(appWaitKey)
    
    ; arrow keys (move selected field)
    cp kRight
    jr nz, +_
    kld(a, (selected_field))
    inc a
    cp 5
    jr nz, $+3
    ld a, 4
    kld((selected_field), a)
    kjp(.redraw)
_:  
    cp kLeft
    jr nz, +_
    kld(a, (selected_field))
    dec a
    cp -1
    jr nz, $+3
    ld a, 0
    kld((selected_field), a)
    kjp(.redraw)
_:  
    cp kUp
    jr nz, +_
    kcall(upPressed)
    kjp(.redraw)
_:  
    cp kDown
    jr nz, +_
    kcall(downPressed)
    kjp(.redraw)
_:  
    ; Clear (cancel)
    cp kClear
    jr nz, +_
    ret
_:  
    ; Enter (save)
    cp kEnter
    jr nz, +_
    kld(ix, (current_year))
    kld((current_month), a)
    ld l, a
    kld((current_day), a)
    ld h, a
    kld((current_hour), a)
    ld b, a
    kld((current_minute), a)
    ld c, a
    ld d, 0
    pcall(convertTimeToTicks)
    pcall(setClock)
    ret
_:  
    jr .waitForKey

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

upPressed:
    push af
        kld(a, (selected_field))
        
        cp 0
        kcall(z, increaseYear)
        cp 1
        kcall(z, increaseMonth)
        cp 2
        kcall(z, increaseDay)
        cp 3
        kcall(z, increaseHour)
        cp 4
        kcall(z, increaseMinute)
    pop af
    
    ret

downPressed:
    push af
        kld(a, (selected_field))
        
        cp 0
        kcall(z, decreaseYear)
        cp 1
        kcall(z, decreaseMonth)
        cp 2
        kcall(z, decreaseDay)
        cp 3
        kcall(z, decreaseHour)
        cp 4
        kcall(z, decreaseMinute)
    pop af
    
    ret

increaseYear:
    push hl
        kld(hl, (current_year))
        inc hl
        kld((current_year), hl)
    pop hl
    ret

increaseMonth:
    push af
        kld(a, (current_month))
        inc a
        cp 12
        jr c, +_
        kcall(increaseYear)
        sub a, 12
_:      kld((current_month), a)
    pop af
    
    ret

increaseDay:
    push af
        kld(a, (current_day))
        inc a
        cp 31
        jr c, +_
        kcall(increaseMonth)
        sub a, 31
_:      kld((current_day), a)
    pop af
    
    ret

increaseHour:
    push af
        kld(a, (current_hour))
        inc a
        cp 24
        jr c, +_
        kcall(increaseDay)
        sub a, 24
_:      kld((current_hour), a)
    pop af
    
    ret

increaseMinute:
    push af
        kld(a, (current_minute))
        inc a
        cp 60
        jr c, +_
        kcall(increaseHour)
        sub a, 60
_:      kld((current_minute), a)
    pop af
    
    ret

decreaseYear:
    push hl
        kld(hl, (current_year))
        dec hl
        kld((current_year), hl)
    pop hl
    ret

decreaseMonth:
    push af
        kld(a, (current_month))
        dec a
        cp 128
        jr c, +_
        kcall(decreaseYear)
        add a, 12
_:      kld((current_month), a)
    pop af
    
    ret

decreaseDay:
    push af
        kld(a, (current_day))
        dec a
        cp 128
        jr c, +_
        kcall(decreaseMonth)
        add a, 31
_:      kld((current_day), a)
    pop af
    
    ret

decreaseHour:
    push af
        kld(a, (current_hour))
        dec a
        cp -1
        jr nz, +_
        kcall(decreaseDay)
        add a, 24
_:      kld((current_hour), a)
    pop af
    
    ret

decreaseMinute:
    push af
        kld(a, (current_minute))
        dec a
        cp -1
        jr nz, +_
        kcall(decreaseHour)
        add a, 60
_:      kld((current_minute), a)
    pop af
    
    ret


; variables
current_year:
    .db 0, 0
current_month:
    .db 0
current_day:
    .db 0
current_hour:
    .db 0
current_minute:
    .db 0
selected_field: ; 0 = year, 1 = month, 2 = day, 3 = hour, 4 = minute
    .db 0

; constants
clock_unsupported_message:
    .db "Clock isn't sup-\nported on this\ncalculator.", 0
clock_unsupported_options:
    .db 1
    .db "Back", 0

instruction_message:
    .db "Use the arrow keys to set the\nclock and press Enter to\nsave or Clear to cancel.", 0

selected_field_indicator_x:
    .db 19, 35, 47, 63, 73

caretUpIcon:
    .db 0b00010000
    .db 0b00111000
    .db 0b01111100
caretDownIcon:
    .db 0b01111100
    .db 0b00111000
    .db 0b00010000
