ASM = nasm

SRC_DIR = src
BUILD_DIR = build
CFLAGS = -ffreestanding -fshort-wchar -g
	
.PHONY: all disk_image kernel bootloader clean always

#
#Build floppy image
#
disk_image: $(BUILD_DIR)/main_disk.img

$(BUILD_DIR)/main_disk.img: bootloader
	dd if=/dev/zero of=$(BUILD_DIR)/main_disk.img bs=1024 count=32768
	mkfs.fat -F 16 -n "CHESSOS" $(BUILD_DIR)/main_disk.img -R 2 -M 0xF8 -r 32 
	dd if=$(BUILD_DIR)/bootloader/stage_1/main.bin bs=2 count=481 skip=31 seek=31 of=$(BUILD_DIR)/main_disk.img conv=notrunc
	mcopy -i $(BUILD_DIR)/main_disk.img $(BUILD_DIR)/bootloader/stage_2/main.bin "::stage2.bin"
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
