org 0x7e00 


second_stage_start:
	[bits 16]
	
	mov ah, 0
	int 10h

	cli
	call setGdt
	mov eax, cr0
	or ax, 1
	mov cr0, eax

	jmp 08h:protected_main

gdtr: dw 0 ; For limit storage
     dd 0 ; For base storage
 
setGdt:
   xor eax, eax
   mov ax, ds
   shl eax, 4
   add eax, GDT_START
   mov [gdtr + 2], eax
   mov eax, GDT_END
   sub eax, GDT_START
   mov [gdtr], ax
   lgdt [gdtr]
   ret


GDT_START:
	dq 0

	dw 0FFFFh
	dw 0x0000
	db 0
	db 10011010b
	db 11001111b
	db 0

	dw 0FFFFh
	dw 0x0000
	db 0
	db 10010010b
	db 11001111b
	db 0
GDT_END:

protected_main:
	[bits 32]
	
	mov ax, 010h
	mov ds, ax
	mov ss, ax
	
	;print something to test

	mov ah, 0x0a
	mov esi, loading
	call puts32

	hlt	

;prints a string
; Params:
;	- ds:esi pointer to start of string
;	- ah color of text

puts32:
	[bits 32]
	;save regsiters which are going to be modified
	push esi
	push eax
	push ebx

	mov ebx, 0xb8000

.loop:
	lodsb	;load into al
	or al, al			;check if next char is null
	jz .done

	;call bios interupt

	mov [ebx], ax

	add ebx, 2

	jmp .loop

;return fromputs
.done:
	pop ebx
	pop eax
	pop esi
	ret
	

	
%define ENDL 0x0D, 0x0A
loading: db 'stage 2 was found, entering protected mode', ENDL,0
videomem: equ 0xb8000

