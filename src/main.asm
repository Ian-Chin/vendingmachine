global _start

extern set_guest
extern welcome_loop

section .text

_start:
    call set_guest
    jmp welcome_loop
