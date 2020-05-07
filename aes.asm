extern AES_init_ctx_iv 
extern AES_ECB_encrypt
extern AES_ECB_decrypt
extern AES_CBC_encrypt_buffer
extern AES_CBC_decrypt_buffer

struc AES_Ctx
        .round_key  resb    176
        .iv         resb    16 
endstruc


section .data
        aesKey      db       0x2b, 0x7e, 0x15, 0x16, 0x28, 0xae, 0xd2, 0xa6, 0xab, 0xf7, 0x15, 0x88, 0x09, 0xcf, 0x4f, 0x3c
        aesIV       db       0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f
section .bss
        aesCtx      resb     AES_Ctx_size
        

section .text
init_aes_ctx:
        push    rbp
        mov     rbp, rsp

        mov     rdi, aesCtx
        mov     rsi, aesKey
        mov     rdx, aesIV
        call    AES_init_ctx_iv

        mov     rax, aesCtx

        leave
        ret

