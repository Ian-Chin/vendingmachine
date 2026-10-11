%include "defs.inc"

global supplier_login

extern print_cstr
extern read_line
extern pause_prompt
extern copy_cstr
extern zero_buf
extern newline
extern echo_off
extern echo_on
extern check_login
extern user_buf
extern pass_buf
extern clear_screen
extern current_user
extern is_supplier
extern welcome_loop
extern menu_loop
extern handle_exit

section .data
    login_ui:
        db 10
        db 27,"[1;34m","==================================================",27,"[0m",10
        db 27,"[1;33m","          S U P P L I E R   L O G I N",27,"[0m",10
        db 27,"[1;34m","==================================================",27,"[0m",10
        db 27,"[0;37m","  Supplier accounts only. Credentials are",27,"[0m",10
        db 27,"[0;37m","  verified against users.txt.",27,"[0m",10
        db 27,"[0;36m","  Type  B  as the username to go back.",27,"[0m",10
        db 27,"[1;34m","__________________________________________________",27,"[0m",10
        db 10, 0

    prompt_user    db 27,"[1;36m","  Username (B = back): ",27,"[0m",0
    prompt_pass    db 27,"[1;36m","  Password: ",27,"[0m",0

    msg_login_ok   db 10, 27,"[1;32m","  [OK] Access granted. Welcome, ",0
    msg_login_ok2  db "!",27,"[0m",10, 0
    msg_login_bad  db 10, 27,"[1;31m","  [FAIL] Invalid username or password.",27,"[0m",10, 0
    msg_empty_user db 10, 27,"[1;31m","  [ERROR] Username cannot be empty.",27,"[0m",10, 0
    msg_empty_pass db 10, 27,"[1;31m","  [ERROR] Password cannot be empty.",27,"[0m",10, 0
    msg_not_sup   db 10, 27,"[1;33m","  [DENIED] That account is a customer account, not a supplier.",27,"[0m",10, 0
    msg_no_file    db 10, 27,"[1;31m","  [ERROR] Cannot open users.txt - account database missing.",27,"[0m",10, 0
    msg_locked     db 10, 27,"[1;31m","  [LOCKED] Too many failed attempts. Returning to welcome screen.",27,"[0m",10, 0
    msg_tries      db 27,"[1;33m","  Attempts remaining: "
    tries_digit    db "3"
                   db 27,"[0m",10, 0

    login_tries    db 3

section .text

supplier_login:
    mov byte [login_tries], 3

.attempt:
    lea esi, [clear_screen]
    call print_cstr
    lea esi, [login_ui]
    call print_cstr

    lea esi, [prompt_user]
    call print_cstr
    lea edi, [user_buf]
    mov esi, NAME_MAX
    call read_line
    cmp eax, 0
    jle handle_exit

    lea esi, [user_buf]
    call is_blank
    test eax, eax
    jnz .empty_user

    mov al, byte [user_buf]
    cmp byte [user_buf + 1], 0
    jne .have_user
    cmp al, 'B'
    je welcome_loop
    cmp al, 'b'
    je welcome_loop
.have_user:

    lea esi, [prompt_pass]
    call print_cstr
    call echo_off
    lea edi, [pass_buf]
    mov esi, NAME_MAX
    call read_line
    push eax
    call echo_on
    lea esi, [newline]
    call print_cstr
    pop eax
    cmp eax, 0
    jle handle_exit

    lea esi, [pass_buf]
    call is_blank
    test eax, eax
    jnz .empty_pass

    call check_login
    lea edi, [pass_buf]
    mov esi, NAME_MAX
    call zero_buf

    cmp eax, 1
    je .granted
    cmp eax, 2
    je .wrong_role
    cmp eax, -1
    je .no_file

    lea esi, [msg_login_bad]
    call print_cstr
    jmp .retry

.wrong_role:
    lea esi, [msg_not_sup]
    call print_cstr
    jmp .retry

; Empty fields are rejected before the account check and do not use up an attempt.
.empty_user:
    lea esi, [msg_empty_user]
    call print_cstr
    call pause_prompt
    jmp .attempt

.empty_pass:
    lea edi, [pass_buf]
    mov esi, NAME_MAX
    call zero_buf
    lea esi, [msg_empty_pass]
    call print_cstr
    call pause_prompt
    jmp .attempt

.no_file:
    lea esi, [msg_no_file]
    call print_cstr
    call pause_prompt
    jmp welcome_loop

.retry:
    dec byte [login_tries]
    cmp byte [login_tries], 0
    jle .locked

    movzx eax, byte [login_tries]
    add al, '0'
    mov byte [tries_digit], al
    lea esi, [msg_tries]
    call print_cstr
    call pause_prompt
    jmp .attempt

.locked:
    lea esi, [msg_locked]
    call print_cstr
    call pause_prompt
    jmp welcome_loop

.granted:
    mov byte [is_supplier], 1
    lea esi, [user_buf]
    lea edi, [current_user]
    call copy_cstr

    lea esi, [msg_login_ok]
    call print_cstr
    lea esi, [current_user]
    call print_cstr
    lea esi, [msg_login_ok2]
    call print_cstr
    call pause_prompt
    jmp menu_loop

; esi = C string. Returns eax = 1 if empty or only spaces/tabs, else 0.
is_blank:
    push esi
.loop:
    mov al, byte [esi]
    test al, al
    jz .blank
    cmp al, ' '
    je .next
    cmp al, 9
    jne .not_blank
.next:
    inc esi
    jmp .loop
.blank:
    mov eax, 1
    jmp .done
.not_blank:
    xor eax, eax
.done:
    pop esi
    ret
