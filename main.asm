default rel
global _start

W       equ 80            ; ширина поля
H       equ 24            ; высота поля
PADDLE  equ 5             ; длина ракетки
ICANON  equ 2             ; флаг: построчный ввод (ждать Enter)
ECHO    equ 8             ; флаг: печатать нажатые клавиши
VTIME   equ 5             ; индекс в c_cc: таймаут чтения
VMIN    equ 6             ; индекс в c_cc: минимум байт для read
TCGETS  equ 0x5401        ; ioctl: прочитать настройки терминала
TCSETS  equ 0x5402        ; ioctl: записать настройки терминала

section .data
pos:     db 27, "[00;00H"
clear:   db 27, "[2J"
clear_len equ $-clear
hide:    db 27, "[?25l"
hide_len equ $-hide
show:    db 27, "[?25h"
show_len equ $-show
block:   db 0xE2, 0x96, 0x88   ; █
block_len equ $-block
h_line:  db 0xE2, 0x94, 0x80   ; ─
v_line:  db 0xE2, 0x94, 0x82   ; │
c_tl:    db 0xE2, 0x94, 0x8C   ; ┌
c_tr:    db 0xE2, 0x94, 0x90   ; ┐
c_bl:    db 0xE2, 0x94, 0x94   ; └
c_br:    db 0xE2, 0x94, 0x98   ; ┘
space:   db " "
BOX_LEN equ 3                  ; длина для всех UTF-8

ball_x:   dd 40
ball_y:   dd 12
ball_dx:  dd 1
ball_dy:  dd 1
paddle_y: dd 13           ; верхняя клетка ракетки
ts:       dq 0, 50000000

section .bss               ; неинициализированные данные (нули)
orig:  resb 36             ; исходные настройки терминала
raw:   resb 36             ; наши «сырые» настройки
keys:  resb 16             ; буфер для нажатых клавиш

section .text
_start:
	; --- сохранить настройки терминала ---
	mov eax, 16               ; ioctl(0, TCGETS, &orig)
	xor edi, edi
	mov esi, TCGETS
	lea rdx, [orig]
	syscall

	; --- скопировать orig -> raw ---
	lea rsi, [orig]
	lea rdi, [raw]
	mov ecx, 36
	rep movsb

	; --- включить «сырой» режим ---
	and dword [raw+12], ~(ICANON | ECHO)   ; c_lflag лежит по смещению 12
	mov byte [raw+17+VMIN], 0              ; c_cc начинается со смещения 17
	mov byte [raw+17+VTIME], 0
	mov eax, 16               ; ioctl(0, TCSETS, &raw)
	xor edi, edi
	mov esi, TCSETS
	lea rdx, [raw]
	syscall

	lea rsi, [clear]
	mov edx, clear_len
	call print
	lea rsi, [hide]
	mov edx, hide_len
	call print

	mov r12d, 1              ; текущий столбец
arena_w_low:
	cmp r12d, W
	jg arena_w_low_done
	mov edi, H               ; строка: нижняя
	mov esi, r12d            ; столбец: текущий
	lea r8, [h_line]
	mov r9d, BOX_LEN
	call put
	inc r12d
	jmp arena_w_low
arena_w_low_done:



game_loop:
	; 1. стереть старое
	lea r8, [space]
	mov r9d, 1
	call draw_paddle
	mov edi, [ball_y]
	mov esi, [ball_x]
	call put

	; 2. ввод
	call handle_input         ; вернёт eax = 1, если нажали q
	test eax, eax
	jnz quit

	; 3. движение мяча
	mov eax, [ball_x]
	add eax, [ball_dx]
	mov [ball_x], eax
	cmp eax, 2
	jle flip_x
	cmp eax, W - 1
	jl x_ok
flip_x:
	neg dword [ball_dx]
x_ok:
	mov eax, [ball_y]
	add eax, [ball_dy]
	mov [ball_y], eax
	cmp eax, 2
	jle flip_y
	cmp eax, H - 1
	jl y_ok
flip_y:
	neg dword [ball_dy]
y_ok:

	; 4. нарисовать новое
	lea r8, [block]
	mov r9d, block_len
	call draw_paddle
	mov edi, [ball_y]
	mov esi, [ball_x]
	call put

	; 5. пауза
	mov eax, 35
	lea rdi, [ts]
	xor esi, esi
	syscall
	jmp game_loop

quit:
	mov eax, 16               ; вернуть терминал как был
	xor edi, edi
	mov esi, TCSETS
	lea rdx, [orig]
	syscall
	lea rsi, [clear]
	mov edx, clear_len
	call print
	lea rsi, [show]
	mov edx, show_len
	call print
	mov eax, 60
	xor edi, edi
	syscall

; handle_input: читает все нажатые клавиши, двигает ракетку
; возвращает eax = 1, если нажата q, иначе 0``
handle_input:
	xor eax, eax              ; read(0, keys, 16)
	xor edi, edi
	lea rsi, [keys]
	mov edx, 16
	syscall
	test eax, eax             ; 0 = ничего не нажато
	jle .clamp
	mov r14d, eax             ; сколько байт прочитали
	xor r13d, r13d            ; индекс текущей клавиши
	lea r15, [keys]
.next:
	movzx eax, byte [r15+r13]
	cmp al, 'q'
	je .quit
	cmp al, 'w'
	jne .not_w
	dec dword [paddle_y]
.not_w:
	cmp al, 's'
	jne .not_s
	inc dword [paddle_y]
.not_s:
	inc r13d
	cmp r13d, r14d
	jl .next
.clamp:                        ; не выпускать ракетку за поле
	cmp dword [paddle_y], 2
	jge .top_ok
	mov dword [paddle_y], 2
.top_ok:
	cmp dword [paddle_y], H - PADDLE
	jle .done
	mov dword [paddle_y], H - PADDLE
.done:
	xor eax, eax
	ret
.quit:
	mov eax, 1
	ret

; draw_paddle: рисует ракетку строкой r8 длины r9d
draw_paddle:
	xor r12d, r12d
.loop:
	mov edi, [paddle_y]
	add edi, r12d
	mov esi, 2
	call put
	inc r12d
	cmp r12d, PADDLE
	jl .loop
	ret

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