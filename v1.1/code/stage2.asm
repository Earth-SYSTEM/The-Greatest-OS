org 0x7E00
bits 16

start_shell:
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov si, welcome
    call print

main_loop:
    mov si, prompt
    call print
    mov di, cmd_buf
    call read_line
    call parse_cmd
    jmp main_loop

print:
    lodsb
    test al, al
    jz .done
    mov ah, 0x0E
    int 0x10
    jmp print
.done:
    ret

newline:
    mov ah, 0x0E
    mov al, 0x0D
    int 0x10
    mov al, 0x0A
    int 0x10
    ret

read_line:
    xor bx, bx
.loop:
    mov ah, 0x00
    int 0x16
    cmp al, 0x0D
    je .done
    cmp al, 0x08
    je .backspace
    cmp al, 0x20
    jb .loop
    stosb
    inc bx
    mov ah, 0x0E
    int 0x10
    jmp .loop
.backspace:
    test bx, bx
    jz .loop
    dec bx
    dec di
    mov ah, 0x0E
    mov al, 0x08
    int 0x10
    mov al, 0x20
    int 0x10
    mov al, 0x08
    int 0x10
    jmp .loop
.done:
    mov al, 0x00
    stosb
    mov ah, 0x0E
    mov al, 0x0D
    int 0x10
    mov al, 0x0A
    int 0x10
    ret

strcmp:
    push si
    push di
.loop:
    lodsb
    mov ah, [di]
    cmp al, ah
    jne .not_eq
    test ah, ah
    jz .eq
    inc di
    jmp .loop
.eq:
    stc
    jmp .done
.not_eq:
    clc
.done:
    pop di
    pop si
    ret

parse_cmd:
    mov si, cmd_buf
    mov di, cmd_help
    call strcmp
    jc do_help

    mov di, cmd_reboot
    call strcmp
    jc do_reboot

    mov di, cmd_ver
    call strcmp
    jc do_ver

    mov si, unknown_msg
    call print
    ret

do_help:
    mov si, help_msg
    call print
    ret

do_reboot:
    mov ax, 0x0003
    int 0x10
    jmp 0xFFFF:0x0000
    ret

do_ver:
    mov si, ver_msg
    call print
    ret

welcome:
    db "The Greatest OS - 16-bit Shell", 0x0D, 0x0A
    db "Type 'help' for commands", 0x0D, 0x0A, 0

prompt:
    db 0x0D, 0x0A, "TheGOS>", 0

unknown_msg:
    db "Unknown command", 0x0D, 0x0A, 0

help_msg:
    db 0x0D, 0x0A
    db "Commands:", 0x0D, 0x0A
    db "  help     - Show this help", 0x0D, 0x0A
    db "  reboot   - Reboot system", 0x0D, 0x0A
    db "  ver      - Show version", 0x0D, 0x0A, 0

ver_msg:
    db 0x0D, 0x0A
    db "The Greatest OS v1.1", 0x0D, 0x0A
    db "16-bit mode", 0x0D, 0x0A
    db "Build: 2026-08-08", 0x0D, 0x0A, 0

cmd_help:   db "help", 0
cmd_reboot: db "reboot", 0
cmd_ver:    db "ver", 0

cmd_buf:
    times 64 db 0

times 49*512 - ($ - $$) db 0