#include "kernel.inc"
#include "corelib.inc"
    .db "KEXC"
    .db KEXC_ENTRY_POINT
    .dw start
    .db KEXC_STACK_SIZE
    .dw 20
    .db KEXC_KERNEL_VER
    .db 0, 6
    .db KEXC_NAME
    .dw name
    .db KEXC_HEADER_END
name:
    .db "System Settings", 0
start:
    pcall(getLcdLock)
    pcall(getKeypadLock)

    pcall(allocScreenBuffer)
    
    ; Load dependencies
    kld(de, corelibPath)
    pcall(loadLibrary)
    
    ; Check whether the clock is supported
    pcall(getTime)
    ; to test the code path for calculators with no clock:
    cp a ; set the zero flag
    jr nz, +_
    ld a, 0
    kld((clock_supported), a)
_:
    
redraw:
    kld(hl, windowTitle)
    xor a
    corelib(drawWindow)
    
    ; Print items
    ld de, 0x0608
    kld(hl, systemInfoStr)
    ld b, 6
    pcall(drawStr)
    kld(hl, receiveOSStr)
    pcall(drawStr)
    kld(a, (clock_supported))
    cp 0
    jr z, +_
    kld(hl, setDateTimeStr)
    pcall(drawStr)
_:  kld(hl, backStr)
    pcall(drawStr)
    pcall(newline)
    
_:  kld(hl, (item))
    add hl, hl
    ld b, h
    ld c, l
    add hl, hl
    add hl, bc
    ld de, 0x0208
    add hl, de
    ld e, l
    kld(hl, caretIcon)
    ld b, 5
    pcall(putSpriteOR)

    pcall(fastCopy)
    pcall(flushKeys)
    corelib(appWaitKey)
    jr nz, -_
    cp kUp
    kcall(z, doUp)
    cp kDown
    kcall(z, doDown)
    cp k2nd
    kcall(z, doSelect)
    cp kEnter
    kcall(z, doSelect)
    cp kMode
    ret z
    jr -_
    
doUp:
    kld(hl, item)
    ld a, (hl)
    or a
    ret z
    dec a
    ld (hl), a
    kld(hl, caretIcon)
    pcall(putSpriteXOR)
    xor a
    ret
#define NB_ITEM 4
doDown:
    kld(hl, item)
    ld a, (hl)
    inc a
    cp NB_ITEM
    ret nc
    ld (hl), a
    kld(hl, caretIcon)
    pcall(putSpriteXOR)
    xor a
    ret
doSelect:
    kld(hl, (item))
    ld h, 0
    kld(de, itemTableClock)
    add hl, hl
    add hl, de
    ld e, (hl)
    inc hl
    ld d, (hl)
    pcall(getCurrentThreadID)
    pcall(getEntryPoint)
    add hl, de
    pop de \ kld(de, redraw) \ push de
    jp (hl)
    
itemTableClock:
    .dw printSystemInfo
    .dw receiveOS
    .dw setDateTime
    .dw exit
itemTableNoClock:
    .dw printSystemInfo
    .dw receiveOS
    .dw exit
    
printSystemInfo:
    pcall(clearBuffer)
    
    kld(hl, windowTitle)
    xor a
    corelib(drawWindow)
    
    ld de, 0x0208
    ld b, 2

    kld(hl, systemVersionStr)
    pcall(drawStr)

    push de
        kld(de, etcVersion)
        pcall(openFileRead)
        jr nz, .noVersion
        pcall(getStreamInfo)
        pcall(malloc)
        inc bc
        pcall(streamReadToEnd)
        pcall(closeStream)
        push ix \ pop hl
        add hl, bc
        dec hl
        xor a
        ld (hl), a
        push ix \ pop hl
    pop de
.writeVersion:
    ld b, 2
    inc d \ inc d \ inc d
    pcall(drawStr)
    pcall(free)

    kld(hl, kernelVersionStr)
    pcall(drawStr)
    
    ld hl, kernelVersion
    inc d \ inc d \ inc d
    pcall(drawStr)
    pcall(newline)
    
    kld(hl, bootCodeVersionStr)
    pcall(drawStr)
    
    pcall(getBootCodeVersionString)
    inc d \ inc d \ inc d
    pcall(drawStr)
    push hl \ pop ix
    pcall(free)

    pcall(newline)
    pcall(newline)

    kld(hl, backStr)
    ld d, 6
    ld b, 5
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

.noVersion:
    pop de
    kld(hl, notFoundStr)
    jr .writeVersion

#include "datetime.asm"

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

exit:
    pop hl
    ret
    
item:
    .db 0
clock_supported:
    .db 1
corelibPath:
    .db "/lib/core", 0
etcVersion:
    .db "/etc/version", 0
windowTitle:
    .db "System Settings", 0
systemVersionStr:
    .db "KnightOS version:\n", 0
kernelVersionStr:
    .db "Kernel version:\n", 0
bootCodeVersionStr:
    .db "Boot Code version:\n", 0
confirmUpgradeStr:
    .db "Warning! Upgrading your\n"
    .db "operating system may\n"
    .db "result in data loss.\n"
    .db "\n"
    .db "    Cancel\n"
    .db "    Proceed", 0
    
systemInfoStr:
    .db "System Info\n", 0
receiveOSStr:
    .db "Receive OS Upgrade\n", 0
setDateTimeStr:
    .db "Set Date/Time\n", 0
backStr:
    .db "Back", 0
notFoundStr:
    .db "Not found\n", 0

caretIcon:
    .db 0b10000000
    .db 0b11000000
    .db 0b11100000
    .db 0b11000000
    .db 0b10000000

; From UOSRECV
; TODO: Fully port UOSRECV including unsigned patches
bootCodeReceiveOS:
    di
    pcall(unlockFlash)
    pcall(getBootPage)
    out (0x06), a
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
