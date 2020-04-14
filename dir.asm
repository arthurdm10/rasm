           
struc DirEnt
        .d_ino          resq    1       ; inode number
        .d_off          resq    1       ; offset to next structure
        .d_reclen       resw    1       ; size of this dirent
        .d_type         resb    1       ; file type
        .d_name         resb    256       ; filename char *
endstruc


;args
dirPath         equ 0x10
dirEntsBuff     equ 0x18
direntBuffSz    equ 0x20

totalRead       equ 0x08


DT_DIR          equ 0x04
DT_REG          equ 0x08

section .data
        fmtJoinPath     db "%s/%s",0x00

get_dir_content:
        push    rbp
        mov     rbp, rsp

        sub     rsp, 0x08

        push    r10
        push    rsi
        push    rdi
        push    rdx

        ; open directory
        ; on success, returns fd in rax
        ; on fail, returns a number less than or equal to 0
        push    0x00
        push    O_RDONLY | O_DIRECTORY
        push    QWORD[rbp + dirPath]
        call    open_file
                
        cmp     r10, 0x00
        jle     ret_failed
        
        mov     rdi, rax                        ;fd
        mov     rax, 217                        ;getdents64 syscall
        mov     rsi, [rbp + dirEntsBuff]        ;buffer
        mov     rdx, [rbp + direntBuffSz]       ;buffer size
        syscall


ret_failed:
        mov     r10, rax
        push    r10
        call    close_file

        mov     rax, r10
        
        pop     rdx
        pop     rdi
        pop     rsi
        pop     r10

        leave
        ret




join_file_path:
        push    rbp
        mov     rbp, rsp

        ;dest must have enough size to store both strings
        
        ;rbp+0x10 = dest
        ;rbp+0x18 = dir path
        ;rbp+0x20 = file path
        
        mov     rdx, [rbp + 0x18]

        push    rdx
        call    __strlen

        cmp     rax, 0x00
        jle     _return_err

        cmp     byte[rdx + rax-1], '/'
        jne      _append_filename
        
        ; remove the last '/' in the dir path
        mov     byte[rdx + rax-1], 0x00

_append_filename:
        mov     rdx, [rbp + 0x20 + 0] 
        cmp     byte[rdx], '/'
        jne      _format_path

        inc     rdx           ;filename - ignore the first '/'

_format_path:
        mov     rcx, rdx
        mov     rdi, [rbp + 0x10]       ;dest
        mov     rsi, fmtJoinPath        ;format
        mov     rdx, [rbp + 0x18]       ;dir
        mov     rax, 0x00
        call    sprintf


_return_err:
        mov rax, -1

_join_filepath_ret:

        leave
        ret


