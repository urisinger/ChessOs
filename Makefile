ASM = nasm

SRC_DIR = src
BUILD_DIR = build

.PHONY: all floppy_image kernel bootloader clean always

#
#Build floppy image
#
floppy_image: $(BUILD_DIR)/main_floppy.img

$(BUILD_DIR)/main_floppy.img: bootloader kernel
	dd if=/dev/zero of=$(BUILD_DIR)/main_floppy.img bs=512 count=2880
	mkfs.fat -F 12 -n "BOOT" $(BUILD_DIR)/main_floppy.img
	dd if=$(BUILD_DIR)/bootloader of=$(BUILD_DIR)/main_floppy.img conv=notrunc
	mcopy -i $(BUILD_DIR)/main_floppy.img $(BUILD_DIR)/kernel "::kernel"
#
#bootloader
#
bootloader: $(BUILD_DIR)/bootloader

$(BUILD_DIR)/bootloader: always
	$(ASM) $(SRC_DIR)/bootloader/boot.asm -f bin -o $(BUILD_DIR)/bootloader					

#
#Build kernel
#

kernel: $(BUILD_DIR)/kernel

$(BUILD_DIR)/kernel: always
	$(ASM) $(SRC_DIR)/kernel/main.asm -f bin -o $(BUILD_DIR)/kernel

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
