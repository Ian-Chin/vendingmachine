TCGETS         equ 0x5401
TCSETS         equ 0x5402
ECHO_BIT       equ 0x08
LFLAG_OFF      equ 12

FILE_BUF_SZ    equ 4096
NAME_MAX       equ 32

; Slot capacity per product, shown as stock/max in the product table.
MAX_STOCK      equ 10
%define MAX_STOCK_STR "10"

; i386 syscall numbers (int 0x80: eax = number, ebx/ecx/edx = args)
SYS_EXIT       equ 1
SYS_READ       equ 3
SYS_WRITE      equ 4
SYS_OPEN       equ 5
SYS_CLOSE      equ 6
SYS_RENAME     equ 38
SYS_IOCTL      equ 54

; open() flags
O_WRONLY       equ 0x001
O_CREAT        equ 0x040
O_TRUNC        equ 0x200
