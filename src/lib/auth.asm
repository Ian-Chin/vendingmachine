%include "defs.inc"

global check_login
global user_buf
global pass_buf

extern scan_field
extern next_line_idx
extern str_eq_region

; check_login locals (32-bit has no r12-r15, so keep them on the stack)
%define LINE_POS   dword [ebp - 4]
%define USER_END   dword [ebp - 8]
%define PASS_END   dword [ebp - 12]
%define USER_OK    dword [ebp - 16]

section .data
    str_supplier   db "supplier", 0
    users_path     db "users.txt", 0

section .bss
    user_buf       resb NAME_MAX
    pass_buf       resb NAME_MAX
    file_buf       resb FILE_BUF_SZ
    file_len       resd 1

section .text

; Returns eax = 1 supplier, 2 other role, 0 no match, -1 file error.
check_login:
    push ebx
    push ecx
    push edx
    push esi
    push edi
    push ebp
    mov ebp, esp
    sub esp, 16

    call load_users
    test eax, eax
    jz .file_error

    mov LINE_POS, 0

.line:
    mov ebx, LINE_POS
    cmp ebx, [file_len]
    jge .no_match

    mov al, byte [file_buf + ebx]
    cmp al, 10
    je .advance
    cmp al, 13
    je .advance
    cmp al, '#'
    je .advance

    mov edx, [file_len]
    mov esi, file_buf
    mov edi, ebx
    call scan_field
    test ecx, ecx
    jz .advance
    mov USER_END, eax

    mov esi, file_buf
    mov ecx, LINE_POS
    mov edx, USER_END
    sub edx, ecx
    mov edi, user_buf
    call str_eq_region
    mov USER_OK, eax

    mov edx, [file_len]
    mov esi, file_buf
    mov edi, USER_END
    inc edi
    call scan_field
    test ecx, ecx
    jz .advance
    mov PASS_END, eax

    cmp USER_OK, 0
    je .advance

    mov esi, file_buf
    mov ecx, USER_END
    inc ecx
    mov edx, PASS_END
    sub edx, ecx
    mov edi, pass_buf
    call str_eq_region
    test eax, eax
    jz .advance

    mov edx, [file_len]
    mov esi, file_buf
    mov edi, PASS_END
    inc edi
    call scan_field

    cmp eax, PASS_END
    jle .role_ready
    cmp byte [file_buf + eax - 1], 13
    jne .role_ready
    dec eax

.role_ready:
    mov edx, eax
    mov ecx, PASS_END
    inc ecx
    sub edx, ecx
    mov esi, file_buf
    mov edi, str_supplier
    call str_eq_region
    test eax, eax
    jnz .is_supplier

    mov eax, 2
    jmp .done

.is_supplier:
    mov eax, 1
    jmp .done

.advance:
    mov edx, [file_len]
    mov esi, file_buf
    mov edi, LINE_POS
    call next_line_idx
    cmp eax, LINE_POS
    jle .no_match
    mov LINE_POS, eax
    jmp .line

.no_match:
    xor eax, eax
    jmp .done

.file_error:
    mov eax, -1

.done:
    mov esp, ebp
    pop ebp
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

load_users:
    push ebx
    push ecx
    push edx
    push esi

    mov dword [file_len], 0

    mov eax, SYS_OPEN
    mov ebx, users_path
    xor ecx, ecx
    xor edx, edx
    int 0x80
    cmp eax, 0
    jl .fail
    mov esi, eax

    mov eax, SYS_READ
    mov ebx, esi
    mov ecx, file_buf
    mov edx, FILE_BUF_SZ
    int 0x80
    cmp eax, 0
    jl .close_fail
    mov [file_len], eax

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
