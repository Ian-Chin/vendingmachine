%include "defs.inc"

global echo_off
global echo_on

section .data
    echo_saved     db 0

section .bss
    termios_orig   resb 64
    termios_new    resb 64

section .text

echo_off:
    push eax
    push ebx
    push ecx
    push edx

    mov byte [echo_saved], 0

    mov eax, SYS_IOCTL
    xor ebx, ebx
    mov ecx, TCGETS
    mov edx, termios_orig
    int 0x80
    cmp eax, 0
    jl .done

    mov ecx, 64
.copy:
    mov bl, byte [termios_orig + ecx - 1]
    mov byte [termios_new + ecx - 1], bl
    loop .copy              ; ecx--, repeat while ecx != 0

.copied:
    mov eax, dword [termios_new + LFLAG_OFF]
    and eax, ~ECHO_BIT
    mov dword [termios_new + LFLAG_OFF], eax

    mov eax, SYS_IOCTL
    xor ebx, ebx
    mov ecx, TCSETS
    mov edx, termios_new
    int 0x80
    cmp eax, 0
    jl .done

    mov byte [echo_saved], 1

.done:
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

echo_on:
    push eax
    push ebx
    push ecx
    push edx

    cmp byte [echo_saved], 0
    je .done

    mov eax, SYS_IOCTL
    xor ebx, ebx
    mov ecx, TCSETS
    mov edx, termios_orig
    int 0x80
    mov byte [echo_saved], 0

.done:
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret
