global welcome_loop

extern print_cstr
extern read_line
extern pause_prompt
extern set_guest
extern clear_screen
extern msg_err_choice
extern choice_buf
extern supplier_login
extern menu_loop
extern handle_exit

section .data
    welcome_ui:
        db 10
        db 27,"[1;36m","==================================================",27,"[0m",10
        db 27,"[1;33m","             A S I A   P A C I F I C",27,"[0m",10
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

section .text

welcome_loop:
    lea esi, [clear_screen]
    call print_cstr
    lea esi, [welcome_ui]
    call print_cstr

    lea edi, [choice_buf]
    mov esi, 16
    call read_line
    cmp eax, 0
    jle handle_exit

    mov al, byte [choice_buf]

    cmp al, '1'
    je enter_as_customer
    cmp al, '2'
    je supplier_login
    cmp al, 'X'
    je handle_exit
    cmp al, 'x'
    je handle_exit

    lea esi, [msg_err_choice]
    call print_cstr
    call pause_prompt
    jmp welcome_loop

enter_as_customer:
    call set_guest
    jmp menu_loop
