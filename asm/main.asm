core_start_sector equ 0x00000001

mov ax,cs
mov ds,ax

mov ax,[0x7c00+gdt_in]
mov dx,[0x7c00+gdt_in+0x2]

mov bx,16
div bx

mov ds,ax
mov bx,dx

;空符表
mov dword [bx+0x00],0x00
mov dword [bx+0x04],0x00

;主引导代码
mov dword [bx+0x08],0x7c0001ff
mov dword [bx+0x0c],0x00409800

;主引导数据
mov dword [bx+0x10],0x7c0001ff
mov dword [bx+0x14],0x00409200

;显示段
mov dword [bx+0x18],0x80007fff
mov dword [bx+0x1c],0x0040920b

;4GB全局数据段
mov dword [bx+0x20],0x0000ffff
mov dword [bx+0x24],0x00cf9200

;栈段
mov dword [bx+0x28],0x7c00fffe
mov dword [bx+0x2c],0x004f9600

mov word [cs:gdt_size+0x7c00],47
lgdt [cs:gdt_size+0x7c00]

in al,0x92
or al,2
out 0x92,al

cli

mov eax,cr0
or eax,1
mov cr0,eax

jmp dword 0x0008:flush

[bits 32]

read_disk:
push eax 
         push ecx
         push edx
      
         push eax
         
         mov dx,0x1f2
         mov al,1
         out dx,al                       ;读取的扇区数

         inc dx                          ;0x1f3
         pop eax
         out dx,al                       ;LBA地址7~0

         inc dx                          ;0x1f4
         mov cl,8
         shr eax,cl
         out dx,al                       ;LBA地址15~8

         inc dx                          ;0x1f5
         shr eax,cl
         out dx,al                       ;LBA地址23~16

         inc dx                          ;0x1f6
         shr eax,cl
         or al,0xe0                      ;第一硬盘  LBA地址27~24
         out dx,al

         inc dx                          ;0x1f7
         mov al,0x20                     ;读命令
         out dx,al

  .waits:
         in al,dx
         and al,0x88
         cmp al,0x08
         jnz .waits                      ;不忙，且硬盘已准备好数据传输 

         mov ecx,256                     ;总共要读取的字数
         mov dx,0x1f0
  .readw:
         in ax,dx
         mov [ebx],ax
         add ebx,2
         loop .readw

         pop edx
         pop ecx
         pop eax
      
         ret
make_GDT: 
    mov edx,eax
    mov ax,bx
    rol eax,16
    mov ax,dx
    ror eax,16
    
    and edx,0xffff0000
    rol edx,8
    bswap edx
    and ebx,0x000f0000
    or edx,ebx

    or edx,ecx

    ret

flush:
    mov cx,0x0028
    mov ss,cx
    mov esp,0xffffffff
    mov eax,core_start_sector
    mov ebx,0x00010000
    mov cx,0x0020
    mov ds,cx

    call read_disk

    mov ebp,0x00010000
    mov eax,ds:[ebp]

    mov ecx,512
    xor ecx,edx
    div ecx

    or edx,edx
    jnz .@1
    dec eax

    .@1:
        or eax,eax
        jz setup
        mov ecx,eax
        mov eax,core_start_sector
        inc eax
        .@2:
            call read_disk
            inc eax
            loop .@2
    
    setup:
    
    mov ebp,0x00010000
    mov edi,ebp
    mov eax,ebp
    add ebp,4
    mov edx,ds:[ebp]
    mov ebx,ds:[ebp+0x04]
    add eax,edx
    sub ebx,edx
    mov ecx,0x00409800

    call make_GDT

    mov [0x7e00+0x30],eax
    mov [0x7e00+0x34],edx

    add ebp,4
    mov eax,edi
    mov edx,ds:[ebp]
    mov ebx,ds:[ebp+0x04]
    add eax,edx
    sub ebx,edx
    mov ecx,0x00409200
    
    call make_GDT

    mov [0x7e00+0x38],eax
    mov [0x7e00+0x3c],edx

    add ebp,4
    mov eax,edi
    mov edx,ds:[ebp]
    mov ebx,ds:[edi]
    add eax,edx
    sub ebx,edx
    mov ecx,0x00409800

    call make_GDT

    mov [0x7e00+0x40],eax
    mov [0x7e00+0x44],edx

    mov word [0x7c00+gdt_size],71
    lgdt [0x7c00+gdt_size]

    jmp far [edi+0x10]

    hlt

gdt_size dw 0
gdt_in dd 0x7e00

times 510-($-$$) db 0
db 0x55,0xaa