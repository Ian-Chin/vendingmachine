global handle_price

extern show_todo
extern is_supplier
extern deny_supplier

section .data
    hdr_price db 10, 27,"[1;33m","--- [PRICE EDITOR] ---",27,"[0m",10, 0

section .text

handle_price:
    cmp byte [is_supplier], 0
    je deny_supplier
    lea esi, [hdr_price]
    jmp show_todo
