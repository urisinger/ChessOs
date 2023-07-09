org 0x7C00
bits 16


%define ENDL 0x0D, 0x0A

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

	;print string
	mov si, helloWorld
	call puts

	hlt

.halt:
	jmp .halt

helloWorld: db 'Hello World!', ENDL, 0


times 510-($-$$) db 0
dw 0AA55h
