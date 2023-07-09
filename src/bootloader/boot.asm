org 0x7C00
bits 16


%define ENDL 0x0D, 0x0A
;
;FAT12 header
;

jmp short _start
nop

BPB_OEM_ID: db 'MSWIN4.1'
BPB_BYTES_PER_SECTOR: dw 512
BPB_SECTORS_PER_CLUSTER: db 1
BPB_RESERVED_SECTORS: dw 1
BPB_FILE_ALLOCATION_COUNT: db 1
BPB_DIR_ENTRIES_COUNT: dw 0e0H
BPB_TOTAL_SECTORS: dw 2880
BPB_MEDIA_DESCRIPTOR_TYPE: db 0F0h
BPB_SECTORS_PER_FAT: dw 9
BPB_SECTORS_PER_TRACK: dw 18
BPB_HEADS: dw 2
BPB_HIDDEN_SECTORS: dd 0
BPB_LARGE_SECTOR_COUNT: dd 0
	
;exstended boot record	

EBR_DRIVE_NUMBER: db 0
				  db 0
EBR_SIG: db 29h
EBR_VOL_ID: db 13h, 47h, 28h, 14h
EBR_VOL_LABEL: db 'CHESS OS   '
EBR_SYS_ID: db 'FAT12   '




_start:
	jmp main

;prints a string
puts:
	;save regsiters which are going to be modified
	push si
	push ax

.puts.loop:
	lodsb				;load into al
	or al, al			;check if next char is null
	jz .puts.done

	;call bios interupt
	mov ah, 0x0E
	mov bh, 0
	INT 0x10
	
	jmp .puts.loop

;return from puts
.puts.done:
	pop ax 
	pop si
	ret

main:
	;setup segmenets
	mov ax, 0
	mov ds, ax
	mov es, ax

	;setup stack
	mov ss, ax
	mov sp, 0x7C00

	;read from flappy disk
	mov [EBR_DRIVE_NUMBER], dl
	mov ax, 1
	mov cl, 1
	mov bx, 0x7E00

	call disk_read

	;print string
	mov si, helloWorld
	call puts

	jmp .halt


.halt:
	cli
	jmp .halt


floppy_error:
	mov si,	Read_Failed
	call puts

wait_for_reset:
	mov ah, 0
	int 16h
	jmp 0FFFFh:0


;
;Disk routines
;

;
;Converts a LBA adress to a CHS adress
;Params:
;	- ax LBA adress
;
;Returns: 
;	- cx [bits 0-5] sector number
;	- cx [bits 6-15] cylinder
;	- dh head
lba_to_chs:

	push ax
	push dx

	xor dx, dx			;dx = 0
	div	word [BPB_SECTORS_PER_TRACK]		;ax = LBA / BPB_SECTORS_PER_TRACK, dx = LBA % BPB_SECTORS_PER_TRACK 
		
	inc dx
	mov cx, dx

	xor dx, dx			;dx = 0

	div word [BPB_HEADS]					;ax = (LBA / BPB_SECTORS_PER_TRACK) / BPB_HEADS, dx = (LBA/BPB_SECTORS_PER_TRACK) % BPB_HEADS

	mov dh, dl			;dh = dx = (LBA/BPB_SECTORS_PER_TRACK) % BPB_HEADS
	mov ch, al			;move lowest 8 bits of ax into cx
	shl ah, 6
	or cl, ah


	pop ax
	mov dl, al
	pop ax
	ret


;
;Reads from disk
; Paramas:
;	- ax LBA adress
;	- cl number of sectors to read(up to 128), takes up the last 8 bits
;	- dl drive number
;	- es:bx memory adress to store data
;

disk_read:
	push ax
	push cx
	push di

	push cx				;save the number of sectors
	call lba_to_chs		;compute CHS
	pop ax				;get the number of sectors to al

	mov ah, 02h		;set the operation to do

	mov di, 3		;times to retry
	jmp .retry

.retry:
	pusha
	stc

	int 13h
	jnc .done

	popa
	call disk_reset

	dec di
	test di,di
	jnz .retry

.fail:
	jmp floppy_error

.done:
	popa
	pop di
	pop dx
	pop ax
	ret
;
;Resets disk constroller
; Params: 
;
;	- dl drive number 
;

disk_reset:
	pusha
	mov ah, 0
	stc
	int 13h
	jc floppy_error
	popa
	ret

helloWorld: db 'Hello World!', ENDL, 0
Read_Failed:db 'Cant read from disk!', ENDL, 0

times 510-($-$$) db 0
dw 0AA55h
