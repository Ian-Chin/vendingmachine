global menu_loop

extern print_cstr
extern read_line
extern pause_prompt
extern clear_screen
extern msg_err_choice
extern choice_buf
extern current_user
extern is_supplier
extern cash
extern change_due
extern print_price
extern handle_browse
extern handle_buy
extern handle_change
extern handle_restock
extern handle_report
extern handle_price
extern handle_logout
extern handle_exit

section .data
    menu_top:
        db 10
        db 27,"[1;36m","==================================================",27,"[0m",10
        db 27,"[1;33m","             A S I A   P A C I F I C",27,"[0m",10
        db 27,"[1;37m","         V E N D I N G   M A C H I N E",27,"[0m",10
        db 27,"[1;36m","==================================================",27,"[0m",10, 0

    menu_customer:
        db 27,"[0;32m","  [1]  ",240,159,148,141," Browse Products",27,"[0m",10
        db 27,"[0;32m","  [2]  ",240,159,155,146," Buy Item",27,"[0m",10
        db 27,"[0;32m","  [3]  ",240,159,146,176," Collect Change",27,"[0m",10, 0

    ; Suppliers do not handle money, so coin/buy/change are left out.
    menu_supplier:
        db 27,"[0;32m","  [1]  ",240,159,148,141," Browse Products",27,"[0m",10
        db 27,"[1;36m","--------------------------------------------------",27,"[0m",10
        db 27,"[1;33m","  -- SUPPLIER TOOLS --",27,"[0m",10
        db 27,"[0;33m","  [2]  ",240,159,147,166," Restock Machine",27,"[0m",10
        db 27,"[0;33m","  [3]  ",240,159,167,190," Sales Report",27,"[0m",10
        db 27,"[0;33m","  [4]  ",240,159,143,183," Price Editor",27,"[0m",10, 0

    menu_footer:
        db 27,"[1;36m","--------------------------------------------------",27,"[0m",10
        db 27,"[0;34m","  [L]  Logout",27,"[0m",10
        db 27,"[0;31m","  [X]  Exit",27,"[0m",10
        db 27,"[1;36m","==================================================",27,"[0m",10, 0

    sess_supplier  db 27,"[1;33m","  Session: SUPPLIER",27,"[0m","  (",27,"[1;37m",0
    sess_customer  db 27,"[1;32m","  Session: CUSTOMER",27,"[0m","  (",27,"[1;37m",0
    sess_tail      db 27,"[0m",")",10,0
    cash_line      db 27,"[1;36m","  Cash : ",27,"[1;37m",0
    tray_line      db 27,"[1;36m","    Change tray: ",27,"[1;33m",0
    line_tail      db 27,"[0m",10,0
    menu_prompt    db 10,27,"[1;35m","  Enter your choice: ",27,"[0m",0

section .text

menu_loop:
    lea esi, [clear_screen]
    call print_cstr

    lea esi, [menu_top]
    call print_cstr
    cmp byte [is_supplier], 0
    jne .supplier_view

    lea esi, [menu_customer]
    call print_cstr
    lea esi, [menu_footer]
    call print_cstr
    lea esi, [sess_customer]
    call print_cstr
    lea esi, [current_user]
    call print_cstr
    lea esi, [sess_tail]
    call print_cstr
    lea esi, [cash_line]
    call print_cstr
    mov edi, [cash]
    call print_price
    lea esi, [tray_line]
    call print_cstr
    mov edi, [change_due]
    call print_price
    lea esi, [line_tail]
    call print_cstr
    call read_choice
    jle handle_exit

    cmp al, '1'
    je handle_browse
    cmp al, '2'
    je handle_buy
    cmp al, '3'
    je handle_change
    jmp .common_keys

.supplier_view:
    lea esi, [menu_supplier]
    call print_cstr
    lea esi, [menu_footer]
    call print_cstr
    lea esi, [sess_supplier]
    call print_cstr
    lea esi, [current_user]
    call print_cstr
    lea esi, [sess_tail]
    call print_cstr
    call read_choice
    jle handle_exit

    cmp al, '1'
    je handle_browse
    cmp al, '2'
    je handle_restock
    cmp al, '3'
    je handle_report
    cmp al, '4'
    je handle_price

.common_keys:
    cmp al, 'L'
    je handle_logout
    cmp al, 'l'
    je handle_logout
    cmp al, 'X'
    je handle_exit
    cmp al, 'x'
    je handle_exit

.invalid:
    lea esi, [msg_err_choice]
    call print_cstr
    call pause_prompt
    jmp menu_loop

; Prints the prompt and reads a line into choice_buf.
; Returns al = first character (0 if empty); flags set from the read_line
; result, so callers branch with jle on EOF/error.
read_choice:
    lea esi, [menu_prompt]
    call print_cstr
    lea edi, [choice_buf]
    mov esi, 16
    call read_line
    mov cl, byte [choice_buf]
    cmp eax, 0
    mov al, cl
    ret
