%include "defs.inc"

global scan_field
global next_line_idx
global str_eq_region
global split_fields
global parse_uint_region
global fld_start
global fld_end

section .bss
    fld_start      resd 8
    fld_end        resd 8

section .text

; esi = buf, edi = start, edx = len. Returns eax = index, ecx = 1 if stopped at ':'.
scan_field:
    push ebx

    mov eax, edi
.loop:
    cmp eax, edx
    jge .at_end
    mov bl, byte [esi + eax]
    cmp bl, ':'
    je .at_colon
    cmp bl, 10
    je .at_end
    inc eax
    jmp .loop

.at_colon:
    mov ecx, 1
    jmp .out
.at_end:
    xor ecx, ecx
.out:
    pop ebx
    ret

next_line_idx:
    mov eax, edi
.loop:
    cmp eax, edx
    jge .out
    cmp byte [esi + eax], 10
    je .found
    inc eax
    jmp .loop

.found:
    inc eax
.out:
    ret

; esi = buf, ecx = offset, edx = len, edi = C string. Returns eax = 1 if equal.
str_eq_region:
    push ebx
    push ecx
    push ebp

    lea ebx, [esi + ecx]
    xor ebp, ebp

.loop:
    cmp ebp, edx
    jge .slice_end
    mov cl, byte [edi + ebp]
    test cl, cl
    jz .not_equal
    mov al, byte [ebx + ebp]
    cmp al, cl
    jne .not_equal
    inc ebp
    jmp .loop

.slice_end:
    cmp byte [edi + ebp], 0
    jne .not_equal
    mov eax, 1
    jmp .done

.not_equal:
    xor eax, eax
.done:
    pop ebp
    pop ecx
    pop ebx
    ret

; esi = buf, edi = line start, edx = len. Fills fld_start/fld_end, returns eax = field count.
split_fields:
    push ebx
    push ecx
    push edx
    push esi
    push edi
    push ebp

    xor ebp, ebp

.field:
    cmp ebp, 8
    jge .out
    mov eax, edi

.scan:
    cmp eax, edx
    jge .last_field
    mov cl, byte [esi + eax]
    cmp cl, 10
    je .last_field
    cmp cl, ':'
    je .at_colon
    inc eax
    jmp .scan

.at_colon:
    mov [fld_start + ebp*4], edi
    mov [fld_end + ebp*4], eax
    inc ebp
    lea edi, [eax + 1]
    jmp .field

.last_field:
    mov ebx, eax
    cmp ebx, edi
    jle .store_last
    cmp byte [esi + ebx - 1], 13
    jne .store_last
    dec ebx

.store_last:
    mov [fld_start + ebp*4], edi
    mov [fld_end + ebp*4], ebx
    inc ebp

.out:
    mov eax, ebp
    pop ebp
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

; esi = buf, ecx = offset, edx = len. Returns eax = parsed unsigned int.
parse_uint_region:
    push ebx
    push ecx
    push ebp

    xor eax, eax
    xor ebp, ebp
    lea ebx, [esi + ecx]

.loop:
    cmp ebp, edx
    jge .done
    movzx ecx, byte [ebx + ebp]
    cmp cl, '0'
    jb .skip
    cmp cl, '9'
    ja .skip
    imul eax, eax, 10
    sub ecx, '0'
    add eax, ecx
.skip:
    inc ebp
    jmp .loop

.done:
    pop ebp
    pop ecx
    pop ebx
    ret
