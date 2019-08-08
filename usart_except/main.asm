.org 0x000
	jmp reset
.org 0x0006 
	jmp handle_INT0
.org 0x000A
	jmp handle_INT2
.org OC1Aaddr
	jmp OC1A_Interrupt

.def temp = r16
.def temp2 = r22
.def temp3 = r24
.def temp4 = r25
.def andar = r17
.def botoes = r18
.def contador = r19
.def flags = r20  ;  0000  0-0-Estado-Porta
.equ flagsPortaFechada = 0   ; 1 - Fechada, 0 - Aberta
.equ flagsEstado = 1 ;  0 - Parado; 1 Em movimento
.def destino = r21


;Bits das Flags
.equ botoesE0 = 6
.equ botoesE1 = 5
.equ botoesE2 = 4
.equ botoesI0 = 2
.equ botoesI1 = 1
.equ botoesI2 = 0
.equ B = 2 ;PORTD2
.equ A = 3 ;PORTD3



enable_transmit:
	cli
	push temp
	ldi temp, (1 << TXEN0)
	sts UCSR0B, temp; enable transmit 
	pop temp
	sei
	ret

startTimer:
	cli
	push temp
	ldi temp, ((WGM>> 2) << WGM12)|(PRESCALE << CS10)
	; CONFIGURA WGM13,12 para CTC,  Seta Prescale
	sts TCCR1B, temp ;start counter
	pop temp
	sei
	ret

resetTimer:
	ret
	cli
	push temp
	ldi temp, 0
	sts TCNT1H, temp
	sts TCNT1L, temp
	pop temp
	sei
	ret

stopTimer:
	cli
	push temp
	ldi temp, 0
	sts TCCR1B, temp ;stop counter
	pop temp
	sei
	ret

liga_buzzer:
	cli
	push temp
	in temp, PORTB
	sbr temp, (1<< 1) ;Buzzer ON
	out PORTB, temp
	pop temp
	sei
	ret
apaga_buzzer:
	cli
	push temp
	in temp, PORTB
	cbr temp, (1<< 1) ;Buzzer OFF
	out PORTB, temp
	pop temp
	sei
	ret


liga_led:
	cli
	push temp
	in temp, PORTB
	sbr temp, ( 1<<5) ; Seta pino do led ON
	out PORTB, temp
	pop temp
	sei
	ret

apaga_led:
	cli
	push temp
	in temp, PORTB
	cbr temp, ( 1<<5 ) ; Seta pino do led OFF
	out PORTB, temp
	pop temp
	sei
	ret

delay20ms:
	cli
	push r22
	push r21
	push r20
	ldi r22,byte3(16*1000*20 / 5)
	ldi r21, high(16*1000*20 / 5)
	ldi r20, low(16*1000*20 / 5)
	subi r20,1
	sbci r21,0
	sbci r22,0
	brcc pc-3
	pop r20
	pop r21
	pop r22
	sei
	ret


atualiza_display:
	cli
	push temp2
	in temp2, PORTD
	cpi andar, 0
	breq atualiza_0
	cpi andar, 1
	breq atualiza_1
	cpi andar, 2
	breq atualiza_2
	cpi andar, 3
	breq atualiza_3
	jmp end_atualiza
	atualiza_0:
		cbr temp2, (1 << A) | (1 << B)
		jmp end_atualiza
	atualiza_1:
		cbr temp2, (1 << B)
		sbr temp2, (1 << A)
		jmp end_atualiza
	atualiza_2:
		cbr temp2, (1 << A)
		sbr temp2, (1 << B)
		jmp end_atualiza
	atualiza_3:
		sbr temp2, (1 << A)
		sbr temp2, (1 << B)
		jmp end_atualiza
	end_atualiza:
	out PORTD, temp2
	pop temp2
	sei
	ret
	; A = 3 PD3
	; B = 2 PD2

abre:
	cli
	call apaga_buzzer
	call stopTimer 
	call resetTimer
	cbr flags, (1 <<flagsPortaFechada)
	call liga_led
	call startTimer
	ldi contador, 0
	sei
	ret

fecha:
	cli
	sbr flags, (1 <<flagsPortaFechada)
	call apaga_buzzer
	call apaga_led
	call stopTimer
	call resetTimer
	ldi contador, 0
	sei
	ret


OC1A_Interrupt:
	cli
	subi contador, -1
	sbrc flags, flagsEstado
	jmp time_movimento
	jmp time_parado
	time_movimento:
		cpi contador, 3
		brne end_time
		cbr flags, (1<<flagsEstado)
		mov andar, destino
		call stopTimer
		call resetTimer
		ldi contador, 0
		cpi andar, 2
		breq tx_2
		cpi andar, 1
		breq tx_1	
		cpi andar, 0
		breq tx_0
		tx_2: 
			ldi temp4, '2'
			sts UDR0, temp4
			jmp end_time
		tx_1:
			ldi temp4, '1'
			sts UDR0, temp4
			jmp end_time
		tx_0:
			ldi temp4, '0'
			sts UDR0, temp4
		  jmp end_time
		jmp end_time
	time_parado:
		sbrc flags, flagsPortaFechada
		jmp end_time
		cpi contador, 5
		breq time_parado_aberta_5
		cpi contador, 10
		breq time_parado_aberta_10
		jmp end_time

	time_parado_aberta_5:
		call liga_buzzer
		jmp end_time
	time_parado_aberta_10:
		call fecha
		jmp end_time
	end_time:
	sei
	reti
	
	
handle_INT2:
	push temp
	in temp, PIND
	cli 
	call delay20ms
	call delay20ms
	;0 do Elevador = PD4 ; PCINT20
	;1 do Elevador = PD5 ; PCINT21
	;2 do Elevador = PD6 ; PCINT22
	;Abrir do Elevador = PD7; PCINT23

	
	
	sbrc temp,4 
	jmp botao_chamar_I0_pressionado
	
	sbrc temp,5
	jmp botao_chamar1_in_pressionado
	
	sbrc temp,6
	jmp botao_chamar2_in_pressionado

	sbrc temp,7
	jmp botao_abrir_pressionado
	
	jmp end_handle_int2
	botao_chamar_I0_pressionado:
		ldi temp4, 'E'
		sts UDR0, temp4			
		sbr botoes, ( 1<<botoesI0)
		jmp end_handle_int2
	botao_chamar1_in_pressionado:
		ldi temp4, 'G'
		sts UDR0, temp4		
		sbr botoes, ( 1<<botoesI1)
		jmp end_handle_int2
	botao_chamar2_in_pressionado:
		ldi temp4, 'H'
		sts UDR0, temp4				
		sbr botoes, ( 1<<botoesI2)
		jmp end_handle_int2
	botao_abrir_pressionado:
		ldi temp4, 'A'
		sts UDR0, temp4
		sbrc flags, flagsEstado
		jmp end_handle_int2
		call abre
		jmp end_handle_int2
	end_handle_int2:
	sei
	pop temp
	reti


handle_INT0:
	push temp
	in temp, PINB
	cli ; TODO: Só desligar essa interrupção
	; Fechar do Elevador = PB0; PCINT0
	; Chamar 0 = PB2; PCINT2
	; Chamar 1 = PB3; PCINT3 
	; Chamar 2  = PB4; PCINT4
	call delay20ms
	call delay20ms;Debouncing
	
	sbrc temp,0
	jmp botao_fechar_pressionado

	sbrc temp,2
	jmp botao_chamar0_ext_pressionado

	sbrc temp,3
	jmp botao_chamar1_ext_pressionado

	sbrc temp,4
	jmp botao_chamar2_ext_pressionado

	jmp end_handle_int0
	botao_chamar0_ext_pressionado:
		ldi temp4, 'B'
		sts UDR0, temp4		
		sbr botoes, ( 1<<botoesE0)
		jmp end_handle_int0
	botao_chamar1_ext_pressionado:
		ldi temp4, 'C'
		sts UDR0, temp4		
		sbr botoes, ( 1<<botoesE1)
		jmp end_handle_int0
	botao_chamar2_ext_pressionado:
		ldi temp4, 'D'
		sts UDR0, temp4		
		sbr botoes, ( 1<<botoesE2)
		jmp end_handle_int0
	botao_fechar_pressionado:
		ldi temp4, 'F'
		sts UDR0, temp4		
		sbrc flags,flagsEstado
		jmp end_handle_int0
		sbrc flags, flagsPortaFechada
		jmp end_handle_int0
		call fecha
		jmp end_handle_int0
	end_handle_int0:
	sei
	pop temp
	reti
reset:
	cli

	; Seta Baud Rate para 9600. Error= 0.2% De acordo com a tabela.
	; f = 16Mhz
	.equ UBRRvalue = 103 

	;initialize USART
	ldi temp, high (UBRRvalue) ;baud rate
	sts UBRR0H, temp
	ldi temp, low (UBRRvalue)
	sts UBRR0L, temp

	;8 bits data, 1 bit stop, no parity
	ldi temp, (3<<UCSZ00) ; 0000 0110
	sts UCSR0C, temp

	call enable_transmit

	#define CLOCK 16.0e6 ;clock speed
	.equ PRESCALE = 0b100 ;/256 prescale
	.equ PRESCALE_DIV = 256

	#define DELAY 1  ;seconds
	.equ WGM = 0b0100 ;Waveform generation mode: CTC
	;you must ensure this value is between 0 and 65535
	.equ TOP = int(0.5 + ((CLOCK/PRESCALE_DIV)*DELAY))
	.if TOP > 65535
	.error "TOP is out of range"	
	.endif

	;On MEGA series, write high byte of 16-bit timer registers first
	ldi temp, high(TOP) ;initialize compare value (TOP)
	sts OCR1AH, temp
	ldi temp, low(TOP)
	sts OCR1AL, temp

	ldi temp, ((WGM&0b11) << WGM10) ;lower 2 bits of WGM 
	sts TCCR1A, temp
	;upper 2 bits of WGM and clock select

	; Comparacao no Match A 
	lds r16, TIMSK1
	sbr r16, 1 <<OCIE1A
	sts TIMSK1, r16	
	
	
	

	;CONFIG PORTB E PORTD como entrada(0) e saida(1)
	ldi temp, 0b00100010
	out DDRB, temp
	ldi temp, 0b00001100
	out DDRD, temp


	;Pin change Interrupt (23:16) and (0:7)
	ldi temp, 0b00000101;
	sts PCICR, temp
 
	; Enables PCINT 4 TO 0, but 1 (the buzzer).
	ldi temp, 0b00011101;
	sts PCMSK0, temp 

	; Enables PCINT 23 TO 20
	ldi temp, 0b11110000
	sts PCMSK2, temp 
	

	;Stack initialization
	ldi temp, low(RAMEND)
	out SPL, temp
	ldi temp, high(RAMEND)
	out SPH, temp

	ldi botoes, 0
	ldi flags, (1 << flagsPortaFechada) ; Porta fechada e Parado.

	;Zerando Saídas	
	ldi temp,0
	sts PORTD,temp
	sts portB,temp

	ldi temp2,0
	ldi temp3,0
	ldi temp4,0
	ldi contador, 0

	call fecha
	call stopTimer    ; Timer 
	call resetTimer   ; Timer = Resetado
	ldi andar, 0        ; Andar = 0
	ldi destino, 0

	sei

	main:
	call atualiza_display
	sbrc flags, flagsEstado
	jmp main
	main_parado:
		cpi andar, 2
		breq main_parado_2
		cpi andar, 1
		breq main_parado_1
		cpi andar, 0
		breq main_parado_0_GO
		jmp default
	main_parado_0_GO:
		jmp main_parado_0
	main_parado_2:
		sbrc botoes, botoesE2
		jmp main_parado_2_E2_I2
		sbrc botoes, botoesI2
		jmp main_parado_2_E2_I2
		sbrc botoes, botoesE1
		jmp main_parado_2_RESTO
		sbrc botoes, botoesI1
		jmp main_parado_2_RESTO
		sbrc botoes, botoesE0
		jmp main_parado_2_RESTO
		sbrc botoes, botoesI0
		jmp main_parado_2_RESTO
		jmp default
	main_parado_2_E2_I2:
		cbr botoes, (1<<botoesE2)|(1<<botoesI2)
		call abre
		jmp default
	main_parado_2_RESTO:
		ldi destino, 1
		jmp default
	main_parado_1:
		sbrc botoes, botoesI1
		jmp main_parado_1_I1

		sbrc botoes, botoesI2
		jmp main_parado_1_E2_I2
		sbrc botoes, botoesE2
		jmp main_parado_1_E2_I2

		sbrc botoes, botoesE1
		jmp main_parado_1_E1

		sbrc botoes, botoesE0
		jmp main_parado_1_E0_I0
		sbrc botoes, botoesI0
		jmp main_parado_1_E0_I0
		jmp default
	main_parado_1_I1:
		call abre
		cbr botoes, (1<<botoesI1)
		jmp default
	main_parado_1_E2_I2:
		ldi destino,2
		jmp default
	main_parado_1_E1:
		call abre
		cbr botoes, (1<<botoesE1)		
		jmp default
	main_parado_1_E0_I0:
		ldi destino,0
		jmp default
	main_parado_0:

		sbrc botoes, botoesI0
		jmp main_parado_0_I0

		sbrc botoes, botoesI2
		jmp main_parado_0_E2_I2_E1_I1
		sbrc botoes, botoesE2
		jmp main_parado_0_E2_I2_E1_I1
		sbrc botoes, botoesI1
		jmp main_parado_0_E2_I2_E1_I1
		sbrc botoes, botoesE1
		jmp main_parado_0_E2_I2_E1_I1

		sbrc botoes, botoesE0
		jmp main_parado_0_E0
		jmp default

	main_parado_0_I0:
		call abre
		cbr botoes, (1<<botoesI0)
		jmp default
	main_parado_0_E2_I2_E1_I1:
		ldi destino, 1
		jmp default
	main_parado_0_E0:
		call abre
		cbr botoes, (1<<botoesE0)
		jmp default
	default:
		sbrs flags, flagsPortaFechada
		jmp main
		default_porta_fechada:
			cp destino, andar
			breq main_go
			default_porta_fechada_destino_diff_andar:
				sbr flags, (1<<flagsEstado)
				call startTimer
		jmp main
	main_go:
		jmp main
