SECTION sys_core vstart=0x80010000

core_len dd core_end

core_entry dd main
[bits 32]
    main:
        mov ebp,esp

	mov ebx,[core_next_laddr]
	call alloc_inst_a_page

	mov [pidt+2],ebx

	push ebx
	mov ax,cs
	mov cx,0x8e00
	mov ebx,exception_handling
	call make_CGDT
	pop ebx

	xor esi,esi
	.idt0:
	mov [ebx+esi*4+0x00],eax
	mov [ebx+esi*4+0x04],edx
	inc esi
	cmp esi,19
	jle .idt0

	push ebx
	mov ebx,hardware_interruption_handling
	mov ax,cs
	mov cx,0x8e00
	call make_CGDT
	pop ebx

	.idt1:
	mov [ebx+esi*8],eax
	mov [ebx+esi*8+4],edx
	inc esi
	cmp esi,255
	jle .idt1

	push ebx
	mov ebx,int_0x50;时钟
	mov ax,cs
	mov cx,0x8e00
	call make_CGDT
	pop ebx

	mov [ebx+0x50*8],eax
	mov [ebx+0x50*8+4],edx

	push ebx;安装api中断
	mov ebx,int_0x86;api
	mov eax,cs
	mov cx,0xee00
	call make_CGDT
	pop ebx

	mov [ebx+0x86*8],eax
	mov [ebx+0x86*8+4],edx

	;准备开放中断
	mov word [pidt],256*8-1
	mov [pidt+2],ebx
	lidt [pidt]

	;设置8259A主片
	mov al,0x11;边沿触发，多片使用，初始化ICW4
	out 0x20,al
	mov al,0x20;中断向量起点0x20
	out 0x21,al
	mov al,0x04;从片连接IRQ2
	out 0x21,al
	mov al,0x01;非自动结束
	out 0x21,al

	;设置8259A从片
	mov al,0x11;边沿触发，多片使用，初始化ICW4
	out 0x20,al
	mov al,0x50;中断向量起点0x70
	out 0x21,al
	mov al,0x04;从片连接主片IRQ2
	out 0x21,al
	mov al,0x01;非自动结束
	out 0x21,al

	;实时时钟设置
	mov al,0x0b
	or al,0x80
	out 0x70,al
	mov al,0x12
	out 0x71,al

	in al,0xa1;读IMR
	and al,0xfe;清空bit 0
	out 0xa1,al;写回

	in al,0x0c
	out 0x70,al
	in al,0x71

	sti

        mov ax,0x0010
        mov ds,ax

	mov ebx,system_string

        call print_String
        
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

        call print_String

	mov ebx,[core_next_laddr]

	call alloc_inst_a_page

	add dword [core_next_laddr],4096

	mov word es:[ebx+0],0

	mov eax,cr3
	mov es:[ebx+28],eax

	mov dword es:[ebx+100],0

	mov dword es:[ebx+102],103

	mov eax,ebx
	mov ebx,103
	mov ecx,0x00408900

	call set_gdt

	mov [program_man_tss+4],bx

	ltr cx

	mov ebx,[core_next_laddr]
	call alloc_inst_a_page
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

	mov eax,0x10
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

	call read_Disk

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
	call alloc_inst_a_page

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

	mov eax,0x0010
	mov ds,eax

	mov dword [ecx+0x00],0

	mov eax,[TCB]
	or eax,eax
	jnz .notcb

	.searc:
	mov edx,eax
	mov eax,[edx+0x00]
	or eax,eax
	jnz .searc

	mov [edx+0x00],ecx
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

    int_0x86:;具体见READED.md
    	pushad

	cmp al,0x0001
	je .print

	cmp al,0x0002
	je .readDisk

	.print:
		mov ax,0x28
		mov ds,ax
		call printString
		jmp .exit

	.readDisk:
		mov eax,edx
		dec ecx
		.b1:
			call read_Disk
			add ebx,0x000001ff
			inc eax
		loop .b1
		jmp .exit

	.exit:
	popad
    	iretd

    int_0x50:
    	pushad

	mov al,0x20
	out 0xa0,al
	out 0x20,al

	mov al,0x0c
	out 0x70,al
	in al,0x71

	mov eax,TCB
	.b0:
		mov ebx,[eax]
		or ebx,ebx
		jz .exit
		cmp word [ebx+0x04],0xffff
		je .b1
		mov eax,ebx
		jmp .b1

	.b1:
		mov ecx,[ebx]
		mov [eax],ecx
	
	.b2:
		mov edx,[eax]
		or edx,edx
		jz .b3
		mov eax,ebx
		jmp .b2

	.b3:
		mov [eax],ebx
		mov dword [ebx],0x00000000

		mov eax,TCB
		
		.b4:
			mov eax,[eax]
			or eax,eax
			jz .exit
			cmp word [eax+0x04],0x0000
			jnz .b4

			not word [eax+0x04]
			not word [ebx+0x04]

			jmp far [eax+0x14]

	.exit:
	popad
    	iretd

    exception_handling:
    	mov ebx,excep_msg
	call print_String
	hlt

    hardware_interruption_handling:
    	push eax

	mov al,0x20
	out 0xa0,al
	out 0x20,al

	pop eax
    	iretd

;----------数据段----------
    load_after db "The interrupt vector table was installed successfully.",0x0d,0x0a,0x00
    system_string db "The HongMuOS is loading succeeded!",0x0d,0x0a,0x00
    CPU_data times 50 db 0
    gdt_size dw 0
    pidt dw 0
    	 dd 0
    gdt_in dd 0
    TCB dd 0x00
    core_buff times 512 db 0
    core_next_laddr dd 0x80100000
    page_bit_map times 32 db 0xff
    times 16 db 0x55
    times 80 db 0x00
    page_bit_len equ $-page_bit_map
    msg_not_have_page db "*****No moer pages*****"
    excep_msg db "",0x0d,0x0a,0x00
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

;----------例程段----------
    alloc_a_4k_page:
	push ebx
	push ecx
	push edx
	push ds

	mov eax,0x0010
	mov ds,eax
	
	xor eax,eax

	.b1:
	bts [page_bit_map],eax
	jnc .b2
	inc eax
	cmp eax,page_bit_len*8
	jl .b1

	mov ebx,msg_not_have_page
	call printString
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

	mov eax,0x0010
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
	ret

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
    	ret

    set_gdt:
        push edx
        push es
        push ds

        push eax

        mov eax,0x0010
        mov es,ax

        mov eax,0x0010
        mov ds,eax

        pop eax

        sgdt [es:gdt_size]

        call make_DT

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
        ret

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

        ret

    print_String:
        push ecx

	cli

        .get_char:
            mov cl,[ebx]
            or cl,cl
            jz .over
            call print_Char
            inc ebx
        jmp .get_char

        .over:
	sti
        pop ecx
        ret

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
            mov eax,0x0010
            mov es,eax

            shl bx,1

            mov [es:0x800b8000+ebx],cl
            pop es
            shr bx,1
            inc bx
        
        .roll_screen:
            cmp bx,2000
            jne .set_cursur
            push es
            push ds

            mov eax,0x0010
            mov ds,eax
            mov es,eax

            mov edi,0x800b8000
            mov esi,0x800b8a00

            cld

            mov ecx,1920
            rep movsd

            mov bx,3840
            mov ecx,80

            .cls:
                mov word es:[0x800b8000+ebx],0x0720
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
        ret

    make_CGDT:;输入：ax=描述符选择子，ebx=32位偏移,cx=类型及属性
    	      ;返回：eax=低32位,edx=高32位
	shl eax,16
	mov ax,bx
	mov edx,ebx
	and edx,0xffff0000
	or edx,0x0000ee00

    	ret
   
SECTION train

core_end: 
