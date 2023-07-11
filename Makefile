ASM = nasm

SRC_DIR = src
BUILD_DIR = build
CFLAGS = -ffreestanding -fshort-wchar -g
	
.PHONY: all floppy_image kernel bootloader clean always

#
#Build floppy image
#
floppy_image: $(BUILD_DIR)/main_floppy.img

$(BUILD_DIR)/main_floppy.img: bootloader
	dd if=/dev/zero of=$(BUILD_DIR)/main_floppy.img bs=512 count=2880
	mkfs.fat -F 12 -n "BOOT" $(BUILD_DIR)/main_floppy.img
	dd if=$(BUILD_DIR)/bootloader/stage_1/main.bin of=$(BUILD_DIR)/main_floppy.img conv=notrunc
	mcopy -i $(BUILD_DIR)/main_floppy.img $(BUILD_DIR)/bootloader/stage_2/main.bin "::stage2.bin"
#
#bootloader
#
bootloader: $(BUILD_DIR)/bootloader

$(BUILD_DIR)/bootloader: always
	make -C $(SRC_DIR)/bootloader/stage_1 BUILD_DIR=$(abspath $(BUILD_DIR)/bootloader/stage_1)  ASM=$(ASM)
	make -C $(SRC_DIR)/bootloader/stage_2 BUILD_DIR=$(abspath $(BUILD_DIR)/bootloader/stage_2)  ASM=$(ASM)

	#$(ASM) $(SRC_DIR)/bootloader/stage_1/main.asm -f bin -o $(BUILD_DIR)/bootloader


#
#Build kernel
#

kernel: $(BUILD_DIR)/kernel


$(BUILD_DIR)/kernel: always

#
#always
#
always:
	mkdir -p $(BUILD_DIR)

#
#clean
#
clean:
	rm -rf $(BUILD_DIR)/*
