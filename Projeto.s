.equ	STACK,		0x10000
.equ	BASE_IO,	0x10000000
# offsets
.equ	RED_LED,	0x0
.equ	GREEN_LED,	0x10 # proposito de teste
.equ	D7S_Low,	0x20
.equ	D7S_High,	0x30
.equ	SWTCH,		0x40
.equ	JTAG_Data,	0x1000
.equ	JTAG_Ctrl,	0x1004

# RTI
.org 0x20
	addi	sp, sp, -32
	stw 	r15, 28(sp)
	stw 	r14, 24(sp)
	stw 	r13, 20(sp)
	stw 	r12, 16(sp)
	stw 	r11, 12(sp)
	stw 	r10, 8(sp)
	stw 	r9, 4(sp)
	stw 	ra, (sp)
	
	# verifica de onde veio a interrupcao (vai precisar pra dps, por enquanto eh so jtag)
	#rdctl	et, ipending
	subi	ea, ea, 0x4
	
	call	JTAG_INTERRUPT
	
	ldw 	r9, 4(sp)
	ldw 	r10, 8(sp)
	ldw 	r11, 12(sp)
	ldw 	r12, 16(sp)
	ldw 	r13, 20(sp)
	ldw 	r14, 24(sp)
	ldw 	r15, 28(sp)
	ldw 	ra, (sp)
	addi	sp, sp, 32
	eret

JTAG_INTERRUPT:
	addi	sp, sp, -4
	stw 	ra, (sp)
	
	ldwio	r13, JTAG_Data(r8)
	
	movi	r11, 0x0a
	andi	r12, r13, 0xFF
	beq 	r11, r12, ENTER_INPUTED
	
	# atualiza o buffer do comando com o novo char
	movia	r10, BUFFER
	ldb 	r11, 1(r10)
	stb 	r11, 0(r10)
	
	ldb 	r11, 2(r10)
	stb 	r11, 1(r10)
	
	ldb 	r11, 3(r10)
	stb 	r11, 2(r10)
	
	ldb 	r11, 4(r10)
	stb 	r11, 3(r10)
	
	stb 	r13, 4(r10)
	
	CHAR_INPUTED:
	stwio	r13, JTAG_Data(r8)
	br		INPUT_END
	
	ENTER_INPUTED:
	call	VALID_COMMAND
	
	# limpa buffer
	stb 	r0, 0(r10)
	stb 	r0, 1(r10)
	stb 	r0, 2(r10)
	stb 	r0, 3(r10)
	stb 	r0, 4(r10)
	
	# imprime o caracter lido no terminal
	stwio	r13, JTAG_Data(r8)
	
	# imprime "cmd:"  no terminal
	mov 	r11, r0
	movi	r11, 0x63
	stwio	r11, JTAG_Data(r8)
	movi	r11, 0x6d
	stwio	r11, JTAG_Data(r8)
	movi	r11, 0x64
	stwio	r11, JTAG_Data(r8)
	movi	r11, 0x3a
	stwio	r11, JTAG_Data(r8)
	
	INPUT_END:
	
	ldw		ra, (sp)
	addi	sp, sp, 4
	ret

VALID_COMMAND:
	addi	sp, sp, -16
	stw 	r13, 12(sp)
	stw 	r12, 8(sp)
	stw 	r11, 4(sp)
	stw 	ra, (sp)
	
	# interpretador do comando
	COMMAND_CHECK:
	ldb 	r11, 2(r10) # verifica se tem "espaco" nessa posicao
	movi	r12, 0x20
	beq 	r11, r12, HAS_SPACE
	NO_SPACE: # se nao tiver, eh um comando simples
	ldb 	r11, 3(r10)
	movi	r12, 0x30
	beq 	r11, r12, SIMPLE_0
	movi	r12, 0x31
	beq 	r11, r12, SIMPLE_1
	movi	r12, 0x32
	beq 	r11, r12, SIMPLE_2
	br  	NOT_FOUND
	
		SIMPLE_0:
	ldb 	r11, 4(r10)
	movi	r12, 0x32
	beq 	r11, r12, CMD_02
	movi	r12, 0x33
	beq 	r11, r12, CMD_03
	br		NOT_FOUND
	
		SIMPLE_1:
	ldb 	r11, 4(r10)
	movi	r12, 0x30
	beq 	r11, r12, CMD_10
	br		NOT_FOUND
	
		SIMPLE_2:
	ldb 	r11, 4(r10)
	movi	r12, 0x30
	beq 	r11, r12, CMD_20
	movi	r12, 0x31
	beq 	r11, r12, CMD_21
	br  	NOT_FOUND
	
	HAS_SPACE: # se tem, eh um comando composto (com parametro passado)
	ldb 	r11, 0(r10)
	movi	r12, 0x30
	beq 	r11, r12, CMPLX_0
	br  	NOT_FOUND
	
		CMPLX_0:
	ldb 	r11, 1(r10)
	movi	r12, 0x30
	beq 	r11, r12, CMD_00
	movi	r12, 0x31
	beq 	r11, r12, CMD_01
	br		NOT_FOUND
	
	# tabela de comandos
		CMD_00:
	call	LED_ON
	br		END_CHECK
		CMD_01:
	call	LED_OFF
	br		END_CHECK
		CMD_02:
	call	LEDS_ON
	br		END_CHECK
		CMD_03:
	call	LEDS_OFF
	br		END_CHECK
		CMD_10:
	call	SWTCH_NUM
	br		END_CHECK
		CMD_20:
	br		END_CHECK
		CMD_21:
	br		END_CHECK
	
	NOT_FOUND:
	# talvez imprima algo no jtag
	END_CHECK:
	
	ldw 	r11, 4(sp)
	ldw 	r12, 8(sp)
	ldw 	r13, 12(sp)
	ldw 	ra, (sp)
	addi	sp, sp, 16
	ret

LED_ON: # comando 00
	addi	sp, sp, -4
	stw 	ra, (sp)
	
	# identifica qual o led escolhido
	ldb 	r11, 3(r10)
	subi	r11, r11, 0x30 # normaliza valor de char pra int
	muli	r13, r11, 0xa
	ldb 	r11, 4(r10)
	subi	r11, r11, 0x30 # normaliza valor de char pra int
	add 	r13, r13, r11
	
	beq 	r13, r0, END_ON # caso o valor seja o led 00, nao encontra o led, ja que comeca em 01, e finaliza
	movi	r11, 0x21
	bge 	r13, r11, END_ON # caso o valor seja maior que 32, nao encontra o led, ja que termina em 32, e finaliza
	
	subi	r13, r13, 0x1
	movi	r11, 0x1
	sll 	r11, r11, r13
	
	# acende o led escolhido
	movia 	r12, LED_SEQ
	ldw 	r13, 0(r12)
	or		r13, r13, r11
	stw 	r13, 0(r12)
	
	END_ON:
	
	ldw 	ra, (sp)
	addi	sp, sp, 4
	ret
	
LED_OFF: # comando 01
	addi	sp, sp, -4
	stw 	ra, (sp)
	
	# identifica qual o led escolhido
	ldb 	r11, 3(r10)
	subi	r11, r11, 0x30 # normaliza valor de char pra int
	muli	r13, r11, 0xa
	ldb 	r11, 4(r10)
	subi	r11, r11, 0x30 # normaliza valor de char pra int
	add 	r13, r13, r11
	
	beq 	r13, r0, END_OFF # caso o valor seja o led 0, nao encontra o led, ja que comeca em 1, e finaliza
	movi	r11, 0x21
	bge 	r13, r11, END_OFF # caso o valor seja maior que 32, nao encontra o led, ja que termina em 32, e finaliza
	
	subi	r13, r13, 0x1
	movi	r11, 0x1
	sll 	r11, r11, r13
	
	ori 	r13, r0, 0xffff
	orhi	r13, r13, 0xffff
	xor 	r11, r11, r13
	
	# acende o led escolhido
	movia 	r12, LED_SEQ
	ldw 	r13, 0(r12)
	and 	r13, r13, r11
	stw 	r13, 0(r12)
	
	END_OFF:
	
	ldw 	ra, (sp)
	addi	sp, sp, 4
	ret
	
LEDS_ON: # comando 02
	addi	sp, sp, -4
	stw 	ra, (sp)
	
	# apaga todos os leds
	movia 	r12, LED_SEQ
	ori 	r11, r0, 0xFFFF
	orhi	r11, r11, 0xFFFF
	stw 	r11, 0(r12)
	
	ldw 	ra, (sp)
	addi	sp, sp, 4
	ret
	
LEDS_OFF: # comando 03
	addi	sp, sp, -4
	stw 	ra, (sp)
	
	# apaga todos os leds
	movia 	r12, LED_SEQ
	stw 	r0, 0(r12)
	
	ldw 	ra, (sp)
	addi	sp, sp, 4
	ret
	
SWTCH_NUM: # comando 10
	addi	sp, sp, -4
	stw 	ra, (sp)
	
	stwio	r0, D7S_Low(r8)
	stwio	r0, D7S_High(r8)
	
	ldwio	r11, SWTCH(r8)
	
	movi	r9, 0x0
	GET_DIGIT:
	movi	r12, 0xA
	divu	r13, r11, r12
	mul 	r14, r13, r12
	sub 	r14, r11, r14
	
	mov 	r11, r13
	
	movia	r12, D7_SEG
	add		r12, r12, r14
	ldb 	r13, (r12)
	
	sll 	r13, r13, r9
	or  	r15, r15, r13
	
	addi	r9, r9, 8
	bne 	r11, r0, GET_DIGIT
	
	stwio	r15, D7S_Low(r8)
	
	ldw 	ra, (sp)
	addi	sp, sp, 4
	ret
	
LED_TESTE: # place-holder
	addi	sp, sp, -12
	stw 	r12, 8(sp)
	stw 	r11, 4(sp)
	stw 	ra, (sp)
	
	# acende/apaga os leds
	ldwio	r11, RED_LED(r8)
	beq 	r11, r0, Acende
	br		Apaga
	Acende:
	movia 	r12, LED_SEQ
	ldw 	r11, 0(r12)
	stwio	r11, RED_LED(r8)
	br		Final
	Apaga:
	stwio	r0, RED_LED(r8)
	Final:
	
	ldw 	r11, 4(sp)
	ldw 	r12, 8(sp)
	ldw 	ra, (sp)
	addi	sp, sp, 12
	ret

.global _start
_start:
	/* r8 - Endereco Base */
	/* r9 - Contador */
	/* r10 - Buffer */
	/* [r11 - r13] - Aux */
	movia	sp, STACK
	
	movia	r8, BASE_IO
	
	/* Habilitando interrupcoes necessarias */
	ldwio	r9, JTAG_Ctrl(r8)
	ori 	r9, r9, 0x1
	stwio	r9, JTAG_Ctrl(r8)
	
	movi	r9, 0x100
	wrctl	ienable, r9
	
	/* Habilita interrupcoes no processador */
	movi	r9, 1
	wrctl	status, r9

	# seta o endereco para o buffer
	movia	r10, BUFFER
	
	# imprime "cmd:"  no terminal
	mov 	r9, r0
	movi	r9, 0x63
	stwio	r9, JTAG_Data(r8)
	movi	r9, 0x6d
	stwio	r9, JTAG_Data(r8)
	movi	r9, 0x64
	stwio	r9, JTAG_Data(r8)
	movi	r9, 0x3a
	stwio	r9, JTAG_Data(r8)

MAIN:
	# timer provisorio (sera posto como interrupcao depois)
	ori 	r11, r0, 0xffff
	orhi	r11, r11, 0xf
	delay:
	subi	r11, r11, 0x1
	bne 	r0, r11, delay
	call	LED_TESTE
	
	br	MAIN
	
LED_SEQ: # sequencia que define quais leds acendem
.word 0x00000000
D7_SEG: # tabela de conversao para decimal em 7-segmentos
.byte 0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F
BUFFER: # buffer para os comandos
.byte 0x00, 0x00, 0x00, 0x00, 0x00