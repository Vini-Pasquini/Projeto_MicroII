.equ	STACK,		0x10000
.equ	BASE_IO,	0x10000000
# offsets
.equ	RED_LED,	0x0
.equ	GREEN_LED,	0x10 # proposito de teste
.equ	D7S_Low,	0x20
.equ	D7S_High,	0x30
.equ	SWTCH,		0x40
.equ	Push_Butt,	0x50
.equ	PB_Mask,	0x58
.equ	PB_Edge,	0x5C
.equ	JTAG_Data,	0x1000
.equ	JTAG_Ctrl,	0x1004
.equ	Timer,  	0x2000

# RTI
.org 0x20
	addi	sp, sp, -32
	stw 	r14, 28(sp)
	stw 	r13, 24(sp)
	stw 	r12, 20(sp)
	stw 	r11, 16(sp)
	stw 	r7, 12(sp)
	stw 	r6, 8(sp)
	stw 	r5, 4(sp)
	stw 	ra, (sp)
	
	# Verifica de onde veio a interrupcao
	rdctl	et, ipending
	beq 	et, r0, OTHER_EXC
	br  	INTERRUPT
	
	OTHER_EXC:
	br  	QUIT_RTI
	
	INTERRUPT:
	subi	ea, ea, 0x4
	
	andi	r11, et, 0x100
	beq 	r11, r0, NOT_JTAG
	call	JTAG_INTERRUPT
	br  	QUIT_RTI
	NOT_JTAG:
	
	andi	r11, et, 0x2
	beq 	r11, r0, NOT_BUTT
	call	BUTT_INTERRUPT
	br  	QUIT_RTI
	NOT_BUTT:
	
	andi	r11, et, 0x1
	beq 	r11, r0, NOT_TIMER
	call	TIMER_INTERRUPT
	br  	QUIT_RTI
	NOT_TIMER:
	
	QUIT_RTI:
	ldw 	r5, 4(sp)
	ldw 	r6, 8(sp)
	ldw 	r7, 12(sp)
	ldw 	r11, 16(sp)
	ldw 	r12, 20(sp)
	ldw 	r13, 24(sp)
	ldw 	r14, 28(sp)
	ldw 	ra, (sp)
	addi	sp, sp, 32
	eret

TIMER_INTERRUPT:
	addi	sp, sp, -4
	stw 	ra, (sp)
	
	# Acende/apaga os leds
	ldwio	r11, RED_LED(r8)
	beq 	r11, r0, TURN_ON
	br		TURN_OFF
	TURN_ON:
	movia 	r12, LED_SEQ
	ldw 	r11, 0(r12)
	stwio	r11, RED_LED(r8)
	br		END_TURN
	TURN_OFF:
	stwio	r0, RED_LED(r8)
	END_TURN:
	stwio	r0,	Timer(r8)
	
	ldw 	ra, (sp)
	addi	sp, sp, 4
	ret
	
BUTT_INTERRUPT:
	addi	sp, sp, -4
	stw 	ra, (sp)
	
	# Verifica se rotacao esta ligada
	ldb 	r13, 0(r9)
	beq 	r13, r0, QUIT_BUTT
	# Verifica qual botao foi pressionado
	ldwio	r13, PB_Edge(r8)
	movi	r11, 0x02
	bne 	r11, r13, OTHER_BUTT
	
	/* Botao 1 */
	# Verifica direcao da rotacao
	ldb 	r13, 1(r9)
	beq 	r13, r0, QUIT_BUTT # Se pausada, sai
	bne 	r13, r11, R_to_L
	
	L_to_R: # Muda de esquerda para direita
	movi	r11, 0x01
	stb 	r11, 1(r9)
	stb 	r11, 2(r9)
	br  	QUIT_BUTT
	
	R_to_L: # Muda de direita para esquerda
	movi	r11, 0x02
	stb 	r11, 1(r9)
	stb 	r11, 2(r9)
	br  	QUIT_BUTT
	
	/* Botao 2 */
	OTHER_BUTT:
	# Verifica se rotacao esta pausada
	ldb 	r13, 1(r9)
	bne 	r13, r0, ROT_ON
	# Se estiver pausada, retoma
	ldb 	r13, 2(r9)
	stb 	r13, 1(r9)
	br  	QUIT_BUTT
	# Se nao, pausa
	ROT_ON:
	stb 	r13, 2(r9)
	stb 	r0, 1(r9)
	
	QUIT_BUTT:
	
	movia	r11, 0x6
	stwio	r11, PB_Edge(r8)
	
	ldw 	ra, (sp)
	addi	sp, sp, 4
	ret
	
JTAG_INTERRUPT:
	addi	sp, sp, -4
	stw 	ra, (sp)
	
	ldwio	r13, JTAG_Data(r8)
	
	movi	r11, 0x0a
	andi	r12, r13, 0xFF
	beq 	r11, r12, ENTER_INPUTED
	
	# atualiza o buffer do comando com o novo char
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
	call	WORD_ON
	br		END_CHECK
		CMD_21:
	call	WORD_OFF
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
	
	call	WORD_OFF # Limpa os displays e seta flag da rotacao pra 0 (comando 21)
	
	ldwio	r11, SWTCH(r8)
	
	movi	r12, 0x373E # maior valor cujo triangular nao ultrapassa 8 digitos é 14141
	bge 	r11, r12, DISPLAY_ERROR
	
	# Tn = (n.(n+1))/2
	addi	r12, r11, 0x1
	mul 	r13, r11, r12
	movi	r12, 0x2
	divu	r11, r13, r12
	
	and 	r7, r7, r0
	and 	r6, r6, r0
	and 	r5, r5, r0
	GET_DIGIT:
	movi	r12, 0xA
	divu	r13, r11, r12
	mul 	r14, r13, r12
	sub 	r14, r11, r14
	
	mov 	r11, r13
	
	movia	r12, D7_SEG
	add 	r12, r12, r14
	ldb 	r13, (r12)
	
	movi	r12, 0x20
	bge 	r5, r12, HIGH_DIGIT
		LOW_DIGIT:
	sll 	r13, r13, r5
	or  	r6, r6, r13
	br  	END_DIGIT
		HIGH_DIGIT:
	subi	r12, r5, 0x20
	sll 	r13, r13, r12
	or  	r7, r7, r13
		END_DIGIT:
	addi	r5, r5, 8
	bne 	r11, r0, GET_DIGIT
	br  	DISPLAY_NUM
	
		DISPLAY_ERROR:
	orhi	r6, r0, 0x5000
	orhi	r7, r0, 0x7950
	ori 	r7, r7, 0x505C
		DISPLAY_NUM:
	stwio	r6, D7S_Low(r8)
	stwio	r7, D7S_High(r8)
	
	ldw 	ra, (sp)
	addi	sp, sp, 4
	ret
	
WORD_ON: # comando 20
	addi	sp, sp, -4
	stw 	ra, (sp)
	
	ldb 	r11, 0(r9)
	bne 	r11, r0, SKIP_ROT
	
	stwio	r0, D7S_Low(r8)
	stwio	r0, D7S_High(r8)
	
	and 	r11, r11, r0 # limpa tanto parte baixa quanto parte alta
	
	orhi	r11, r0, 0x5B06 # 21 nos displays (parte alta do display baixo)
	stwio	r11, D7S_Low(r8)
	
	and 	r11, r11, r0 # limpa tanto parte baixa quanto parte alta
	
	ori 	r11, r0, 0x5B3F # 20 nos displays (parte baixa do display alto)
	stwio	r11, D7S_High(r8)
	SKIP_ROT:
	
	movi	r11, 0x01
	stb 	r11, 0(r9)
	
	ldw 	ra, (sp)
	addi	sp, sp, 4
	ret
	
WORD_OFF: # comando 21
	addi	sp, sp, -8
	stw 	r11, 4(sp)
	stw 	ra, (sp)
	
	stwio	r0, D7S_Low(r8)
	stwio	r0, D7S_High(r8)
	
	movi	r11, 0x00
	stb 	r11, 0(r9)
	
	ldw 	r11, 4(sp)
	ldw 	ra, (sp)
	addi	sp, sp, 8
	ret
	
ROTATE_LEFT:
	addi	sp, sp, -20
	stw 	r14, 16(sp)
	stw 	r13, 12(sp)
	stw 	r12, 8(sp)
	stw 	r11, 4(sp)
	stw 	ra, (sp)
	
	ldwio	r11, D7S_Low(r8)
	andhi	r12, r11, 0xFF00
	srli	r12, r12, 0x18
	
	ldwio	r13, D7S_High(r8)
	andhi	r14, r13, 0xFF00
	srli	r14, r14, 0x18
	
	slli	r11, r11, 0x8
	or  	r11, r11, r14
	
	slli	r13, r13, 0x8
	or  	r13, r13, r12
	
	stwio	r13, D7S_High(r8)
	stwio	r11, D7S_Low(r8)
	
	ldw 	r11, 4(sp)
	ldw 	r12, 8(sp)
	ldw 	r13, 12(sp)
	ldw 	r14, 16(sp)
	ldw 	ra, (sp)
	addi	sp, sp, 20
	ret
	
ROTATE_RIGHT:
	addi	sp, sp, -20
	stw 	r14, 16(sp)
	stw 	r13, 12(sp)
	stw 	r12, 8(sp)
	stw 	r11, 4(sp)
	stw 	ra, (sp)
	
	ldwio	r11, D7S_Low(r8)
	andi	r12, r11, 0xFF
	slli	r12, r12, 0x18
	
	ldwio	r13, D7S_High(r8)
	andi	r14, r13, 0xFF
	slli	r14, r14, 0x18
	
	srli	r11, r11, 0x8
	or  	r11, r11, r14
	
	srli	r13, r13, 0x8
	or  	r13, r13, r12
	
	stwio	r13, D7S_High(r8)
	stwio	r11, D7S_Low(r8)
	
	ldw 	r11, 4(sp)
	ldw 	r12, 8(sp)
	ldw 	r13, 12(sp)
	ldw 	r14, 16(sp)
	ldw 	ra, (sp)
	addi	sp, sp, 20
	ret
	
.global _start
_start:
	/* r8 - Endereco Base */
	/* r9 - Flag para rotacao */
	/* r10 - Buffer */
	/* [r11 - r14] - Aux */
	
	movia	sp, STACK # Seta endereco inicial da Stack
	
	movia	r8, BASE_IO # Endereco base para E/S
	movia	r9, ROT_FLAG # Seta o endereco para a flag direcional
	movia	r10, BUFFER # Seta o endereco para o buffer
	
	/* Habilitando interrupcoes necessarias */
	# JTag
	ldwio	r11, JTAG_Ctrl(r8)
	ori 	r11, r11, 0x1
	stwio	r11, JTAG_Ctrl(r8)
	
	# Seta os bits dos botoes 1 e 2 no registrador de interrupcao
	movi	r11, 0x6 # Equivalente a 0b0110
	stwio	r11, PB_Mask(r8)
	
	# Seta o tempo do timer (Aproximadamente 250ms)
	movia	r11, 0xFFFF
	stwio	r11, Timer+8(r8)
	movia	r11, 0xAF
	stwio	r11, Timer+12(r8)
	movia	r11, 0x7
	stwio	r11, Timer+4(r8)
	
	# Habilita as interrupcoes dos dispositivos
	movi	r11, 0x103
	wrctl	ienable, r11
	
	# Habilita interrupcoes no processador
	movi	r11, 1
	wrctl	status, r11
	
	# Imprime "cmd:"  no terminal
	mov 	r11, r0
	movi	r11, 0x63
	stwio	r11, JTAG_Data(r8)
	movi	r11, 0x6d
	stwio	r11, JTAG_Data(r8)
	movi	r11, 0x64
	stwio	r11, JTAG_Data(r8)
	movi	r11, 0x3a
	stwio	r11, JTAG_Data(r8)

MAIN:
	# Tempo pra rotacao (Aproximadamente 200ms)
	ori 	r11, r0, 0xffff
	orhi	r11, r11, 0x7
	WAIT:
	subi	r11, r11, 0x1
	bne 	r0, r11, WAIT
	
	ldb 	r13, 0(r9)
	beq 	r13, r0, END_ROT
	
	movi	r11, 0x1
	ldb 	r13, 1(r9)
	beq 	r13, r0, END_ROT
	beq 	r13, r11, R_ROT
	L_ROT:
	call	ROTATE_LEFT
	br	END_ROT
	R_ROT:
	call	ROTATE_RIGHT
	END_ROT:
	
	br	MAIN
	
LED_SEQ: # sequencia que define quais leds acendem
.word 0x00000000
ROT_FLAG: # Flag para rotacao (0 - Rotacao ligada [0 ou 1]; 1 - Direcao [0, 1, 2]; 2 - buffer)
.byte 0x00, 0x02, 0x01 # (Direcoes: 0 - parado; 2 - esquerda; 1 - direita)
D7_SEG: # tabela de conversao para decimal em 7-segmentos
.byte 0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F
BUFFER: # buffer para os comandos
.byte 0x00, 0x00, 0x00, 0x00, 0x00