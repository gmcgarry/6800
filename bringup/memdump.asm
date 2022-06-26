; dumps all memory over ACIA
; runs from ROM
; requires 128B RAM for STACK

; CLOCK = 3.6864MHz => 0.9216MHz
;	/16 = 57600 bps

ACIA	EQU	0D800H
ACIACS	EQU	ACIA+0
ACIADA	EQU	ACIA+1

XHI	EQU	30H
XLO	EQU	31H

	.base	0xE000
	.org	0xE000
START:
	LDS	#$007F
	CLC

	CLRA
	LDX	#$007F
1:
	STAA	,X
	DEX
	BNE	1b

MAIN:
	BSR	INIT
	LDX	#0000H
1:
	STX	XHI
	LDAA	XHI
	JSR	PUTHEX
	LDAA	XLO
	JSR	PUTHEX
	LDAA	#':'
	JSR	PUTC
	LDAA	#' '
	JSR	PUTC
	LDAA	,X
	JSR	PUTHEX
	LDAA	#'\r'
	JSR	PUTC
	LDAA	#'\n'
	JSR	PUTC
	INX
	BRA	1b

INIT:
        LDAA    #$03    ; RESET CODE
        STAA    ACIACS
        NOP
        NOP
        NOP
        LDAA    #$15    ; 0,00,101,01: no rx irq, RTS=low no tx irq, /16, N81 NON-INTERRUPT
        STAA    ACIACS
	RTS

PUTC:
        PSHA
1:
        LDAA    ACIACS
        ASRA    
        ASRA    
        BCC     1b
        PULA    
        STAA    ACIADA
        RTS

PUTHEX:
	PSHA
	BSR	1f	; OUT LEFT HEX CHAR
	PULA
	BRA	2f	; OUTPUT RIGHT HEX CHAR AND R
1:
	LSRA		; OUT HEX LEFT BCD DIGIT
	LSRA
	LSRA
	LSRA
2:
	ANDA    #$F     ; OUT HEX RIGHT BCD DIGIT
	ADDA    #$30
	CMPA    #$39
	BLS     PUTC
	ADDA    #$7
	BRA	PUTC

	.org	0xFFF8
IRQ:
	.word	START
SOFT:
	.word	START
NMI:
	.word	START
RESET:
	.word	START

	.end
