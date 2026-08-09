; ============================================
; Earth-SYSTEM OS - MBR 引导程序 v1.0（完整版）
; 编译：nasm -f bin boot.asm -o boot.bin
; 写入：dd if=boot.bin of=grub_test.img bs=512 count=1 conv=notrunc
; 转换：qemu-img convert -f raw -O vmdk -o compat6 grub_test.img Earth-SYSTEM-OS.vmdk
; ============================================

org 0x7C00
bits 16

start:
    ; 初始化段寄存器和栈
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    ; 设置显示模式（80x25 彩色文本）
    mov ax, 0x0003
    int 0x10

    ; 显示欢迎消息
    mov si, msg
    call print

    ; ==========================================
    ; 尝试 APM 关机（现代 BIOS 支持）
    ; ==========================================
    mov ax, 0x5307          ; APM 关机功能
    mov bx, 0x0001          ; 所有设备
    mov cx, 0x0003          ; 系统关机
    int 0x15
    jc shutdown_fail        ; 如果关机失败，跳到重启

shutdown_ok:
    ; 关机成功，停在这里（虚拟机应该已经关闭）
    cli
    hlt
    jmp shutdown_ok

shutdown_fail:
    ; ==========================================
    ; 如果关机失败，尝试重启
    ; ==========================================
    int 0x19                ; BIOS 热重启
    ; 如果重启也失败，进入死循环
    jmp hang

hang:
    jmp hang

print:
    mov ah, 0x0E
.next:
    lodsb
    test al, al
    jz .done
    int 0x10
    jmp .next
.done:
    ret

msg:
    db "Earth-SYSTEM OS is alive!", 0x0D, 0x0A
    db "Preparing to shut down...", 0x0D, 0x0A, 0

; ==========================================
; MBR 填充和签名
; ==========================================
times 510 - ($ - $$) db 0
dw 0xAA55