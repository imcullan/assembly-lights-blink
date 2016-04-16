;**** Timer **** 
TSCR1 EQU $46
TSCR2 EQU $4D
TIOS  EQU $40
TCTL1 EQU $48
TCTL2 EQU $49
TFLG1 EQU $4E
TIE   EQU $4C
TSCNT EQU $44
TC4	  EQU $58
TC1	  EQU $52
;***************

;*** PORTS **** 
DDRA  EQU $02
PORTA EQU $00
PORTB EQU $01
DDRB  EQU $03
PORTM EQU $0250
DDRM  EQU $0252
;**************

;*** ADC Unit *** 
ATDCTL2	EQU $122
ATDCTL4 EQU $124
ATDCTL5	EQU $125
ADTSTAT0 EQU $126
ATD1DR1H EQU $132
ADT1DR1L EQU $133
;****************

;***************************START: INITIALIZATION******************************
.hc12             			    		; Include .hc12 directive, in case you need MUL
			ORG $1000

			ORG $400
			LDS #$4000

			LDAA #$90           		; Perform basic timer initialization to setup an output compare on PT4 
			STAA TSCR1
			LDAA #$03
			STAA TSCR2
			LDAA #$10
			STAA TIOS 

			LDAA #$01           		; Initialize register TCTL1 to toggle bit 4 on each compare event 
			STAA TCTL1

					   	      			; Initialize A/D
		  	LDAA #%11000000  	    	; Initialize ADTCTL2
		  	STAA ATDCTL2
		
		  	JSR Delay1MS     	   		; Wait at least 1ms after initializing ADTCTL2. 
		
		  	LDAA #%11100101  	   		; Initialize ADTCTL4 (8 bit resolution, 16 A/D clock
		  	STAA ATDCTL4	   	   		; periods, default mask 00101)
	
		  	LDAA #$FF		   			; Initialize DDRA so PORTA is all outputs
		  	STAA DDRA	
;***************************END: INITIALIZATION******************************

;***************************START: PERFORM SAMPLING************************* 				
INITAD 	  	LDAA #%11000000  	   		; Initiate sampling by writing to the ATDCTL5 register.
		  	STAA ATDCTL5	   	   		  	 	   
			
		  	BRCLR ADTSTAT0,%10000000,* 	; Spin on ADTSTAT0 bit 7 to detect conversion complete
		  	STAA ADTSTAT0		
		  			   
		  	LDAA ADT1DR1L		   		; Read eight bit A/D data from ATD1DR1L 
;***************************END: PERFORM SAMPLING***************************
		  	
;***************************START: TURN LIGHTS ON***************************
		  	CMPA #!32	  	   			; Less than 1/8 Vref
		  	BHI TWO
		  	LDAB #%00000001
		  	BRA DISPLAY

TWO		  	CMPA #!64		   			; Between 1/8 and 2/8 Vref
		  	BHI THREE
		  	LDAB #%00000011
		  	BRA DISPLAY

THREE	  	CMPA #!96					; Between 2/8 and 3/8 Vref
		  	BHI FOUR
		  	LDAB #%00000111
		  	BRA DISPLAY

FOUR	  	CMPA #!128		   			; Between 3/8 and 4/8 Vref
		  	BHI FIVE
		  	LDAB #%00001111
		  	BRA DISPLAY

FIVE	  	CMPA #!160		   			; Between 4/8 and 5/8 Vref
		  	BHI SIX
		  	LDAB #%00011111
		  	BRA DISPLAY

SIX	  	  	CMPA #!192		   			; Between 5/8 and 6/8 Vref
		  	BHI SEVEN
		  	LDAB #%00111111
		  	BRA DISPLAY

SEVEN	  	CMPA #!224		   			; Between 6/8 and 7/8 Vref
		  	BHI EIGHT
		  	LDAB #%01111111
		  	BRA DISPLAY
 
EIGHT	  	LDAB #%11111111	   			; Larger than 7/8 Vref
		 	   
DISPLAY	  	STAB PORTA	   	   			; Display raw A/D data on the LED bank
;***************************END: TURN LIGHTS ON****************************

;***************************START: WAIT 500ms******************************
		  	LDX #$0						; Clear X (used to wait 500ms)
ONTIMER     LDD TSCNT           		; Read current 16 bit value of TSCNT

			ADDD #!1000  	    		; Add an offset to the current TSCNT equivalent to a 1ms delay and store to TC4 
			STD TC4              

			BRCLR TFLG1,$10,*   		; Spin until the TFLG1 register indicates a bit 4 compare event (1ms passed)
				
			INX							; Increment X
			CPX #!500					; Compare value in X to 500
			BNE ONTIMER					; Branch to ONTIMER if not equal to 1000
;***************************END: WAIT 500ms********************************

;********************START: TURN LIGHTS OFF AND WAIT 500ms******************************
			LDAB #%00000000				; Turn off lights
			STAB PORTA
			LDX #$0						; Clear X (used to wait 500ms)
OFFTIMER  	LDD TSCNT           		; Read current 16 bit value of TSCNT

			ADDD #!1000  	    		; Add an offset to the current TSCNT equivalent to a 1ms delay and store to TC4 
			STD TC4              

			BRCLR TFLG1,$10,*   		; Spin until the TFLG1 register indicates a bit 4 compare event (1ms passed)
				
			INX							; Increment X
			CPX #!500					; Compare value in X to 500
			BNE OFFTIMER				; Branch to OFFTIMER if not equal to 1000
;********************END: TURN LIGHTS OFF AND WAIT 500ms******************************

			BRA INITAD					; Perform next A/D conversion

Delay1MS:  	
		  	LDY #!2000	   				; load accumulator Y with decimal 2000
D1LOOP:	    DEY 		 	   			; Decrement Y
		  	BNE D1LOOP	   				; Branch to D1LOOP if Y not equal to 0
		  	RTS			   				; returns from sub-routine