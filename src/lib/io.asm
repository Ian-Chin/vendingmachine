%include "defs.inc"

global print_cstr
global print_n
global print_uint
global pad_spaces
global read_line
global pause_prompt
global copy_cstr
global zero_buf
global newline
global num_buf

section .data
    newline        db 10, 0
    spaces32       db "                                ", 0
    msg_pause      db 10, 27,"[0;36m","  Press ENTER to continue...",27,"[0m",0

section .bss
    temp_buf       resb 64
    num_buf        resb 24

section .text

print_cstr:
    push eax
    push ebx
    push ecx
    push edx

    xor edx, edx
.len_loop:
    cmp byte [esi + edx], 0
    je .len_found
    inc edx
    jmp .len_loop

.len_found:
    test edx, edx
    jz .done

    mov eax, SYS_WRITE
    mov ebx, 1
    mov ecx, esi
    int 0x80

.done:
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

print_n:
    push eax
    push ebx
    push ecx
    push edx

    cmp edx, 0
    jle .done
    mov eax, SYS_WRITE
    mov ebx, 1
    mov ecx, esi
    int 0x80

.done:
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

print_uint:
    push ebx
    push ecx
    push edx
    push esi
    push edi

    mov eax, edi
    mov ebx, 10
    mov ecx, 24

.conv:
    dec ecx
    xor edx, edx
    div ebx
    add dl, '0'
    mov byte [num_buf + ecx], dl
    test eax, eax
    jnz .conv

    mov edx, 24
    sub edx, ecx
    lea esi, [num_buf + ecx]
    call print_n
    mov eax, edx

    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

pad_spaces:
    push edx
    push esi
    push edi

    cmp edi, 0
    jle .done
    cmp edi, 32
    jle .sized
    mov edi, 32
.sized:
    mov esi, spaces32
    mov edx, edi
    call print_n

.done:
    pop edi
    pop esi
    pop edx
    ret

; edi = buffer, esi = buffer size. Returns eax = bytes consumed (<= 0 on EOF/error).
read_line:
    push ebx
    push ecx
    push edx
    push esi
    push edi
    push ebp

    mov ebp, edi            ; ebp = buffer
    dec esi
    push esi                ; [esp] = max chars to store
    xor edi, edi            ; edi = chars stored
    xor esi, esi            ; esi = bytes read

.next_byte:
    mov eax, SYS_READ
    xor ebx, ebx
    mov ecx, temp_buf
    mov edx, 1
    int 0x80
    cmp eax, 0
    jle .finish

    inc esi
    mov dl, byte [temp_buf]
    cmp dl, 10
    je .finish
    cmp dl, 13
    je .next_byte

    cmp edi, [esp]
    jge .next_byte

    mov byte [ebp + edi], dl
    inc edi
    jmp .next_byte

.finish:
    mov byte [ebp + edi], 0
    test esi, esi
    jz .read_done
    mov eax, esi

.read_done:
    add esp, 4
    pop ebp
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

pause_prompt:
    push eax
    push ebx
    push ecx
    push edx
    push esi

    mov esi, msg_pause
    call print_cstr

.wait:
    mov eax, SYS_READ
    xor ebx, ebx
    mov ecx, temp_buf
    mov edx, 1
    int 0x80
    cmp eax, 0
    jle .done
    cmp byte [temp_buf], 10
    jne .wait

.done:
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

copy_cstr:
    push eax
    push ecx

    xor ecx, ecx
.loop:
    cmp ecx, NAME_MAX - 1
    jge .cap
    mov al, byte [esi + ecx]
    mov byte [edi + ecx], al
    test al, al
    jz .done
    inc ecx
    jmp .loop

.cap:
    mov byte [edi + ecx], 0
.done:
    pop ecx
    pop eax
    ret

; edi = buffer, esi = size. Wipes the buffer back to front with LOOP.
zero_buf:
    push ecx

    mov ecx, esi
    cmp ecx, 0
    jle .done
.loop:
    mov byte [edi + ecx - 1], 0
    loop .loop              ; ecx--, repeat while ecx != 0

.done:
    pop ecx
    ret
