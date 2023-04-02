core_start_sector equ 0x00000001

SECTION main vstart=0x00007c00
mov ax,cs
mov ds,ax

mov ax,[gdt_in]
mov dx,[gdt_in+0x2]

mov bx,16
div bx

mov ds,ax
mov bx,dx

;空符表
mov dword [bx+0x00],0x00
mov dword [bx+0x04],0x00

;全局代码
mov dword [bx+0x08],0x0000ffff
mov dword [bx+0x0c],0x00cf9800

;全局数据
mov dword [bx+0x10],0x0000ffff
mov dword [bx+0x14],0x00cf9200

mov word [cs:gdt_size],47
lgdt [cs:gdt_size]

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

flush:
    mov cx,0x0010
    mov ss,cx
    mov esp,0x00007c00
    mov eax,core_start_sector
    mov ebx,0x00010000
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
        jz pages
        mov ecx,eax
        mov eax,core_start_sector
        inc eax
        .@2:
            call read_disk
            inc eax
            loop .@2
    
    pages:
    
    mov ebx,0x00020000
    mov dword [ebx+4096],0x00020003

    mov edx,0x00021003

    mov [ebx+0x000],edx
    mov [ebx+0x800],edx

    mov ebx,0x00021000
    xor eax,eax
    xor esi,esi

    .b1:
    	mov edx,eax
	or edx,0x00000003
	mov [ebx+esi*4],edx
	add eax,0x1000
	inc esi
	cmp esi,256
	jl .b1

    mov eax,0x00020000
    mov cr3,eax

    or dword [gdt_in],0x80000000
    lgdt [gdt_size]

    mov eax,cr0
    or eax,0x80000000
    mov cr0,eax

    add esp,0x80000000

    jmp [0x80010004]

    hlt

gdt_size dw 0
gdt_in dd 0x7e00

times 510-($-$$) db 0
db 0x55,0xaa
