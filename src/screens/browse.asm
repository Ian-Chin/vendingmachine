%include "defs.inc"

global handle_browse
global load_products
global print_catalogue
global print_price
global prod_buf
global prod_len
global products_path
global msg_no_prod

extern print_cstr
extern print_n
extern print_uint
extern pad_spaces
extern pause_prompt
extern next_line_idx
extern str_eq_region
extern split_fields
extern parse_uint_region
extern fld_start
extern fld_end
extern newline
extern num_buf
extern clear_screen
extern menu_loop

section .data
    hdr_browse     db 10, 27,"[1;32m","--- [BROWSE PRODUCTS] ---",27,"[0m",10, 0
    products_path  db "products.txt", 0
    cat_food       db "food", 0
    cat_drink      db "drink", 0

    tbl_head:
        db 27,"[1;37m","  CODE  ITEM                           PRICE     STOCK",27,"[0m",10
        db 27,"[0;36m","  -----------------------------------------------------",27,"[0m",10, 0
    sec_food       db 10,27,"[1;33m","  ",240,159,141,171,"  F O O D",27,"[0m",10,0
    sec_drink      db 10,27,"[1;36m","  ",240,159,165,164,"  D R I N K S",27,"[0m",10,0
    row_indent     db "  ", 0
    price_prefix   db "RM ", 0
    dot_str        db ".", 0
    col_code       db 27,"[1;37m",0
    col_name       db 27,"[0;37m",0
    col_price      db 27,"[1;32m",0
    col_stock      db 27,"[1;33m",0
    col_reset      db 27,"[0m",0
    stock_max      db "/", MAX_STOCK_STR, 0
    out_mark       db 27,"[1;31m","  (SOLD OUT)",27,"[0m",0
    msg_no_prod    db 10,27,"[1;31m","  [ERROR] Cannot open products.txt - stock file missing.",27,"[0m",10,0

section .bss
    prod_buf       resb FILE_BUF_SZ
    prod_len       resd 1
    cur_cat        resd 1

section .text

handle_browse:
    mov esi, clear_screen
    call print_cstr
    mov esi, hdr_browse
    call print_cstr

    call load_products
    test eax, eax
    jz .no_file

    call print_catalogue
    jmp .out

.no_file:
    mov esi, msg_no_prod
    call print_cstr
.out:
    call pause_prompt
    jmp menu_loop

; Prints the food and drink tables from prod_buf. Call load_products first.
print_catalogue:
    push esi
    push edi

    mov esi, sec_food
    call print_cstr
    mov esi, tbl_head
    call print_cstr
    mov edi, cat_food
    call print_products

    mov esi, sec_drink
    call print_cstr
    mov esi, tbl_head
    call print_cstr
    mov edi, cat_drink
    call print_products

    pop edi
    pop esi
    ret

load_products:
    push ebx
    push ecx
    push edx
    push esi

    mov dword [prod_len], 0

    mov eax, SYS_OPEN
    mov ebx, products_path
    xor ecx, ecx
    xor edx, edx
    int 0x80
    cmp eax, 0
    jl .fail
    mov esi, eax

    mov eax, SYS_READ
    mov ebx, esi
    mov ecx, prod_buf
    mov edx, FILE_BUF_SZ
    int 0x80
    cmp eax, 0
    jl .close_fail
    mov [prod_len], eax

    mov eax, SYS_CLOSE
    mov ebx, esi
    int 0x80

    mov eax, 1
    jmp .done

.close_fail:
    mov eax, SYS_CLOSE
    mov ebx, esi
    int 0x80
.fail:
    xor eax, eax
.done:
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

; edi = category C string. Prints every product row in that category.
print_products:
    push ebx
    push ecx
    push edx
    push esi
    push edi
    push ebp

    mov [cur_cat], edi
    xor ebp, ebp            ; ebp = line position

.line:
    cmp ebp, [prod_len]
    jge .done

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

    mov ecx, [fld_start + 5*4]
    mov edx, [fld_end + 5*4]
    sub edx, ecx
    mov esi, prod_buf
    mov edi, [cur_cat]
    call str_eq_region
    test eax, eax
    jz .advance

    call print_row

.advance:
    mov edx, [prod_len]
    mov esi, prod_buf
    mov edi, ebp
    call next_line_idx
    cmp eax, ebp
    jle .done
    mov ebp, eax
    jmp .line

.done:
    pop ebp
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

print_row:
    push ebx
    push ecx
    push edx
    push esi
    push edi

    mov esi, row_indent
    call print_cstr

    mov esi, col_code
    call print_cstr
    xor edi, edi
    mov esi, 6
    call print_field_pad

    mov esi, col_name
    call print_cstr
    mov edi, 2
    xor esi, esi
    call print_field_pad
    mov edi, 1
    call pad_spaces

    mov edi, 1
    mov esi, 24
    call print_field_pad

    mov ecx, [fld_start + 3*4]
    mov edx, [fld_end + 3*4]
    sub edx, ecx
    mov esi, prod_buf
    call parse_uint_region
    mov ebx, eax
    mov esi, col_price
    call print_cstr
    mov edi, ebx
    call print_price
    mov edi, 10
    sub edi, eax
    call pad_spaces

    mov ecx, [fld_start + 4*4]
    mov edx, [fld_end + 4*4]
    sub edx, ecx
    mov esi, prod_buf
    call parse_uint_region
    mov ebx, eax
    mov esi, col_stock
    call print_cstr
    mov edi, ebx
    call print_uint
    mov esi, stock_max
    call print_cstr
    mov esi, col_reset
    call print_cstr

    test ebx, ebx
    jnz .have_stock
    mov esi, out_mark
    call print_cstr
.have_stock:

    mov esi, newline
    call print_cstr

    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

; edi = field index, esi = column width.
print_field_pad:
    push ebx
    push ecx
    push edx
    push esi
    push edi

    mov ebx, esi
    mov ecx, [fld_start + edi*4]
    mov edx, [fld_end + edi*4]
    sub edx, ecx
    lea esi, [prod_buf + ecx]
    call print_n

    mov edi, ebx
    sub edi, edx
    call pad_spaces

    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

; edi = price in cents. Returns eax = characters printed.
print_price:
    push ebx
    push ecx
    push edx
    push esi
    push edi

    mov esi, price_prefix
    call print_cstr

    mov eax, edi
    xor edx, edx
    mov ecx, 100
    div ecx
    mov ebx, edx

    mov edi, eax
    call print_uint
    mov edi, eax

    mov esi, dot_str
    call print_cstr

    mov eax, ebx
    xor edx, edx
    mov ecx, 10
    div ecx
    add al, '0'
    mov byte [num_buf], al
    add dl, '0'
    mov byte [num_buf + 1], dl
    mov esi, num_buf
    mov edx, 2
    call print_n

    lea eax, [edi + 6]

    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret
