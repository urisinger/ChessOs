org 0x0



CODE_SEG equ kernel_code_descriptor - GDT_Start
DATA_SEG equ kernel_data_descriptor - GDT_Start
start:
	[bits 16]
	;print loading msg
	mov si, loading
	call puts16

	cli
	lgdt [GDT_Descriptor]
	mov eax, cr0
	or al, 1
	mov cr0, eax

	jmp CODE_SEG:protected_main


;prints a string
puts16:
	[bits 16]
	;save regsiters which are going to be modified

	push si
	push ax

.loop:
	[bits 16]
	lodsb				;load into al
	or al, al			;check if next char is null
	jz .done

	;call bios interupt
	mov ah, 0x0e
	mov bh, 0
	int 0x10
	
	jmp .loop

;return from puts
.done:
	[bits 16]
	pop ax 
	pop si
	ret


protected_main:
	[bits 32]
	
	hlt
	hlt
	mov ax, DATA_SEG
	mov ds, ax
	mov ss, ax

	;print something to test
	mov ax, videomem
	mov es, ax
	mov bx,0

	mov al, 'A'
	mov ah, 0x0f
	
	mov [es:bx], ax


	hlt

.halt:
	jmp .halt
	
[bits 16]
%define ENDL 0x0D, 0x0A
videomem equ 0xb800
loading: db 'Stage 2 found, loading kernel', ENDL, 0

GDT_Start:
	null_descriptor:
		dd 0x0 
		dd 0x0
	kernel_code_descriptor:
		dw 0xffff  ;first 16 bits of limit = 0xfffff
		dw 0x0000	;first 24 bits of base = 0
		db 0x0
		db 10011010b	;prsense, privlge,type props
		db 11001111b	;other flags(first 4 bits) + limit(last 4 bits)
		db 0x0
	kernel_data_descriptor:
		dw 0xffff  ;first 16 bits of limit = 0xfffff
		dw 0x0000	;first 24 bits of base = 0
		db 0x0
		db 10010010b	;prsense, privlge,type props
		db 11001111b	;other flags(first 4 bits) + limit(last 4 bits)
		db 0x0
GDT_End:

GDT_Descriptor;
	dw GDT_End - GDT_Start - 1	;size
	dd GDT_Start	;start

