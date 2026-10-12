%include "defs.inc"

global handle_restock

extern print_cstr
extern print_uint
extern read_line
extern pause_prompt
extern load_products
extern print_catalogue
extern normalize_code
extern find_product
extern print_field
extern save_field
extern parse_uint_cstr
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
    restock_ui:
        db 10
        db 27,"[1;33m","==================================================",27,"[0m",10
        db 27,"[1;37m","         R E S T O C K   M A C H I N E",27,"[0m",10
        db 27,"[1;33m","==================================================",27,"[0m",10
        db 27,"[0;37m","  Enter a product code to refill. Each slot holds ",MAX_STOCK_STR,".",27,"[0m",10
        db 27,"[0;36m","  Type  B  to go back to the menu.",27,"[0m",10, 0

    prompt_code    db 10,27,"[1;35m","  Item code (B = back): ",27,"[0m",0
    prompt_qty     db 27,"[1;35m","  Add how many? (F = fill, B = back): ",27,"[0m",0

    item_lbl       db 10,27,"[1;37m","  ",0
    stock_lbl      db 27,"[0;37m","   Stock: ",27,"[1;33m",0
    stock_max      db "/", MAX_STOCK_STR, 0
    room_lbl       db 27,"[0;37m","   Room for: ",27,"[1;32m",0
    line_end       db 27,"[0m",10,0
    space_str      db " ",0

    msg_empty      db 27,"[1;31m","  [ERROR] No code entered. Please enter a product code.",27,"[0m",10,0
    msg_bad_code   db 27,"[1;31m","  [ERROR] Unknown product code. Check the table above.",27,"[0m",10,0
    msg_full       db 27,"[1;33m","  [FULL] That slot is already full. Choose another.",27,"[0m",10,0
    msg_bad_qty    db 27,"[1;31m","  [ERROR] Enter a number from 1 to ",0
    msg_bad_qty2   db ", F to fill, or B to go back.",27,"[0m",10,0
    msg_ok         db 10,27,"[1;32m","  [OK] Restocked ",27,"[1;37m",0
    msg_ok2        db 27,"[1;32m","  -  stock now ",27,"[1;33m",0
    msg_save_fail  db 10,27,"[1;31m","  [ERROR] Cannot update products.txt. Stock not changed.",27,"[0m",10,0

section .bss
    item_stock     resd 1
    item_room      resd 1
    new_stock      resd 1

section .text

handle_restock:
    cmp byte [is_supplier], 0
    je deny_supplier

    lea esi, [clear_screen]
    call print_cstr
    lea esi, [restock_ui]
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

    mov ecx, [fld_start + 4*4]
    mov edx, [fld_end + 4*4]
    sub edx, ecx
    mov esi, prod_buf
    call parse_uint_region
    mov [item_stock], eax
    cmp eax, MAX_STOCK
    jae .full
    mov ecx, MAX_STOCK
    sub ecx, eax
    mov [item_room], ecx

    lea esi, [item_lbl]
    call print_cstr
    call print_item
    lea esi, [stock_lbl]
    call print_cstr
    mov edi, [item_stock]
    call print_uint
    lea esi, [stock_max]
    call print_cstr
    lea esi, [room_lbl]
    call print_cstr
    mov edi, [item_room]
    call print_uint
    lea esi, [line_end]
    call print_cstr

.ask_qty:
    lea esi, [prompt_qty]
    call print_cstr
    lea edi, [choice_buf]
    mov esi, 16
    call read_line
    cmp eax, 0
    jle handle_exit

    lea esi, [choice_buf]
    call normalize_code
    cmp eax, 1
    jne .number
    cmp byte [esi], 'B'
    je .prompt
    cmp byte [esi], 'F'
    jne .number
    mov eax, [item_room]
    jmp .apply

.number:
    call parse_uint_cstr
    test ecx, ecx
    jz .bad_qty
    test eax, eax
    jz .bad_qty
    cmp eax, [item_room]
    ja .bad_qty

.apply:
    add eax, [item_stock]
    mov [new_stock], eax
    mov ecx, 4
    call save_field
    test eax, eax
    jz .save_fail

    lea esi, [msg_ok]
    call print_cstr
    call print_item
    lea esi, [msg_ok2]
    call print_cstr
    mov edi, [new_stock]
    call print_uint
    lea esi, [stock_max]
    call print_cstr
    lea esi, [line_end]
    call print_cstr
    call pause_prompt
    jmp handle_restock

.bad_qty:
    lea esi, [msg_bad_qty]
    call print_cstr
    mov edi, [item_room]
    call print_uint
    lea esi, [msg_bad_qty2]
    call print_cstr
    jmp .ask_qty

.save_fail:
    lea esi, [msg_save_fail]
    call print_cstr
    call pause_prompt
    jmp handle_restock

.empty:
    lea esi, [msg_empty]
    jmp .report
.bad_code:
    lea esi, [msg_bad_code]
    jmp .report
.full:
    lea esi, [msg_full]
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
