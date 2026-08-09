org 0x7C00
bits 16

start:
    xor ax, ax
    mov ss, ax
    mov sp, 0x7C00
    mov ds, ax
    mov es, ax

    mov si, msg
    call print

    mov ax, 0x0000
    mov es, ax
    mov bx, 0x7E00
    mov ah, 0x02
    mov al, 49
    mov ch, 0
    mov cl, 2
    mov dh, 0
    mov dl, 0x80
    int 0x13
    jc error

    jmp 0x0000:0x7E00

error:
    mov si, err_msg
    call print
    jmp $

print:
    lodsb
    test al, al
    jz .done
    mov ah, 0x0E
    int 0x10
    jmp print
.done:
    ret

msg:
    db "Loading...", 0
err_msg:
    db "Error!", 0

times 446 - ($ - $$) db 0
times 64 db 0
dw 0xAA55