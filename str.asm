[BITS 64]
global  __strlen
global  __find
global  __strchr
global  __set
global  __strcat
global __stresize
global __strchrcount
global __streverse


section .text
;extern "C" void         __streverse(char *src);
;reverse string 'str'
__streverse:
    push rbp
    mov rbp, rsp

    ;rdi str

    xor rcx, rcx

    call __strlen                               ;get string size
    cmp rax, 0x00                               ;check if its not empty
    je _doneReverse

    dec rax
    lea rsi, [rdi + rax]
    lea rdi, [rdi]

    mov rcx, rax
    inc rcx
    shr rcx,0x1
    std                                             ;set direction flag
_revLoop:
    mov dl, byte[rdi]
    lodsb
    mov byte[rdi], al
    mov byte[rsi + 1], dl
    inc rdi
    loop _revLoop

    cld
    lea rdi, [rdi-4]


_doneReverse:
    xor rax, rax
    pop rbp
    ret




;extern "C" int          __strchrcount(const char *str, char c);
__strchrcount:
    push rbp
    mov rbp, rsp


    ;rdi str
    ;rsi c
    xor rcx, rcx

    call __strlen
    cmp rax, 0x00
    je  _done

    mov dl, sil

    lea rsi, [rdi]                              ;rsi points to 'str'

_countChr:
    lodsb
    cmp al, 0x00
    je _done

    cmp al, dl
    jne _countChr
    inc rcx
    jmp _countChr

_done:
    pop rbp
    mov rax, rcx
    ret


;extern "C" void __stresize(char* dst, const int& n);
;resize 'dst' to 'n' elements
__stresize:
    ;rdi dst
    ;rsi n
    push     rbp
    mov      rbp, rsp
    sub rsp, 0x8

    cmp dword[rsi], 0x00
    jl  _return

    call __strlen
    cmp eax, dword[rsi]                        ;check if n is bigger than dst size
    jbe _return

    push rdi
    xor rax, rax
    mov eax, dword[rsi]

    lea rdi, [rdi + rax]
    mov byte[rdi], 0x00
    pop rdi

_return:
    leave
    ret






;char *__strcat(char *dest, const char *src);
;concat src to dest, return pointer to first char of 'src' in 'dest'
;dest must have enough space to concat 'src' + null terminator
__strcat:
    ;rdi dest
    ;rsi src
    push        rbp
    mov         rbp, rsp
    sub         rsp, 0x08

    call __strlen                               ;get the size of 'dest' in byte
    lea rdi,[rdi + rax]                         ;point rdi to the end of 'dest'
    lea r8,[rdi]                                ;keep r8 pointing to the end of 'dest'

    push rdi                                    ;put rdi on the stack
    mov rdi, rsi                                ;move rsi to rdi, so we can call __strlen
    call __strlen                               ;size of 'src' in bytes
    mov rcx, rax
    pop rdi                                             ;restore rdi('dest' string)

    cld                                                 ;clear the direction flag
    inc rcx                                            ;increment rcx, to get the null terminator from 'src'
    rep movsb                                           ;copy bytes from rsi into rdi


    lea rax, [r8]                                       ;rax point to the end of 'dest'

    mov rsp, rbp
    pop rbp
    ret






;;char* __strchr(const char* str, const char& c);
;;return a pointer to the first 'c' in 'str'
__strchr:
    ;rdi str
    ;rsi c
    push        rbp
    mov         rbp, rsp

    mov cl, byte[rsi]
    lea rsi, [rdi]                  ;;load the pointer into  rsi
    xor al, al

_loop:
    lodsb
    cmp al, cl             ;;found
    je  _found

    cmp al, 0x00            ;;end of the string
    je  _nfound

    jmp _loop


_nfound:
    mov rsi,0x01

_found:
    dec rsi
    mov rax, rsi                ;;get the address of the char
    leave
    ret



;;__find(const int* vet, int sz, int value);
;;look for a value in a int array
__find:
    ;;rdi  = array
    ;;rsi = size of the array
    ;;rdx = value to find

    push        rbp
    mov         rbp, rsp

    mov rax, rdi                    ;first address of the vector
    xor rcx, rcx                    ;set rcx to 0, will be used to count

_search:
    cmp  DWORD[rax], edx            ;value in eax == value we want?
                                    ;use DWORD, int size is 4 bytes
    je _doneFind

    cmp rcx, rsi
    je _notfound

    inc rcx
    lea rax, [rax + 0x4]
    jmp _search

_notfound:
    mov rcx, -0x1
_doneFind:
    mov rax, rcx
    leave
    ret





