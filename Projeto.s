.equ	STACK,		0x10000
.equ	BASE_IO,	0x10000000
# offsets
.equ	JTAG_Data,	0x1000
.equ	JTAG_Ctrl,	0x1004

# RTI
.org 0x20
	addi	sp, sp, -24
	stw		r20, 20(sp)
	stw		r12, 16(sp)
	stw		r11, 12(sp)
	stw		r10, 8(sp)
	stw		r9, 4(sp)
	stw		ra, (sp)
	
	#rdctl	et, ipending
	subi	ea, ea, 0x4
	
	call	JTAG_INTERRUPT
	
	ldw		r9, 4(sp)
	ldw		r10, 8(sp)
	ldw		r11, 12(sp)
	ldw		r12, 16(sp)
	ldw		r20, 20(sp)
	ldw		ra, (sp)
	addi	sp, sp, 24
	eret

JTAG_INTERRUPT:
	addi	sp, sp, -4
	stw		ra, (sp)
	
	ldwio	r20, JTAG_Data(r8)
	
	movi	r11, 0x0a
	andi	r12, r20, 0xFF
	beq		r11, r12, ENTER_INPUTED
	
	movia	r10, BUFFER
	
	ldb		r11, 1(r10)
	stb		r11, 0(r10)
	
	ldb		r11, 2(r10)
	stb		r11, 1(r10)
	
	ldb		r11, 3(r10)
	stb		r11, 2(r10)
	
	ldb		r11, 4(r10)
	stb		r11, 3(r10)
	
	stb		r20, 4(r10)
	
	br		CHAR_INPUTED
	
	ENTER_INPUTED:
	
	call	VALID_COMMAND
	
	stb		r0, 0(r10)
	stb		r0, 1(r10)
	stb		r0, 2(r10)
	stb		r0, 3(r10)
	stb		r0, 4(r10)
	
	CHAR_INPUTED:
	stwio	r20, JTAG_Data(r8)
	
	ldw		ra, (sp)
	addi	sp, sp, 4
	ret

VALID_COMMAND:
	addi	sp, sp, -4
	stw		ra, (sp)
	
	movi	r11, 0b0
	stwio	r11, 0(r8)
	
	ldw		ra, (sp)
	addi	sp, sp, 4
	ret

.global _start
_start:
	/* r8 - Endereco Base */
	/* r9 - Contador */
	/* r10 - Buffer */
	/* r11 - Aux */
	movia	sp, STACK
	
	movia	r8, BASE_IO
	
	/* Habilitando interrupcoes necessarias */
	ldwio	r9, JTAG_Ctrl(r8)
	ori		r9, r9, 0x1
	stwio	r9, JTAG_Ctrl(r8)
	
	movi	r9, 0x100
	wrctl	ienable, r9
	
	/* Habilita interrupcoes no processador */
	movi	r9, 1
	wrctl	status, r9

	movia	r10, BUFFER

MAIN:

	ldb		r11, 0(r10)
	ldb		r12, 1(r10)
	ldb		r13, 2(r10)
	ldb		r14, 3(r10)
	ldb		r15, 4(r10)
	
	br	MAIN
	
AUX:
.byte 0x00
BUFFER:
.byte 0x00, 0x00, 0x00, 0x00, 0x00