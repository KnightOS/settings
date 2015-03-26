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
    pcall(clockSupported)
    ; to test the code path for calculators with no clock:
    ;or 1 ; reset the Z flag
    jr z, +_
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
    push af
        ld c, NB_ITEM
        kld(a, (clock_supported))
        cp 0
        jr nz, +_ ; if clock isn't supported, there is one option less
        ld a, c
        dec a
        ld c, a
_:  pop af
    cp c
    ret nc
    ld (hl), a
    kld(hl, caretIcon)
    pcall(putSpriteXOR)
    xor a
    ret
doSelect:
    kld(hl, (item))
    ld h, 0
    push af
        kld(a, (clock_supported))
        kld(de, itemTableClock)
        cp 0
        jr nz, +_
        kld(de, itemTableNoClock)
_:  pop af
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

    kld(hl, knightOSForStr)
    pcall(drawStr)

identifyPlatform:
    pcall(colorSupported)
    kld(hl, platformTI84pCSEStr)
    jr z, identifiedPlatform
    in a, (0x02)
    bit 1, a
    kld(hl, platformTI73Str)
    jr z, identifiedPlatform
    rlca
    kld(hl, platformTI83pStr)
    jr nc, identifiedPlatform
    and 0x40
    kld(hl, platformTI83pSEStr)
    jr z, identifiedPlatform
    in a, (0x21)
    and 0x03
    kld(hl, platformTI84pStr)
    jr z, identifiedPlatform
    kld(hl, platformTI84pSEStr)

identifiedPlatform:
    inc d
    pcall(drawStr)
    pcall(newline)
    pcall(newline)

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

#include "datetime.asm"
#include "upgrade.asm"

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
knightOSForStr:
    .db "KnightOS ", 0
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

platformTI73Str:
    .db "TI-73", 0
platformTI83pStr:
    .db "TI-83+", 0
platformTI83pSEStr:
    .db "TI-83+ SE", 0
platformTI84pStr:
    .db "TI-84+", 0
platformTI84pSEStr:
    .db "TI-84+ SE", 0
platformTI84pCSEStr:
    .db "TI-84+ CSE", 0

systemInfoStr:
    .db "System Info\n", 0
receiveOSStr:
    .db "Receive OS Upgrade\n", 0
setDateTimeStr:
    .db "Set Date/Time\n", 0
backStr:
    .db "Back", 0

caretIcon:
    .db 0b10000000
    .db 0b11000000
    .db 0b11100000
    .db 0b11000000
    .db 0b10000000
    
    ; additional byte to avoid a KFS (?) bug
    ; see https://github.com/KnightOS/KnightOS/issues/296
    nop
