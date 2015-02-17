include .knightos/variables.make

ALL_TARGETS:=$(BIN)settings $(APPS)settings.app $(SHARE)icons/settings.img

$(BIN)settings: *.asm
	mkdir -p $(BIN)
	$(AS) $(ASFLAGS) --listing $(OUT)main.list main.asm $(BIN)settings

$(APPS)settings.app: config/settings.app
	mkdir -p $(APPS)
	cp config/settings.app $(APPS)

$(SHARE)icons/settings.img: config/settings.png
	mkdir -p $(SHARE)icons
	kimg -c config/settings.png $(SHARE)icons/settings.img

include .knightos/sdk.make
