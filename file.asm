
STDIN           equ 0x00
STDOUT          equ 0x01
SYS_READ        equ 0x00
SYS_WRITE       equ 0x01
SYS_OPEN        equ 0x02
SYS_CLOSE       equ 0x03



O_RDONLY        equ 00
O_WRONLY        equ 01
O_RDWR          equ 02
O_CREAT         equ 0100
O_DIRECTORY     equ 0x10000

BUFF_SZ         equ 4096



struc FileType
        .name           resq    1
        .fd             resq    1
endstruc

 
section .text



open_file:
        push    rbp
        mov     rbp, rsp

        push    rdi
        push    rsi
        push    rdx  

        mov     rax, SYS_OPEN                  ; system call for open
        mov     rdi, [rbp + 0x10]               ; filename
        mov     rsi, [rbp + 0x18]                ; flags(read,write..)
        mov     rdx, [rbp + 0x20]                ; mode (file permisisons)
        syscall  

        pop    rdx
        pop    rsi
        pop    rdi

        leave
        ret        


close_file:
        push    rbp
        mov     rbp, rsp

        push    rdi

        mov     rax, SYS_CLOSE                  ; syscall close
        mov     rdi, [rbp + 0x10]               ; file descriptor
        syscall  

        pop    rdi

        leave
        ret        


write_file:
        push    rbp
        mov     rbp, rsp

        push    rax
        push    rdi
        push    rsi
        push    rdx

        mov     rax, SYS_WRITE                  ; system call for write
        mov     rdi, [rbp + 0x10]                ;file descriptor
        mov     rsi, [rbp + 0x18]                ; address of string to output
        mov     rdx, [rbp + 0x20]                ; number of bytes
        syscall                         ; invoke operating system to do the write
        
        
        pop    rdx
        pop    rsi
        pop    rdi
        pop    rax

        leave
        ret

read_file:
        push    rbp
        mov     rbp, rsp

        push    rdi
        push    rsi
        push    rdx


        mov     rax, SYS_READ                  ; system call for read
        mov     rdi, [rbp + 0x10]                ;file descriptor
        mov     rsi, [rbp + 0x18]                ; buffer
        mov     rdx, [rbp + 0x20]                ; number of bytes
        syscall                         ; invoke operating system to do the write

_done_read_file:

        pop     rdx
        pop     rsi
        pop     rdi
        
        leave
        ret
        


create_file:
        push    rbp
        mov     rbp, rsp

        push    rcx


        mov     rcx, O_CREAT
        or      rcx, O_WRONLY
        
        push    0644o
        push    rcx
        push    QWORD [rbp + 0x10]
        call    open_file

        pop rcx
        leave
        ret


delete_file:
        push    rbp
        mov     rbp, rsp

        
        mov     rax, 87
        mov     rdi, QWORD[rbp + 0x10]
        syscall

        leave
        ret
