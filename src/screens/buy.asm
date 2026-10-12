%include "defs.inc"

global handle_buy

extern print_cstr
extern print_n
extern print_price
extern read_line
extern pause_prompt
extern load_products
extern print_catalogue
extern split_fields
extern next_line_idx
extern str_eq_region
extern parse_uint_region
extern fld_start
extern fld_end
extern prod_buf
extern prod_len
extern msg_no_prod
extern clear_screen
extern choice_buf
extern cash
extern change_due
extern menu_loop
extern handle_exit
extern normalize_code
extern find_product
extern print_field
extern save_field
extern record_sale

section .data
    buy_ui:
        db 10
        db 27,"[1;32m","==================================================",27,"[0m",10
        db 27,"[1;33m","                B U Y   I T E M",27,"[0m",10
        db 27,"[1;32m","==================================================",27,"[0m",10
        db 27,"[0;37m","  Enter the product code from the table, e.g. A1",27,"[0m",10
        db 27,"[0;36m","  Type  B  to go back to the menu.",27,"[0m",10, 0

    cash_lbl       db 10,27,"[1;36m","  Cash: ",27,"[1;37m",0
    tray_lbl       db 27,"[1;36m","    Change tray: ",27,"[1;33m",0
    color_reset    db 27,"[0m",10,0
    prompt_code    db 10,27,"[1;35m","  Item code (B = back): ",27,"[0m",0

    msg_empty      db 27,"[1;31m","  [ERROR] No code entered. Please enter a product code.",27,"[0m",10,0
    msg_bad_code   db 27,"[1;31m","  [ERROR] Unknown product code. Check the table above.",27,"[0m",10,0
    msg_sold_out   db 27,"[1;33m","  [SOLD OUT] That item is out of stock. Choose another.",27,"[0m",10,0
    msg_no_cash    db 27,"[1;33m","  [NOT ENOUGH CASH] Price ",0
    msg_no_cash2   db ", you only have ",0
    msg_no_cash3   db ".",27,"[0m",10,0
    msg_save_fail  db 10,27,"[1;31m","  [ERROR] Cannot update products.txt. Purchase cancelled, money returned.",27,"[0m",10,0

    pay_hdr        db 10,27,"[1;32m","  Paying for: ",27,"[1;37m",0
    pay_price      db 27,"[0;37m","   Price: ",27,"[1;32m",0
    pay_menu:
        db 27,"[0;36m","  --------------------------------------------------",27,"[0m",10
        db 27,"[0;37m","  Notes: [1] RM 10   [2] RM 5    [3] RM 1",27,"[0m",10
        db 27,"[0;37m","  Coins: [4] 50 sen  [5] 20 sen  [6] 10 sen",27,"[0m",10
        db 27,"[0;36m","  [C] Cancel and take your money back",27,"[0m",10, 0
    lbl_paid       db 10,27,"[1;36m","  Paid: ",27,"[1;37m",0
    lbl_due        db 27,"[1;36m","    Still due: ",27,"[1;33m",0
    lbl_cash       db 27,"[1;36m","    Cash: ",27,"[1;37m",0
    prompt_pay     db 10,27,"[1;35m","  Insert money (C = cancel): ",27,"[0m",0
    msg_bad_pay    db 27,"[1;31m","  [ERROR] Choose 1-6 to insert money, or C to cancel.",27,"[0m",10,0
    msg_too_much   db 27,"[1;33m","  [REJECTED] You do not have that much cash left.",27,"[0m",10,0
    msg_inserted   db 27,"[1;32m","  [OK] Inserted ",0
    msg_cancel     db 10,27,"[1;33m","  [CANCELLED] Returned to your cash: ",0

    msg_vend       db 10,27,"[1;32m","  [OK] Dispensing ",27,"[1;37m",0
    msg_vend2      db 27,"[1;32m","  -  please take your item.",27,"[0m",10,0
    msg_paid       db 27,"[0;37m","  Paid: ",0
    msg_change     db "    Change: ",0
    msg_collect    db 27,"[0;36m","  Change is in the tray. Use Collect Change to get it back.",27,"[0m",10,0
    space_str      db " ",0

    ; Values for payment options 1-6, in sen.
    money_vals     dd 1000, 500, 100, 50, 20, 10

section .bss
    item_price     resd 1
    item_stock     resd 1
    paid           resd 1

section .text

handle_buy:
    lea esi, [clear_screen]
    call print_cstr
    lea esi, [buy_ui]
    call print_cstr

    call load_products
    test eax, eax
    jz .no_file
    call print_catalogue
    call show_wallet

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
    mov [item_price], eax

    mov ecx, [fld_start + 4*4]
    mov edx, [fld_end + 4*4]
    sub edx, ecx
    mov esi, prod_buf
    call parse_uint_region
    test eax, eax
    jz .sold_out
    mov [item_stock], eax

    mov ebx, [cash]
    cmp ebx, [item_price]
    jb .no_cash

    ; Fields still describe the chosen line: 1 = name, 2 = emoji.
    call take_payment
    test eax, eax
    jz handle_buy

    mov eax, [item_stock]
    dec eax
    mov ecx, 4
    call save_field
    test eax, eax
    jz .save_fail

    ; The item is already out, so a failed log write does not undo the sale.
    mov eax, [item_price]
    call record_sale

    mov eax, [paid]
    sub eax, [item_price]
    add [change_due], eax

    lea esi, [msg_vend]
    call print_cstr
    mov edi, 2
    call print_field
    lea esi, [space_str]
    call print_cstr
    mov edi, 1
    call print_field
    lea esi, [msg_vend2]
    call print_cstr

    lea esi, [msg_paid]
    call print_cstr
    mov edi, [paid]
    call print_price
    lea esi, [msg_change]
    call print_cstr
    mov edi, [paid]
    sub edi, [item_price]
    call print_price
    lea esi, [color_reset]
    call print_cstr
    test edi, edi
    jz .vend_done
    lea esi, [msg_collect]
    call print_cstr
.vend_done:
    call pause_prompt
    jmp handle_buy

.save_fail:
    mov eax, [paid]
    add [cash], eax
    lea esi, [msg_save_fail]
    call print_cstr
    call pause_prompt
    jmp handle_buy

.no_cash:
    lea esi, [msg_no_cash]
    call print_cstr
    mov edi, [item_price]
    call print_price
    lea esi, [msg_no_cash2]
    call print_cstr
    mov edi, [cash]
    call print_price
    lea esi, [msg_no_cash3]
    call print_cstr
    jmp .prompt

.empty:
    lea esi, [msg_empty]
    jmp .report
.bad_code:
    lea esi, [msg_bad_code]
    jmp .report
.sold_out:
    lea esi, [msg_sold_out]
.report:
    call print_cstr
    jmp .prompt

.no_file:
    lea esi, [msg_no_prod]
    call print_cstr
    call pause_prompt
    jmp menu_loop

; Takes notes/coins from cash until item_price is covered. cash + paid stays
; equal to the starting cash, which is >= the price, so the customer can
; always finish with 10 sen coins.
; Returns eax = 1 paid (amount in [paid]), 0 cancelled (money refunded).
take_payment:
    push ebx
    push esi
    push edi

    mov dword [paid], 0

    lea esi, [pay_hdr]
    call print_cstr
    mov edi, 2
    call print_field
    lea esi, [space_str]
    call print_cstr
    mov edi, 1
    call print_field
    lea esi, [pay_price]
    call print_cstr
    mov edi, [item_price]
    call print_price
    lea esi, [color_reset]
    call print_cstr
    lea esi, [pay_menu]
    call print_cstr

.status:
    lea esi, [lbl_paid]
    call print_cstr
    mov edi, [paid]
    call print_price
    lea esi, [lbl_due]
    call print_cstr
    mov edi, [item_price]
    sub edi, [paid]
    call print_price
    lea esi, [lbl_cash]
    call print_cstr
    mov edi, [cash]
    call print_price
    lea esi, [color_reset]
    call print_cstr

.ask:
    lea esi, [prompt_pay]
    call print_cstr
    lea edi, [choice_buf]
    mov esi, 16
    call read_line
    cmp eax, 0
    jle handle_exit

    lea esi, [choice_buf]
    call normalize_code
    cmp eax, 1
    jne .bad
    movzx eax, byte [esi]
    cmp al, 'C'
    je .cancel
    cmp al, '1'
    jb .bad
    cmp al, '6'
    ja .bad

    mov ebx, [money_vals + (eax - '1')*4]
    cmp ebx, [cash]
    ja .too_much
    sub [cash], ebx
    add [paid], ebx

    lea esi, [msg_inserted]
    call print_cstr
    mov edi, ebx
    call print_price
    lea esi, [color_reset]
    call print_cstr

    mov eax, [paid]
    cmp eax, [item_price]
    jb .status
    mov eax, 1
    jmp .done

.bad:
    lea esi, [msg_bad_pay]
    call print_cstr
    jmp .ask
.too_much:
    lea esi, [msg_too_much]
    call print_cstr
    jmp .ask

.cancel:
    mov eax, [paid]
    add [cash], eax
    lea esi, [msg_cancel]
    call print_cstr
    mov edi, [paid]
    call print_price
    lea esi, [color_reset]
    call print_cstr
    call pause_prompt
    xor eax, eax
.done:
    pop edi
    pop esi
    pop ebx
    ret

show_wallet:
    push esi
    push edi

    lea esi, [cash_lbl]
    call print_cstr
    mov edi, [cash]
    call print_price
    lea esi, [tray_lbl]
    call print_cstr
    mov edi, [change_due]
    call print_price
    lea esi, [color_reset]
    call print_cstr

    pop edi
    pop esi
    ret
