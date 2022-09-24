PIA	EQU	$D400
PIADATA	EQU	PIA+0
PIACTLA	EQU	PIA+1
PIADATB	EQU	PIA+2
PIACTLB	EQU	PIA+3

; for SMITHBUG
;MONITR	EQU	$E01A
;PUTC	EQU	$E205
;GETC	EQU	$E1EE
;GETHEX	EQU	$E072
;OUTHL	EQU	$E07D
;OUTHR	EQU	$E081

; for MIKBUG
MONITR  EQU     $E0E3
PUTC    EQU     $E075
GETC    EQU     $E078
GETHEX  EQU     $E0AA
OUTHL   EQU     $E067
OUTHR   EQU     $E06B

IOVEC	EQU	$7F00

; Data Register A:
;
; Depending on bit 2 in Control Register 
;	- bit 2 = 0: data direction
;	- bit 2 = 1: data bits (0=input, 1=output)
;
; Control Register A:
;
; |bit7|bit6|bit5|bit4|bit3|bit2|bit1|bit0|
; |    |    |    |    |    |	|_________|
; |    |    |    |    |    |         |
; |    |    |    |    |    |         '-- CA1 control (set-up)
; |    |    |    |    |    '-- =0 Direction. =1 Port itself/Periph. A
; |    |    '----'----'--- CA2 control (set-up)
; |    '--- (read only) Interrupt via CA2 (if interrupts enabled)
; '--- (read only) Interrupt via CA1 (if interrupts enabled)
;
; CA1 setup:
;   bit0 sets interrupt on high -> low transition
;   bit1 sets interrupt on low -> high transition
;	0=disabled, 1=enabled
;
; CA2 setup:
;   bit5 sets mode: 0=interrupt mode, 1=I/O mode
;   interrupt mode:
;	 bit4,bit3 behave as CA1 setup
;   I/O mode:
;	 00 CA2 pin goes low after when CPU reads PortA
;	 01 N/A
;	 10 set CA2 pin low
;	 11 set CA2 pin high

	ORG	$0100
START	JMP	MAIN

intros	.ascii	"\r\nPIA Demo"
crlfs	.asciz	"\r\n"

MAIN	LDX	#intros
	JSR	PUTS

	JSR	PIA_INIT

LOOP	LDAA	#'#'
	JSR	PUTC
	LDAA	#' '
	JSR	PUTC
	JSR	GETC
	PSHA
	LDX	#crlfs
	JSR	PUTS
	PULA

1:	CMPA	#'D'		; dump
	BNE	1f
	JSR	DUMP
	BRA	LOOP

1:	CMPA	#'R'		; reset
	BNE	1f
	JSR	PIA_INIT
	JMP	LOOP

1:	CMPA	#'W'		; write
	BNE	1f
	JSR	WRITE
	JMP	LOOP

1:	CMPA	#'I'		; interrupts
	BNE	1f
	JSR	IRQTST
	JMP	LOOP

1:	CMPA	#'X'		; exit
	BNE	1f
	JMP	MONITR

1:	JMP	LOOP


PIA_INIT:
	CLR	PIACTLA		; access PortA DDR
	LDAA	#$FF		; set PortA as outputs
	STAA	PIADATA	
	LDAA	#$04		; access PortA DAT
	STAA	PIACTLA
	LDAA	#$0F		; set lower pins as high
	STAA	PIADATA

	CLR	PIACTLB		; access PortB DDR
	LDAA	#$FF		; set PortB as outputs
	STAA	PIADATB	
	LDAA	#$04		; access PortB DAT
	STAA	PIACTLB
	LDAA	#$0F		; set lower pins as high
	STAA	PIADATB

	RTS

DUMP	CLRB
	LDX	#PIA
1:	TBA
	JSR	PUTHEX
	LDAA	#':'
	JSR	PUTC
	LDAA	#' '
	JSR	PUTC
	LDAA	,X
	JSR	PUTHEX
	INX
	LDAA	#'\r'
	JSR	PUTC
	LDAA	#'\n'
	JSR	PUTC
	INCB
	CMPB	#$4
	BLO	1b
	RTS

irqs	.asciz	"testing interrupts\r\n"
IRQTST	LDX	#irqs
	JSR	PUTS

	SEI
	LDX	#ISR
	STX	IOVEC	; set redirect from ROM monitor vector

	LDAA	#$1F	; all change interrupts on PortA and PortB
	STAA	PIACTLA
	STAA	PIACTLB

	CLI
	RTS

XSAVE	DS	2

inta1	.asciz	"PIN CA1 change\r\n"
inta2	.asciz	"PIN CA2 change\r\n"
intb1	.asciz	"PIN CB1 change\r\n"
intb2	.asciz	"PIN CB2 change\r\n"
unknown	.asciz	"not for us\r\n"

ISR	PSHA
	STX	XSAVE

	LDAA	PIACTLA
	JSR	PUTHEX
	LDAA	PIACTLB
	JSR	PUTHEX
	LDX	#crlfs
	JSR	PUTS

	LDAA	PIACTLA
	BITA	#$40
	BEQ	1f
	LDX	#inta2
	JSR	PUTS
1:	BITA	#$80
	BEQ	1f
	LDX	#inta1
	JSR	PUTS
1:	LDAA	PIACTLB
	BITA	#$40
	BEQ	1f
	LDX	#intb2
	JSR	PUTS
1:	BITA	#$80
	BEQ	1f
	LDX	#intb1
	JSR	PUTS
	JMP	9f
1:	LDX	unknown
	JSR	PUTS
9:	LDAA	PIADATA		; clear interrupt
	LDAA	PIADATB		; clear interrupt
	LDX	XSAVE
	PULA
	RTI

writes	.asciz	"PORT/VALUE? "
WRITE	LDX	#writes
	JSR	PUTS
	LDX	#PIADATA
	JSR	GETC
	CMPA	#'A'
	BEQ	1f
	CMPA	#'B'
	BNE	9f
	INX
	INX
1:	LDAA	#' '
	JSR	PUTC
	JSR	GETHEX
	STAA	,X
	LDX	#crlfs
	JSR	PUTS
9:	RTS

1:	JSR	PUTC
	INX
PUTS	LDAA	0,X
  	BNE	1b
  	RTS

PUTHEX	PSHA
	JSR	OUTHL
	PULA
	JMP	OUTHR

	END
