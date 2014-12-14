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
    ld a, d
    kld((current_second), a)

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
        ld de, 0x0220
        jr nc, .drawYear2000

.drawYear1900:
        ld de, 0x0a20
        kcall(drawDecAPadded)
        
        ; "19"
        ld a, '1'
        ld de, 0x0220
        pcall(drawChar)
        ld a, '9'
        ld de, 0x0620
        pcall(drawChar)
        
        jr .endDrawYear

.drawYear2000:
        sub 100
        ld de, 0x0a20
        kcall(drawDecAPadded)
        
        ; "20"
        ld a, '2'
        ld de, 0x0220
        pcall(drawChar)
        ld a, '0'
        ld de, 0x0620
        pcall(drawChar)

.endDrawYear:
    pop hl
    
    ; now, draw the month and day
    kld(a, (current_month))
    inc a
    ld de, 0x1620
    kcall(drawDecAPadded)
    kld(a, (current_day))
    inc a
    ld de, 0x2220
    kcall(drawDecAPadded)
    
    ; the dashes
    ld a, '-'
    ld de, 0x1220
    pcall(drawChar)
    ld de, 0x1e20
    pcall(drawChar)

.drawTime:
    kld(a, (current_hour))
    ld de, 0x3220
    kcall(drawDecAPadded)
    kld(a, (current_minute))
    ld de, 0x3c20
    kcall(drawDecAPadded)
    
    ; the colon
    ld a, ':'
    ld de, 0x3a20
    pcall(drawChar)
    
.drawSelection:
    kld(hl, selected_field_indicator_x)
    kld(a, (selected_field))
    ld d, 0
    ld e, a
    add hl, de
    ld d, (hl)
    ld e, 0x1c
    ld b, 3
    kld(hl, caretUpIcon)
    pcall(putSpriteOR)
    ld e, 0x26
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
    kld((selected_field), a)
    kjp(.redraw)
_:  
    cp kLeft
    jr nz, +_
    kld(a, (selected_field))
    dec a
    kld((selected_field), a)
    kjp(.redraw)
_:  
    ; Clear (cancel)
    cp kClear
    jr nz, +_
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
current_second:
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
    .db 6, 22, 34, 50, 60

caretUpIcon:
    .db 0b00010000
    .db 0b00111000
    .db 0b01111100
caretDownIcon:
    .db 0b01111100
    .db 0b00111000
    .db 0b00010000