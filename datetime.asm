setDateTime:
    
    ; get the current time (for the default value)
    ; as in Tue 2014-11-11 15:04:32
    ;        A   IX  L  H  B  C  D
    pcall(getTime)
    
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
    kjp(nz, .redraw)
    
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
    
    kcall(ensureDayWithinBounds)
    
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
    
    kcall(ensureDayWithinBounds)
    
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
    push af \ push bc \ push de
        kld(hl, (current_year))
        kld(a, (current_month))
        ld e, a
        kcall(monthLength)
        ld b, a
        kld(a, (current_day))
        inc a
        cp b
        jr c, +_
        kcall(increaseMonth)
        sub a, b
_:      kld((current_day), a)
    pop de \ pop bc \ pop af
    
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
    push af \ push bc \ push de
        kld(a, (current_day))
        dec a
        cp 128
        jr c, +_
        kcall(decreaseMonth)
        push af
            kld(hl, (current_year))
            kld(a, (current_month))
            ld e, a
            kcall(monthLength)
            ld b, a
        pop af
        add a, b
_:      kld((current_day), a)
    pop de \ pop bc \ pop af
    
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

; ensures that the day is not higher than the month length
ensureDayWithinBounds:
    kld(hl, (current_year))
    kld(a, (current_month))
    ld e, a
    kcall(monthLength)
    ld b, a
    
    kld(a, (current_day))
    ; if a >= b, then do a := b - 1
    cp b
    jr c, +_
    ld a, b
    dec a
    kld((current_day), a)
_:  ret


; TODO The next functions should be moved to the kernel

;; monthLength
;;   Computes the amount of days in a given month.
;; Inputs:
;;   HL: the year
;;    E: the month (0-11)
;; Outputs:
;;    A: the amount of days in this month
monthLength:
    ld a, e
    cp 1
    jr nz, +_ ; if not February, avoid the costly leap year computation
    kcall(isLeapYear)
_:  push hl \ push bc
        cp 1
        jr z, +_ ; if a = 1, so we have a leap year
        kld(hl, month_length_non_leap)
        jr ++_
_:      kld(hl, month_length_leap)
_:      ld b, 0
        ld c, e
        add hl, bc
        ld a, (hl)
    pop bc \ pop hl
    
    ret

;; isLeapYear
;;   Determines whether the given year is a leap year.
;; Inputs:
;;   HL: the year
;; Outputs:
;;    A: 1 if it is a leap year; 0 if it is not
isLeapYear:
    
    push bc \ push de
        
        ; divisible by 400?
        ld a, h
        ld c, l
        ld de, 400
        pcall(divACByDE) ; remainder in hl
        
        ld a, h
        cp 0
        jr nz, .notDivisibleBy400
        ld a, l
        cp 0
        jr nz, .notDivisibleBy400
    pop de \ pop bc
    
    ld a, 1
    ret
    
.notDivisibleBy400:
        
        ; divisible by 100?
        ld c, 100
        push hl
            pcall(divHLByC) ; remainder in a
            cp 0
            jr nz, .notDivisibleBy100
        pop hl
    pop de \ pop bc
    
    ld a, 0
    ret
    
.notDivisibleBy100:
        pop hl
        
        ; divisible by 4?
        ld c, 4
        push hl
            pcall(divHLByC) ; remainder in a
            cp 0
            jr nz, .notDivisibleBy4
        pop hl
    pop de \ pop bc
    
    ld a, 1
    ret
    
.notDivisibleBy4:
        pop hl
    pop de \ pop bc
    
    ld a, 0
    ret

;; weekday
;;   Determines the weekday (Sunday, Monday, ...) of a given date.
;; Inputs:
;;   HL: the year
;;    E: the month (0-11)
;;    D: the day (0-30)
;; Outputs:
;;    B: the weekday (0-6, 0 = Sunday, 6 = Saturday) of the given date
weekday:
    ; TODO implement
    ld b, 0
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

; lengths of the months
month_length_non_leap:
    .db 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31
month_length_leap:
    .db 31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31
