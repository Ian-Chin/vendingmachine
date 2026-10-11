%include "defs.inc"

START_CASH     equ 2000        ; every customer starts with RM 20.00

global clear_screen
global msg_err_choice
global choice_buf
global current_user
global is_supplier
global set_guest
global show_todo
global deny_supplier
global cash
global change_due

extern print_cstr
extern pause_prompt
extern copy_cstr
extern menu_loop

section .data
    clear_screen   db 27, "[H", 27, "[2J", 0
    str_guest      db "Guest", 0
    msg_err_choice db 10, 27,"[1;31m","  [ERROR] Invalid menu option selected!",27,"[0m",10, 0
    msg_todo       db 27,"[0;37m","  [INFO] This screen is not built yet.",27,"[0m",10, 0
    msg_need_sup   db 10, 27,"[1;31m","  [DENIED] Supplier access required. Log in as supplier.",27,"[0m",10, 0

section .bss
    choice_buf     resb 16
    current_user   resb NAME_MAX
    is_supplier    resb 1
    cash           resd 1          ; customer's wallet in sen (100 = RM 1.00)
    change_due     resd 1          ; change waiting in the tray, in sen

section .text

set_guest:
    push esi
    push edi

    mov byte [is_supplier], 0
    mov dword [cash], START_CASH
    mov dword [change_due], 0
    lea esi, [str_guest]
    lea edi, [current_user]
    call copy_cstr

    pop edi
    pop esi
    ret

show_todo:
    call print_cstr
    lea esi, [msg_todo]
    call print_cstr
    call pause_prompt
    jmp menu_loop

deny_supplier:
    lea esi, [msg_need_sup]
    call print_cstr
    call pause_prompt
    jmp menu_loop
