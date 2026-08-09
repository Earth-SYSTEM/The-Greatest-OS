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

strcmp_prefix:
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

strcmp_filename:
    push si
    push di
    push cx
    push ax
    mov cx, 11
.loop:
    lodsb
    cmp al, '.'
    je .skip_ext
    cmp al, 0
    je .pad
    cmp al, 'a'
    jb .not_lower
    cmp al, 'z'
    ja .not_lower
    sub al, 0x20
.not_lower:
    mov ah, [di]
    cmp al, ah
    jne .not_eq
    inc di
    loop .loop
    jmp .eq
.skip_ext:
    mov al, ' '
    cmp al, [di]
    jne .not_eq
    inc di
    jmp .loop
.pad:
    mov ah, [di]
    cmp ah, ' '
    jne .not_eq
    inc di
    loop .pad
    jmp .eq
.eq:
    stc
    jmp .done
.not_eq:
    clc
.done:
    pop ax
    pop cx
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

    mov di, cmd_dir
    call strcmp
    jc do_dir

    mov di, cmd_type
    call strcmp_prefix 
    jc do_type

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

do_ver:
    mov si, ver_msg
    call print
    ret

do_dir:
    call fat_init
    mov si, ROOT_DIR_ADDR
    mov cx, [root_entries]
.dir_loop:
    cmp byte [si], 0x00
    je .dir_done
    cmp byte [si], 0xE5
    je .dir_next
    call print_filename
    call newline
.dir_next:
    add si, 32
    loop .dir_loop
.dir_done:
    ret

type_debug_msg:
    db "[TYPE] ", 0

do_type:
    call fat_init

    ; 跳过 "type "
    mov si, cmd_buf + 4

    ; 跳过可能存在的空格
.skip_space:
    lodsb
    cmp al, ' '
    je .skip_space
    dec si

    ; 如果没有文件名 → 直接返回
    cmp byte [si], 0
    je .done

    ; 在根目录中查找文件
    mov di, ROOT_DIR_ADDR
    mov cx, [root_entries]
.find_loop:
    cmp byte [di], 0x00
    je .not_found
    cmp byte [di], 0xE5
    je .next
    call strcmp_filename
    jc .found
.next:
    add di, 32
    loop .find_loop

.not_found:
    mov si, not_found_msg
    call print
    ret

.found:
    mov ax, [di+0x1A]
    call read_file_by_cluster
.done:
    ret

print_filename:
    pusha
    mov di, si
    mov cx, 8
.name_loop:
    mov al, [di]
    cmp al, ' '
    je .name_skip
    call print_char
.name_skip:
    inc di
    loop .name_loop
    mov al, '.'
    call print_char
    mov cx, 3
.ext_loop:
    mov al, [di]
    cmp al, ' '
    je .ext_skip
    call print_char
.ext_skip:
    inc di
    loop .ext_loop
    popa
    ret

print_char:
    pusha
    mov ah, 0x0E
    int 0x10
    popa
    ret

fat_init:
    pusha
    mov ax, 0x0000
    mov es, ax
    mov bx, BUFFER_ADDR
    call read_sector
    mov ax, [BUFFER_ADDR + 0x0E]
    mov [reserved_sectors], ax
    mov ax, [BUFFER_ADDR + 0x16]
    mov [sectors_per_fat], ax
    mov ax, [BUFFER_ADDR + 0x11]
    mov [root_entries], ax
    movzx ax, byte [BUFFER_ADDR + 0x10]
    mov [fat_count], ax
    mov ax, [reserved_sectors]
    mov cx, [sectors_per_fat]
    mov bx, FAT_TABLE_ADDR
    call read_sectors
    mov ax, [reserved_sectors]
    add ax, [fat_count]
    mul word [sectors_per_fat]
    mov [root_start], ax
    mov cx, [root_entries]
    shr cx, 4
    mov bx, ROOT_DIR_ADDR
    call read_sectors
    popa
    ret

read_file_by_cluster:
    pusha
    mov bx, FAT_TABLE_ADDR
.read_loop:
    cmp ax, 0xFFF8
    jae .read_done
    push ax
    sub ax, 2
    push ax
    mul word [sectors_per_cluster]
    add ax, [root_start]
    add ax, [reserved_sectors]
    add ax, [fat_count]
    mul word [sectors_per_fat]
    add ax, [root_start]
    call read_sector
    mov si, BUFFER_ADDR
    call print
    pop ax
    mov cx, ax
    shl cx, 1
    add bx, cx
    mov ax, [bx]
    jmp .read_loop
.read_done:
    popa
    ret

read_sector:
    pusha
    mov ah, 0x02
    mov al, 0x01
    mov cx, ax
    mov dh, 0x00
    mov dl, 0x80
    int 0x13
    popa
    ret

read_sectors:
    pusha
    mov ah, 0x02
    mov dl, 0x80
    int 0x13
    popa
    ret

BUFFER_ADDR          equ 0x3000
FAT_TABLE_ADDR       equ 0x1000
ROOT_DIR_ADDR        equ 0x2000

reserved_sectors:    dw 0
sectors_per_fat:     dw 0
root_entries:        dw 0
fat_count:           dw 0
root_start:          dw 0
sectors_per_cluster: db 0

welcome:
    db "The Greatest OS v1.2 - FAT16", 0x0D, 0x0A
    db "Type 'help' for commands", 0x0D, 0x0A, 0

prompt:
    db 0x0D, 0x0A, "TheGOS>", 0

unknown_msg:
    db "Unknown command", 0x0D, 0x0A, 0

not_found_msg:
    db "File not found", 0x0D, 0x0A, 0

help_msg:
    db 0x0D, 0x0A
    db "Commands:", 0x0D, 0x0A
    db "  help     - Show this help", 0x0D, 0x0A
    db "  reboot   - Reboot system", 0x0D, 0x0A
    db "  ver      - Show version", 0x0D, 0x0A
    db "  dir      - List files", 0x0D, 0x0A
    db "  type     - Show file content", 0x0D, 0x0A, 0

ver_msg:
    db 0x0D, 0x0A
    db "The Greatest OS v1.2", 0x0D, 0x0A
    db "16-bit mode + FAT16", 0x0D, 0x0A
    db "Build: 2026-08-08", 0x0D, 0x0A, 0

cmd_help:   db "help", 0
cmd_reboot: db "reboot", 0
cmd_ver:    db "ver", 0
cmd_dir:    db "dir", 0
cmd_type:   db "type", 0

cmd_buf:
    times 64 db 0

times 49*512 - ($ - $$) db 0