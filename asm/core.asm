core_len dd core_end

code_seg dd section.sys_code.start
data_seg dd section.sys_data.start
routine_seg dd section.sys_routine.start

core_entry dd main
           dw 0x0030

[bits 32]

SECTION sys_code vstart=0 align=16
    main:
        mov ebp,esp

        mov eax,0x00400000
        mov ebx,print_String
        mov cl,0

        call 0x0040:set_Call_GDT
        
        mov ebx,system_string
        mov ax,0x0038
        mov ds,ax
        call 0x0048:print_String
        
        mov eax,0x80000002
        cpuid
        mov [CPU_data+0x00],eax
        mov [CPU_data+0x04],ebx
        mov [CPU_data+0x08],ecx
        mov [CPU_data+0x0c],edx

        mov eax,0x80000003
        cpuid
        mov [CPU_data+0x10],eax
        mov [CPU_data+0x14],ebx
        mov [CPU_data+0x18],ecx
        mov [CPU_data+0x1c],edx

        mov eax,0x80000004
        cpuid
        mov [CPU_data+0x20],eax
        mov [CPU_data+0x24],ebx
        mov [CPU_data+0x28],ecx
        mov [CPU_data+0x2c],edx
        mov word [CPU_data+0x2f],0x20

        mov ebx,CPU_data

        call 0x0048:print_String
        
	mov ax,0x20
	mov es,ax

        mov ebx,[PDT]
	mov ecx,1024
	xor esi,esi
	.b1:
	mov dword es:[ebx+esi],0x00000000
	add esi,4

	loop .b1
	
	mov dword es:[ebx+4092],0x00020003
	mov dword es:[ebx+0],0x00021003

	mov ebx,0x00021000
	xor eax,eax
	xor esi,esi

	.b2:
	mov edx,eax
	or edx,0x00000003
	mov es:[ebx+esi*4],edx
	add eax,0x00001000
	inc esi
	cmp esi,256
	jl .b2

	.b3:
	mov dword es:[ebx+esi*4],0x00000000
	inc esi
	cmp esi,1024
	jl .b3

        mov eax,0x00020000
        mov cr3,eax

	mov eax,cr0

	or eax,0x80000000
	
	mov cr0,eax

        mov ebx,0xfffff000
	mov esi,0x80000000

	shr esi,22
	shl esi,2

	mov dword es:[ebx+esi],0x00021003

	sgdt [gdt_size]

	mov ebx,[gdt_in]

	or dword es:[ebx+0x08+4],0x80000000
	or dword es:[ebx+0x10+4],0x80000000
	or dword es:[ebx+0x18+4],0x80000000
	or dword es:[ebx+0x28+4],0x80000000
	or dword es:[ebx+0x30+4],0x80000000
	or dword es:[ebx+0x38+4],0x80000000
	or dword es:[ebx+0x40+4],0x80000000

	add dword [gdt_in],0x80000000

	lgdt [gdt_size]

	jmp 0x0030:flush

	flush:

        hlt

    load_relocate_program:
        push ebp
	push ds
	push es
	mov ebp,esp

	mov ax,0x20
	mov es,ax
	mov ax,0x38
	mov ds,ax

	mov eax,[TCB]
	call addTIT ;添加任务信息表

	pop es
	pop ds
	pop ebp
        ret

    addTIT:
    	push ebp
	mov ebp,esp

	mov ebx,eax

	pop ebp
    	ret

SECTION sys_data vstart=0 align=16
    system_string db 'The HongMuOS is loading succeeded!',0x0d,0x0a,0x00
    CPU_data times 50 db 0
    gdt_size dw 0
    gdt_in dd 0
    PDT dd 0x20000
    PT dd 0x21000
    TCB dd 0x0
    salt:
        salt_1:
            db "@printString"
            times 256-($-salt_1) db 0
            dd 0
            dw 0
        salt_2:
            db "@backSystem"
            times 256-($-salt_2) db 0
            dd 0
            dw 0
        salt_3:
            db "@readDisk"
            times 256-($-salt_3) db 0
            dd 0
            dw 0

SECTION sys_routine vstart=0 align=16
    set_Call_GDT:
        push ebp
        or ax,bx
        and ebx,0xffff0000
        or bl,cl

        push edx

        mov edx,0x0000ec00
        or ebx,edx

        pop edx

        push ds
        push ax

        mov ax,0x38
        mov ds,ax

        pop ax

        sgdt [gdt_size]

        mov ebp,[gdt_in]
        mov di,[gdt_size]
        and edi,0x0000ffff
        inc edi
        add ebp,edi

        push es
        push ax

        mov ax,0x20
        mov es,ax

        pop ax

        mov es:[ebp+0x00],eax
        mov es:[ebp+0x04],ebx

        add word [gdt_size],8

        lgdt [gdt_size]

        pop es

        pop ds
        pop ebp

        retf
    set_gdt:
        push edx
        push es
        push ds

        push ax

        mov ax,0x0038
        mov es,ax

        mov ax,0x0020
        mov ds,ax

        pop ax

        sgdt [es:gdt_size]

        call make_GDT

        xor ebx,ebx
        mov bx,[es:gdt_size]
        inc bx
        add ebx,[es:gdt_in]
        mov [ebx+0x00],eax
        mov [ebx+0x04],eax

        add word [es:gdt_size],8

        lgdt [es:gdt_size]

        pop ds
        pop es
        pop edx
        retf

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

    print_String:
        push ecx

        .get_char:
            mov cl,[ebx]
            or cl,cl
            jz .over
            call print_Char
            inc ebx
        jmp .get_char

        .over:
        pop ecx
        retf

    print_Char:
        pushad

        mov al,14
        mov dx,0x3d4
        out dx,al

        inc dx
        in al,dx

        dec dx
        mov ah,al
        mov al,15
        out dx,al

        inc dx
        in al,dx
        mov bx,ax

        and ebx,0x0000ffff

        cmp cl,0x0d
        jne .put_0x0a
        mov ax,bx
        mov bl,80
        div bl
        mul bl
        mov bx,ax
        jmp .set_cursur

        .put_0x0a:
            cmp cl,0x0a
            jne .put_other
            add bx,80
            jmp .roll_screen

        .put_other:
            push es
            mov ax,0x0018
            mov es,ax

            shl bx,1

            mov [es:bx],cl
            pop es
            shr bx,1
            inc bx
        
        .roll_screen:
            cmp bx,2000
            jne .set_cursur
            push es
            push ds

            mov ax,0x0018
            mov ds,ax
            mov es,ax

            mov edi,0x00
            mov esi,0xa0

            cld

            mov ecx,1920
            rep movsd

            mov bx,3840
            mov ecx,80

            .cls:
                mov word es:[bx],0x0720
                add bx,2
                loop .cls

            pop ds
            pop es

            mov bx,1920

        .set_cursur:
            mov al,14
            mov dx,0x3d4
            out dx,al

            inc dx
            mov al,bh
            out dx,al

            dec dx
            mov al,15
            out dx,al

            inc dx
            mov al,bl
            out dx,al

        popad
        retf

    ;times 512-($-$$) db 1

SECTION train

core_end: 
