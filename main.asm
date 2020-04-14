; %include "str_funcs.asm"

%include "file.asm"
%include "dir.asm"
; %include "str.asm"

extern printf
extern strcmp
extern sprintf
extern malloc
extern free 
extern AES_init_ctx 

DIRENT_BUFF_SZ        equ 4096



section .data
        openfile_error          db "Failed to open file",0xa,0x00
        openfile_error_len      equ $-openfile_error

        readdir_error           db "Failed to readdir",0xa,0x00
        readdir_error_len       equ $-readdir_error

        fmtReadFileFailed       db "Failed to read file '%s' error code %d", 0x0a, 0x00
        fmtTotalRead            db "Read %d from file", 0x0a, 0x00

        dirpath                 db "/home/frost/asm", 0x00
        
        newLine                 db 0xa, 0x00

        fmtPrintFilename        db "%s",0x0a, 0x00
        fmtHex                  db "%x", 0x0a, 0x00
        fmtDec                  db "%d", 0x0a, 0x00

        errFailedToMalloc       db "Failed to allocate memory", 0x0a, 0x00
        dotdotDir               db "..", 0x00
        dotDir                  db ".", 0x00
        delfile                 db "ee.txt", 0x00

section .bss
        file_fd                 resq 1
        fileBuffer              resb BUFF_SZ

        
        
global    _start


section   .text
_start: 

        push    rbp
        mov     rbp, rsp

        push    delfile
        call    delete_file

        ; push    dirpath
        ; call    get_dir_files_rec

        jmp     exit_0

get_dir_files_rec:
        ; arguments
        directory               equ 0x10

        ; local variables
        bufferPtr               equ 0x10
        totalDirEntsSize        equ 0x18
        filePath                equ 0x20

        push    rbp
        mov     rbp, rsp
        sub     rsp, 0x48

        ; allocate memory for dirents structs
        mov     rdi, DIRENT_BUFF_SZ
        call    malloc
        test    rax, rax
        jz      exit_0
        mov     QWORD[rbp - bufferPtr], rax


        ; allocate memory for file path
        mov     rdi, 0xff
        call    malloc
        test    rax, rax
        jz      exit_0
        mov     QWORD[rbp - filePath], rax



        push    DIRENT_BUFF_SZ
        push    QWORD[rbp - bufferPtr]
        push    QWORD[rbp + directory]       ; dir path
        call    get_dir_content

        cmp     rax, 0x00
        jg      read_dirent


        mov     rdi, fmtDec
        mov     rsi, rax
        mov     rax, 0x00
        call    printf

        push    readdir_error_len
        push    readdir_error
        call    write_stdout


        push    QWORD[rbp + directory]
        call    __strlen


        push    rax
        push    QWORD[rbp + directory]
        call    write_stdout

        jmp     _ret_get_dir_files

read_dirent:
        xor     r15, r15
        mov     QWORD[rbp-totalDirEntsSize], rax

read_next_dirent:
        mov     rbx, [rbp - bufferPtr]
        lea     rbx, [rbx + r15]

        lea     rsi, [rbx + DirEnt.d_name]

        
        ; check for ".." 
        mov     rdi, dotdotDir
        call    strcmp
        cmp     rax, 0x00
        je      _next_offset

        ; check for "."
        mov     rdi, dotDir
        call    strcmp
        cmp     rax, 0x00
        je      _next_offset



        push    rsi
        push    QWORD [rbp + directory]
        push    QWORD [rbp - filePath]
        call    join_file_path


        cmp     BYTE[rbx + DirEnt.d_type], DT_REG
        je      _print_reg_file

        push    rsi
        push    rdi
        push    rax
        push    rbx
        push    rcx
        push    r15

        push    QWORD [rbp - filePath]
        call    get_dir_files_rec
        pop     r10

        pop     r15
        pop     rcx
        pop     rbx
        pop     rax
        pop     rdi
        pop     rsi


        jmp     _next_offset

_print_reg_file:
        push    QWORD [rbp - filePath]
        call    __strlen

        push    rax
        push    QWORD [rbp - filePath]
        call    write_stdout

        push    1
        push    newLine
        call    write_stdout

        ;; read file content
        push    0x00                                    ; no need for permissions
        push    O_RDONLY                                ; open mode
        push    QWORD [rbp - filePath]                            ; file path
        call    open_file

        cmp     rax, 0x00
        jle     openfile_failed

        mov     QWORD[file_fd], rax
        xor     r10, r10

        push    BUFF_SZ
        push    fileBuffer
        push    QWORD[file_fd]
_read_loop:
        call    read_file
        add     r10, rax

        cmp     rax, 0x00       
        jg      _read_loop

        mov     rdi, fmtTotalRead
        mov     rsi, r10
        mov     rax, 0x00
        call    printf

        push    QWORD[file_fd]
        call    close_file

_next_offset:
        ; get the size of this struct
        ; so we can get the next one
        lea     rcx, [rbx + DirEnt.d_reclen]
        movzx   rax, word[rcx]
        add     r15, rax
        
        cmp     r15, QWORD[rbp-totalDirEntsSize]
        jl      read_next_dirent
        
_ret_get_dir_files:
        leave
        ret





openfile_failed:
        push    openfile_error_len
        push    openfile_error
        call    write_stdout

        jmp     exit_0    

readfile_failed:
        mov     rdi, fmtReadFileFailed
        mov     rsi, filePath
        mov     rcx, rax
        mov     rax, 0x00
        call    printf

        jmp     exit_0

exit_0:
        mov     rax, 60                 ; system call for exit
        xor     rdi, rdi                ; exit code 0
        syscall                           ; invoke operating system to exit


write_stdout:
        push    rbp
        mov     rbp, rsp

        push    QWORD [rbp + 0x18]
        push    QWORD [rbp + 0x10]
        
        push    STDOUT
        call    write_file

        leave    
        ret

        

;;strlen function
__strlen:
    push        rbp
    mov         rbp, rsp


    push    rsi
    push    rcx
    push    rdi

    ;rdi str
    xor rcx, rcx                        ;set rcx to 0, will be used to count
    mov rsi, [rbp + 0x10]

_count:
    lodsb
    cmp al,0x00
    je _doneStrLen
    inc rcx
    jmp _count


_doneStrLen:
    mov rax, rcx

    pop rdi
    pop rcx
    pop rsi
    
    leave                                       ;destroy stackframe
    ret
