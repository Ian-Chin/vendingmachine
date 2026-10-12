%include "defs.inc"

; Product lookup and editing shared by the buy, restock and price screens.
; All of these work on prod_buf, so call load_products first.

global normalize_code
global find_product
global print_field
global save_field
global fmt_uint
global parse_uint_cstr
global parse_money

extern print_n
extern split_fields
extern next_line_idx
extern str_eq_region
extern fld_start
extern fld_end
extern prod_buf
extern prod_len
extern products_path

section .data
    tmp_path       db "products.tmp", 0

section .bss
    num_txt        resb 12
    cut_start      resd 1
    cut_end        resd 1
    prod_idx       resd 1

section .text

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

; edi = product code C string. Returns eax = product index + 1 if found (its
; position among the product lines), with fld_start/fld_end describing that
; product line, else 0.
find_product:
    push ebx
    push ecx
    push edx
    push esi
    push edi
    push ebp

    mov ebx, edi
    mov dword [prod_idx], 0
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
    inc dword [prod_idx]

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
    mov eax, [prod_idx]
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

; eax = value, edi = one past the end of the output buffer.
; Writes the decimal digits ending at edi. Returns esi = first digit.
fmt_uint:
    push ebx
    push edx

    mov esi, edi
    mov ebx, 10
.conv:
    xor edx, edx
    div ebx
    add dl, '0'
    dec esi
    mov byte [esi], dl
    test eax, eax
    jnz .conv

    pop edx
    pop ebx
    ret

; esi = C string of digits only. Returns eax = value, ecx = 1 if valid
; (1-6 digits, nothing else), else ecx = 0.
parse_uint_cstr:
    push edx

    xor eax, eax
    xor ecx, ecx            ; ecx = digit count
.loop:
    movzx edx, byte [esi + ecx]
    test edx, edx
    jz .end
    sub edx, '0'
    cmp edx, 9
    ja .bad
    cmp ecx, 6
    jae .bad
    imul eax, eax, 10
    add eax, edx
    inc ecx
    jmp .loop

.end:
    test ecx, ecx
    jz .bad
    mov ecx, 1
    jmp .done
.bad:
    xor ecx, ecx
.done:
    pop edx
    ret

; esi = C string such as "3", "2.5" or "2.50" (ringgit, up to 2 decimals).
; Returns eax = amount in sen, ecx = 1 if valid, else ecx = 0.
parse_money:
    push ebx
    push edx
    push esi

    xor eax, eax
    xor ebx, ebx            ; ebx = digits seen
.whole:
    movzx edx, byte [esi]
    test edx, edx
    jz .no_frac
    cmp edx, '.'
    je .frac
    sub edx, '0'
    cmp edx, 9
    ja .bad
    cmp ebx, 4
    jae .bad
    imul eax, eax, 10
    add eax, edx
    inc ebx
    inc esi
    jmp .whole

.no_frac:
    imul eax, eax, 100
    jmp .check

.frac:
    inc esi
    imul eax, eax, 100

    movzx edx, byte [esi]
    test edx, edx
    jz .check
    sub edx, '0'
    cmp edx, 9
    ja .bad
    imul edx, edx, 10
    add eax, edx
    inc ebx
    inc esi

    movzx edx, byte [esi]
    test edx, edx
    jz .check
    sub edx, '0'
    cmp edx, 9
    ja .bad
    add eax, edx
    inc ebx
    inc esi
    cmp byte [esi], 0
    jne .bad

.check:
    test ebx, ebx
    jz .bad
    mov ecx, 1
    jmp .done
.bad:
    xor ecx, ecx
.done:
    pop esi
    pop edx
    pop ebx
    ret

; eax = new value, ecx = field index of the current product line. Rewrites
; products.txt with that field replaced, via a temp file + rename, so a failed
; write leaves the original. Returns eax = 1 ok, 0 failure.
save_field:
    push ebx
    push ecx
    push edx
    push esi
    push edi
    push ebp

    mov edx, [fld_start + ecx*4]
    mov [cut_start], edx
    mov edx, [fld_end + ecx*4]
    mov [cut_end], edx

    lea edi, [num_txt + 12]
    call fmt_uint           ; esi = digits

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
    mov edx, [cut_start]
    call write_all
    or ebp, eax

    mov ecx, esi
    lea edx, [num_txt + 12]
    sub edx, esi
    call write_all
    or ebp, eax

    mov eax, [cut_end]
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
