include .knightos/variables.make

ALL_TARGETS:=$(BIN)settings

$(BIN)settings: main.asm
	mkdir -p $(BIN)
	$(AS) $(ASFLAGS) --listing $(OUT)main.list main.asm $(BIN)settings

include .knightos/sdk.make
