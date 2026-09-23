global _start

section .data

pos: db 27, "[00;00H"
clear: db 27, "\e[2J"

section .text

_start:
	mov eax, 1
	














goto:
	mov bl, 10
	mov eax, edi
	div bl
	add ax, 0x3030
	mov [rel pos+2], ax
	mov eax, esi
	div bl
	add ax, 0x3030
	mov [erl pos+5], ax
	mov eax, 1
	mov edi, 1
	lea rsi, [rel pos]
	mov edx, 8
	syscall
	ret





















