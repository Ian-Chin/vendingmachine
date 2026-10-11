global handle_change

extern print_cstr
extern print_uint
extern print_price
extern pad_spaces
extern pause_prompt
extern clear_screen
extern cash
extern change_due
extern menu_loop

section .data
    change_ui:
        db 10
        db 27,"[1;32m","==================================================",27,"[0m",10
        db 27,"[1;33m","         C O L L E C T   C H A N G E",27,"[0m",10
        db 27,"[1;32m","==================================================",27,"[0m",10, 0

    msg_none       db 27,"[0;37m","  [INFO] The change tray is empty.",27,"[0m",10,0
    msg_total      db 27,"[1;36m","  Collecting: ",27,"[1;37m",0
    color_reset    db 27,"[0m",10,0
    coin_head:
        db 10,27,"[1;37m","  COIN       QTY",27,"[0m",10
        db 27,"[0;36m","  ----------------",27,"[0m",10, 0
    row_indent     db "  ",27,"[1;32m",0
    qty_mark       db 27,"[0;37m","x ",27,"[1;33m",0
    other_lbl      db "  ",27,"[0;37m","Other: ",27,"[1;32m",0
    msg_take       db 10,27,"[1;32m","  [OK] Change added to your cash. Cash now: ",27,"[1;37m",0

    ; Change is paid out in coins, largest first.
    coins          dd 100, 50, 20, 10
    COIN_COUNT     equ ($ - coins) / 4

section .text

handle_change:
    lea esi, [clear_screen]
    call print_cstr
    lea esi, [change_ui]
    call print_cstr

    mov ebx, [change_due]
    test ebx, ebx
    jz .nothing

    lea esi, [msg_total]
    call print_cstr
    mov edi, ebx
    call print_price
    lea esi, [color_reset]
    call print_cstr

    lea esi, [coin_head]
    call print_cstr

    xor ebp, ebp            ; ebp = coin index, ebx = amount left
.coin:
    cmp ebp, COIN_COUNT
    jge .remainder
    mov ecx, [coins + ebp*4]
    mov eax, ebx
    xor edx, edx
    div ecx
    mov ebx, edx
    test eax, eax
    jz .next_coin

    mov edx, eax            ; edx = quantity
    lea esi, [row_indent]
    call print_cstr
    mov edi, ecx
    call print_price
    mov edi, 11
    sub edi, eax
    call pad_spaces
    lea esi, [qty_mark]
    call print_cstr
    mov edi, edx
    call print_uint
    lea esi, [color_reset]
    call print_cstr

.next_coin:
    inc ebp
    jmp .coin

; Only reachable if a price in products.txt is not a multiple of 10 sen.
.remainder:
    test ebx, ebx
    jz .paid_out
    lea esi, [other_lbl]
    call print_cstr
    mov edi, ebx
    call print_price
    lea esi, [color_reset]
    call print_cstr

.paid_out:
    mov eax, [change_due]
    add [cash], eax
    mov dword [change_due], 0
    lea esi, [msg_take]
    call print_cstr
    mov edi, [cash]
    call print_price
    lea esi, [color_reset]
    call print_cstr
    jmp .out

.nothing:
    lea esi, [msg_none]
    call print_cstr
.out:
    call pause_prompt
    jmp menu_loop
