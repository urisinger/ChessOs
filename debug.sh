#!/bin/bash
qemu-system-i386 -fda build/main_floppy.img -s -S & gdb -tui -ex 'target remote localhost:1234' \
    -ex 'set architecture i8086' \
    -ex 'break *0x7c00' \
    -ex 'continue'
