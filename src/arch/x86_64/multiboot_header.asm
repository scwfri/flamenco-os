section .multiboot_header
header_start:
	dd 0xe8520d6 ; multiboot 2 magic header
	dd 0 ; procetected mode i386
	dd header_end - header_start
	; checksum
	dd 0x100000000 - (0xe85250d6 + 0 + (header_end - header_start))

	dw 0
	dw 0
	dd 8
header_end:
