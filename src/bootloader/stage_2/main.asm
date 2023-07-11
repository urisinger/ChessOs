
[bits 16]


start:

	;print loading msg
	mov si, loading
	call puts16

	

	cli
	lgdt [GDT_Descriptor]
	mov eax, cr0
	or eax, 1
	mov cr0, eax
	
	jmp CODE_SEG:protected_main


;prints a string
puts16:
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

;return from puts
.done:
	pop ax 
	pop si
	ret

[bits 32]
protected_main:
	hlt
	mov al, 'B'
	mov ah, 0x0f
	
	mov [videomem], ax

	hlt

.halt:
	jmp .halt
	

%define ENDL 0x0D, 0x0A
videomem equ 0xb8000
loading: db 'Stage 2 found, loading kernel', ENDL, 0

GDT_Start:
	null_descriptor:
		dd 0 
		dd 0
	kernel_code_descriptor:
		dw 0xffff  ;first 16 bits of limit = 0xfffff
		dw 0	;first 24 bits of base = 0
		db 0
		db 10011010b	;prsense, privlge,type props
		db 11001111b	;other flags(first 4 bits) + limit(last 4 bits)
	kernel_data_descriptor:
		dw 0xffff  ;first 16 bits of limit = 0xfffff
		dw 0	;first 24 bits of base = 0
		db 0
		db 10010010b	;prsense, privlge,type props
		db 11001111b	;other flags(first 4 bits) + limit(last 4 bits)
GDT_End:

GDT_Descriptor;
	dw GDT_End - GDT_Start - 1	;size
	dd GDT_Start	;start

CODE_SEG equ kernel_code_descriptor - GDT_Start
DATA_SEG equ kernel_data_descriptor - GDT_Start
