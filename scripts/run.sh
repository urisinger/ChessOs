#!/bin/bash
qemu-system-i386 --no-reboot --no-shutdown -hda ../build/main_disk.img -d int -M smm=off
