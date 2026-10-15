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
        MENU_TOP equ 10                ; строка первого пункта меню
        MENU_COL equ 26                ; столбец курсора меню
        MENU_VAL equ 40                ; столбец значения пункта
        MENU_ITEMS equ 3               ; сколько пунктов в меню

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

; --- меню ---
title_txt:
        db "P O N G"
        title_len equ $-title_txt
help1:
        db "W/S - выбор   A/D - изменить"
        help1_len equ $-help1
help2:
        db "Enter - старт   Q - выход"
        help2_len equ $-help2
gt:
        db ">"
lt_sp:
        db "< "
tail:
        db " >          "              ; хвост пробелов стирает прошлое значение
        tail_len equ $-tail
lbl_mode:
        db "Режим:"
        lbl_mode_len equ $-lbl_mode
lbl_speed:
        db "Скорость:"
        lbl_speed_len equ $-lbl_speed
lbl_win:
        db "До очков:"
        lbl_win_len equ $-lbl_win
m_two:
        db "Вдвоём"
        m_two_len equ $-m_two
m_cpu:
        db "Компьютер"
        m_cpu_len equ $-m_cpu
s_slow:
        db "Медленно"
        s_slow_len equ $-s_slow
s_norm:
        db "Нормально"
        s_norm_len equ $-s_norm
s_fast:
        db "Быстро"
        s_fast_len equ $-s_fast
w_5:
        db "5"
w_10:
        db "10"
w_21:
        db "21"

; таблицы строк: пары (адрес, длина) по 16 байт
opt_lbl:
        dq lbl_mode, lbl_mode_len, lbl_speed, lbl_speed_len, lbl_win, lbl_win_len
mode_tab:
        dq m_two, m_two_len, m_cpu, m_cpu_len
speed_tab:
        dq s_slow, s_slow_len, s_norm, s_norm_len, s_fast, s_fast_len
win_tab:
        dq w_5, 1, w_10, 2, w_21, 2
opt_tabs:
        dq mode_tab, speed_tab, win_tab
opt_cnt:
        dd 2, 3, 3                     ; сколько значений у каждого пункта
opt_val:
        dd 0, 1, 1                     ; выбранные значения (по умолчанию)
speed_ns:
        dq 80000000, 50000000, 30000000 ; пауза кадра для каждой скорости
win_vals:
        dd 5, 10, 21
menu_row:
        dd 0                           ; пункт под курсором

; результат меню
game_mode:
        dd 0                           ; 0 = вдвоём, 1 = против компьютера
win_score:
        dd 10                          ; до скольких очков игра

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
bot_tick:
        resd 1                         ; бот ходит через кадр

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

        lea rsi, [hide]
        mov edx, hide_len
        call print

        call menu                      ; вернёт eax = 1, если нажали q
        test eax, eax
        jnz quit

        lea rsi, [clear]
        mov edx, clear_len
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
        cmp dword [game_mode], 1       ; против компьютера — правой ракеткой рулит бот
        jne .no_bot
        call bot
.no_bot:

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
        cmp dword [game_mode], 0       ; против бота стрелки не работают
        jne .not_down
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

; menu: стартовый экран. W/S (стрелки) — пункт, A/D (стрелки) — значение,
; Enter/пробел — старт. Пишет game_mode, win_score и скорость в ts
; возвращает eax = 1, если нажата q или Ctrl+C, иначе 0
menu:
        lea rsi, [clear]
        mov edx, clear_len
        call print
        mov edi, 6
        mov esi, (X - title_len) / 2 + 1
        lea r8, [title_txt]
        mov r9d, title_len
        call put
        mov edi, 18
        mov esi, (X - 28) / 2 + 1      ; 28 символов на экране (кириллица — 2 байта)
        lea r8, [help1]
        mov r9d, help1_len
        call put
        mov edi, 19
        mov esi, (X - 25) / 2 + 1
        lea r8, [help2]
        mov r9d, help2_len
        call put

        xor r12d, r12d                 ; подписи пунктов
.label:
        lea edi, [r12*2 + MENU_TOP]
        mov esi, MENU_COL + 2
        mov rax, r12
        shl rax, 4
        lea rcx, [opt_lbl]
        mov r8, [rcx + rax]
        mov r9d, [rcx + rax + 8]
        call put
        inc r12d
        cmp r12d, MENU_ITEMS
        jl .label

.draw:                                 ; курсор и значения
        xor r12d, r12d
.row:
        lea r8, [space]
        cmp r12d, [menu_row]
        jne .mark
        lea r8, [gt]
.mark:
        lea edi, [r12*2 + MENU_TOP]
        mov esi, MENU_COL
        mov r9d, 1
        call put
        lea edi, [r12*2 + MENU_TOP]
        mov esi, MENU_VAL
        lea r8, [lt_sp]
        mov r9d, 2
        call put
        lea rax, [opt_tabs]
        mov rax, [rax + r12*8]         ; таблица строк этого пункта
        lea rcx, [opt_val]
        mov ecx, [rcx + r12*4]         ; выбранное значение
        shl ecx, 4
        mov rsi, [rax + rcx]
        mov edx, [rax + rcx + 8]
        call print
        lea rsi, [tail]
        mov edx, tail_len
        call print
        inc r12d
        cmp r12d, MENU_ITEMS
        jl .row

.wait:
        xor eax, eax                   ; read(0, keys, 16)
        xor edi, edi
        lea rsi, [keys]
        mov edx, 16
        syscall
        test eax, eax
        jg .got
        mov eax, 35                    ; ничего не нажато — подождать
        lea rdi, [ts]
        xor esi, esi
        syscall
        jmp .wait
.got:
        mov r14d, eax                  ; сколько байт прочитали
        xor r13d, r13d
        lea r15, [keys]
.key:
        movzx eax, byte [r15+r13]
        cmp al, 'q'
        je .quit
        cmp al, 3                      ; Ctrl+C
        je .quit
        cmp al, 10                     ; Enter
        je .start
        cmp al, 13
        je .start
        cmp al, ' '
        je .start
        cmp al, 'w'
        je .up
        cmp al, 'A'                    ; стрелка вверх
        je .up
        cmp al, 's'
        je .down
        cmp al, 'B'                    ; стрелка вниз
        je .down
        cmp al, 'a'
        je .left
        cmp al, 'D'                    ; стрелка влево
        je .left
        cmp al, 'd'
        je .right
        cmp al, 'C'                    ; стрелка вправо
        je .right
.next:
        inc r13d
        cmp r13d, r14d
        jl .key
        jmp .draw
.up:
        dec dword [menu_row]
        jns .next
        mov dword [menu_row], MENU_ITEMS - 1
        jmp .next
.down:
        inc dword [menu_row]
        cmp dword [menu_row], MENU_ITEMS
        jl .next
        mov dword [menu_row], 0
        jmp .next
.left:
        mov ecx, [menu_row]
        lea rdx, [opt_val]
        dec dword [rdx + rcx*4]
        jns .next
        lea rax, [opt_cnt]
        mov eax, [rax + rcx*4]         ; по кругу: на последнее значение
        dec eax
        mov [rdx + rcx*4], eax
        jmp .next
.right:
        mov ecx, [menu_row]
        lea rdx, [opt_val]
        mov eax, [rdx + rcx*4]
        inc eax
        lea rsi, [opt_cnt]
        cmp eax, [rsi + rcx*4]
        jl .store
        xor eax, eax                   ; по кругу: на первое значение
.store:
        mov [rdx + rcx*4], eax
        jmp .next

.start:
        mov eax, [opt_val]             ; режим
        mov [game_mode], eax
        mov eax, [opt_val+4]           ; скорость -> пауза кадра
        lea rdx, [speed_ns]
        mov rax, [rdx + rax*8]
        mov [ts+8], rax
        mov eax, [opt_val+8]           ; до скольких очков
        lea rdx, [win_vals]
        mov eax, [rdx + rax*4]
        mov [win_score], eax
        xor eax, eax
        ret
.quit:
        mov eax, 1
        ret

; bot: двигает правую ракетку к мячу, пока он летит к ней,
; иначе возвращает в центр. Ходит раз в два кадра — чтобы можно было обыграть
bot:
        xor dword [bot_tick], 1
        jz .done                       ; чётный кадр — пропускаем
        mov eax, [ball_y]
        cmp dword [ball_dx], 0
        jg .chase
        mov eax, Y / 2                 ; мяч улетает — к центру
.chase:
        sub eax, PADDLE / 2            ; цель: мяч напротив середины ракетки
        cmp eax, [paddle_r]
        je .done
        jl .up
        inc dword [paddle_r]
        jmp .clamp
.up:
        dec dword [paddle_r]
.clamp:
        lea rbp, [paddle_r]
        call clamp
.done:
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

; arena_y вертикальная линия, r13d = номер столбца
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
