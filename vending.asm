; ==============================================================================
; File: vending.asm
; Description: Vending Machine Terminal Interface - Main Menu (Stage 1)
; Target: Linux x86_64 (NASM syntax, Syscalls)
;
; Stage 1 scope: main menu only. Each choice routes to its own screen handler,
; which currently prints a placeholder and returns to the menu. Replace the
; bodies of the handlers below to build out each interface.
; ==============================================================================

default rel

section .data
    ; --- ANSI Formatting & Clear Screen ---
    clear_screen   db 27, "[H", 27, "[2J", 0

    ; --- Main Menu UI ---
    menu_header    db "==================================================", 10
                   db "            SNACK-O-MATIC VENDING MACHINE         ", 10
                   db "==================================================", 10
                   db "  1. Browse Products                              ", 10
                   db "  2. Insert Coins                                 ", 10
                   db "  3. Buy Item                                     ", 10
                   db "  4. Collect Change                               ", 10
                   db "  5. Machine Status                               ", 10
                   db "  X. Exit                                         ", 10
                   db "--------------------------------------------------", 10
                   db "Credit: RM 0.00", 10
                   db "--------------------------------------------------", 10
                   db "Enter your choice: ", 0

    ; --- Screen Headers (placeholders for Stage 2) ---
    hdr_browse     db 10, "--- [BROWSE PRODUCTS] ---", 10, 0
    hdr_insert     db 10, "--- [INSERT COINS] ---", 10, 0
    hdr_buy        db 10, "--- [BUY ITEM] ---", 10, 0
    hdr_change     db 10, "--- [COLLECT CHANGE] ---", 10, 0
    hdr_status     db 10, "--- [MACHINE STATUS] ---", 10, 0

    ; --- Feedback Messages ---
    msg_todo       db "  [INFO] This screen is not built yet.", 10, 0
    msg_err_choice db 10, "[ERROR] Invalid menu option selected!", 10, 0
    msg_pause      db 10, "Press ENTER to return to menu...", 0
    msg_exit       db 10, "Thank you. Please take your item. Goodbye!", 10, 0
    newline        db 10, 0

section .bss
    choice_buf     resb 16
    temp_buf       resb 64

section .text
    global _start

_start:

menu_loop:
    ; 1. Clear screen and display Menu UI
    mov rsi, clear_screen
    call print_cstr

    mov rsi, menu_header
    call print_cstr

    ; 2. Read user choice
    mov rdi, choice_buf
    mov rsi, 16
    call read_line

    ; Stdin closed (EOF) or read error: leave instead of looping forever
    cmp rax, 0
    jle handle_exit

    ; Reject empty input
    cmp byte [choice_buf], 0
    je invalid_choice

    ; 3. Route choice on first character
    mov al, byte [choice_buf]

    cmp al, '1'
    je handle_browse

    cmp al, '2'
    je handle_insert

    cmp al, '3'
    je handle_buy

    cmp al, '4'
    je handle_change

    cmp al, '5'
    je handle_status

    cmp al, 'X'
    je handle_exit
    cmp al, 'x'
    je handle_exit
    cmp al, '6'
    je handle_exit

invalid_choice:
    mov rsi, msg_err_choice
    call print_cstr
    call pause_prompt
    jmp menu_loop

; ==============================================================================
; [1] BROWSE PRODUCTS
; ==============================================================================
handle_browse:
    mov rsi, hdr_browse
    call print_cstr
    mov rsi, msg_todo
    call print_cstr
    call pause_prompt
    jmp menu_loop

; ==============================================================================
; [2] INSERT COINS
; ==============================================================================
handle_insert:
    mov rsi, hdr_insert
    call print_cstr
    mov rsi, msg_todo
    call print_cstr
    call pause_prompt
    jmp menu_loop

; ==============================================================================
; [3] BUY ITEM
; ==============================================================================
handle_buy:
    mov rsi, hdr_buy
    call print_cstr
    mov rsi, msg_todo
    call print_cstr
    call pause_prompt
    jmp menu_loop

; ==============================================================================
; [4] COLLECT CHANGE
; ==============================================================================
handle_change:
    mov rsi, hdr_change
    call print_cstr
    mov rsi, msg_todo
    call print_cstr
    call pause_prompt
    jmp menu_loop

; ==============================================================================
; [5] MACHINE STATUS
; ==============================================================================
handle_status:
    mov rsi, hdr_status
    call print_cstr
    mov rsi, msg_todo
    call print_cstr
    call pause_prompt
    jmp menu_loop

; ==============================================================================
; [X] EXIT
; ==============================================================================
handle_exit:
    mov rsi, msg_exit
    call print_cstr

    ; sys_exit(0)
    mov rax, 60
    xor rdi, rdi
    syscall

; ==============================================================================
; UTILITY AND HELPER FUNCTIONS
; ==============================================================================

; ------------------------------------------------------------------------------
; print_cstr: Prints null-terminated string at rsi
; ------------------------------------------------------------------------------
print_cstr:
    push rax
    push rdi
    push rdx
    push rcx

    ; Compute string length
    mov rdx, 0
.len_loop:
    cmp byte [rsi + rdx], 0
    je .len_found
    inc rdx
    jmp .len_loop

.len_found:
    test rdx, rdx
    jz .done

    mov rax, 1          ; sys_write
    mov rdi, 1          ; stdout
    syscall

.done:
    pop rcx
    pop rdx
    pop rdi
    pop rax
    ret

; ------------------------------------------------------------------------------
; read_line: Reads line from stdin into buffer at rdi (max rsi-1 bytes)
; Null terminates and strips newline / carriage return.
; Returns rax = bytes read by sys_read (0 = EOF, negative = error).
; ------------------------------------------------------------------------------
read_line:
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push r12
    push r13

    mov rbx, rdi        ; destination buffer
    mov r12, rsi        ; max buffer size
    dec r12             ; reserve one byte for the null terminator

    ; sys_read(0, temp_buf, 63)
    mov rax, 0          ; sys_read
    mov rdi, 0          ; stdin
    mov rsi, temp_buf
    mov rdx, 63
    syscall
    mov r13, rax        ; keep byte count for the return value

    ; If rax <= 0, treat as empty string
    cmp rax, 0
    jle .empty_str

    ; Copy chars to destination, stopping at newline, CR, or buffer limit
    xor rcx, rcx
.copy_loop:
    cmp rcx, rax
    jge .terminate
    cmp rcx, r12
    jge .terminate

    mov dl, byte [temp_buf + rcx]
    cmp dl, 10          ; '\n'
    je .terminate
    cmp dl, 13          ; '\r'
    je .terminate

    mov byte [rbx + rcx], dl
    inc rcx
    jmp .copy_loop

.terminate:
    mov byte [rbx + rcx], 0
    jmp .read_done

.empty_str:
    mov byte [rbx], 0

.read_done:
    mov rax, r13        ; return byte count
    pop r13
    pop r12
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

; ------------------------------------------------------------------------------
; pause_prompt: Displays pause message and waits for user to press ENTER
; ------------------------------------------------------------------------------
pause_prompt:
    push rax
    push rdi
    push rsi
    push rdx

    mov rsi, msg_pause
    call print_cstr

    ; Consume one line from stdin
    mov rax, 0          ; sys_read
    mov rdi, 0          ; stdin
    mov rsi, temp_buf
    mov rdx, 64
    syscall

    pop rdx
    pop rsi
    pop rdi
    pop rax
    ret
