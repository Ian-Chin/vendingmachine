%include "defs.inc"

; Every purchase appends one "code:price_sen" line to sales.txt. The report
; reads that log and totals it per product.

global handle_report
global record_sale

extern print_cstr
extern print_n
extern print_uint
extern print_price
extern pad_spaces
extern pause_prompt
extern load_products
extern find_product
extern fmt_uint
extern split_fields
extern next_line_idx
extern parse_uint_region
extern fld_start
extern fld_end
extern prod_buf
extern prod_len
extern msg_no_prod
extern newline
extern clear_screen
extern is_supplier
extern deny_supplier
extern menu_loop

section .data
    report_ui:
        db 10
        db 27,"[1;33m","==================================================",27,"[0m",10
        db 27,"[1;37m","            S A L E S   R E P O R T",27,"[0m",10
        db 27,"[1;33m","==================================================",27,"[0m",10, 0

    sales_path     db "sales.txt", 0

    tbl_head:
        db 10,27,"[1;37m","  CODE  ITEM                       SOLD      REVENUE",27,"[0m",10
        db 27,"[0;36m","  -------------------------------------------------------",27,"[0m",10, 0
    tbl_rule       db 27,"[0;36m","  -------------------------------------------------------",27,"[0m",10, 0
    row_indent     db "  ", 0
    col_code       db 27,"[1;37m",0
    col_name       db 27,"[0;37m",0
    col_dim        db 27,"[0;90m",0
    col_sold       db 27,"[1;33m",0
    col_money      db 27,"[1;32m",0
    col_reset      db 27,"[0m",0
    space_str      db " ",0
    total_lbl      db 27,"[1;37m","  TOTAL",0
    other_lbl      db 27,"[0;37m","  Sales of products no longer in the catalogue: ",27,"[1;33m",0
    other_mid      db 27,"[0;37m"," item(s), ",27,"[1;32m",0
    line_end       db 27,"[0m",10,0

    msg_none       db 10,27,"[0;37m","  [INFO] No sales recorded yet.",27,"[0m",10,0

section .bss
    sold_qty       resd MAX_PRODUCTS
    sold_amt       resd MAX_PRODUCTS
    total_qty      resd 1
    total_amt      resd 1
    known_qty      resd 1
    known_amt      resd 1
    sales_fd       resd 1
    sales_buf      resb FILE_BUF_SZ
    code_tmp       resb CODE_MAX + 1
    sale_line      resb 32
    sale_num       resb 12

section .text

handle_report:
    cmp byte [is_supplier], 0
    je deny_supplier

    lea esi, [clear_screen]
    call print_cstr
    lea esi, [report_ui]
    call print_cstr

    call load_products
    test eax, eax
    jz .no_file

    call tally_sales
    cmp dword [total_qty], 0
    je .no_sales

    lea esi, [tbl_head]
    call print_cstr
    call print_rows
    lea esi, [tbl_rule]
    call print_cstr

    lea esi, [total_lbl]
    call print_cstr
    mov edi, 28
    call pad_spaces
    mov ebx, [total_qty]
    call print_sold_amt
    mov edi, [total_amt]
    call print_price
    lea esi, [line_end]
    call print_cstr

    ; Log lines whose code is not in products.txt still count toward the total.
    mov eax, [total_qty]
    sub eax, [known_qty]
    jz .out
    lea esi, [newline]
    call print_cstr
    lea esi, [other_lbl]
    call print_cstr
    mov edi, eax
    call print_uint
    lea esi, [other_mid]
    call print_cstr
    mov edi, [total_amt]
    sub edi, [known_amt]
    call print_price
    lea esi, [line_end]
    call print_cstr
    jmp .out

.no_sales:
    lea esi, [msg_none]
    call print_cstr
    jmp .out

.no_file:
    lea esi, [msg_no_prod]
    call print_cstr
.out:
    call pause_prompt
    jmp menu_loop

; ebx = units. Prints them in the SOLD column and leaves the cursor at REVENUE.
print_sold_amt:
    push eax
    push edi

    lea esi, [col_sold]
    call print_cstr
    mov edi, ebx
    call print_uint
    mov edi, 10
    sub edi, eax
    call pad_spaces
    lea esi, [col_money]
    call print_cstr

    pop edi
    pop eax
    ret

; Prints one row per product line in prod_buf, in file order.
print_rows:
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi
    push ebp

    xor ebp, ebp            ; ebp = line position
    xor ebx, ebx            ; ebx = product index

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

    cmp ebx, MAX_PRODUCTS
    jge .done
    call print_report_row
    inc ebx

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
    pop eax
    ret

; ebx = product index; fld_start/fld_end describe its line.
print_report_row:
    push eax
    push ebx
    push esi
    push edi

    lea esi, [row_indent]
    call print_cstr

    lea esi, [col_code]
    call print_cstr
    mov edi, 0
    mov eax, 6
    call print_pad

    ; Products that never sold are dimmed so the sellers stand out.
    lea esi, [col_name]
    cmp dword [sold_qty + ebx*4], 0
    jne .name_color
    lea esi, [col_dim]
.name_color:
    call print_cstr
    mov edi, 2
    xor eax, eax
    call print_pad
    lea esi, [space_str]
    call print_cstr
    mov edi, 1
    mov eax, 24
    call print_pad

    mov eax, [sold_amt + ebx*4]
    mov ebx, [sold_qty + ebx*4]
    call print_sold_amt
    mov edi, eax
    call print_price
    lea esi, [line_end]
    call print_cstr

    pop edi
    pop esi
    pop ebx
    pop eax
    ret

; edi = field index, eax = column width. Prints the field padded with spaces.
print_pad:
    push ecx
    push edx
    push esi
    push edi

    mov ecx, [fld_start + edi*4]
    mov edx, [fld_end + edi*4]
    sub edx, ecx
    lea esi, [prod_buf + ecx]
    call print_n

    mov edi, eax
    sub edi, edx
    call pad_spaces

    pop edi
    pop esi
    pop edx
    pop ecx
    ret

; Reads sales.txt in buffer-sized chunks and fills sold_qty/sold_amt (indexed
; like find_product) plus the totals. A missing file means no sales.
tally_sales:
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi
    push ebp

    xor eax, eax
    lea edi, [sold_qty]
    mov ecx, MAX_PRODUCTS
    rep stosd
    lea edi, [sold_amt]
    mov ecx, MAX_PRODUCTS
    rep stosd
    mov dword [total_qty], 0
    mov dword [total_amt], 0
    mov dword [known_qty], 0
    mov dword [known_amt], 0

    mov eax, SYS_OPEN
    mov ebx, sales_path
    xor ecx, ecx
    xor edx, edx
    int 0x80
    cmp eax, 0
    jl .done
    mov [sales_fd], eax

    xor ebp, ebp            ; ebp = bytes held in sales_buf

.read:
    mov eax, SYS_READ
    mov ebx, [sales_fd]
    lea ecx, [sales_buf + ebp]
    mov edx, FILE_BUF_SZ
    sub edx, ebp
    int 0x80
    cmp eax, 0
    jl .close
    je .last
    add ebp, eax

    ; Tally only complete lines; carry the partial tail into the next read.
    mov ecx, ebp
.find_nl:
    dec ecx
    js .no_nl
    cmp byte [sales_buf + ecx], 10
    jne .find_nl
    inc ecx

    mov edx, ecx
    call tally_lines

    lea esi, [sales_buf + ecx]
    lea edi, [sales_buf]
    sub ebp, ecx
    mov ecx, ebp
    rep movsb
    jmp .read

.no_nl:
    cmp ebp, FILE_BUF_SZ
    jb .read
    xor ebp, ebp            ; a line longer than the buffer is junk, drop it
    jmp .read

.last:
    mov edx, ebp
    call tally_lines

.close:
    mov eax, SYS_CLOSE
    mov ebx, [sales_fd]
    int 0x80

.done:
    pop ebp
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

; edx = bytes of sales_buf to tally. Each line is "code:price_sen".
tally_lines:
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi
    push ebp

    xor ebp, ebp            ; ebp = line position

.line:
    cmp ebp, edx
    jge .done

    mov al, byte [sales_buf + ebp]
    cmp al, 10
    je .advance
    cmp al, 13
    je .advance
    cmp al, '#'
    je .advance

    mov esi, sales_buf
    mov edi, ebp
    call split_fields
    cmp eax, 2
    jl .advance

    mov ecx, [fld_start + 4]
    push edx
    mov edx, [fld_end + 4]
    sub edx, ecx
    call parse_uint_region
    mov ebx, eax            ; ebx = price

    inc dword [total_qty]
    add [total_amt], ebx

    ; Copy the code out before find_product reuses fld_start/fld_end.
    mov ecx, [fld_start]
    mov edx, [fld_end]
    sub edx, ecx
    cmp edx, CODE_MAX
    ja .unknown
    push esi
    lea esi, [sales_buf + ecx]
    lea edi, [code_tmp]
    mov ecx, edx
    rep movsb
    mov byte [edi], 0
    pop esi

    lea edi, [code_tmp]
    call find_product
    test eax, eax
    jz .unknown
    cmp eax, MAX_PRODUCTS
    ja .unknown
    inc dword [sold_qty + eax*4 - 4]
    add [sold_amt + eax*4 - 4], ebx
    inc dword [known_qty]
    add [known_amt], ebx

.unknown:
    pop edx

.advance:
    mov esi, sales_buf
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
    pop eax
    ret

; eax = price paid in sen; fld_start/fld_end describe the product line sold.
; Appends "code:price" to sales.txt. Returns eax = 1 ok, 0 failure.
record_sale:
    push ebx
    push ecx
    push edx
    push esi
    push edi

    lea edi, [sale_num + 12]
    call fmt_uint           ; esi = digits

    mov ecx, [fld_start]
    mov edx, [fld_end]
    sub edx, ecx
    cmp edx, CODE_MAX
    ja .fail

    lea edi, [sale_line]
    push esi
    lea esi, [prod_buf + ecx]
    mov ecx, edx
    rep movsb
    pop esi
    mov byte [edi], ':'
    inc edi
    lea ecx, [sale_num + 12]
    sub ecx, esi
    rep movsb
    mov byte [edi], 10
    inc edi

    mov eax, SYS_OPEN
    mov ebx, sales_path
    mov ecx, O_WRONLY | O_CREAT | O_APPEND
    mov edx, 0644o
    int 0x80
    cmp eax, 0
    jl .fail
    mov ebx, eax

    ; One write per line keeps each appended record whole.
    mov eax, SYS_WRITE
    lea ecx, [sale_line]
    mov edx, edi
    sub edx, ecx
    int 0x80
    mov esi, eax

    mov eax, SYS_CLOSE
    int 0x80
    cmp esi, edx
    jne .fail

    mov eax, 1
    jmp .done
.fail:
    xor eax, eax
.done:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret
