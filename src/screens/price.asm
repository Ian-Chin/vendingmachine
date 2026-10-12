%include "defs.inc"

global handle_price

extern print_cstr
extern print_price
extern read_line
extern pause_prompt
extern load_products
extern print_catalogue
extern normalize_code
extern find_product
extern print_field
extern save_field
extern parse_money
extern parse_uint_region
extern fld_start
extern fld_end
extern prod_buf
extern msg_no_prod
extern clear_screen
extern choice_buf
extern is_supplier
extern deny_supplier
extern menu_loop
extern handle_exit

section .data
    price_ui:
        db 10
        db 27,"[1;33m","==================================================",27,"[0m",10
        db 27,"[1;37m","              P R I C E   E D I T O R",27,"[0m",10
        db 27,"[1;33m","==================================================",27,"[0m",10
        db 27,"[0;37m","  Enter a product code, then its new price in RM.",27,"[0m",10
        db 27,"[0;36m","  Type  B  to go back to the menu.",27,"[0m",10, 0

    prompt_code    db 10,27,"[1;35m","  Item code (B = back): ",27,"[0m",0
    prompt_price   db 27,"[1;35m","  New price, e.g. 2.50 (B = back): RM ",27,"[0m",0

    item_lbl       db 10,27,"[1;37m","  ",0
    price_lbl      db 27,"[0;37m","   Current price: ",27,"[1;32m",0
    line_end       db 27,"[0m",10,0
    space_str      db " ",0

    msg_empty      db 27,"[1;31m","  [ERROR] No code entered. Please enter a product code.",27,"[0m",10,0
    msg_bad_code   db 27,"[1;31m","  [ERROR] Unknown product code. Check the table above.",27,"[0m",10,0
    msg_bad_fmt    db 27,"[1;31m","  [ERROR] Enter the price like 3, 2.5 or 2.50.",27,"[0m",10,0
    msg_range      db 27,"[1;31m","  [ERROR] Price must be between RM 0.10 and ",0
    msg_range2     db ".",27,"[0m",10,0
    msg_coins      db 27,"[1;31m","  [ERROR] Price must be a multiple of 10 sen (smallest coin).",27,"[0m",10,0
    msg_same       db 27,"[1;33m","  [INFO] That is already the price. Nothing changed.",27,"[0m",10,0
    msg_ok         db 10,27,"[1;32m","  [OK] ",27,"[1;37m",0
    msg_ok2        db 27,"[0;37m","  ",0
    msg_arrow      db 27,"[0;37m","  ->  ",27,"[1;32m",0
    msg_save_fail  db 10,27,"[1;31m","  [ERROR] Cannot update products.txt. Price not changed.",27,"[0m",10,0

section .bss
    old_price      resd 1
    new_price      resd 1

section .text

handle_price:
    cmp byte [is_supplier], 0
    je deny_supplier

    lea esi, [clear_screen]
    call print_cstr
    lea esi, [price_ui]
    call print_cstr

    call load_products
    test eax, eax
    jz .no_file
    call print_catalogue

.prompt:
    lea esi, [prompt_code]
    call print_cstr
    lea edi, [choice_buf]
    mov esi, 16
    call read_line
    cmp eax, 0
    jle handle_exit

    lea esi, [choice_buf]
    call normalize_code
    test eax, eax
    jz .empty
    cmp eax, CODE_MAX
    ja .bad_code
    cmp eax, 1
    jne .lookup
    cmp byte [esi], 'B'
    je menu_loop

.lookup:
    mov edi, esi
    call find_product
    test eax, eax
    jz .bad_code

    mov ecx, [fld_start + 3*4]
    mov edx, [fld_end + 3*4]
    sub edx, ecx
    mov esi, prod_buf
    call parse_uint_region
    mov [old_price], eax

    lea esi, [item_lbl]
    call print_cstr
    call print_item
    lea esi, [price_lbl]
    call print_cstr
    mov edi, [old_price]
    call print_price
    lea esi, [line_end]
    call print_cstr

.ask_price:
    lea esi, [prompt_price]
    call print_cstr
    lea edi, [choice_buf]
    mov esi, 16
    call read_line
    cmp eax, 0
    jle handle_exit

    lea esi, [choice_buf]
    call normalize_code
    cmp eax, 1
    jne .parse
    cmp byte [esi], 'B'
    je .prompt

.parse:
    ; Accept an optional "RM" in front, e.g. "RM 2.50".
    cmp eax, 2
    jb .money
    cmp word [esi], 'RM'
    jne .money
    add esi, 2
.skip_space:
    cmp byte [esi], ' '
    jne .money
    inc esi
    jmp .skip_space

.money:
    call parse_money
    test ecx, ecx
    jz .bad_fmt
    test eax, eax
    jz .bad_range
    cmp eax, MAX_PRICE
    ja .bad_range
    mov [new_price], eax
    xor edx, edx
    mov ecx, 10
    div ecx
    test edx, edx
    jnz .bad_coins

    mov eax, [new_price]
    cmp eax, [old_price]
    je .same
    mov ecx, 3
    call save_field
    test eax, eax
    jz .save_fail

    lea esi, [msg_ok]
    call print_cstr
    call print_item
    lea esi, [msg_ok2]
    call print_cstr
    mov edi, [old_price]
    call print_price
    lea esi, [msg_arrow]
    call print_cstr
    mov edi, [new_price]
    call print_price
    lea esi, [line_end]
    call print_cstr
    call pause_prompt
    jmp handle_price

.bad_fmt:
    lea esi, [msg_bad_fmt]
    call print_cstr
    jmp .ask_price
.bad_range:
    lea esi, [msg_range]
    call print_cstr
    mov edi, MAX_PRICE
    call print_price
    lea esi, [msg_range2]
    call print_cstr
    jmp .ask_price
.bad_coins:
    lea esi, [msg_coins]
    call print_cstr
    jmp .ask_price
.same:
    lea esi, [msg_same]
    call print_cstr
    jmp .prompt

.save_fail:
    lea esi, [msg_save_fail]
    call print_cstr
    call pause_prompt
    jmp handle_price

.empty:
    lea esi, [msg_empty]
    jmp .report
.bad_code:
    lea esi, [msg_bad_code]
.report:
    call print_cstr
    jmp .prompt

.no_file:
    lea esi, [msg_no_prod]
    call print_cstr
    call pause_prompt
    jmp menu_loop

; Prints "<emoji> <name>" for the current product line.
print_item:
    push esi
    push edi

    mov edi, 2
    call print_field
    lea esi, [space_str]
    call print_cstr
    mov edi, 1
    call print_field

    pop edi
    pop esi
    ret
