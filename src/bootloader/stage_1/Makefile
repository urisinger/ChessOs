BUILD_DIR?=build/
ASM?=nasm

.PHONY=all clean

all:stage_1

stage_1: always main.asm
	$(ASM) main.asm -f bin -o $(BUILD_DIR)/main.bin

clean: 
	rm -f $(BUILD_DIR)

always:
	mkdir -p $(BUILD_DIR)
