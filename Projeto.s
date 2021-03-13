.equ	STACK,		0x10000
.equ	BASE_IO,	0x10000000
# offsets
.equ	RED_LED,	0x0
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
	
	# Verifica de onde veio a excecao
	rdctl	et, ipending
	beq 	et, r0, OTHER_EXC # Caso nao seja interrupcao
	br  	INTERRUPT # Caso seja interrupcao
	
	OTHER_EXC: # Para excecoes que nao sejam interrupcoes
	br  	QUIT_RTI
	
	INTERRUPT:
	subi	ea, ea, 0x4
	# Verifica qual dispositivo gerou a interrupcao
	andi	r11, et, 0x100
	beq 	r11, r0, NOT_JTAG
	call	JTAG_INTERRUPT # Chama o tratamento para JTAG
	br  	QUIT_RTI
	NOT_JTAG:
	
	andi	r11, et, 0x2
	beq 	r11, r0, NOT_BUTT
	call	BUTT_INTERRUPT # Chama o tratamento para os botoes
	br  	QUIT_RTI
	NOT_BUTT:
	
	andi	r11, et, 0x1
	beq 	r11, r0, NOT_TIMER
	call	TIMER_INTERRUPT # Chama o tratamento para o timer
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

TIMER_INTERRUPT: # Tratamento para interrupcao do timer
	addi	sp, sp, -4
	stw 	ra, (sp)
	
	# Acende/apaga os leds vermelhos
	ldwio	r11, RED_LED(r8)
	beq 	r11, r0, TURN_ON # Caso valor atual == 0 (apagado), acender
	br		TURN_OFF # Caso != 0 (aceso), apagar
	TURN_ON:
	movia 	r12, LED_SEQ # Pega o endereco da sequencia de leds
	ldw 	r11, 0(r12) # Pega o valor da sequencia de leds
	stwio	r11, RED_LED(r8) # Acende de acordo com o valor da sequencia de leds
	br		END_TURN
	TURN_OFF:
	stwio	r0, RED_LED(r8) # Apaga
	END_TURN:
	stwio	r0,	Timer(r8) # Reseta RUN e TO
	
	ldw 	ra, (sp)
	addi	sp, sp, 4
	ret
	
BUTT_INTERRUPT: # Tratamento para interrupcao dos botoes
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
	bne 	r13, r0, ROT_ON # Se != 0 (ativa), pausa
	# Se = 0 (pausada), retoma
	ldb 	r13, 2(r9)
	stb 	r13, 1(r9)
	br  	QUIT_BUTT
	ROT_ON:
	stb 	r13, 2(r9)
	stb 	r0, 1(r9)
	
	QUIT_BUTT:
	# Reseta a captura de borda para a proxima interrupcao
	movia	r11, 0x6
	stwio	r11, PB_Edge(r8)
	
	ldw 	ra, (sp)
	addi	sp, sp, 4
	ret
	
JTAG_INTERRUPT: # Tratamento para interrupcao do JTAG
	addi	sp, sp, -4
	stw 	ra, (sp)
	
	ldwio	r13, JTAG_Data(r8)
	
	movi	r11, 0x0a # Valor do caracter <ENTER>
	andi	r12, r13, 0xFF # Pega caracter mais recente na fila
	beq 	r11, r12, ENTER_INPUTED # Verifica se <ENTER> foi pressionado
	# Caso <ENTER> nao pressionado
	/* Atualiza o buffer de comando com o novo caracter */
	# 01234 -> 1234[]
	ldb 	r11, 1(r10)
	stb 	r11, 0(r10)
	ldb 	r11, 2(r10)
	stb 	r11, 1(r10)
	ldb 	r11, 3(r10)
	stb 	r11, 2(r10)
	ldb 	r11, 4(r10)
	stb 	r11, 3(r10)
	# Com a posicao 4 "vazia", salva o novo caracter na mesma
	stb 	r13, 4(r10)
	
	CHAR_INPUTED:
	stwio	r13, JTAG_Data(r8) # Imprime o caracter no terminal
	br		INPUT_END
	
	ENTER_INPUTED: # Caso <ENTER> pressionado
	call	VALID_COMMAND # Chama interpretador de comando
	
	# Limpa buffer de comando
	stb 	r0, 0(r10)
	stb 	r0, 1(r10)
	stb 	r0, 2(r10)
	stb 	r0, 3(r10)
	stb 	r0, 4(r10)
	
	# Pula linha (imprime <ENTER> no terminal)
	stwio	r13, JTAG_Data(r8)
	
	# Imprime "cmd:" no terminal
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

VALID_COMMAND: # Interpretador de comando
	addi	sp, sp, -16
	stw 	r13, 12(sp)
	stw 	r12, 8(sp)
	stw 	r11, 4(sp)
	stw 	ra, (sp)
	
	COMMAND_CHECK:
	ldb 	r11, 2(r10) # Pega caracter na posico 2
	movi	r12, 0x20 # Valor do caracter <SPACE>
	beq 	r11, r12, HAS_SPACE # Verifica se é <SPACE>
	NO_SPACE: # Caso nao tenha espaco, trata-se de um comando simples (sem passagem de parametro)
	# Verifica o primeiro digito do comando
	ldb 	r11, 3(r10)
	movi	r12, 0x30
	beq 	r11, r12, SIMPLE_0
	movi	r12, 0x31
	beq 	r11, r12, SIMPLE_1
	movi	r12, 0x32
	beq 	r11, r12, SIMPLE_2
	br  	NOT_FOUND
	
	/* Verifica, dependendo do primeiro digito, o segundo digito do comando */
		SIMPLE_0: # Para digito inicial 0
	ldb 	r11, 4(r10)
	movi	r12, 0x32
	beq 	r11, r12, CMD_02
	movi	r12, 0x33
	beq 	r11, r12, CMD_03
	br		NOT_FOUND
	
		SIMPLE_1: # Para digito inicial 1
	ldb 	r11, 4(r10)
	movi	r12, 0x30
	beq 	r11, r12, CMD_10
	br		NOT_FOUND
	
		SIMPLE_2: # Para digito inicial 2
	ldb 	r11, 4(r10)
	movi	r12, 0x30
	beq 	r11, r12, CMD_20
	movi	r12, 0x31
	beq 	r11, r12, CMD_21
	br  	NOT_FOUND
	
	HAS_SPACE: # Caso tenha espaco, trata-se de um comando com passagem de parametro
	# Verifica o primeiro digito do comando
	ldb 	r11, 0(r10)
	movi	r12, 0x30
	beq 	r11, r12, CMPLX_0
	br  	NOT_FOUND
	
	/* Verifica, dependendo do primeiro digito, o segundo digito do comando */
		CMPLX_0: # Para digito inicial 0
	ldb 	r11, 1(r10)
	movi	r12, 0x30
	beq 	r11, r12, CMD_00
	movi	r12, 0x31
	beq 	r11, r12, CMD_01
	br		NOT_FOUND
	
	# Tabela de comandos existentes
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
	
	NOT_FOUND: # Caso comando nao seja encontrado, imprime mensagem de erro
	mov 	r11, r0
	movi	r11, 0x0a
	stwio	r11, JTAG_Data(r8)
	movi	r11, 0x43
	stwio	r11, JTAG_Data(r8)
	movi	r11, 0x6F
	stwio	r11, JTAG_Data(r8)
	movi	r11, 0x6D
	stwio	r11, JTAG_Data(r8)
	movi	r11, 0x6D
	stwio	r11, JTAG_Data(r8)
	movi	r11, 0x61
	stwio	r11, JTAG_Data(r8)
	movi	r11, 0x6E
	stwio	r11, JTAG_Data(r8)
	movi	r11, 0x64
	stwio	r11, JTAG_Data(r8)
	movi	r11, 0x20
	stwio	r11, JTAG_Data(r8)
	movi	r11, 0x6E
	stwio	r11, JTAG_Data(r8)
	movi	r11, 0x6F
	stwio	r11, JTAG_Data(r8)
	movi	r11, 0x74
	stwio	r11, JTAG_Data(r8)
	movi	r11, 0x20
	stwio	r11, JTAG_Data(r8)
	movi	r11, 0x66
	stwio	r11, JTAG_Data(r8)
	movi	r11, 0x6F
	stwio	r11, JTAG_Data(r8)
	movi	r11, 0x75
	stwio	r11, JTAG_Data(r8)
	movi	r11, 0x6E
	stwio	r11, JTAG_Data(r8)
	movi	r11, 0x64
	stwio	r11, JTAG_Data(r8)
	movi	r11, 0x21
	stwio	r11, JTAG_Data(r8)
	
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
	
	# Identifica qual o led escolhido
	ldb 	r11, 3(r10)
	subi	r11, r11, 0x30 # Normaliza valor de char pra int
	muli	r13, r11, 0xa
	ldb 	r11, 4(r10)
	subi	r11, r11, 0x30 # Normaliza valor de char pra int
	add 	r13, r13, r11
	/* Para valores fora de alcance */
	beq 	r13, r0, END_ON # Caso o valor seja o led 00, nao encontra o led, ja que comeca em 01, e finaliza
	movi	r11, 0x21
	bge 	r13, r11, END_ON # Caso o valor seja maior que 32, nao encontra o led, ja que termina em 32, e finaliza
	
	# Coloca 1 na posicao do led
	subi	r13, r13, 0x1
	movi	r11, 0x1
	sll 	r11, r11, r13
	
	# Acende o led escolhido (ativa o bit correspondente na sequencia de leds)
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
	
	# Identifica qual o led escolhido
	ldb 	r11, 3(r10)
	subi	r11, r11, 0x30 # Normaliza valor de char pra int
	muli	r13, r11, 0xa
	ldb 	r11, 4(r10)
	subi	r11, r11, 0x30 # Normaliza valor de char pra int
	add 	r13, r13, r11
	/* Para valores fora de alcance */
	beq 	r13, r0, END_OFF # Caso o valor seja o led 0, nao encontra o led, ja que comeca em 1, e finaliza
	movi	r11, 0x21
	bge 	r13, r11, END_OFF # Caso o valor seja maior que 32, nao encontra o led, ja que termina em 32, e finaliza
	
	# Coloca 1 na posicao do led
	subi	r13, r13, 0x1
	movi	r11, 0x1
	sll 	r11, r11, r13
	
	# Cria a sequencia inversa (0 na posicao do led)
	ori 	r13, r0, 0xffff
	orhi	r13, r13, 0xffff
	xor 	r11, r11, r13
	
	# Apaga o led escolhido (desativa o bit correspondente na sequencia de leds)
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
	
	# Acende todos os leds
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
	
	# Apaga todos os leds
	movia 	r12, LED_SEQ
	stw 	r0, 0(r12)
	
	ldw 	ra, (sp)
	addi	sp, sp, 4
	ret
	
SWTCH_NUM: # comando 10
	addi	sp, sp, -4
	stw 	ra, (sp)
	
	call	WORD_OFF # Limpa os displays e seta flag da rotacao pra 0 (comando 21)
	
	ldwio	r11, SWTCH(r8) # Pega valor das chaves
	
	movi	r12, 0x373E # Maior valor cujo triangular nao ultrapassa 8 digitos é 14141
	bge 	r11, r12, DISPLAY_ERROR # Caso o valor ultrapasse 14141, mostra erro
	
	# Tn = (n.(n+1))/2
	addi	r12, r11, 0x1
	mul 	r13, r11, r12
	movi	r12, 0x2
	divu	r11, r13, r12 # Triangular do valor das chaves
	
	and 	r7, r7, r0 # Limpa sequencia dos digitos altos
	and 	r6, r6, r0 # Limpa sequencia dos digitos baixos
	and 	r5, r5, r0 # Zera contador
	GET_DIGIT: # Loop pra pegar a sequencia de digitos do valor calculado
	/* Pega valor%10 (resto -> digito da unidade), e transforma valor = valor/10 */
	movi	r12, 0xA
	divu	r13, r11, r12 # valor' = valor/10
	# Logica para pegar o resto
	mul 	r14, r13, r12 
	sub 	r14, r11, r14
	# Seta valor = valor' (trunca a unidade)
	mov 	r11, r13
	# Converte valor do digito em código para os displays
	movia	r12, D7_SEG # Pega endereco da tabela de conversao
	add 	r12, r12, r14 # Pega da posicao correspondente ao digito (0 a 9)
	ldb 	r13, (r12) # Pega o codigo da posicao respectiva
	
	movi	r12, 0x20
	bge 	r5, r12, HIGH_DIGIT /* Verifica se eh um dos primeiros 4 digitos ou nao */
		LOW_DIGIT: # Primeiros 4 digitos (digitos baixos)
	sll 	r13, r13, r5 # Adequa digito a sua posicao respectiva
	or  	r6, r6, r13 # Adiciona o digito na sequencia
	br  	END_DIGIT
		HIGH_DIGIT: # Ultimos 4 digitos (digitos altos)
	subi	r12, r5, 0x20 # Pega posicao normalizada para a parte alta dos displays
	sll 	r13, r13, r12 # Adequa digito a sua posicao respectiva
	or  	r7, r7, r13 # Adiciona o digito na sequencia
		END_DIGIT:
	addi	r5, r5, 8 # Itera contador (cada digito ocupa 1 byte, portanto)
	bne 	r11, r0, GET_DIGIT # Se valor' nao for 0, pega proximo digito (unidade do mesmo)
	br  	DISPLAY_NUM # Caso contrario, finaliza
	
		DISPLAY_ERROR: # Caso triangular 9+ digitos, seta valor para a palavra "error"
	orhi	r6, r0, 0x5000
	orhi	r7, r0, 0x7950
	ori 	r7, r7, 0x505C
		DISPLAY_NUM: # Imprime valor nos displays de 7 segmentos
	stwio	r6, D7S_Low(r8)
	stwio	r7, D7S_High(r8)
	
	ldw 	ra, (sp)
	addi	sp, sp, 4
	ret
	
WORD_ON: # comando 20
	addi	sp, sp, -4
	stw 	ra, (sp)
	
	ldb 	r11, 0(r9) # Verifica a flag de rotacao
	bne 	r11, r0, SKIP_ROT # Se rotacao ja ligada, pula o comando
	# Limpa o conteúdo dos displays
	stwio	r0, D7S_Low(r8)
	stwio	r0, D7S_High(r8)
	/* Imprime a palavra 2021 no centro dos displays [__20 21__] */
	and 	r11, r11, r0 # Limpa registrador
	orhi	r11, r0, 0x5B06 # 21 nos displays (parte alta do display baixo)
	stwio	r11, D7S_Low(r8)
	
	and 	r11, r11, r0 # Limpa registrador
	ori 	r11, r0, 0x5B3F # 20 nos displays (parte baixa do display alto)
	stwio	r11, D7S_High(r8)
	SKIP_ROT:
	
	# Seta flag de rotacao para ligada
	movi	r11, 0x01
	stb 	r11, 0(r9)
	
	ldw 	ra, (sp)
	addi	sp, sp, 4
	ret
	
WORD_OFF: # comando 21
	addi	sp, sp, -8
	stw 	r11, 4(sp)
	stw 	ra, (sp)
	
	# Apaga conteúdo dos displays
	stwio	r0, D7S_Low(r8)
	stwio	r0, D7S_High(r8)
	
	# Seta flag de rotacao para desligada
	movi	r11, 0x00
	stb 	r11, 0(r9)
	
	ldw 	r11, 4(sp)
	ldw 	ra, (sp)
	addi	sp, sp, 8
	ret
	
ROTATE_LEFT: # Roda conteudo dos displays para a esquerda
	addi	sp, sp, -20
	stw 	r14, 16(sp)
	stw 	r13, 12(sp)
	stw 	r12, 8(sp)
	stw 	r11, 4(sp)
	stw 	ra, (sp)
	
	ldwio	r11, D7S_Low(r8) # Pega valor da parte baixa
	andhi	r12, r11, 0xFF00 # Salva o ultimo digito da parte baixa
	srli	r12, r12, 0x18 # Normaliza a posicao do digito para a primeira
	
	ldwio	r13, D7S_High(r8) # Pega valor da parte alta
	andhi	r14, r13, 0xFF00 # Salva o ultimo digito da parte alta
	srli	r14, r14, 0x18 # Normaliza a posicao do digito para a primeira
	
	slli	r11, r11, 0x8 # Roda a parte baixa em 1 digito (1 byte, 8 bits)
	or  	r11, r11, r14 # Coloca o digito salvo da parte alta na parte baixa
	
	slli	r13, r13, 0x8 # Roda a parte alta em 1 digito (1 byte, 8 bits)
	or  	r13, r13, r12 # Coloca o digito salvo da parte baixa na parte alta
	
	# Atualiza ambas as partes (8 digitos)
	stwio	r13, D7S_High(r8)
	stwio	r11, D7S_Low(r8)
	
	ldw 	r11, 4(sp)
	ldw 	r12, 8(sp)
	ldw 	r13, 12(sp)
	ldw 	r14, 16(sp)
	ldw 	ra, (sp)
	addi	sp, sp, 20
	ret
	
ROTATE_RIGHT: # Roda conteudo dos displays para a esquerda
	addi	sp, sp, -20
	stw 	r14, 16(sp)
	stw 	r13, 12(sp)
	stw 	r12, 8(sp)
	stw 	r11, 4(sp)
	stw 	ra, (sp)
	
	ldwio	r11, D7S_Low(r8) # Pega valor da parte baixa
	andi	r12, r11, 0xFF # Salva o primeiro digito da parte baixa
	slli	r12, r12, 0x18 # Normaliza a posicao do digito para a ultima
	
	ldwio	r13, D7S_High(r8) # Pega valor da parte alta
	andi	r14, r13, 0xFF # Salva o primeiro digito da parte alta
	slli	r14, r14, 0x18 # Normaliza a posicao do digito para a ultima
	
	srli	r11, r11, 0x8 # Roda a parte baixa em 1 digito (1 byte, 8 bits)
	or  	r11, r11, r14 # Coloca o digito salvo da parte alta na parte baixa
	
	srli	r13, r13, 0x8 # Roda a parte alta em 1 digito (1 byte, 8 bits)
	or  	r13, r13, r12 # Coloca o digito salvo da parte baixa na parte alta
	
	# Atualiza ambas as partes (8 digitos)
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
	# Verifica se a rotacao esta ligada ou desligada
	ldb 	r13, 0(r9)
	beq 	r13, r0, END_ROT # Se == 0 (desligada), pula pro final
	# Verifica se a rotacao esta pausada ou despausada
	movi	r11, 0x1
	ldb 	r13, 1(r9)
	beq 	r13, r0, END_ROT # Se == 0 (pausada), pula pro final
	beq 	r13, r11, R_ROT # Se == 1 (esquerda), pula pra rotacao direita
	L_ROT:
	call	ROTATE_LEFT # Chama se 1(r9) == 2
	br	END_ROT
	R_ROT:
	call	ROTATE_RIGHT # Chama se 1(r9) == 1
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