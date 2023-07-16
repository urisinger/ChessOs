org 0x7C00
bits 16


;
;FAT12 header
;

%define ENDL 0x0D, 0x0A
jmp  _start
nop

BPB_OEM_ID: db 'MSWIN4.1'
BPB_BYTES_PER_SECTOR: dw 5092
BPB_SECTORS_PER_CLUSTER: db 2
BPB_RESERVED_SECTORS: dw 2
BPB_FILE_ALLOCATION_COUNT: db 2
BPB_DIR_ENTRIES_COUNT: dw 0e0H
BPB_TOTAL_SECTORS: dw 2880
BPB_MEDIA_DESCRIPTOR_TYPE: db 0F0H
BPB_SECTORS_PER_FAT: dw 9
BPB_SECTORS_PER_TRACK: dw 18
BPB_HEADS: dw 2
BPB_HIDDEN_SECTORS: dd 0
BPB_LARGE_SECTOR_COUNT: dd 0
	
;exstended boot record	

EBR_DRIVE_NUMBER: db 0x0
				  db 0
EBR_SIG: db 28h
EBR_VOL_ID: db 13h, 47h, 28h, 14h
EBR_VOL_LABEL: db 0
EBR_SYS_ID: db 0




_start:

	;setup segmenets
	mov ax, 0
	mov ds, ax
	mov es, ax

	;setup stack
	mov ss, ax
	mov sp, 0x7C00
	
	push es
	push word .after
	retf

.after:
	;read from flappy disk
	mov dl, [EBR_DRIVE_NUMBER]	;set dl to current drive number

	push es
	mov ah, 08h
	int 13h
	jc disk_error
	pop es
	push cx
	and cl, 0x3F
	xor ch, ch
	mov [BPB_SECTORS_PER_TRACK], cx
	pop cx


	inc dh
	mov [BPB_HEADS], dh
	
	xor dx,dx

	;print starting message
	mov si, loadmsg
	call puts
	mov si, STAGE2
	call load_file_root
	xor bx,bx
	mov es, bx
	mov bx, second_stage_start
	mov cx, 1
	mov ax, 1

	;call disk_read

	jmp second_stage_start





wait_for_reset:
	hlt
	mov ah, 0
	int 16h
	jmp _start



;
;Disk routines
;

;
;loads file in root file dir
; Params: 
;	-si pointer to start of filname
;	-es:bx where to load file
;

load_file_root:
	[bits 16]
	push ax
	push bx
	push es
	push dx
	push si
	;find start of root dir
	mov ax, [BPB_SECTORS_PER_FAT]
	mov bl, [BPB_FILE_ALLOCATION_COUNT]
	xor bh, bh
	mul bx
	add ax, [BPB_RESERVED_SECTORS]
	
	mov [root_LBA], ax
	

	;find size of root dir
	mov ax, [BPB_DIR_ENTRIES_COUNT]
	shl ax, 5
	xor dx, dx
	mov bx, [BPB_BYTES_PER_SECTOR]
	div bx
	


	test dx, dx
	jz .load_file_after
	inc ax

.load_file_after:

	mov [root_size], ax

	mov cx, ax
	mov ax, [root_LBA]
	mov dl, [EBR_DRIVE_NUMBER]
	mov bx, buffer_seg
	mov es, bx
	xor bx, bx

	call disk_read
	mov di, bx
	xor bx, bx

.find:
	mov si, STAGE2
	mov cx, 11
	push di
	repe cmpsb 
	pop di
	je .found

	add di, 32
	inc bx

	cmp bx, [BPB_DIR_ENTRIES_COUNT]
	jl .find

.not_found:
	mov si, Kernel_no
	call puts
	
	jmp wait_for_reset

.found:
	mov ax, es:[di + 26]
	mov [Kernel_cluster], ax
	mov bx, buffer_seg
	mov es, bx
	xor bx, bx
	mov ax, [BPB_RESERVED_SECTORS]
	mov cl, [BPB_SECTORS_PER_FAT]
	mov dl, [EBR_DRIVE_NUMBER]
	call disk_read
	
	xor bx, bx
	mov es, bx
		
	mov bx, second_stage_start


.load_file_loop:
	mov ax, [Kernel_cluster]
	sub ax, 2
	mov cx, [BPB_SECTORS_PER_CLUSTER]
	mul cx
	add ax, [root_LBA]
	add ax, [root_size]

	mov cx, [BPB_SECTORS_PER_CLUSTER]
	mov dl, [EBR_DRIVE_NUMBER]
	call disk_read
	add bx, [BPB_BYTES_PER_SECTOR]

	mov ax, [Kernel_cluster]
	mov cx, 2
	mul cx
	mov si, ax
	mov cx, buffer_seg
	mov es, cx
	mov ax, [es:si]
	xor cx, cx
	mov es, cx

	cmp ax, 0xFFF8
	jae .read_finish

	mov [Kernel_cluster], ax
	jmp .load_file_loop

.read_finish:

	pop dx
	pop es
	pop bx
	pop ax
	pop si
	ret

	
disk_error:
	mov si,	Read_Failed
	call puts
	jmp wait_for_reset



;
;Reads from disk
; Paramas:
;	- ax LBA adress
;	- cl number of sectors to read(up to 128), takes up the lowest 8 bits
;	- dl drive number
;	- es:bx memory adress to store data
;

disk_read:
	push ax
	push cx
	push di
	push cx				;save the number of sectors
	call .lba_to_chs		;compute CHS
	pop ax				;get the number of sectors to al

	mov ah, 02h		;set the operation to do

	mov di, 3		;times to retry

.retry:
	pusha
	stc

	int 13h
	jnc .done

	popa
	call .disk_reset

	dec di
	test di, di
	jnz .retry

.fail:
	jmp disk_error


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

.disk_reset:
	pusha
	mov ah, 0
	stc
	int 13h
	jc disk_error
	popa
	ret

;
;Converts a LBA adress to a CHS adress
; Params:
;	- ax LBA adress
;
; Returns: 
;	- cx [bits 0-5] sector number
;	- cx [bits 6-15] cylinder
;	- dh head
;
.lba_to_chs:

	push ax
	push dx

	xor dx, dx			;dx = 0
	div	word [BPB_SECTORS_PER_TRACK]		;ax = head = LBA / BPB_SECTORS_PER_TRACK, dx = sector = LBA % BPB_SECTORS_PER_TRACK + 1
		
	inc dx
	mov cx, dx

	xor dx, dx			;dx = 0

	div word [BPB_HEADS]					;ax = (LBA / BPB_SECTORS_PER_TRACK) / BPB_HEADS, dx = (LBA/BPB_SECTORS_PER_TRACK) % BPB_HEADS

	mov dh, dl			;dh = dl = (LBA/BPB_SECTORS_PER_TRACK) % BPB_HEADS
	mov ch, al			;move lowest 8 bits of ax into ch
	shl ah, 6			;get the 2 upper bits of ax
	or cl, ah			;move 

	pop ax
	mov dl, al
	pop ax
	ret



;prints a string
; Params:
;	-si pointer to string to read
;
puts:
	;save regsiters which are going to be modified
	push si
	push ax

.loop:
	lodsb				;load into al
	or al, al			;check if next char is null
	jz .done

	;call bios interupt
	mov ah, 0x0E
	mov bh, 0
	INT 0x10
	
	jmp .loop

;return fromputs
.done:
	pop ax 
	pop si
	ret

buffer_seg equ 0x2000
STAGE2: db 'STAGE2  BIN'
root_LBA: dw 0
root_size: dw 0
loadmsg: db 'loading stage 2', ENDL, 0
Kernel_no: db 'stage2 not found', ENDL, 0
Read_Failed:db 'Cant read disk', ENDL, 0
Kernel_cluster: dw 0
times 510-($-$$) db 0
dw 0AA55h


second_stage_start:

