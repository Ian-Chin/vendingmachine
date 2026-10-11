global handle_report

extern show_todo
extern is_supplier
extern deny_supplier

section .data
    hdr_report db 10, 27,"[1;33m","--- [SALES REPORT] ---",27,"[0m",10, 0

section .text

handle_report:
    cmp byte [is_supplier], 0
    je deny_supplier
    lea esi, [hdr_report]
    jmp show_todo
