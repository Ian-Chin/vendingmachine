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
extern products_path
extern msg_no_prod
extern clear_screen
extern choice_buf
extern cash
extern change_due
extern menu_loop
extern handle_exit

CODE_MAX       equ 4

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

    tmp_path       db "products.tmp", 0

section .bss
    item_price     resd 1
    item_stock     resd 1
    paid           resd 1
    stock_txt      resb 12

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
    call save_stock
    test eax, eax
    jz .save_fail

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

; esi = C string. Trims spaces/tabs and uppercases in place.
; Returns esi = trimmed start, eax = length.
normalize_code:
    push ecx

.skip_lead:
    mov al, byte [esi]
    cmp al, ' '
    je .lead_next
    cmp al, 9
    jne .lead_done
.lead_next:
    inc esi
    jmp .skip_lead
.lead_done:

    xor ecx, ecx
.upper:
    mov al, byte [esi + ecx]
    test al, al
    jz .trim
    cmp al, 'a'
    jb .upper_next
    cmp al, 'z'
    ja .upper_next
    sub al, 32
    mov byte [esi + ecx], al
.upper_next:
    inc ecx
    jmp .upper

.trim:
    test ecx, ecx
    jz .done
    mov al, byte [esi + ecx - 1]
    cmp al, ' '
    je .cut
    cmp al, 9
    jne .done
.cut:
    dec ecx
    mov byte [esi + ecx], 0
    jmp .trim

.done:
    mov eax, ecx
    pop ecx
    ret

; edi = product code C string. Returns eax = 1 if found, with fld_start/fld_end
; describing that product line, else 0.
find_product:
    push ebx
    push ecx
    push edx
    push esi
    push edi
    push ebp

    mov ebx, edi
    xor ebp, ebp            ; ebp = line position

.line:
    cmp ebp, [prod_len]
    jge .missing

    mov al, byte [prod_buf + ebp]
    cmp al, 10
    je .advance
    cmp al, 13
    je .advance
    cmp al, '#'
    je .advance

    mov esi, prod_buf
    mov edi, ebp
    mov edx, [prod_len]
    call split_fields
    cmp eax, 6
    jl .advance

    mov ecx, [fld_start]
    mov edx, [fld_end]
    sub edx, ecx
    mov esi, prod_buf
    mov edi, ebx
    call str_eq_region
    test eax, eax
    jnz .found

.advance:
    mov edx, [prod_len]
    mov esi, prod_buf
    mov edi, ebp
    call next_line_idx
    cmp eax, ebp
    jle .missing
    mov ebp, eax
    jmp .line

.found:
    mov eax, 1
    jmp .done
.missing:
    xor eax, eax
.done:
    pop ebp
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

; edi = field index of the current product line.
print_field:
    push ecx
    push edx
    push esi

    mov ecx, [fld_start + edi*4]
    mov edx, [fld_end + edi*4]
    sub edx, ecx
    lea esi, [prod_buf + ecx]
    call print_n

    pop esi
    pop edx
    pop ecx
    ret

; eax = new stock for the current product line. Rewrites products.txt with
; that stock via a temp file + rename, so a failed write leaves the original.
; Returns eax = 1 ok, 0 failure.
save_stock:
    push ebx
    push ecx
    push edx
    push esi
    push edi
    push ebp

    lea esi, [stock_txt + 12]
    mov ebx, 10
.conv:
    xor edx, edx
    div ebx
    add dl, '0'
    dec esi
    mov byte [esi], dl
    test eax, eax
    jnz .conv

    mov eax, SYS_OPEN
    mov ebx, tmp_path
    mov ecx, O_WRONLY | O_CREAT | O_TRUNC
    mov edx, 0644o
    int 0x80
    cmp eax, 0
    jl .fail
    mov edi, eax            ; edi = fd
    xor ebp, ebp            ; ebp = 1 once any write fails

    mov ecx, prod_buf
    mov edx, [fld_start + 4*4]
    call write_all
    or ebp, eax

    mov ecx, esi
    lea edx, [stock_txt + 12]
    sub edx, esi
    call write_all
    or ebp, eax

    mov eax, [fld_end + 4*4]
    lea ecx, [prod_buf + eax]
    mov edx, [prod_len]
    sub edx, eax
    call write_all
    or ebp, eax

    mov eax, SYS_CLOSE
    mov ebx, edi
    int 0x80
    test ebp, ebp
    jnz .fail

    mov eax, SYS_RENAME
    mov ebx, tmp_path
    mov ecx, products_path
    int 0x80
    cmp eax, 0
    jl .fail

    mov eax, 1
    jmp .done
.fail:
    xor eax, eax
.done:
    pop ebp
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

; edi = fd, ecx = buffer, edx = length. Returns eax = 0 ok, 1 failure.
write_all:
    push ebx
    push ecx
    push edx

.again:
    test edx, edx
    jz .ok
    mov eax, SYS_WRITE
    mov ebx, edi
    int 0x80
    cmp eax, 0
    jle .fail
    add ecx, eax
    sub edx, eax
    jmp .again

.ok:
    xor eax, eax
    jmp .done
.fail:
    mov eax, 1
.done:
    pop edx
    pop ecx
    pop ebx
    ret
