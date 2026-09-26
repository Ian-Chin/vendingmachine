; ==============================================================================
; File: vending.asm
; Description: Vending Machine Terminal Interface
;              Stage 1 - Welcome screen, role-based login, main menu
; Target: Linux x86_64 (NASM syntax, raw syscalls, no libc)
;
; Build:  nasm -f elf64 -o vending.o vending.asm && ld -o vending vending.o
;
; Flow:   welcome_loop -> [1] guest customer | [2] supplier login -> menu_loop
;
; Accounts live in "users.txt" next to the binary, one record per line:
;     username:password:role         (role = supplier | customer)
; Only records with role "supplier" unlock the supplier tools in the menu.
;
; Stock lives in "products.txt", one record per line:
;     code:name:emoji:price_cents:stock:category   (category = food | drink)
; ==============================================================================

default rel

; --- ioctl / termios constants (used to hide the typed password) -------------
TCGETS         equ 0x5401
TCSETS         equ 0x5402
ECHO_BIT       equ 0x08            ; ECHO flag inside termios.c_lflag
LFLAG_OFF      equ 12              ; byte offset of c_lflag in struct termios

FILE_BUF_SZ    equ 4096
NAME_MAX       equ 32

section .data
    ; --- Screen control -------------------------------------------------------
    clear_screen   db 27, "[H", 27, "[2J", 0
    newline        db 10, 0

    ; --- Welcome screen -------------------------------------------------------
    welcome_ui:
        db 10
        db 27,"[1;36m","==================================================",27,"[0m",10
        db 27,"[1;33m","           S N A C K - O - M A T I C",27,"[0m",10
        db 27,"[1;37m","         V E N D I N G   M A C H I N E",27,"[0m",10
        db 27,"[1;36m","==================================================",27,"[0m",10
        db 27,"[1;35m","   ",240,159,141,171,"  Fresh Snacks   *   Cold Drinks  ",240,159,165,164,27,"[0m",10
        db 27,"[0;35m","                  Open 24 / 7",27,"[0m",10
        db 27,"[1;36m","--------------------------------------------------",27,"[0m",10
        db 27,"[1;32m","  [1]  Continue as Customer",27,"[0m",10
        db 27,"[1;34m","  [2]  Supplier Login",27,"[0m",10
        db 27,"[1;31m","  [X]  Exit",27,"[0m",10
        db 27,"[1;36m","==================================================",27,"[0m",10
        db 10
        db 27,"[1;35m","  Select an option: ",27,"[0m",0

    ; --- Supplier login screen ------------------------------------------------
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

    prompt_user      db 27,"[1;36m","  Username (B = back): ",27,"[0m",0
    prompt_pass      db 27,"[1;36m","  Password: ",27,"[0m",0

    ; --- Main menu (static parts; dynamic lines printed separately) -----------
    menu_top:
        db 10
        db 27,"[1;36m","==================================================",27,"[0m",10
        db 27,"[1;33m","           S N A C K - O - M A T I C",27,"[0m",10
        db 27,"[1;36m","==================================================",27,"[0m",10, 0

    menu_common:
        db 27,"[0;32m","  [1]  ",240,159,148,141," Browse Products",27,"[0m",10   ; magnifier
        db 27,"[0;32m","  [2]  ",240,159,170,153," Insert Coins",27,"[0m",10      ; coin
        db 27,"[0;32m","  [3]  ",240,159,155,146," Buy Item",27,"[0m",10          ; cart
        db 27,"[0;32m","  [4]  ",240,159,146,176," Collect Change",27,"[0m",10    ; money bag
        db 27,"[0;32m","  [5]  ",240,159,147,138," Machine Status",27,"[0m",10, 0 ; bar chart

    menu_supplier:
        db 27,"[1;36m","--------------------------------------------------",27,"[0m",10
        db 27,"[1;33m","  -- SUPPLIER TOOLS --",27,"[0m",10
        db 27,"[0;33m","  [6]  ",240,159,147,166," Restock Machine",27,"[0m",10   ; package
        db 27,"[0;33m","  [7]  ",240,159,167,190," Sales Report",27,"[0m",10      ; receipt
        db 27,"[0;33m","  [8]  ",240,159,143,183," Price Editor",27,"[0m",10, 0   ; tag

    menu_footer:
        db 27,"[1;36m","--------------------------------------------------",27,"[0m",10
        db 27,"[0;34m","  [L]  Logout",27,"[0m",10
        db 27,"[0;31m","  [X]  Exit",27,"[0m",10
        db 27,"[1;36m","==================================================",27,"[0m",10, 0

    ; --- Dynamic status lines -------------------------------------------------
    sess_supplier  db 27,"[1;33m","  Session: SUPPLIER",27,"[0m","  (",27,"[1;37m",0
    sess_customer  db 27,"[1;32m","  Session: CUSTOMER",27,"[0m","  (",27,"[1;37m",0
    sess_tail      db 27,"[0m",")",10,0
    credit_line    db 27,"[1;36m","  Credit : RM 0.00",27,"[0m",10,0
    menu_prompt    db 10,27,"[1;35m","  Enter your choice: ",27,"[0m",0

    str_guest      db "Guest", 0
    str_supplier   db "supplier", 0
    users_path     db "users.txt", 0
    products_path  db "products.txt", 0
    cat_food       db "food", 0
    cat_drink      db "drink", 0

    ; --- Product table rendering ----------------------------------------------
    tbl_head:
        db 27,"[1;37m","  CODE  ITEM                           PRICE     STOCK",27,"[0m",10
        db 27,"[0;36m","  -----------------------------------------------------",27,"[0m",10, 0
    sec_food       db 10,27,"[1;33m","  ",240,159,141,171,"  F O O D",27,"[0m",10,0
    sec_drink      db 10,27,"[1;36m","  ",240,159,165,164,"  D R I N K S",27,"[0m",10,0
    row_indent     db "  ", 0
    spaces32       db "                                ", 0
    price_prefix   db "RM ", 0
    dot_str        db ".", 0
    col_code       db 27,"[1;37m",0
    col_name       db 27,"[0;37m",0
    col_price      db 27,"[1;32m",0
    col_stock      db 27,"[1;33m",0
    col_reset      db 27,"[0m",0
    out_mark       db 27,"[1;31m","  (SOLD OUT)",27,"[0m",0
    msg_no_prod    db 10,27,"[1;31m","  [ERROR] Cannot open products.txt - stock file missing.",27,"[0m",10,0

    ; --- Screen headers (placeholders for Stage 2) ----------------------------
    hdr_browse     db 10, 27,"[1;32m","--- [BROWSE PRODUCTS] ---",27,"[0m",10, 0
    hdr_insert     db 10, 27,"[1;32m","--- [INSERT COINS] ---",27,"[0m",10, 0
    hdr_buy        db 10, 27,"[1;32m","--- [BUY ITEM] ---",27,"[0m",10, 0
    hdr_change     db 10, 27,"[1;32m","--- [COLLECT CHANGE] ---",27,"[0m",10, 0
    hdr_status     db 10, 27,"[1;32m","--- [MACHINE STATUS] ---",27,"[0m",10, 0
    hdr_restock    db 10, 27,"[1;33m","--- [RESTOCK MACHINE] ---",27,"[0m",10, 0
    hdr_report     db 10, 27,"[1;33m","--- [SALES REPORT] ---",27,"[0m",10, 0
    hdr_price      db 10, 27,"[1;33m","--- [PRICE EDITOR] ---",27,"[0m",10, 0

    ; --- Feedback messages ----------------------------------------------------
    msg_todo       db 27,"[0;37m","  [INFO] This screen is not built yet.",27,"[0m",10, 0
    msg_err_choice db 10, 27,"[1;31m","  [ERROR] Invalid menu option selected!",27,"[0m",10, 0
    msg_need_sup   db 10, 27,"[1;31m","  [DENIED] Supplier access required. Log in as supplier.",27,"[0m",10, 0
    msg_pause      db 10, 27,"[0;36m","  Press ENTER to continue...",27,"[0m",0
    msg_exit       db 10, 27,"[1;35m","  Thank you. Please take your item. Goodbye!",27,"[0m",10, 0

    msg_login_ok   db 10, 27,"[1;32m","  [OK] Access granted. Welcome, ",0
    msg_login_ok2  db "!",27,"[0m",10, 0
    msg_login_bad  db 10, 27,"[1;31m","  [FAIL] Invalid username or password.",27,"[0m",10, 0
    msg_not_sup    db 10, 27,"[1;33m","  [DENIED] That account is a customer account, not a supplier.",27,"[0m",10, 0
    msg_no_file    db 10, 27,"[1;31m","  [ERROR] Cannot open users.txt - account database missing.",27,"[0m",10, 0
    msg_locked     db 10, 27,"[1;31m","  [LOCKED] Too many failed attempts. Returning to welcome screen.",27,"[0m",10, 0
    msg_tries      db 27,"[1;33m","  Attempts remaining: "
    tries_digit    db "3"
                   db 27,"[0m",10, 0

    echo_saved     db 0                ; 1 = terminal echo was turned off by us
    login_tries    db 3

section .bss
    choice_buf     resb 16
    temp_buf       resb 64
    user_buf       resb NAME_MAX
    pass_buf       resb NAME_MAX
    current_user   resb NAME_MAX
    is_supplier    resb 1
    file_buf       resb FILE_BUF_SZ
    file_len       resq 1
    prod_buf       resb FILE_BUF_SZ
    prod_len       resq 1
    fld_start      resq 8
    fld_end        resq 8
    num_buf        resb 24
    termios_orig   resb 64
    termios_new    resb 64

section .text
    global _start

; ==============================================================================
; PROGRAM ENTRY
; ==============================================================================
_start:
    ; Start every run as a logged-out guest session
    mov byte [is_supplier], 0
    lea rsi, [str_guest]
    lea rdi, [current_user]
    call copy_cstr

; ==============================================================================
; WELCOME SCREEN
; ==============================================================================
welcome_loop:
    lea rsi, [clear_screen]
    call print_cstr
    lea rsi, [welcome_ui]
    call print_cstr

    lea rdi, [choice_buf]
    mov rsi, 16
    call read_line
    cmp rax, 0
    jle handle_exit                 ; EOF or read error

    mov al, byte [choice_buf]

    cmp al, '1'
    je enter_as_customer
    cmp al, '2'
    je supplier_login
    cmp al, 'X'
    je handle_exit
    cmp al, 'x'
    je handle_exit

    lea rsi, [msg_err_choice]
    call print_cstr
    call pause_prompt
    jmp welcome_loop

; --- [1] Guest customer: no credentials needed --------------------------------
enter_as_customer:
    mov byte [is_supplier], 0
    lea rsi, [str_guest]
    lea rdi, [current_user]
    call copy_cstr
    jmp menu_loop

; ==============================================================================
; SUPPLIER LOGIN (3 attempts, validated against users.txt)
; ==============================================================================
supplier_login:
    mov byte [login_tries], 3

.attempt:
    lea rsi, [clear_screen]
    call print_cstr
    lea rsi, [login_ui]
    call print_cstr

    ; --- username ---
    lea rsi, [prompt_user]
    call print_cstr
    lea rdi, [user_buf]
    mov rsi, NAME_MAX
    call read_line
    cmp rax, 0
    jle handle_exit

    ; --- [B] back to the welcome screen (single 'B' or 'b' as the username) ---
    mov al, byte [user_buf]
    cmp byte [user_buf + 1], 0
    jne .have_user
    cmp al, 'B'
    je welcome_loop
    cmp al, 'b'
    je welcome_loop
.have_user:

    ; --- password (echo disabled while typing) ---
    lea rsi, [prompt_pass]
    call print_cstr
    call echo_off
    lea rdi, [pass_buf]
    mov rsi, NAME_MAX
    call read_line
    push rax
    call echo_on
    lea rsi, [newline]
    call print_cstr                 ; the suppressed ENTER never printed one
    pop rax
    cmp rax, 0
    jle handle_exit

    call check_login                ; 1 = supplier, 2 = wrong role, 0 = bad creds, -1 = no file
    lea rdi, [pass_buf]
    mov rsi, NAME_MAX
    call zero_buf                   ; do not keep the password in memory

    cmp rax, 1
    je .granted
    cmp rax, 2
    je .wrong_role
    cmp rax, -1
    je .no_file

    ; --- bad credentials ---
    lea rsi, [msg_login_bad]
    call print_cstr
    jmp .retry

.wrong_role:
    lea rsi, [msg_not_sup]
    call print_cstr
    jmp .retry

.no_file:
    lea rsi, [msg_no_file]
    call print_cstr
    call pause_prompt
    jmp welcome_loop

.retry:
    dec byte [login_tries]
    cmp byte [login_tries], 0
    jle .locked

    ; Patch the single digit inside msg_tries, then show it
    movzx rax, byte [login_tries]
    add al, '0'
    mov byte [tries_digit], al
    lea rsi, [msg_tries]
    call print_cstr
    call pause_prompt
    jmp .attempt

.locked:
    lea rsi, [msg_locked]
    call print_cstr
    call pause_prompt
    jmp welcome_loop

.granted:
    mov byte [is_supplier], 1
    lea rsi, [user_buf]
    lea rdi, [current_user]
    call copy_cstr

    lea rsi, [msg_login_ok]
    call print_cstr
    lea rsi, [current_user]
    call print_cstr
    lea rsi, [msg_login_ok2]
    call print_cstr
    call pause_prompt
    jmp menu_loop

; ==============================================================================
; MAIN MENU (supplier rows only rendered for a supplier session)
; ==============================================================================
menu_loop:
    lea rsi, [clear_screen]
    call print_cstr

    lea rsi, [menu_top]
    call print_cstr
    lea rsi, [menu_common]
    call print_cstr

    cmp byte [is_supplier], 0
    je .skip_supplier_rows
    lea rsi, [menu_supplier]
    call print_cstr
.skip_supplier_rows:

    lea rsi, [menu_footer]
    call print_cstr

    ; --- session line ---
    cmp byte [is_supplier], 0
    je .customer_line
    lea rsi, [sess_supplier]
    call print_cstr
    jmp .session_name
.customer_line:
    lea rsi, [sess_customer]
    call print_cstr
.session_name:
    lea rsi, [current_user]
    call print_cstr
    lea rsi, [sess_tail]
    call print_cstr

    lea rsi, [credit_line]
    call print_cstr
    lea rsi, [menu_prompt]
    call print_cstr

    ; --- read choice ---
    lea rdi, [choice_buf]
    mov rsi, 16
    call read_line
    cmp rax, 0
    jle handle_exit

    cmp byte [choice_buf], 0
    je invalid_choice

    mov al, byte [choice_buf]

    cmp al, '1'
    je handle_browse
    cmp al, '2'
    je handle_insert
    cmp al, '3'
    je handle_buy
    cmp al, '4'
    je handle_change
    cmp al, '5'
    je handle_status

    cmp al, '6'
    je handle_restock
    cmp al, '7'
    je handle_report
    cmp al, '8'
    je handle_price

    cmp al, 'L'
    je handle_logout
    cmp al, 'l'
    je handle_logout
    cmp al, 'X'
    je handle_exit
    cmp al, 'x'
    je handle_exit

invalid_choice:
    lea rsi, [msg_err_choice]
    call print_cstr
    call pause_prompt
    jmp menu_loop

; ==============================================================================
; [1] BROWSE PRODUCTS
; ==============================================================================
handle_browse:
    lea rsi, [clear_screen]
    call print_cstr
    lea rsi, [hdr_browse]
    call print_cstr

    call load_products
    test rax, rax
    jz .no_file

    lea rsi, [sec_food]
    call print_cstr
    lea rsi, [tbl_head]
    call print_cstr
    lea rdi, [cat_food]
    call print_products

    lea rsi, [sec_drink]
    call print_cstr
    lea rsi, [tbl_head]
    call print_cstr
    lea rdi, [cat_drink]
    call print_products
    jmp .out

.no_file:
    lea rsi, [msg_no_prod]
    call print_cstr
.out:
    call pause_prompt
    jmp menu_loop

; ==============================================================================
; [2] INSERT COINS
; ==============================================================================
handle_insert:
    lea rsi, [hdr_insert]
    call print_cstr
    lea rsi, [msg_todo]
    call print_cstr
    call pause_prompt
    jmp menu_loop

; ==============================================================================
; [3] BUY ITEM
; ==============================================================================
handle_buy:
    lea rsi, [hdr_buy]
    call print_cstr
    lea rsi, [msg_todo]
    call print_cstr
    call pause_prompt
    jmp menu_loop

; ==============================================================================
; [4] COLLECT CHANGE
; ==============================================================================
handle_change:
    lea rsi, [hdr_change]
    call print_cstr
    lea rsi, [msg_todo]
    call print_cstr
    call pause_prompt
    jmp menu_loop

; ==============================================================================
; [5] MACHINE STATUS
; ==============================================================================
handle_status:
    lea rsi, [hdr_status]
    call print_cstr
    lea rsi, [msg_todo]
    call print_cstr
    call pause_prompt
    jmp menu_loop

; ==============================================================================
; [6] RESTOCK MACHINE   (supplier only)
; ==============================================================================
handle_restock:
    cmp byte [is_supplier], 0
    je deny_supplier
    lea rsi, [hdr_restock]
    call print_cstr
    lea rsi, [msg_todo]
    call print_cstr
    call pause_prompt
    jmp menu_loop

; ==============================================================================
; [7] SALES REPORT      (supplier only)
; ==============================================================================
handle_report:
    cmp byte [is_supplier], 0
    je deny_supplier
    lea rsi, [hdr_report]
    call print_cstr
    lea rsi, [msg_todo]
    call print_cstr
    call pause_prompt
    jmp menu_loop

; ==============================================================================
; [8] PRICE EDITOR      (supplier only)
; ==============================================================================
handle_price:
    cmp byte [is_supplier], 0
    je deny_supplier
    lea rsi, [hdr_price]
    call print_cstr
    lea rsi, [msg_todo]
    call print_cstr
    call pause_prompt
    jmp menu_loop

deny_supplier:
    lea rsi, [msg_need_sup]
    call print_cstr
    call pause_prompt
    jmp menu_loop

; ==============================================================================
; [L] LOGOUT - drop privileges and go back to the welcome screen
; ==============================================================================
handle_logout:
    mov byte [is_supplier], 0
    lea rdi, [current_user]
    mov rsi, NAME_MAX
    call zero_buf
    lea rdi, [user_buf]
    mov rsi, NAME_MAX
    call zero_buf
    lea rsi, [str_guest]
    lea rdi, [current_user]
    call copy_cstr
    jmp welcome_loop

; ==============================================================================
; [X] EXIT
; ==============================================================================
handle_exit:
    call echo_on                    ; never leave the terminal without echo
    lea rsi, [msg_exit]
    call print_cstr

    mov rax, 60                     ; sys_exit
    xor rdi, rdi
    syscall

; ==============================================================================
; LOGIN VALIDATION
; ==============================================================================

; ------------------------------------------------------------------------------
; check_login: match user_buf / pass_buf against users.txt
; Returns rax =  1  credentials match and role is "supplier"
;                2  credentials match but role is not "supplier"
;                0  no matching credentials
;               -1  users.txt could not be read
; ------------------------------------------------------------------------------
check_login:
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push r12
    push r13
    push r14
    push r15

    call load_users
    test rax, rax
    jz .file_error

    xor r15, r15                    ; cursor into file_buf

.line:
    mov rdx, [file_len]
    cmp r15, rdx
    jge .no_match

    ; Skip blank lines and comments
    lea rbx, [file_buf]
    mov al, byte [rbx + r15]
    cmp al, 10
    je .advance
    cmp al, 13
    je .advance
    cmp al, '#'
    je .advance

    ; --- field 1: username, ends at first ':' ---
    lea rsi, [file_buf]
    mov rdi, r15
    call scan_field                 ; rax = stop index, rcx = 1 when stopped on ':'
    test rcx, rcx
    jz .advance                     ; malformed record
    mov r13, rax                    ; index of first ':'

    lea rsi, [file_buf]
    mov rcx, r15
    mov rdx, r13
    sub rdx, r15                    ; username length
    lea rdi, [user_buf]
    call str_eq_region
    mov r14, rax                    ; username match flag

    ; --- field 2: password, ends at second ':' ---
    mov rdx, [file_len]
    lea rsi, [file_buf]
    lea rdi, [r13 + 1]
    call scan_field
    test rcx, rcx
    jz .advance                     ; malformed record
    mov r12, rax                    ; index of second ':'

    test r14, r14
    jz .advance                     ; username did not match, skip the rest

    lea rsi, [file_buf]
    lea rcx, [r13 + 1]
    mov rdx, r12
    sub rdx, r13
    dec rdx                         ; password length
    lea rdi, [pass_buf]
    call str_eq_region
    test rax, rax
    jz .advance

    ; --- credentials match: field 3 decides the role ---
    mov rdx, [file_len]
    lea rsi, [file_buf]
    lea rdi, [r12 + 1]
    call scan_field                 ; stops at ':', newline or end of buffer
    mov r14, rax                    ; role field end

    ; Trim a trailing CR so CRLF files still work
    cmp r14, r12
    jle .role_ready
    lea rbx, [file_buf]
    mov rcx, r14
    dec rcx
    cmp byte [rbx + rcx], 13
    jne .role_ready
    dec r14

.role_ready:
    lea rsi, [file_buf]
    lea rcx, [r12 + 1]
    mov rdx, r14
    sub rdx, r12
    dec rdx                         ; role length
    lea rdi, [str_supplier]
    call str_eq_region
    test rax, rax
    jnz .is_supplier

    mov rax, 2                      ; valid account, but not a supplier
    jmp .done

.is_supplier:
    mov rax, 1
    jmp .done

.advance:
    mov rdx, [file_len]
    lea rsi, [file_buf]
    mov rdi, r15
    call next_line_idx
    cmp rax, r15
    jle .no_match                   ; safety: never spin on the same line
    mov r15, rax
    jmp .line

.no_match:
    xor rax, rax
    jmp .done

.file_error:
    mov rax, -1

.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

; ------------------------------------------------------------------------------
; load_users: read users.txt into file_buf, store byte count in file_len
; Returns rax = 1 on success, 0 on failure
; ------------------------------------------------------------------------------
load_users:
    push rcx                        ; syscall clobbers rcx
    push rdi
    push rsi
    push rdx
    push r13

    mov qword [file_len], 0

    mov rax, 2                      ; sys_open
    lea rdi, [users_path]
    xor rsi, rsi                    ; O_RDONLY
    xor rdx, rdx
    syscall
    cmp rax, 0
    jl .fail
    mov r13, rax                    ; fd

    mov rax, 0                      ; sys_read
    mov rdi, r13
    lea rsi, [file_buf]
    mov rdx, FILE_BUF_SZ
    syscall
    cmp rax, 0
    jl .close_fail
    mov [file_len], rax

    mov rax, 3                      ; sys_close
    mov rdi, r13
    syscall

    mov rax, 1
    jmp .done

.close_fail:
    mov rax, 3                      ; sys_close
    mov rdi, r13
    syscall
.fail:
    xor rax, rax
.done:
    pop r13
    pop rdx
    pop rsi
    pop rdi
    pop rcx
    ret

; ------------------------------------------------------------------------------
; scan_field: walk forward until ':', newline, or end of buffer
;   rsi = buffer base, rdi = start index, rdx = buffer length
;   rax = index where scanning stopped
;   rcx = 1 if it stopped on ':', else 0
; ------------------------------------------------------------------------------
scan_field:
    push rbx
    push r10

    mov rax, rdi
.loop:
    cmp rax, rdx
    jge .at_end
    lea rbx, [rsi + rax]
    movzx r10, byte [rbx]
    cmp r10b, ':'
    je .at_colon
    cmp r10b, 10
    je .at_end
    inc rax
    jmp .loop

.at_colon:
    mov rcx, 1
    jmp .out
.at_end:
    xor rcx, rcx
.out:
    pop r10
    pop rbx
    ret

; ------------------------------------------------------------------------------
; next_line_idx: index of the first byte after the next newline
;   rsi = buffer base, rdi = start index, rdx = buffer length
;   rax = next line start (or rdx at end of buffer)
; ------------------------------------------------------------------------------
next_line_idx:
    push rbx

    mov rax, rdi
.loop:
    cmp rax, rdx
    jge .out
    lea rbx, [rsi + rax]
    cmp byte [rbx], 10
    je .found
    inc rax
    jmp .loop

.found:
    inc rax
.out:
    pop rbx
    ret

; ------------------------------------------------------------------------------
; str_eq_region: compare a buffer slice with a null-terminated string
;   rsi = buffer base, rcx = slice start index, rdx = slice length
;   rdi = null-terminated string
;   rax = 1 if identical (same length and bytes), else 0
; ------------------------------------------------------------------------------
str_eq_region:
    push rbx
    push r10
    push r11

    lea rbx, [rsi + rcx]            ; slice start pointer
    xor r10, r10

.loop:
    cmp r10, rdx
    jge .slice_end
    mov r11b, byte [rdi + r10]
    test r11b, r11b
    jz .not_equal                   ; string ended before the slice did
    mov al, byte [rbx + r10]
    cmp al, r11b
    jne .not_equal
    inc r10
    jmp .loop

.slice_end:
    cmp byte [rdi + r10], 0
    jne .not_equal                   ; string is longer than the slice
    mov rax, 1
    jmp .done

.not_equal:
    xor rax, rax
.done:
    pop r11
    pop r10
    pop rbx
    ret

; ==============================================================================
; PRODUCT CATALOGUE (records live in products.txt)
;   code:name:emoji:price_cents:stock:category
; ==============================================================================

; ------------------------------------------------------------------------------
; load_products: read products.txt into prod_buf, byte count into prod_len
; Returns rax = 1 on success, 0 on failure
; ------------------------------------------------------------------------------
load_products:
    push rcx                        ; syscall clobbers rcx
    push rdi
    push rsi
    push rdx
    push r13

    mov qword [prod_len], 0

    mov rax, 2                      ; sys_open
    lea rdi, [products_path]
    xor rsi, rsi                    ; O_RDONLY
    xor rdx, rdx
    syscall
    cmp rax, 0
    jl .fail
    mov r13, rax                    ; fd

    mov rax, 0                      ; sys_read
    mov rdi, r13
    lea rsi, [prod_buf]
    mov rdx, FILE_BUF_SZ
    syscall
    cmp rax, 0
    jl .close_fail
    mov [prod_len], rax

    mov rax, 3                      ; sys_close
    mov rdi, r13
    syscall

    mov rax, 1
    jmp .done

.close_fail:
    mov rax, 3                      ; sys_close
    mov rdi, r13
    syscall
.fail:
    xor rax, rax
.done:
    pop r13
    pop rdx
    pop rsi
    pop rdi
    pop rcx
    ret

; ------------------------------------------------------------------------------
; print_products: print every product row whose category field matches
;   rdi = null-terminated category string ("food" / "drink")
; ------------------------------------------------------------------------------
print_products:
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push r12
    push r13
    push r14
    push r15

    mov r12, rdi                    ; wanted category
    xor r15, r15                    ; cursor into prod_buf

.line:
    mov rdx, [prod_len]
    cmp r15, rdx
    jge .done

    ; Skip blank lines and comments
    lea rbx, [prod_buf]
    mov al, byte [rbx + r15]
    cmp al, 10
    je .advance
    cmp al, 13
    je .advance
    cmp al, '#'
    je .advance

    lea rsi, [prod_buf]
    mov rdi, r15
    mov rdx, [prod_len]
    call split_fields               ; rax = field count
    cmp rax, 6
    jl .advance                     ; malformed record

    ; --- category filter (field 5) ---
    lea rbx, [fld_start]
    mov rcx, [rbx + 5*8]
    lea rbx, [fld_end]
    mov rdx, [rbx + 5*8]
    sub rdx, rcx                    ; category length
    lea rsi, [prod_buf]
    mov rdi, r12
    call str_eq_region
    test rax, rax
    jz .advance

    call print_row

.advance:
    mov rdx, [prod_len]
    lea rsi, [prod_buf]
    mov rdi, r15
    call next_line_idx
    cmp rax, r15
    jle .done                       ; safety: never spin on the same line
    mov r15, rax
    jmp .line

.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

; ------------------------------------------------------------------------------
; print_row: render the record currently described by fld_start / fld_end
; Layout:  "  " code(6) emoji+space name(24) price(10) stock
; ------------------------------------------------------------------------------
print_row:
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push r13

    lea rsi, [row_indent]
    call print_cstr

    ; --- code ---
    lea rsi, [col_code]
    call print_cstr
    xor rdi, rdi                    ; field 0
    mov rsi, 6
    call print_field_pad

    ; --- emoji + one space ---
    lea rsi, [col_name]
    call print_cstr
    mov rdi, 2                      ; field 2
    xor rsi, rsi                    ; no padding: emoji is multi-byte
    call print_field_pad
    mov rdi, 1
    call pad_spaces

    ; --- name ---
    mov rdi, 1                      ; field 1
    mov rsi, 24
    call print_field_pad

    ; --- price (field 3 holds cents) ---
    lea rbx, [fld_start]
    mov rcx, [rbx + 3*8]
    lea rbx, [fld_end]
    mov rdx, [rbx + 3*8]
    sub rdx, rcx
    lea rsi, [prod_buf]
    call parse_uint_region
    mov r13, rax                    ; cents
    lea rsi, [col_price]
    call print_cstr
    mov rdi, r13
    call print_price                ; rax = characters printed
    mov rdi, 10
    sub rdi, rax
    call pad_spaces

    ; --- stock (field 4) ---
    lea rbx, [fld_start]
    mov rcx, [rbx + 4*8]
    lea rbx, [fld_end]
    mov rdx, [rbx + 4*8]
    sub rdx, rcx
    lea rsi, [prod_buf]
    call parse_uint_region
    mov r13, rax                    ; stock count
    lea rsi, [col_stock]
    call print_cstr
    mov rdi, r13
    call print_uint
    lea rsi, [col_reset]
    call print_cstr

    test r13, r13
    jnz .have_stock
    lea rsi, [out_mark]
    call print_cstr
.have_stock:

    lea rsi, [newline]
    call print_cstr

    pop r13
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

; ------------------------------------------------------------------------------
; print_field_pad: print one field of the current record, then pad with spaces
;   rdi = field index, rsi = column width (0 = print with no padding)
; ------------------------------------------------------------------------------
print_field_pad:
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push r13
    push r14

    mov r13, rsi                    ; requested width
    lea rbx, [fld_start]
    mov rcx, [rbx + rdi*8]
    lea rbx, [fld_end]
    mov rdx, [rbx + rdi*8]
    sub rdx, rcx                    ; field length
    mov r14, rdx
    lea rsi, [prod_buf]
    add rsi, rcx
    call print_n

    mov rdi, r13
    sub rdi, r14
    call pad_spaces

    pop r14
    pop r13
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

; ------------------------------------------------------------------------------
; split_fields: record the ':'-separated fields of one line
;   rsi = buffer base, rdi = line start index, rdx = buffer length
;   Fills fld_start[i] / fld_end[i] for up to 8 fields; a trailing CR is trimmed
;   rax = number of fields found
; ------------------------------------------------------------------------------
split_fields:
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push r8
    push r9
    push r10

    xor r8, r8                      ; fields stored
    mov r9, rdi                     ; start of the current field

.field:
    cmp r8, 8
    jge .out
    mov rax, r9

.scan:
    cmp rax, rdx
    jge .last_field
    lea rbx, [rsi + rax]
    mov cl, byte [rbx]
    cmp cl, 10
    je .last_field
    cmp cl, ':'
    je .at_colon
    inc rax
    jmp .scan

.at_colon:
    lea rbx, [fld_start]
    mov [rbx + r8*8], r9
    lea rbx, [fld_end]
    mov [rbx + r8*8], rax
    inc r8
    lea r9, [rax + 1]
    jmp .field

.last_field:
    mov r10, rax
    cmp r10, r9
    jle .store_last
    lea rbx, [rsi + r10]
    cmp byte [rbx - 1], 13          ; trim a trailing CR (CRLF files)
    jne .store_last
    dec r10

.store_last:
    lea rbx, [fld_start]
    mov [rbx + r8*8], r9
    lea rbx, [fld_end]
    mov [rbx + r8*8], r10
    inc r8

.out:
    mov rax, r8
    pop r10
    pop r9
    pop r8
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

; ------------------------------------------------------------------------------
; parse_uint_region: read an unsigned decimal out of a buffer slice
;   rsi = buffer base, rcx = slice start, rdx = slice length
;   rax = value (non-digits are ignored)
; ------------------------------------------------------------------------------
parse_uint_region:
    push rbx
    push r10
    push r11

    xor rax, rax
    xor r10, r10
    lea rbx, [rsi + rcx]

.loop:
    cmp r10, rdx
    jge .done
    movzx r11, byte [rbx + r10]
    cmp r11b, '0'
    jb .skip
    cmp r11b, '9'
    ja .skip
    imul rax, rax, 10
    sub r11b, '0'
    movzx r11, r11b
    add rax, r11
.skip:
    inc r10
    jmp .loop

.done:
    pop r11
    pop r10
    pop rbx
    ret

; ------------------------------------------------------------------------------
; print_price: print cents as "RM <ringgit>.<sen>"
;   rdi = amount in cents,  rax = characters printed
; ------------------------------------------------------------------------------
print_price:
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push r13
    push r14

    lea rsi, [price_prefix]
    call print_cstr                 ; "RM " = 3 columns

    mov rax, rdi
    xor rdx, rdx
    mov rcx, 100
    div rcx                         ; rax = ringgit, rdx = sen
    mov r13, rdx                    ; sen

    mov rdi, rax
    call print_uint
    mov r14, rax                    ; digits in the ringgit part

    lea rsi, [dot_str]
    call print_cstr

    ; sen always two digits
    mov rax, r13
    xor rdx, rdx
    mov rcx, 10
    div rcx                         ; rax = tens, rdx = ones
    add al, '0'
    mov byte [num_buf], al
    mov al, dl
    add al, '0'
    mov byte [num_buf + 1], al
    lea rsi, [num_buf]
    mov rdx, 2
    call print_n

    lea rax, [r14 + 6]              ; "RM " + '.' + 2 sen digits + ringgit digits

    pop r14
    pop r13
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

; ------------------------------------------------------------------------------
; print_uint: print an unsigned integer in decimal
;   rdi = value,  rax = digits printed
; ------------------------------------------------------------------------------
print_uint:
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push r8
    push r9

    mov rax, rdi
    lea rbx, [num_buf]
    mov r8, 24                      ; fill num_buf from the back

.conv:
    dec r8
    xor rdx, rdx
    mov r9, 10
    div r9                          ; rax = quotient, rdx = digit
    add dl, '0'
    mov byte [rbx + r8], dl
    test rax, rax
    jnz .conv

    mov rdx, 24
    sub rdx, r8                     ; digit count
    mov r9, rdx
    lea rsi, [num_buf]
    add rsi, r8
    call print_n
    mov rax, r9

    pop r9
    pop r8
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

; ------------------------------------------------------------------------------
; pad_spaces: print rdi spaces (nothing when rdi <= 0, capped at 32)
; ------------------------------------------------------------------------------
pad_spaces:
    push rax
    push rdx
    push rsi
    push rdi

    cmp rdi, 0
    jle .done
    cmp rdi, 32
    jle .sized
    mov rdi, 32
.sized:
    lea rsi, [spaces32]
    mov rdx, rdi
    call print_n

.done:
    pop rdi
    pop rsi
    pop rdx
    pop rax
    ret

; ------------------------------------------------------------------------------
; print_n: write rdx bytes starting at rsi to stdout
; ------------------------------------------------------------------------------
print_n:
    push rax
    push rcx
    push rdx
    push rdi

    cmp rdx, 0
    jle .done
    mov rax, 1                      ; sys_write
    mov rdi, 1                      ; stdout
    syscall

.done:
    pop rdi
    pop rdx
    pop rcx
    pop rax
    ret

; ==============================================================================
; TERMINAL ECHO CONTROL (password masking)
; ==============================================================================

; ------------------------------------------------------------------------------
; echo_off: clear the ECHO flag on stdin so typed passwords stay hidden.
; Silently does nothing when stdin is not a terminal.
; ------------------------------------------------------------------------------
echo_off:
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi

    mov byte [echo_saved], 0

    mov rax, 16                     ; sys_ioctl
    xor rdi, rdi                    ; stdin
    mov rsi, TCGETS
    lea rdx, [termios_orig]
    syscall
    cmp rax, 0
    jl .done

    ; Copy the saved struct so the original stays untouched for restore
    xor rcx, rcx
.copy:
    cmp rcx, 64
    jge .copied
    lea rsi, [termios_orig]
    mov bl, byte [rsi + rcx]
    lea rsi, [termios_new]
    mov byte [rsi + rcx], bl
    inc rcx
    jmp .copy

.copied:
    lea rsi, [termios_new]
    mov eax, dword [rsi + LFLAG_OFF]
    and eax, ~ECHO_BIT
    mov dword [rsi + LFLAG_OFF], eax

    mov rax, 16                     ; sys_ioctl
    xor rdi, rdi
    mov rsi, TCSETS
    lea rdx, [termios_new]
    syscall
    cmp rax, 0
    jl .done

    mov byte [echo_saved], 1

.done:
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ------------------------------------------------------------------------------
; echo_on: restore the terminal settings saved by echo_off (no-op otherwise)
; ------------------------------------------------------------------------------
echo_on:
    push rax
    push rcx                        ; syscall clobbers rcx
    push rdx
    push rsi
    push rdi

    cmp byte [echo_saved], 0
    je .done

    mov rax, 16                     ; sys_ioctl
    xor rdi, rdi
    mov rsi, TCSETS
    lea rdx, [termios_orig]
    syscall
    mov byte [echo_saved], 0

.done:
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rax
    ret

; ==============================================================================
; UTILITY AND HELPER FUNCTIONS
; ==============================================================================

; ------------------------------------------------------------------------------
; print_cstr: Prints null-terminated string at rsi
; ------------------------------------------------------------------------------
print_cstr:
    push rax
    push rdi
    push rdx
    push rcx

    ; Compute string length
    mov rdx, 0
.len_loop:
    cmp byte [rsi + rdx], 0
    je .len_found
    inc rdx
    jmp .len_loop

.len_found:
    test rdx, rdx
    jz .done

    mov rax, 1          ; sys_write
    mov rdi, 1          ; stdout
    syscall

.done:
    pop rcx
    pop rdx
    pop rdi
    pop rax
    ret

; ------------------------------------------------------------------------------
; read_line: Reads one line from stdin into buffer at rdi (max rsi-1 chars)
; Null terminates, drops CR, and consumes the trailing newline. Reading a byte
; at a time keeps the rest of the line out of our way, so piped input and
; several prompts in a row behave the same as an interactive terminal.
; Returns rax = bytes consumed (0 = EOF before any byte, negative = error).
; ------------------------------------------------------------------------------
read_line:
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push r12
    push r13
    push r14

    mov rbx, rdi        ; destination buffer
    mov r12, rsi        ; buffer size
    dec r12             ; reserve one byte for the null terminator
    xor r14, r14        ; characters stored (rcx is unusable: syscall clobbers it)
    xor r13, r13        ; bytes consumed from stdin

.next_byte:
    mov rax, 0          ; sys_read
    mov rdi, 0          ; stdin
    lea rsi, [temp_buf]
    mov rdx, 1
    syscall
    cmp rax, 0
    jle .finish         ; EOF or read error

    inc r13
    mov dl, byte [temp_buf]
    cmp dl, 10          ; '\n' ends the line
    je .finish
    cmp dl, 13          ; ignore CR
    je .next_byte

    cmp r14, r12        ; buffer full: drop the char but keep draining the line
    jge .next_byte

    mov byte [rbx + r14], dl
    inc r14
    jmp .next_byte

.finish:
    mov byte [rbx + r14], 0
    test r13, r13
    jnz .have_bytes
    ; nothing consumed: pass the sys_read result through (0 = EOF, <0 = error)
    jmp .read_done
.have_bytes:
    mov rax, r13        ; bytes consumed

.read_done:
    pop r14
    pop r13
    pop r12
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

; ------------------------------------------------------------------------------
; copy_cstr: copy null-terminated string rsi -> rdi, capped at NAME_MAX-1 bytes
; ------------------------------------------------------------------------------
copy_cstr:
    push rax
    push rcx

    xor rcx, rcx
.loop:
    cmp rcx, NAME_MAX - 1
    jge .cap
    mov al, byte [rsi + rcx]
    mov byte [rdi + rcx], al
    test al, al
    jz .done
    inc rcx
    jmp .loop

.cap:
    mov byte [rdi + rcx], 0
.done:
    pop rcx
    pop rax
    ret

; ------------------------------------------------------------------------------
; zero_buf: write rsi zero bytes starting at rdi
; ------------------------------------------------------------------------------
zero_buf:
    push rcx

    xor rcx, rcx
.loop:
    cmp rcx, rsi
    jge .done
    mov byte [rdi + rcx], 0
    inc rcx
    jmp .loop

.done:
    pop rcx
    ret

; ------------------------------------------------------------------------------
; pause_prompt: Displays pause message and waits for user to press ENTER
; ------------------------------------------------------------------------------
pause_prompt:
    push rax
    push rdi
    push rsi
    push rdx
    push rcx                ; syscall clobbers rcx

    lea rsi, [msg_pause]
    call print_cstr

    ; Consume exactly one line from stdin, one byte at a time
.wait:
    mov rax, 0          ; sys_read
    mov rdi, 0          ; stdin
    lea rsi, [temp_buf]
    mov rdx, 1
    syscall
    cmp rax, 0
    jle .done           ; EOF or error: stop waiting
    cmp byte [temp_buf], 10
    jne .wait

.done:
    pop rcx
    pop rdx
    pop rsi
    pop rdi
    pop rax
    ret
