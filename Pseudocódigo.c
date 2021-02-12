/* Pseudocodigo escrito usando sintaxe SIMILAR a c (nao necessariamente correta) */

/* Definicao dos Enderecos Necessarios */
#define STACK		0x10000
#define BASE_IO		0x10000000
// offsets
#define RED_LED		0x0
#define DISPLAY		0x20
#define SWITCHES	0x40
#define BUTTONS		0x50
#define JTAG_Data	0x1000
#define JTAG_Ctrl	0x1004
#define TIMER		0x2000

/* Definicao dos Metodos chamados por Interrupcao */
// Possivel que algum metodo seja mudado para polling no codigo principal

int buffer[5]; // buffer vai atualizando ate usuario dar enter, no enter chama COMANDO_VALIDADO();
int lastChar;
// Tratamento de Interrupcao
void RTI(int dispositivo){
	switch(dispositivo){
		case TIMER:
			break;
		case BUTTONS:
			break;
		case JTAG_Ctrl:
			if(lastChar == 0x0a /* ENTER */ ){
				buffer = {}; // limpa buffer
				lastChar = {}; // limpa lasChar
				COMANDO_VALIDADO();
			}else{
				// "NiosII" como metodos .c
				ldwio( rXX, JTAG_Data*r8 ); // le data (reseta RI e pega char)
				// exemplo: buffer = 0xaabbccddee, rXX = 0xff
				rYY = buffer; // rYY = 0xaabbccddee;
				shitfLeft( rYY, rYY, 8 ); // 0xbbccddee00;
				or( buffer, rYY, rXX ); // 0xbbccddeeff;
				
				stwio( JTAG_Data*r8, rXX); // escreve char no terminal
			}break;
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
	
}
// Desativa pulsacao do xx-ésimo LED vermelho
void COMANDO_01(int xx){
	
}
// Destaiva pulsacao de todos os LED vermelhos
void COMANDO_02(){
	
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
	// Este codigo roda ate uma interrupcao ocorrer, entao RTI() eh chamada;
	return 0;
}






