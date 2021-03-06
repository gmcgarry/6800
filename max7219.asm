; MAX7219 driver
; SPI 8-digit LED Display Driver
;
; pins: VCC, GND, DATA, CS, CLK
;
; 16-bit instructions, 8-bit address + 8-bit data
; MSB first, latch bits on rising edge
; 16 registers
; BCD decode (0-9) is controlled per digit
;
; attached to PIA PORTB, SDAT=0,SLAT=1,SCLK=2
;

PUTC    EQU     $E205
MONITR  EQU     $E01A

STACK	EQU	$7E00

; port addresses
PORT	EQU	$D402

; pin assignments
SDAT	EQU	0
SLAT	EQU	1
SCLK	EQU	2

CMD_NOOP  	EQU	0
CMD_DIGIT0	EQU	1
CMD_DIGIT1	EQU	2
CMD_DIGIT2	EQU	3
CMD_DIGIT3	EQU	4
CMD_DIGIT4	EQU	5
CMD_DIGIT5	EQU	6
CMD_DIGIT6	EQU	7
CMD_DIGIT7	EQU	8
CMD_DECODEMODE  EQU	9
CMD_INTENSITY   EQU	10
CMD_SCANLIMIT   EQU	11
CMD_SHUTDOWN	EQU	12
CMD_DISPLAYTEST	EQU	15

	ORG	$0100
RESET	LDS	#STACK
	JMP	MAIN

; must be within 256-byte page
;  A
; F B
;  G
; E C
;  D
;
; DP,ABCDEFG
TBL	DB	01111110B,00110000B,01101101B,01111001B,00110011B,01011011B,01011111B,01110000B
	DB	01111111B,01111011B,01110111B,00011111B,01001110B,00111101B,01001111B,01000111B

MAIN	LDX	#starts
	BSR	PUTS

	BSR	INIT

	; reset
	LDAA	#CMD_DISPLAYTEST
	CLRA
	BSR	WRITECMD

	; enable all LEDs/lines
	LDAA	#CMD_SCANLIMIT
	LDAB	#7
	BSR	WRITECMD

	; disable BCD decode on all digits
	LDAA	#CMD_DECODEMODE
	CLRB
	BSR	WRITECMD

	; clear display
	BSR	CLEAR

	; low intensity
	LDAA	#CMD_INTENSITY
	CLRB
	BSR	WRITECMD

	; turn on
	LDAA	#CMD_SHUTDOWN
	LDAB	#1
	BSR	WRITECMD

	CLRA
1:	DECA
	BSR	PUTHEX
	BSR	DELAY
	CMPA	#0
	BNE	1b

	LDX	#ends
	BSR	PUTS

	JMP	MONITR

starts	.asciz	"max7219 LED driver.\r\n"
ends	.asciz	"done.\r\n"

DELAY	LDX	#$2FFF
1:	DEX
	BNE	1b
	RTS

; char in A
PUTHEX	PSHA
	PSHB

	PSHA
	ASRA
	ASRA
	ASRA
	ASRA
	ANDA	#$0F
	TAB
	LDAA	#CMD_DIGIT1
	BSR	SETDIGIT
	PULB
	ANDB	#$0F
	LDAA	#CMD_DIGIT0
	BSR	SETDIGIT
	
	PULB
	PULA
	RTS

INIT	PSHA
	PSHB
	CLR	PORT+1                  ; select DDR
	LDAB	#(1<<SDAT)|(1<<SLAT)|(1<<SCLK)
	STAB	PORT
	LDAA	#$04			; select DATA
	STAA	PORT+1
	CLR	PORT			; set to low
	PULB
	PULA
	RTS

CLEAR	PSHA
	PSHB
	LDAA	#8
	CLRB
1:	BSR	WRITECMD
	DECA
	BPL	1b
	PULB
	PULA
	RTS

XHI	DS	1
XLO	DS	1

; A=digit
; B=value
SETDIGIT:
	PSHB
	ADDB	#<TBL
	STAB	XLO
	CLRB
	ADCB	#>TBL
	STAB	XHI
	LDX	XHI
	LDAB	,X
	BSR	WRITECMD
	PULB
	RTS

; A=command
; B=data
WRITECMD:	; sent MSB first
	PSHA
	BSR	WRITEBYTE
	TBA
	BSR	WRITEBYTE
	LDAA	#(1<<SLAT)	; pull LATCH high
	STAA	PORT
	CLRA			; pull LATCH low
	STAA	PORT
	PULA
	RTS

; A=byte
WRITEBYTE:
	PSHA
	PSHB
	LDX	#8
1:	ASLA
	ROLB
	ANDB	#(1<<SDAT)	; mask SDAT
	STAB	PORT
	ORAB	#(1<<SCLK)	; SCLK high
	STAB	PORT
	ANDB	#(1<<SDAT)	; SCLK low
	STAB	PORT
	DEX
	BNE	1b
	PULB
	PULA
	RTS

1:	BSR	PUTC
	INX
PUTS	LDAA	0,X
	BNE	1b
	RTS

	END
