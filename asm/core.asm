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
        
        mov ax,0x0038
        mov ds,ax
	mov [Call_gate1],bx

	mov ebx,system_string

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
	mov ax,0x38
	mov ds,ax

	mov ax,0x28
	mov ss,ax

	mov eax,0x00400000
	mov ebx,read_Disk

	call 0x0040:set_Call_GDT

	mov [Call_gate2],bx

	mov ebx,load_after

	call far [printString]

	mov ebx,[core_next_laddr]

	call 0x0040:alloc_inst_a_page

	add dword [core_next_laddr],4096

	mov word es:[ebx+0],0

	mov eax,cr3
	mov es:[ebx+28],eax

	mov dword es:[ebx+100],0

	mov dword es:[ebx+102],103

	mov eax,ebx
	mov ebx,103
	mov ecx,0x00408900

	call 0x0040:set_gdt

	mov [program_man_tss+4],bx

	ltr cx

	mov ebx,[core_next_laddr]
	call 0x0040:alloc_inst_a_page
	add dword [core_next_laddr],4096

	mov dword es:[ebx+0x06],0

	mov word es:[ebx+0x0a],0xffff

	mov ecx,ebx
	call addTIT

	push dword 100

	push ecx

	call load_relocate_program

        hlt

    load_relocate_program:
        pushad
	push ds
	push es
	mov ebp,esp

	mov eax,0x20
	mov es,eax

	mov ebx,0xfffff000
	xor esi,esi

	.b1:
	mov dword es:[ebx+esi*4],0x00000000
	inc esi
	cmp esi,0x512
	jl .b1

	mov eax,0x38
	mov ds,eax

	mov eax,[ebp+12*4]
	mov ebx,core_buff

	call far [readDisk]

	mov eax,[core_buff]
	and ebx,0xfffff000
	add ebx,0x1000
	test eax,0x00000fff
	cmovz eax,ebx

	mov ecx,eax
	shr ecx,12

	mov eax,[ebp+12*4]
	mov esi,[ebp+11*4]

	.b2:
	mov ebx,es:[esi+0x06]
	add dword es:[esi+0x06],0x1000
	call 0x0040:alloc_inst_a_page

	push ecx
	mov ecx,8

	.b3:
	call far [readDisk]
	inc eax
	loop .b3

	pop ecx
	loop .b2

	mov ebx,[core_next_laddr]
	call 0x0040:alloc_inst_a_page
	add dword [core_next_laddr],4096

	mov es:[esi+0x14],ebx
	mov word es:[esi+0x12],103

	mov ebx,es:[esi+0x06]
	add dword es:[esi+0x06],0x1000
	call 0x0040:alloc_inst_a_page
	mov es:[esi+0x0c],ebx

	mov eax,0x00000000
	mov ebx,0x000fffff
	mov ecx,0x00c0f800

	call 0x0040:make_DT

	mov ebx,esi
	call fill_descriptor_ldt

	mov ebx,es:[esi+0x14]

	mov es:[ebx+76],cx;填写TSS的cs

	mov eax,0x00000000
	mov ebx,0x000fffff
	mov ecx,0x00c0f200

	call 0x0040:make_DT

	mov ebx,es:[esi+0x14]

	mov es:[ebx+84],cx;填写TSS的ds
	mov es:[ebx+72],cx;填写TSS的es
	mov es:[ebx+88],cx;填写TSS的fs
	mov es:[ebx+92],cx;填写TSS的gs

	pop es
	pop ds
	popad
        ret

    fill_descriptor_ldt:
    	push eax
	push edx
	push edi

	mov ecx,0x0020
	mov ds,ecx

	mov edi,[ebx+0x0c]

	xor ecx,ecx
	mov cx,[ebx+0x0a]
	inc cx

	mov [edi+ecx+0x00],eax
	mov [edi+ecx+0x04],edx

	add cx,8
	dec cx

	mov [ebx+0x0a],cx

	mov ax,cx
	xor dx,dx
	mov cx,8
	div cx
	
	mov cx,ax
	shl cx,3
	or cx,0x0004

	pop edi
	pop edx
	pop eax
	ret

    addTIT:
    	push eax
	push edx
	push es
	push ds
    	push ebp
	mov ebp,esp

	mov eax,0x0038
	mov ds,eax

	mov eax,0x0020
	mov es,eax

	mov dword es:[ecx+0x00],0

	mov eax,[TCB]
	or eax,eax
	jnz .notcb

	.searc:
	mov edx,eax
	mov eax,es:[edx+0x00]
	or eax,eax
	jnz .searc

	mov es:[edx+0x00],ecx
	jmp .retpc

	.notcb:
	mov [TCB],ecx

	.retpc:
	pop ebp
	pop ds
	pop es
	pop edx
	pop eax
    	ret

SECTION sys_data vstart=0 align=16
    load_after db "The call gate was installed successfully.",0x0d,0x0a,0x00
    system_string db "The HongMuOS is loading succeeded!",0x0d,0x0a,0x00
    CPU_data times 50 db 0
    gdt_size dw 0
    gdt_in dd 0
    PDT dd 0x20000
    PT dd 0x21000
    TCB dd 0x00
    core_buff times 512 db 0
    core_next_laddr dd 0x80100000
    page_bit_map times 32 db 0xff
    times 16 db 0x55
    times 80 db 0x00
    page_bit_len equ $-page_bit_map
    msg_not_have_page db "*****No moer pages*****"
    program_man_tss dd 0
    dw 0
    salt:
        salt_1:
            db "@printString"
            times 256-($-salt_1) db 0
            printString dd 0
            Call_gate1 dw 0
        salt_2:
            db "@readDisk"
            times 256-($-salt_2) db 0
            readDisk dd 0
            Call_gate2 dw 0

SECTION sys_routine vstart=0 align=16
    alloc_a_4k_page:
	push ebx
	push ecx
	push edx
	push ds

	mov eax,0x0038
	mov ds,eax
	
	xor eax,eax

	.b1:
	bts [page_bit_map],eax
	jnc .b2
	inc eax
	cmp eax,page_bit_len*8
	jl .b1

	mov ebx,msg_not_have_page
	call far [printString]
	hlt

	.b2:
	shr eax,12

	pop ds
	pop edx
	pop ecx
	pop ebx
	ret
    alloc_inst_a_page:
    	push eax
	push ebx
	push esi
	push ds

	mov eax,0x0020
	mov ds,eax

	mov esi,ebx
	and esi,0xffc00000

	shr esi,20
	or esi,0xfffff000

	test dword [esi],0x00000001

	jnz .b1

	call alloc_a_4k_page
	or eax,0x00000007
	mov [esi],ebx

	.b1:
	mov esi,ebx
	shr esi,10
	and esi,0x003ff000
	or esi,0xffc00000

	and ebx,0x003ff000
	shr ebx,10
	or esi,ebx

	call alloc_a_4k_page
	or eax,0x00000007
	mov [esi],eax

	pop ds
	pop esi
	pop ebx
	pop eax
	retf

    read_Disk:
    	pushad

	push eax

	mov al,1
	mov dx,0x1f2
	out dx,al

	pop eax

	inc dx;dx=0x1f3
	out dx,al

	inc dx;dx=0x1f4
	mov cl,8
	shr eax,cl
	out dx,al

	inc dx;dx=0x1f5
	shr eax,cl
	out dx,al

	inc dx;dx=0x1f6
	shr eax,cl
	or al,0xe0
	out dx,al

	inc dx;dx=0x1f7
	mov al,0x20
	out dx,al

	.waits:
		in al,dx
		and al,0x88
		cmp al,0x08
		jne .waits
	
	mov ecx,256
	mov dx,0x1f0
	
	.readw:
		in ax,dx
		mov [ebx],ax
		add ebx,2
		loop .waits

	popad
    	retf

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
        push eax

        mov eax,0x20
        mov es,eax

        pop eax

        mov es:[ebp+0x00],eax
        mov es:[ebp+0x04],ebx

        add word [gdt_size],8

        lgdt [gdt_size]

	mov ebx,edi

        pop es

        pop ds
        pop ebp

        retf
    set_gdt:
        push edx
        push es
        push ds

        push eax

        mov eax,0x0038
        mov es,ax

        mov eax,0x0020
        mov ds,eax

        pop eax

        sgdt [es:gdt_size]

        call 0x0040:make_DT

        xor ebx,ebx
        mov bx,[es:gdt_size]
        inc bx
        add ebx,[es:gdt_in]
        mov [ebx+0x00],eax
        mov [ebx+0x04],edx

        add word [es:gdt_size],8

        lgdt [es:gdt_size]

        pop ds
        pop es
        pop edx
        retf

    make_DT:
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

        retf

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
            mov eax,0x0018
            mov es,eax

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

            mov eax,0x0018
            mov ds,eax
            mov es,eax

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
