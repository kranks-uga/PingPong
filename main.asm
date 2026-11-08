        default rel
        global _start

        X equ 80                       ; ширина поля
        Y equ 24                       ; высота поля
        PADDLE equ 5                   ; длина ракетки в клетках
        PADDLE_H equ PADDLE * 2        ; длина ракетки в половинках клетки
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
        WIN_ROW equ 2                  ; пункт «До очков» — число, а не строка из таблицы
        BOT_SEE equ X - 22             ; с какого столбца бот следит за мячом
        KEY_UP equ 256                 ; коды стрелок от next_key
        KEY_DOWN equ 257
        KEY_RIGHT equ 258
        KEY_LEFT equ 259
        EV_TAP equ 0                   ; next_key: старый терминал, просто символ
        EV_RELEASE equ 3               ; next_key: кнопку отпустили

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
kb_on:                                 ; протокол клавиатуры kitty: присылать
        db 27, "[>15u"                 ; нажатие, повтор и отпускание каждой клавиши
        db 27, "[?u"                   ; плюс её код в US-раскладке (флаг 4),
                                       ; и спросить, поддерживается ли он
        kb_on_len equ $-kb_on
kb_off:
        db 27, "[<u"
        kb_off_len equ $-kb_off
block:
        db 0xE2, 0x96, 0x88            ; █
        block_len equ $-block
half_top:
        db 0xE2, 0x96, 0x80            ; ▀ — верхняя половина клетки
half_bottom:
        db 0xE2, 0x96, 0x84            ; ▄ — нижняя половина клетки
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
        dd (Y / 2 - PADDLE / 2) * 2    ; верхняя клетка левой ракетки (в половинках)
paddle_r:
        dd (Y / 2 - PADDLE / 2) * 2    ; верхняя клетка правой ракетки (в половинках)
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
; конец игры: (адрес, длина в байтах, длина на экране) по 16 байт
over_tab:
        dq won_l, won_l_len, 20
        dq won_r, won_r_len, 21
        dq won_you, won_you_len, 12
        dq won_cpu, won_cpu_len, 18
won_l:
        db "Победил левый игрок!"
        won_l_len equ $-won_l
won_r:
        db "Победил правый игрок!"
        won_r_len equ $-won_r
won_you:
        db "Вы победили!"
        won_you_len equ $-won_you
won_cpu:
        db "Победил компьютер!"
        won_cpu_len equ $-won_cpu
over_help:
        db "Enter - меню   Q - выход"
        over_help_len equ $-over_help
        OVER_HELP_W equ 24             ; символов на экране
win_txt:
        db "00"                        ; число очков для меню

; таблицы строк: пары (адрес, длина) по 16 байт
opt_lbl:
        dq lbl_mode, lbl_mode_len, lbl_speed, lbl_speed_len, lbl_win, lbl_win_len
mode_tab:
        dq m_two, m_two_len, m_cpu, m_cpu_len
speed_tab:
        dq s_slow, s_slow_len, s_norm, s_norm_len, s_fast, s_fast_len
opt_tabs:
        dq mode_tab, speed_tab, 0      ; у «До очков» таблицы нет — печатаем число
opt_min:
        dd 0, 0, 1                     ; наименьшее значение каждого пункта
opt_max:
        dd 1, 2, 99                    ; наибольшее значение каждого пункта
opt_val:
        dd 0, 1, 10                    ; выбранные значения (по умолчанию)
speed_ns:
        dq 40000000, 25000000, 15000000 ; половина паузы кадра: мяч ходит каждый второй кадр
angle_rel:
        dd -2, -2, -1, -1, 0, 0, 0, 1, 1, 2, 2 ; dy по положению мяча в ракетке
                                               ; (сдвиг мяча от центра в половинках: -5..5)
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
        resb 64                        ; буфер для нажатых клавиш
keys_len equ $-keys
held:
        resb 4                         ; зажаты ли: w, s, вверх, вниз
tap:
        resb 4                         ; нажаты в этом кадре (старый терминал)
kitty:
        resb 1                         ; 1 = терминал ответил на ESC [ ? u
csi_f:
        resd 5                         ; поля ESC-последовательности: код, модификаторы,
                                       ; событие, мусор, код в US-раскладке
old_l:
        resd 1                         ; позиции ракеток до ввода
old_r:
        resd 1
prev_y:
        resd 1                         ; строка мяча до хода
bot_aim:
        resd 1                         ; какой клеткой ракетки бот отобьёт мяч
ball_tick:
        resd 1                         ; мяч двигается через кадр (ракетки — каждый кадр)

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
        lea rsi, [kb_on]
        mov edx, kb_on_len
        call print

new_game:                              ; сюда же возвращаемся после конца партии
        xor eax, eax
        mov [score_l], eax
        mov [score_r], eax
        mov [held], eax                ; иначе ракетка поедет сама, если кнопку
        mov [tap], eax                 ; отпустили на экране конца игры
        mov dword [ball_x], X / 2
        mov dword [ball_y], Y / 2
        mov dword [ball_dx], 1
        mov dword [ball_dy], 1
        mov dword [paddle_l], (Y / 2 - PADDLE / 2) * 2
        mov dword [paddle_r], (Y / 2 - PADDLE / 2) * 2
        mov dword [ball_tick], 0

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

        call draw_paddles

game_loop:
; 1. ввод: ракетки двигаются каждый кадр, но на полклетки
        mov eax, [paddle_l]
        mov [old_l], eax
        mov eax, [paddle_r]
        mov [old_r], eax
        call handle_input              ; вернёт eax = 1, если нажали q
        test eax, eax
        jnz quit

; 2. мяч и бот — каждый второй кадр, чтобы ракетки двигались плавнее
        xor dword [ball_tick], 1
        jz ball_frame
        jmp draw_frame

ball_frame:
; стереть старый мяч (ракетки не трогаем — иначе мигают)
        lea r8, [space]
        mov r9d, 1
        mov edi, [ball_y]
        mov esi, [ball_x]
        call put

        cmp dword [game_mode], 1       ; против компьютера — правой ракеткой рулит бот
        jne no_bot_frame
        call bot
no_bot_frame:

; 3. движение мяча: сначала по вертикали (стенки)
        mov eax, [ball_y]
        mov [prev_y], eax
        add eax, [ball_dy]
        cmp eax, 2                     ; при dy = ±2 мяч может проскочить
        jle top_wall                   ; на рамку — прижимаем его к краю
        cmp eax, Y - 1
        jge bottom_wall
        jmp y_store
top_wall:
        mov eax, 2
        jmp flip_y
bottom_wall:
        mov eax, Y - 1
flip_y:
        neg dword [ball_dy]
y_store:
        mov [ball_y], eax
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
        call aim
        jmp bounce
right_side:
        lea rbp, [paddle_r]
        call hit_paddle
        test eax, eax
        jz goal_left                   ; правый промахнулся
        call aim
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
        rdtsc                          ; подача всегда пологая (dy = ±1) в случайную
        and eax, 2                     ; сторону: иначе крутой мяч, который бот
        dec eax                        ; пропустил, летит к нему снова тем же путём
        mov [ball_dy], eax             ; 0 -> -1, 2 -> 1
        call draw_score
        call game_over                 ; кто-то набрал нужный счёт?
        test eax, eax
        jg new_game                    ; 1 = Enter: в меню
        js quit                        ; -1 = q
moved:

draw_frame:
; 4. нарисовать ракетки
        lea rbp, [paddle_l]
        mov r14d, PADDLE_L_X
        mov r15d, [old_l]
        call update_paddle
        lea rbp, [paddle_r]
        mov r14d, PADDLE_R_X
        mov r15d, [old_r]
        call update_paddle

; мяч — только на своём кадре
        cmp dword [ball_tick], 0
        jne sleep_frame
        lea r8, [block]
        mov r9d, block_len
        mov edi, [ball_y]
        mov esi, [ball_x]
        call put

sleep_frame:
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
        lea rsi, [kb_off]
        mov edx, kb_off_len
        call print
        mov eax, 60
        xor edi, edi
        syscall

; handle_input: читает все события клавиатуры, двигает ракетки
; левая: w/s, правая: стрелки. Пока кнопка зажата, ракетка едет на полклетки
; за кадр; в старом терминале одно нажатие сдвигает её на целую клетку
; возвращает eax = 1, если нажата q или Ctrl+C, иначе 0
handle_input:
        xor eax, eax                   ; read(0, keys, keys_len)
        xor edi, edi
        lea rsi, [keys]
        mov edx, keys_len
        syscall
        test eax, eax                  ; 0 = ничего не нажато
        jle .move
        mov r14d, eax                  ; сколько байт прочитали
        xor r13d, r13d                 ; позиция в буфере
        lea r15, [keys]
.next:
        call next_key
        cmp eax, -1
        je .move
        cmp edx, EV_RELEASE
        je .slot
        cmp eax, 'q'
        je .quit
        cmp eax, 3                     ; Ctrl+C
        je .quit
.slot:
        xor ecx, ecx                   ; номер кнопки в held/tap
        cmp eax, 'w'
        je .found
        inc ecx
        cmp eax, 's'
        je .found
        inc ecx
        cmp eax, KEY_UP
        je .found
        inc ecx
        cmp eax, KEY_DOWN
        jne .next
.found:
        lea rsi, [tap]
        cmp edx, EV_TAP
        jne .event
        mov byte [rsi + rcx], 1        ; без отпусканий: сдвиг на одну клетку
        jmp .next
.event:
        lea rsi, [held]
        cmp edx, EV_RELEASE
        setne byte [rsi + rcx]         ; нажатие/повтор = 1, отпускание = 0
        jmp .next
.move:
        mov eax, [held]
        mov edx, [tap]
        mov dword [tap], 0
        test eax, eax                  ; в kitty-терминале кнопка зажата —
        jz .tap_step                   ; шаг полклетки за кадр
        mov ecx, 1
        jmp .step
.tap_step:
        mov ecx, 2                     ; старый терминал: целая клетка за нажатие
.step:
        or eax, edx                    ; по байту на кнопку
        test al, al
        jz .not_w
        sub dword [paddle_l], ecx
.not_w:
        test ah, ah
        jz .not_s
        add dword [paddle_l], ecx
.not_s:
        cmp dword [game_mode], 0       ; против бота стрелки не работают
        jne .clamp
        test eax, 0x10000
        jz .not_up
        sub dword [paddle_r], ecx
.not_up:
        test eax, 0x1000000
        jz .clamp
        add dword [paddle_r], ecx
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

; next_key: r15 = буфер, r13d = позиция (сдвигается), r14d = длина
; возвращает eax = клавиша (символ, 3 = Ctrl+C, KEY_* = стрелки, 0 = неизвестная,
; -1 = буфер кончился), edx = событие: 1 нажатие, 2 повтор, EV_RELEASE отпускание,
; EV_TAP — старый терминал без событий
; понимает обычные символы, ESC [ A..D и kitty-формат ESC [ код ; мод : событие u
next_key:
        cmp r13d, r14d
        jl .have
        mov eax, -1
        ret
.have:
        movzx eax, byte [r15 + r13]
        inc r13d
        mov edx, EV_TAP
        cmp eax, 27
        jne .ret                       ; обычный символ
        cmp r13d, r14d
        jge .ret                       ; одиночный ESC
        cmp byte [r15 + r13], '['
        jne .ret
        inc r13d
        xor eax, eax
        mov [csi_f], eax
        mov [csi_f + 4], eax
        mov [csi_f + 8], eax
        mov [csi_f + 16], eax
        xor ecx, ecx                   ; текущее поле
        xor esi, esi                   ; сколько было ';'
.byte:
        cmp r13d, r14d
        jge .unknown                   ; последовательность оборвалась
        movzx eax, byte [r15 + r13]
        inc r13d
        cmp eax, '0'
        jb .not_digit
        cmp eax, '9'
        ja .not_digit
        sub eax, '0'
        lea rdi, [csi_f]
        imul edx, [rdi + rcx*4], 10
        add edx, eax
        mov [rdi + rcx*4], edx
        jmp .byte
.not_digit:
        cmp eax, ';'
        jne .not_semi
        inc esi
        mov ecx, 3                     ; третье и дальше поле — в мусор
        cmp esi, 1
        jne .byte
        mov ecx, 1                     ; модификаторы
        jmp .byte
.not_semi:
        cmp eax, ':'
        jne .not_colon
        cmp ecx, 1
        je .ev_field
        test esi, esi
        jnz .junk                      ; ':' в дальнейших полях — мусор
        test ecx, ecx
        jz .junk                       ; код:shifted — shifted не нужен
        cmp ecx, 3
        jne .junk
        mov ecx, 4                     ; код:shifted:base — клавиша в US-раскладке
        jmp .byte
.junk:
        mov ecx, 3
        jmp .byte
.ev_field:
        mov ecx, 2                     ; ':' после модификаторов — тип события
        jmp .byte
.not_colon:
        cmp eax, '?'                   ; ESC [ ? флаги u — ответ kitty на запрос
        jne .not_query
        mov byte [kitty], 1
.not_query:
        cmp eax, 0x40                  ; финальный байт: 0x40..0x7E
        jb .byte                       ; '>' и прочее пропускаем
        mov edx, [csi_f + 8]           ; событие
        test edx, edx
        jnz .ev_ok
        movzx edx, byte [kitty]        ; не указано: в kitty это нажатие (1),
                                       ; в старом терминале — EV_TAP (0)
.ev_ok:
        cmp eax, 'u'
        je .unicode
        sub eax, 'A'
        cmp eax, 3
        ja .unknown
        add eax, KEY_UP                ; A..D -> вверх, вниз, вправо, влево
        ret
.unicode:
        mov eax, [csi_f + 16]          ; в русской раскладке «ц» придёт как
        test eax, eax                  ; ESC [ 1094 :: 119 u — берём 119 = 'w'
        jnz .base
        mov eax, [csi_f]
.base:
        mov ecx, [csi_f + 4]
        dec ecx
        js .ret                        ; модификаторы не указаны (ESC [ 119 u)
        test ecx, 4                    ; зажат Ctrl?
        jz .ret
        cmp eax, 'a'
        jb .ret
        cmp eax, 'z'
        ja .ret
        sub eax, 96                    ; Ctrl+буква -> управляющий символ (c -> 3)
.ret:
        ret
.unknown:
        xor eax, eax
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
        lea rcx, [opt_val]
        mov ecx, [rcx + r12*4]         ; выбранное значение
        cmp r12d, WIN_ROW
        je .number
        lea rax, [opt_tabs]
        mov rax, [rax + r12*8]         ; таблица строк этого пункта
        shl ecx, 4
        mov rsi, [rax + rcx]
        mov edx, [rax + rcx + 8]
        jmp .value
.number:                               ; 1..99 -> одна или две цифры
        mov eax, ecx
        mov cl, 10
        div cl                         ; al = десятки, ah = единицы
        add ax, 0x3030
        mov [win_txt], ax
        lea rsi, [win_txt]
        mov edx, 2
        cmp al, '0'
        jne .value
        inc rsi                        ; без ведущего нуля
        dec edx
.value:
        call print
        lea rsi, [tail]
        mov edx, tail_len
        call print
        inc r12d
        cmp r12d, MENU_ITEMS
        jl .row

.wait:
        xor eax, eax                   ; read(0, keys, keys_len)
        xor edi, edi
        lea rsi, [keys]
        mov edx, keys_len
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
.next:
        call next_key
        cmp eax, -1
        je .draw
        cmp edx, EV_RELEASE            ; в меню отпускания не нужны
        je .next
        cmp eax, 'q'
        je .quit
        cmp eax, 3                     ; Ctrl+C
        je .quit
        cmp eax, 10                    ; Enter
        je .start
        cmp eax, 13
        je .start
        cmp eax, ' '
        je .start
        cmp eax, 'w'
        je .up
        cmp eax, KEY_UP
        je .up
        cmp eax, 's'
        je .down
        cmp eax, KEY_DOWN
        je .down
        cmp eax, 'a'
        je .left
        cmp eax, KEY_LEFT
        je .left
        cmp eax, 'd'
        je .right
        cmp eax, KEY_RIGHT
        je .right
        jmp .next
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
        mov eax, [rdx + rcx*4]
        dec eax
        lea rsi, [opt_min]
        cmp eax, [rsi + rcx*4]
        jge .store
        lea rsi, [opt_max]
        mov eax, [rsi + rcx*4]         ; по кругу: на последнее значение
        jmp .store
.right:
        mov ecx, [menu_row]
        lea rdx, [opt_val]
        mov eax, [rdx + rcx*4]
        inc eax
        lea rsi, [opt_max]
        cmp eax, [rsi + rcx*4]
        jle .store
        lea rsi, [opt_min]
        mov eax, [rsi + rcx*4]         ; по кругу: на первое значение
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
        mov eax, [opt_val+8]           ; до скольких очков (1..99)
        mov [win_score], eax
        xor eax, eax
        ret
.quit:
        mov eax, 1
        ret

; bot: пока мяч летит к правой ракетке, прикидывает по прямой, где он её
; пересечёт, и подставляет под него случайную клетку ракетки;
; иначе возвращается в центр.
; Двигается каждый кадр мяча на полклетки и начинает «видеть» мяч только
; с BOT_SEE — чтобы можно было обыграть
bot:
        cmp dword [ball_dx], 0
        jg .coming
        rdtsc                          ; мяч улетает — выбрать клетку для
        xor edx, edx                   ; следующего удара (0..PADDLE-1),
        mov ecx, PADDLE                ; иначе бот всегда бьёт серединой
        div ecx                        ; и мяч летит по прямой
        mov [bot_aim], edx
        jmp .center
.coming:
        cmp dword [ball_x], BOT_SEE
        jge .predict
.center:
        mov eax, (Y / 2 - PADDLE / 2) * 2 ; мяч ещё далеко — ждать в центре
        jmp .chase
.predict:                              ; где мяч будет у ракетки, если лететь
        mov eax, PADDLE_R_X            ; по прямой: y + dy * (сколько осталось).
        sub eax, [ball_x]              ; Отскоки от стенок бот не учитывает —
        imul eax, [ball_dy]            ; крутой мяч от стенки его обманывает
        add eax, [ball_y]
        cmp eax, 2
        jge .top_ok
        mov eax, 2
.top_ok:
        cmp eax, Y - 1
        jle .bottom_ok
        mov eax, Y - 1
.bottom_ok:
        sub eax, [bot_aim]             ; цель: мяч напротив выбранной клетки
        shl eax, 1                     ; клетки -> половинки клетки
.chase:
        cmp eax, [paddle_r]            ; eax = нужный верх ракетки в половинках
        je .done
        jl .up
        add dword [paddle_r], 1        ; за ход — полклетки
        jmp .clamp
.up:
        sub dword [paddle_r], 1
.clamp:
        lea rbp, [paddle_r]
        call clamp
.done:
        ret

; clamp: не выпускать ракетку [rbp] за поле (позиция в половинках клетки)
clamp:
        cmp dword [rbp], 4
        jge .top_ok
        mov dword [rbp], 4
.top_ok:
        cmp dword [rbp], (Y - PADDLE) * 2
        jle .done
        mov dword [rbp], (Y - PADDLE) * 2
.done:
        ret

; hit_paddle: rbp = ракетка (позиция в половинках клетки); eax = 1, если мяч
; на её высоте до или после хода — иначе удар краем ракетки по диагонали
; считается голом
hit_paddle:
        mov eax, [rbp]
        shr eax, 1                     ; верхняя клетка ракетки
        mov ecx, [rbp]
        add ecx, PADDLE_H - 1
        shr ecx, 1                     ; нижняя клетка ракетки
        mov edx, [ball_y]
        cmp edx, eax
        jl .prev
        cmp edx, ecx
        jle .hit
.prev:
        mov edx, [prev_y]
        cmp edx, eax
        jl .miss
        cmp edx, ecx
        jg .miss
.hit:
        mov eax, 1
        ret
.miss:
        xor eax, eax
        ret

; aim: rbp = ракетка; dy зависит от того, где мяч попал в ракетку:
; центр — прямо, края — круто вверх/вниз
aim:
        mov eax, [ball_y]
        shl eax, 1                     ; верх мяча в половинках клетки
        sub eax, [rbp]                 ; сдвиг от верха ракетки
        sub eax, 4                     ; центр мяча минус центр ракетки (5)
        add eax, 5                     ; индекс 0..10 для сдвига -5..5
        jns .lo_ok
        xor eax, eax                   ; мяч ушёл выше — край ракетки
.lo_ok:
        cmp eax, 10
        jle .hi_ok
        mov eax, 10                    ; мяч ушёл ниже — край ракетки
.hi_ok:
        lea rcx, [angle_rel]
        mov eax, [rcx + rax*4]
        mov [ball_dy], eax
        ret

; game_over: если кто-то набрал win_score — пишет победителя и ждёт клавишу
; возвращает eax = 0, если играем дальше, 1 = в меню (Enter/пробел), -1 = выход (q)
game_over:
        mov eax, [win_score]
        xor ecx, ecx                   ; 0 = левый, 1 = правый
        cmp [score_l], eax
        jge .won
        inc ecx
        cmp [score_r], eax
        jge .won
        xor eax, eax
        ret
.won:
        cmp dword [game_mode], 1       ; против компьютера: «вы» / «компьютер»
        jne .text
        add ecx, 2
.text:
        lea rax, [over_tab]
        imul ecx, ecx, 24
        add rax, rcx
        mov r8, [rax]
        mov r9d, [rax + 8]
        mov ecx, [rax + 16]
        mov esi, X
        sub esi, ecx
        shr esi, 1
        inc esi                        ; по центру
        mov edi, Y / 2 - 1
        call put
        mov edi, Y / 2 + 1
        mov esi, (X - OVER_HELP_W) / 2 + 1
        lea r8, [over_help]
        mov r9d, over_help_len
        call put
.wait:
        xor eax, eax                   ; read(0, keys, keys_len)
        xor edi, edi
        lea rsi, [keys]
        mov edx, keys_len
        syscall
        test eax, eax
        jg .got
        mov eax, 35                    ; ничего не нажато — подождать
        lea rdi, [ts]
        xor esi, esi
        syscall
        jmp .wait
.got:
        mov r14d, eax
        xor r13d, r13d
        lea r15, [keys]
.next:
        call next_key
        cmp eax, -1
        je .wait
        cmp edx, EV_RELEASE
        je .next
        cmp eax, 'q'
        je .quit
        cmp eax, 3                     ; Ctrl+C
        je .quit
        cmp eax, 10                    ; Enter
        je .menu
        cmp eax, 13
        je .menu
        cmp eax, ' '
        jne .next
.menu:
        mov eax, 1
        ret
.quit:
        mov eax, -1
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

; update_paddle: rbp = ракетка, r14d = столбец, r15d = старый верх (в половинках)
; если ракетка сдвинулась — стирает только освободившиеся клетки и рисует новую
update_paddle:
        mov eax, [rbp]
        cmp eax, r15d
        je .done                       ; не двигалась — ничего не рисуем
        mov r12d, r15d
        shr r12d, 1                    ; верхняя клетка старой ракетки
        lea r13d, [r15d + PADDLE_H - 1]
        shr r13d, 1                    ; нижняя клетка старой ракетки
        mov r10d, eax
        shr r10d, 1                    ; верхняя клетка новой ракетки
        lea r15d, [eax + PADDLE_H - 1]
        shr r15d, 1                    ; нижняя клетка новой ракетки
.erase:
        cmp r12d, r13d
        jg .draw
        cmp r12d, r10d
        jl .erase_cell
        cmp r12d, r15d
        jle .next
.erase_cell:
        mov edi, r12d
        mov esi, r14d
        lea r8, [space]
        mov r9d, 1
        call put
.next:
        inc r12d
        jmp .erase
.draw:
        call draw_paddle
.done:
        ret

; draw_paddles: рисует обе ракетки
draw_paddles:
        lea rbp, [paddle_l]
        mov r14d, PADDLE_L_X
        call draw_paddle
        lea rbp, [paddle_r]
        mov r14d, PADDLE_R_X
        call draw_paddle
        ret

; draw_paddle: rbp = ракетка (верх в половинках клетки), r14d = столбец
; целые клетки рисует █, а неполные края — ▄ сверху и ▀ снизу
draw_paddle:
        mov r10d, [rbp]                ; верх ракетки в половинках
        mov r12d, r10d
        shr r12d, 1                    ; верхняя клетка
        lea r13d, [r10d + PADDLE_H - 1]
        shr r13d, 1                    ; нижняя клетка
        test r10d, 1
        jz .middle                     ; верхняя клетка целая
        mov edi, r12d
        mov esi, r14d
        lea r8, [half_bottom]
        mov r9d, BOX_LEN
        call put
        inc r12d
.middle:
        mov r15d, r10d
        add r15d, PADDLE_H
        test r15d, 1
        jz .full_end
        mov r15d, r13d
        dec r15d                       ; нижняя клетка неполная
        jmp .mid_loop
.full_end:
        mov r15d, r13d
.mid_loop:
        cmp r12d, r15d
        jg .bottom
        mov edi, r12d
        mov esi, r14d
        lea r8, [block]
        mov r9d, BOX_LEN
        call put
        inc r12d
        jmp .mid_loop
.bottom:
        mov r15d, r10d
        add r15d, PADDLE_H
        test r15d, 1
        jz .done
        mov edi, r13d
        mov esi, r14d
        lea r8, [half_top]
        mov r9d, BOX_LEN
        call put
.done:
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
