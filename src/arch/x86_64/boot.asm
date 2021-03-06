global start
extern long_mode_start

section .text
bits 32
start:
	mov esp, stack_top  ; update stack pointer register

	; ensure processor support required features
	; e.g. long mode
	call check_multiboot
	call check_cpuid
	call check_long_mode

	call init_page_tables
	call enable_paging

	; load 64-bit Global Descriptor Table
	lgdt [gdt64.pointer]

	jmp gdt64.code:long_mode_start

	mov dword [0xb8000], 0x2f4b2f4f
	hlt

; read-only data
section .rodata
gdt64:
	dq 0  ; dq => define quad (0 entry)
.code: equ $ - gdt64  ; offset of gdt from current address.. used when we load GDT offset into cs register
	dq (1 << 43) | (1 << 44) | (1 << 47) | (1 << 53)  ; set some bits
.pointer: ; sub-label of gdt64... acess through gdt64.pointer
	dw $ - gdt64 - 1  ; $ replaced with current address (.pointer)
	dq gdt64

; print 'ERR: ' and error code in al
error:
	mov dword [0xb8000], 0x4f524f45  ; 0x8000 => beginning of VGA text buffer
	mov dword [0xb8004], 0x4f3a4f52  ; 0xf4 is color code (white text red bg)
	mov dword [0xb8008], 0x4f204f20  ; 0x52 => R, 0x45 => E, 0x3a => :, 0x20 => <space>
	mov byte  [0xb800a], al
	hlt

check_multiboot:
	cmp eax, 0x36d76289
	jne .no_multiboot
	ret
.no_multiboot:
	mov al, "0"
	jmp error

; https://wiki.osdev.org/Setting_Up_Long_Mode#Detection_of_CPUID
check_cpuid:
	; Check if CPUID is supported by attempting to flip the ID bit (bit 21)
	; in the FLAGS register. If we can flip it, CPUID is available.

	; Copy FLAGS in to EAX via stack
	pushfd
	pop eax

	; Copy to ECX as well for comparing later on
	mov ecx, eax

	; Flip the ID bit
	xor eax, 1 << 21

	; Copy EAX to FLAGS via the stack
	push eax
	popfd

	; Copy FLAGS back to EAX (with the flipped bit if CPUID is supported)
	pushfd
	pop eax

	; Restore FLAGS from the old version stored in ECX (i.e. flipping the
			; ID bit back if it was ever flipped).
	push ecx
	popfd

	; Compare EAX and ECX. If they are equal then that means the bit
	; wasn't flipped, and CPUID isn't supported.
	cmp eax, ecx
	je .no_cpuid
	ret
.no_cpuid:
	mov al, "1"
	jmp error

; https://wiki.osdev.org/Setting_Up_Long_Mode#x86_or_x86-64
check_long_mode:
	; test if extended processor info in available
	; 0x80000000 returns highest supported parameter value
	; older processors don't support 0x80000001
	; which is needed to check for long mode (set 29th bit in edx)
	mov eax, 0x80000000    ; implicit argument for cpuid
	cpuid                  ; get highest supported argument
	cmp eax, 0x80000001    ; it needs to be at least 0x80000001
	jb .no_long_mode       ; if it's less, the CPU is too old for long mode

	; use extended info to test if long mode is available
	mov eax, 0x80000001    ; argument for extended processor info
	cpuid                  ; returns various feature bits in ecx and edx
	test edx, 1 << 29      ; test if the LM-bit is set in the D-register
	jz .no_long_mode       ; If it's not set, there is no long mode
	ret
.no_long_mode:
	mov al, "2"
	jmp error

init_page_tables:
	; map first entry in P4 to P3
	mov eax, p3_table
	or eax, 0b11  ; present + writable
	mov [p4_table], eax

	; map first entry in P3 to P2
	mov eax, p2_table
	or eax, 0b11  ; present + writable
	mov [p3_table], eax

	; map P2 to 2MiB page table
	mov ecx, 0  ; counter
	;jmp .map_p2_table
.map_p2_table:
	; map ecx-th P2 entry to huge page table @ 2MiB * ecx (counter)
	mov eax, 0x200000  ; 2MiB
	mul ecx
	or eax, 0b10000011  ; present + writable + huge
	mov [p2_table + ecx * 8], eax  ; map exch-th entry

	inc ecx  ; inc counter
	cmp ecx, 512  ; if counter == 512, whole P2 table is mapped
	jne .map_p2_table

	ret

enable_paging:
	; load P4 to cr3 register (stores the location of P4 for use by cpu)
	mov eax, p4_table
	mov cr3, eax

	; enable PAE-flag in cr4
	mov eax, cr4
	or eax, 1 << 5
	mov cr4, eax
	
	; set long mode bit in model specific register
	mov ecx, 0xc0000080
	rdmsr  ; read model specific register
	or eax, 1 << 8
	wrmsr  ; write model specific register

	; enable paging in cr0
	mov eax, cr0
	or eax, 1 << 31  ; set 31st bit in eax
	mov cr0, eax

	ret

; create stack memory
section .bss
align 4096  ; align page tables
; page tables, resb reserves buytes without initializing
p4_table:  ; PML4
	resb 4096
p3_table:  ; PDP
	resb 4096
p2_table:  ; PD
	resb 4096
p1_table:  ; PT
	resb 4096
stack_bottom:
	resb 64  ; reserve byte
stack_top:
