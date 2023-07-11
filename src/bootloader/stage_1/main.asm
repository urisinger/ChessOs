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
BPB_SECTORS_PER_CLUSTER: db 2
BPB_RESERVED_SECTORS: dw 1
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
EBR_VOL_LABEL: db 'CHESS OS   '
EBR_SYS_ID: db 'FAT12   '


KERNEL_LOAD_SEGMENT equ 0x2000
KERNEL_LOAD_OFFSET equ 0


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

	;print starting message
	mov si, loadmsg
	call puts
	
	
	;find root dir LBA = reseerved + num_fats * sectors_per_fat
	mov ax, [BPB_SECTORS_PER_FAT]		;compute the lba of the root dir
	mov bl, [BPB_FILE_ALLOCATION_COUNT] 
	xor bh, bh
	mul bx
	add ax, [BPB_RESERVED_SECTORS]

	mov [root_LBA], ax		; save the LBA of start of root

	;compute size of root dir = (32 * root_dir_entries) / bytes_per_sector
	mov ax, [BPB_DIR_ENTRIES_COUNT]
	shl ax, 5			;ax *= 32
	xor dx, dx          ;dx = 0
	div word [BPB_BYTES_PER_SECTOR]  ;ax =  (32 * root_dir_entries) / bytes_per_sector, dx = (32 * root_dir_entries) % bytes_per_sector
		
	test dx, dx
	jz .root_dir_after
	

	inc ax
	jmp .root_dir_after

	

.root_dir_after:
	; save the size of root
	mov [root_size], ax

	;read root dir
	mov cl, al		;cl = number of sectors to read
	mov ax, [root_LBA]		;ax = LBA of root
	mov dl, [EBR_DRIVE_NUMBER]		;dl = drive number
	mov bx, buffer			;es:bx = buffer to write to
	
	call disk_read	;read from disk
	
	; find kernel.bin
	xor bx, bx
	mov di, buffer 
	jmp .search_kernel

.search_kernel:
	;find the kernel.bin file
	mov si, kernel.bin			;check if the current filename is equal to kernel.bin, if it is, go into .found_kernel
	mov cx, 11				
	push di
	repe cmpsb
	pop di
	je .found_kernel
	
	;check if search is over, if it is, throw a kenrel_not_found error
	add di, 32
	inc bx
	cmp bx, [BPB_DIR_ENTRIES_COUNT]
	jl .search_kernel

	jmp .kernel_not_found

		

.found_kernel:
	;get the kernel cluster adress to memory
	mov ax, [di+26]
	mov [Kernel_cluster], ax
	
	;load FAT from disk
	
	mov ax, [BPB_RESERVED_SECTORS]
	mov bx, buffer
	mov cl, [BPB_SECTORS_PER_FAT]
	mov dl, [EBR_DRIVE_NUMBER]

	call disk_read
	;load the kernel from disk
	mov bx, KERNEL_LOAD_SEGMENT
	mov es, bx
	mov bx, KERNEL_LOAD_OFFSET

	
.load_kernel_loop:

	;get kernel cluster
	mov ax, [Kernel_cluster]
	
	add ax, [root_LBA]			;add the root offset to the kernel cluster
	add ax, [root_size]
	sub ax, 2
	mov cl, 1
	mov dl, [EBR_DRIVE_NUMBER]

	call disk_read

	add bx, [BPB_BYTES_PER_SECTOR]

	mov ax, [Kernel_cluster]

	mov cx, 3
	mul cx
	mov cx, 2
	div cx
	
	mov si, buffer
	add si, ax
	
	mov ax, [ds:si]

	or dx, dx
	jz .even
		
.odd:

	shr ax, 4	
	jmp .next_cluster_after

.even:
	and ax, 0x0FFF

.next_cluster_after:
	
	cmp ax, 0x0FF8
	jae .read_finish

	mov [Kernel_cluster], ax
	jmp .load_kernel_loop

.read_finish:

	;jump to kernel
	mov dl, [EBR_DRIVE_NUMBER]		;restore dl register to drive boot device

	mov ax, KERNEL_LOAD_SEGMENT
	
	mov es, ax
	mov ds, ax

	
	jmp KERNEL_LOAD_SEGMENT:KERNEL_LOAD_OFFSET 



.kernel_not_found:
	mov si, Kernel_no
	call puts
	jmp wait_for_reset

floppy_error:
	mov si,	Read_Failed
	call puts
	jmp wait_for_reset



wait_for_reset:
	hlt
	mov ah, 0
	int 16h
	jmp _start


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

;return from47456 puts
.puts.done:
	pop ax 
	pop si
	ret


;
;Disk routines
;

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
lba_to_chs:

	push ax
	push dx

	xor dx, dx			;dx = 0
	div	word [BPB_SECTORS_PER_TRACK]		;ax = LBA / BPB_SECTORS_PER_TRACK, dx = LBA % BPB_SECTORS_PER_TRACK 
		
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
	test di, di
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



kernel.bin: db 'STAGE2  BIN'
root_LBA: dw 0
root_size: dw 0
loadmsg: db 'loading stage 2...', ENDL, 0
Kernel_no: db 'stage2 not found', ENDL, 0
Read_Failed:db 'Cant read disk', ENDL, 0
Kernel_cluster: dw 0
times 510-($-$$) db 0
dw 0AA55h



buffer:
