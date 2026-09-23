default rel
global _start

W equ 80                  ; ширина поля
H equ 24                  ; высота поля

section .data
pos:     db 27, "[00;00H"
clear:   db 27, "[2J"
clear_len equ $-clear
hide:    db 27, "[?25l"   ; спрятать курсор
hide_len equ $-hide
show:    db 27, "[?25h"   ; показать курсор
show_len equ $-show
ball:    db 0xE2, 0x96, 0x88
ball_len equ $-ball
space:   db " "

ball_x:  dd 40
ball_y:  dd 12
ball_dx: dd 1
ball_dy: dd 1
ts:      dq 0, 50000000   ; 0 с + 50 000 000 нс = 50 мс

section .text
_start:
	lea rsi, [clear]
	mov edx, clear_len
	call print
	lea rsi, [hide]
	mov edx, hide_len
	call print

	mov r12d, 300             ; кадров до выхода
game_loop:
	; 1. стереть мяч на старом месте
	mov edi, [ball_y]
	mov esi, [ball_x]
	lea r8, [space]
	mov r9d, 1
	call put

	; 2. сдвинуть по x, отскок от левой/правой стены
	mov eax, [ball_x]
	add eax, [ball_dx]
	mov [ball_x], eax
	cmp eax, 1
	jle flip_x
	cmp eax, W
	jl x_ok
flip_x:
	neg dword [ball_dx]
x_ok:
	; 3. то же по y
	mov eax, [ball_y]
	add eax, [ball_dy]
	mov [ball_y], eax
	cmp eax, 1
	jle flip_y
	cmp eax, H
	jl y_ok
flip_y:
	neg dword [ball_dy]
y_ok:
	; 4. нарисовать мяч
	mov edi, [ball_y]
	mov esi, [ball_x]
	lea r8, [ball]
	mov r9d, ball_len
	call put

	; 5. пауза
	mov eax, 35               ; nanosleep(&ts, NULL)
	lea rdi, [ts]
	xor esi, esi
	syscall

	dec r12d
	jnz game_loop

	lea rsi, [show]
	mov edx, show_len
	call print
	mov eax, 60
	xor edi, edi
	syscall

; print: rsi = адрес, edx = длина
print:
	mov eax, 1
	mov edi, 1
	syscall
	ret

; put: edi = строка, esi = столбец, r8 = адрес, r9d = длина
put:
	call goto
	mov rsi, r8
	mov edx, r9d
	call print
	ret

; goto: edi = строка, esi = столбец (1..99)
goto:
	mov bl, 10
	mov eax, edi
	div bl
	add ax, 0x3030
	mov [pos+2], ax
	mov eax, esi
	div bl
	add ax, 0x3030
	mov [pos+5], ax
	lea rsi, [pos]
	mov edx, 8
	call print
	ret