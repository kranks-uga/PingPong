        default rel
        global _start

        X equ 80                       ; ширина поля
        Y equ 24                       ; высота поля
        PADDLE equ 5                   ; длина ракетки
        PADDLE_L_X equ 2               ; столбец левой ракетки
        PADDLE_R_X equ X - 1           ; столбец правой ракетки
        ISIG equ 1                     ; флаг: Ctrl+C убивает программу
        ICANON equ 2                   ; флаг: построчный ввод (ждать Enter)
        ECHO equ 8                     ; флаг: печатать нажатые клавиши
        VTIME equ 5                    ; индекс в c_cc: таймаут чтения
        VMIN equ 6                     ; индекс в c_cc: минимум байт для read
        TCGETS equ 0x5401              ; ioctl: прочитать настройки терминала
        TCSETS equ 0x5402              ; ioctl: записать настройки терминала

        section .data
pos:
        db 27, "[00;00H"
clear:
        db 27, "[2J"
        clear_len equ $-clear
hide:
        db 27, "[?25l"
        hide_len equ $-hide
show:
        db 27, "[?25h"
        show_len equ $-show
block:
        db 0xE2, 0x96, 0x88            ; █
        block_len equ $-block
h_line:
        db 0xE2, 0x94, 0x80            ; ─
v_line:
        db 0xE2, 0x94, 0x82            ; │
c_tl:
        db 0xE2, 0x94, 0x8C            ; ┌
c_tr:
        db 0xE2, 0x94, 0x90            ; ┐
c_bl:
        db 0xE2, 0x94, 0x94            ; └
c_br:
        db 0xE2, 0x94, 0x98            ; ┘
space:
        db " "
        BOX_LEN equ 3                  ; длина для всех UTF-8

ball_x:
        dd 40
ball_y:
        dd 12
ball_dx:
        dd 1
ball_dy:
        dd 1
paddle_l:
        dd 10                          ; верхняя клетка левой ракетки
paddle_r:
        dd 10                          ; верхняя клетка правой ракетки
score_l:
        dd 0
score_r:
        dd 0
score_txt:
        db " 00 : 00 "
        score_len equ $-score_txt
ts:
        dq 0, 50000000

        section .bss                   ; неинициализированные данные (нули)
orig:
        resb 36                        ; исходные настройки терминала
raw:
        resb 36                        ; наши «сырые» настройки
keys:
        resb 16                        ; буфер для нажатых клавиш
old_l:
        resd 1                         ; позиции ракеток до ввода
old_r:
        resd 1
prev_y:
        resd 1                         ; строка мяча до хода

        section .text
_start:
; --- сохранить настройки терминала ---
        mov eax, 16                    ; ioctl(0, TCGETS, &orig)
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
        and dword [raw+12], ~(ICANON | ECHO | ISIG) ; c_lflag лежит по смещению 12
        mov byte [raw+17+VMIN], 0      ; c_cc начинается со смещения 17
        mov byte [raw+17+VTIME], 0
        mov eax, 16                    ; ioctl(0, TCSETS, &raw)
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

        mov r13d, 1                    ; нижний
        call arena_x
        mov r13d, Y                    ; верхний
        call arena_x

        mov r13d, 1
        call arena_y
        mov r13d, X
        call arena_y

        mov edi, 1                     ; верхний левый угол
        mov esi, 1
        lea r8, [c_tl]
        mov r9d, BOX_LEN
        call put

        mov edi, 1                     ; верхний правый угол
        mov esi, X
        lea r8, [c_tr]
        mov r9d, BOX_LEN
        call put

        mov edi, Y                     ; нижний левый угол
        mov esi, 1
        lea r8, [c_bl]
        mov r9d, BOX_LEN
        call put

        mov edi, Y                     ; нижний правый угол
        mov esi, X
        lea r8, [c_br]
        mov r9d, BOX_LEN
        call put

        call draw_score

        lea r8, [block]
        mov r9d, block_len
        call draw_paddles

game_loop:
; 1. стереть старый мяч (ракетки не трогаем — иначе мигают)
        lea r8, [space]
        mov r9d, 1
        mov edi, [ball_y]
        mov esi, [ball_x]
        call put

; 2. ввод
        mov eax, [paddle_l]
        mov [old_l], eax
        mov eax, [paddle_r]
        mov [old_r], eax
        call handle_input              ; вернёт eax = 1, если нажали q
        test eax, eax
        jnz quit

; 3. движение мяча: сначала по вертикали (стенки)
        mov eax, [ball_y]
        mov [prev_y], eax
        add eax, [ball_dy]
        mov [ball_y], eax
        cmp eax, 2
        jle flip_y
        cmp eax, Y - 1
        jl y_ok
flip_y:
        neg dword [ball_dy]
y_ok:
; потом по горизонтали (ракетки)
        mov eax, [ball_x]
        add eax, [ball_dx]
        cmp eax, PADDLE_L_X
        je left_side
        cmp eax, PADDLE_R_X
        je right_side
        mov [ball_x], eax
        jmp moved
left_side:
        lea rbp, [paddle_l]
        call hit_paddle
        test eax, eax
        jz goal_right                  ; левый промахнулся
        jmp bounce
right_side:
        lea rbp, [paddle_r]
        call hit_paddle
        test eax, eax
        jz goal_left                   ; правый промахнулся
bounce:
        neg dword [ball_dx]            ; отскок от ракетки
        mov eax, [ball_dx]
        add [ball_x], eax
        jmp moved
goal_left:
        inc dword [score_l]
        jmp serve
goal_right:
        inc dword [score_r]
serve:                                 ; мяч в центр, летит к проигравшему
        mov dword [ball_x], X / 2
        mov dword [ball_y], Y / 2
        call draw_score
moved:

; 4. нарисовать новое
        lea rbp, [paddle_l]
        mov r14d, PADDLE_L_X
        mov r15d, [old_l]
        call update_paddle
        lea rbp, [paddle_r]
        mov r14d, PADDLE_R_X
        mov r15d, [old_r]
        call update_paddle
        lea r8, [block]
        mov r9d, block_len
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
        mov eax, 16                    ; вернуть терминал как был
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

; handle_input: читает все нажатые клавиши, двигает ракетки
; левая: w/s, правая: стрелки (приходят как ESC [ A / ESC [ B)
; возвращает eax = 1, если нажата q или Ctrl+C, иначе 0
handle_input:
        xor eax, eax                   ; read(0, keys, 16)
        xor edi, edi
        lea rsi, [keys]
        mov edx, 16
        syscall
        test eax, eax                  ; 0 = ничего не нажато
        jle .clamp
        mov r14d, eax                  ; сколько байт прочитали
        xor r13d, r13d                 ; индекс текущей клавиши
        lea r15, [keys]
.next:
        movzx eax, byte [r15+r13]
        cmp al, 'q'
        je .quit
        cmp al, 3                      ; Ctrl+C
        je .quit
        cmp al, 'w'
        jne .not_w
        dec dword [paddle_l]
.not_w:
        cmp al, 's'
        jne .not_s
        inc dword [paddle_l]
.not_s:
        cmp al, 'A'                    ; стрелка вверх
        jne .not_up
        dec dword [paddle_r]
.not_up:
        cmp al, 'B'                    ; стрелка вниз
        jne .not_down
        inc dword [paddle_r]
.not_down:
        inc r13d
        cmp r13d, r14d
        jl .next
.clamp:
        lea rbp, [paddle_l]
        call clamp
        lea rbp, [paddle_r]
        call clamp
        xor eax, eax
        ret
.quit:
        mov eax, 1
        ret

; clamp: не выпускать ракетку [rbp] за поле
clamp:
        cmp dword [rbp], 2
        jge .top_ok
        mov dword [rbp], 2
.top_ok:
        cmp dword [rbp], Y - PADDLE
        jle .done
        mov dword [rbp], Y - PADDLE
.done:
        ret

; hit_paddle: rbp = ракетка; eax = 1, если мяч на её высоте
; до или после хода — иначе удар краем ракетки по диагонали считается голом
hit_paddle:
        mov eax, [ball_y]
        sub eax, [rbp]                 ; 0..PADDLE-1 = попал
        cmp eax, PADDLE                ; беззнаково: отрицательные тоже мимо
        jb .hit
        mov eax, [prev_y]
        sub eax, [rbp]
        cmp eax, PADDLE
        jb .hit
        xor eax, eax
        ret
.hit:
        mov eax, 1
        ret

; draw_score: рисует счёт поверх верхней стенки
draw_score:
        mov bl, 10
        mov eax, [score_l]
        div bl
        add ax, 0x3030
        mov [score_txt+1], ax
        mov eax, [score_r]
        div bl
        add ax, 0x3030
        mov [score_txt+6], ax
        mov edi, 1
        mov esi, (X - score_len) / 2 + 1
        lea r8, [score_txt]
        mov r9d, score_len
        call put
        ret

; update_paddle: rbp = ракетка, r14d = столбец, r15d = старая верхняя клетка
; если ракетка сдвинулась — стирает только освободившиеся клетки и рисует новую
update_paddle:
        mov eax, [rbp]
        cmp eax, r15d
        je .done                       ; не двигалась — ничего не рисуем
        lea r8, [space]
        mov r9d, 1
        xor r12d, r12d
.erase:
        mov edi, r15d
        add edi, r12d                  ; клетка старой ракетки
        mov eax, edi
        sub eax, [rbp]
        cmp eax, PADDLE                ; входит в новую ракетку?
        jb .keep
        mov esi, r14d
        call put
.keep:
        inc r12d
        cmp r12d, PADDLE
        jl .erase
        lea r8, [block]
        mov r9d, block_len
        call draw_paddle
.done:
        ret

; draw_paddles: рисует обе ракетки строкой r8 длины r9d
draw_paddles:
        lea rbp, [paddle_l]
        mov r14d, PADDLE_L_X
        call draw_paddle
        lea rbp, [paddle_r]
        mov r14d, PADDLE_R_X
        call draw_paddle
        ret

; draw_paddle: rbp = ракетка, r14d = столбец, r8/r9d = что рисовать
draw_paddle:
        xor r12d, r12d
.loop:
        mov edi, [rbp]
        add edi, r12d
        mov esi, r14d
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

; arena_x: горизонтальная линия, r13d = номер строки
arena_x:
        mov r12d, 1                    ; начинаем с первого столбца
.loop:
        cmp r12d, X
        jg .done
        mov edi, r13d                  ; строка: из аргумента
        mov esi, r12d                  ; столбец: текущий
        lea r8, [h_line]
        mov r9d, BOX_LEN
        call put
        inc r12d
        jmp .loop
.done:
        ret

arena_y:
        mov r12d, 1
.loop:
        cmp r12d, Y
        jg .done
        mov edi, r12d
        mov esi, r13d
        lea r8, [v_line]
        mov r9d, BOX_LEN
        call put
        inc r12d
        jmp .loop
.done:
        ret
