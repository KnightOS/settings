include .knightos/variables.make

ALL_TARGETS:=$(BIN)settings $(APPS)settings.app

$(BIN)settings: main.asm
	mkdir -p $(BIN)
	$(AS) $(ASFLAGS) --listing $(OUT)main.list main.asm $(BIN)settings

$(APPS)settings.app: config/settings.app
	mkdir -p $(APPS)
	cp config/settings.app $(APPS)

include .knightos/sdk.make
