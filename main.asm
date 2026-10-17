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
angle_tab:
        dd -2, -1, 0, 1, 2             ; dy для клеток ракетки сверху вниз
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
bot_tick:
        resd 1                         ; бот ходит через кадр
bot_aim:
        resd 1                         ; какой клеткой ракетки бот отобьёт мяч

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
        lea rsi, [kb_off]
        mov edx, kb_off_len
        call print
        mov eax, 60
        xor edi, edi
        syscall

; handle_input: читает все события клавиатуры, двигает ракетки
; левая: w/s, правая: стрелки. Ракетка едет на клетку за кадр, пока кнопка зажата
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
        or eax, [tap]                  ; по байту на кнопку
        mov dword [tap], 0
        test al, al
        jz .not_w
        dec dword [paddle_l]
.not_w:
        test ah, ah
        jz .not_s
        inc dword [paddle_l]
.not_s:
        cmp dword [game_mode], 0       ; против бота стрелки не работают
        jne .clamp
        shr eax, 16
        test al, al
        jz .not_up
        dec dword [paddle_r]
.not_up:
        test ah, ah
        jz .clamp
        inc dword [paddle_r]
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

; bot: пока мяч летит к правой ракетке, прикидывает по прямой, где он её
; пересечёт, и подставляет под него случайную клетку ракетки;
; иначе возвращается в центр.
; Ходит раз в два кадра и начинает «видеть» мяч только с BOT_SEE — чтобы можно было обыграть
bot:
        xor dword [bot_tick], 1
        jz .done                       ; чётный кадр — пропускаем
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
        mov eax, Y / 2 - PADDLE / 2    ; мяч ещё далеко — ждать в центре
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
.chase:
        cmp eax, [paddle_r]            ; eax = нужная верхняя клетка ракетки
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

; aim: rbp = ракетка; dy зависит от клетки, в которую попал мяч:
; центр — прямо, края — круто вверх/вниз
aim:
        mov eax, [ball_y]
        sub eax, [rbp]                 ; 0..PADDLE-1
        jns .pos
        xor eax, eax                   ; задел по диагонали выше ракетки
.pos:
        cmp eax, PADDLE - 1
        jle .ok
        mov eax, PADDLE - 1            ; задел по диагонали ниже ракетки
.ok:
        lea rcx, [angle_tab]
        mov eax, [rcx + rax*4]
        mov [ball_dy], eax
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
