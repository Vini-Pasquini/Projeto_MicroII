/* Pseudocodigo escrito usando sintaxe SIMILAR a c (nao necessariamente correta) */

/* Definicao dos Enderecos Necessarios */
#define STACK		0x10000
#define BASE_IO 	0x10000000
// offsets
#define RED_LED 	0x0
#define DISPLAY 	0x20
#define SWITCHES	0x40
#define BUTTONS 	0x50
#define BTN_Mask	0x58
#define BTN_Edge	0x5C
#define JTAG_Data	0x1000
#define JTAG_Ctrl	0x1004
#define TM_Status	0x2000
#define TM_Ctrl 	0x2004
#define TM_Vle_Low	0x2008
#define TM_Vle_High 0x200C

/* Definicao dos Metodos chamados por Interrupcao */
// Possivel que algum metodo seja mudado para polling no codigo principal

// variáveis de uso geral
int buffer[5]; // buffer vai atualizando ate usuario dar enter, no enter chama COMANDO_VALIDADO();
int lastChar;
bool ledOn = false;
int leds[18];
// Tratamento de Interrupcao
void RTI(int dispositivo){
	switch(dispositivo){
		case TIMER:
			if(ledOn){
				stwio( r0, RED_LED*r8 );
				ledOn = false;
			}else{
				lwd( rYY, leds ); // movia rXY, leds; ldw rYY, (rXY)
				stwio( rYY, RED_LED*r8 );
				ledOn = true;
			}
			break;
		case BUTTONS:
			
			break;
		case JTAG_Ctrl:
			if(lastChar == 0x0a /* ENTER */ ){
				COMANDO_VALIDADO();
				buffer = {}; // limpa buffer
				lastChar = {}; // limpa lasChar
			}else{
				// "NiosII" como metodos .c
				ldwio( rXX, JTAG_Data*r8 ); // le data (reseta RI e pega char)
				// exemplo: buffer = 0xaabbccddee, rXX = 0xff
				rYY = buffer; // rYY = 0xaabbccddee;
				slli( rYY, rYY, 8 ); // 0xbbccddee00;
				or( buffer, rYY, rXX ); // 0xbbccddeeff;
			}stwio( rXX, JTAG_Data*r8 ); // escreve char no terminal
			break;
		default:
			break;
	}return;
}
// Ao ocorrer interrupcao pela JTAG, verifica se existe um comando valido
void COMANDO_VALIDADO(){
	if(buffer[2] == ' '){
		int comando[] = { buffer[0], buffer[1] };
		int enesimo[] = { buffer[3], buffer[4] };
		switch(comando){
			case "00":
				COMANDO_00(enesimo); break;
			case "01":
				COMANDO_01(enesimo); break;
			default:
				printf("ERROR"); break;
		}
	}else{
		int commando[] = { buffer[3], buffer[4] };
		switch(comando){
			case "02":
				COMANDO_02(); break;
			case "10":
				COMANDO_10(); break;
			case "20":
				COMANDO_20(); break;
			case "21":
				COMANDO_21(); break;
			default:
				printf("ERROR"); break;
		}
	}
}
// Ativa pulsacao do xx-ésimo LED vermelho
void COMANDO_00(int xx){
	// leds[xx] = 1;
	rXX = 0b1
	slli( rXX, rXX, xx );
	lwd( rYY, leds ); // movia rXY, leds; ldw rYY, (rXY)
	or( rYY, rYY, rXX );
	stw( rYY, leds );
}
// Desativa pulsacao do xx-ésimo LED vermelho
void COMANDO_01(int xx){
	// leds[xx] = 0;
	rXX = 0xFFFFFFFE // movhi 0xFFFF; ori 0xFFFE
	roli( rXX, rXX, xx );
	lwd( rYY, leds ); // movia rXY, leds; ldw rYY, (rXY)
	and( rYY, rYY, rXX );
	stw( rYY, leds );
}
// Destaiva pulsacao de todos os LED vermelhos
void COMANDO_02(){
	// lenOn = 0;
	lwd( rYY, leds ); // movia rXY, leds; ldw rYY, (rXY)
	and( rYY, rYY, r0 );
	stw( rYY, leds );
}
// Mostra numero triangular das chaves nos Displays de 7-seg
void COMANDO_10(){
	
}
// Mostra palavra "2021" nos Displays de 7-seg e ativa botoes de acao
void COMANDO_20(){
	
}
// Muda sentido da rotacao (se nao, mostra "error" nos displays)
void BOTAO_KEY1(){
	
}
// Pausa/Retorna rotacao (se nao, mostra "error" nos displays)
void BOTAO_KEY2(){
	
}
// Apaga palavra "2021" dos Displays de 7-seg e desativa botoes de acao
void COMANDO_21(){
	
}
/* Código Principal */
int main(){
	/* Inicializacao dos registradores necessarios */
	sp = STACK;
	
	r8 = BASE_IO;
	
	/* Habilitacao das interrupcoes necessarias */
	// Timer
	r10 = 0x7;
	stwio( r10, TM_Ctrl*r8 );
	r10 = 0xFFFF // valor provisorio
	stwio( r10, TM_Vle_Low*r8 );
	r10 = 0xF // valor provisorio
	stwio( r10, TM_Vle_High*r8 );
	// Botoes
	r10 = 0x6;
	stwio( r10, BTN_MASK*r8 );
	// JTAG
	ldwio( r10, JTAG_Ctrl*r8 );
	ori( r10, r10, 0x1 );
	stwio( r10, JTAG_Ctrl*r8 );
	
	/* Habilitacao das interrupcoes dos dispositivos no ienable */
	r10 = 0x103; // refetente às IRQ 0 (Timer), 1 (Botoes) e 8 (Jtag);
	wrctl( ienable, r10 );
	
	/* Habilitacao das interrupcoes no processador */
	r10 = 0x1;
	wrctl( status, r10 );
	
	/* Resto do código */
	// Este loop roda ate uma interrupcao ocorrer, entao RTI() eh chamada;
	for(;;){
		
	}
	
	return 0;
}






