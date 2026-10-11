%include "defs.inc"

global handle_logout

extern zero_buf
extern set_guest
extern current_user
extern user_buf
extern welcome_loop

section .text

handle_logout:
    lea edi, [current_user]
    mov esi, NAME_MAX
    call zero_buf
    lea edi, [user_buf]
    mov esi, NAME_MAX
    call zero_buf
    call set_guest
    jmp welcome_loop
