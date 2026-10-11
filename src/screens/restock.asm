global handle_restock

extern show_todo
extern is_supplier
extern deny_supplier

section .data
    hdr_restock db 10, 27,"[1;33m","--- [RESTOCK MACHINE] ---",27,"[0m",10, 0

section .text

handle_restock:
    cmp byte [is_supplier], 0
    je deny_supplier
    lea esi, [hdr_restock]
    jmp show_todo
