%include "defs.inc"

global handle_exit

extern print_cstr
extern echo_on

section .data
    msg_exit       db 10, 27,"[1;35m","  Thank you. Please take your item. Goodbye!",27,"[0m",10, 0

section .text

handle_exit:
    call echo_on
    mov esi, msg_exit
    call print_cstr

    mov eax, SYS_EXIT
    xor ebx, ebx
    int 0x80
