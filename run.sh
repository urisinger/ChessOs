#!/bin/bash
qemu-system-i386 --no-reboot --no-shutdown -fda build/main_floppy.img -d int -M smm=off
