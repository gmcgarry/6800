;
; Demo on OLED display
;   - 0.96 inch OLED (white)
;   - SSD1306 driver chip
;   - 128X64 pixels
;   - I2C interface

STACK		EQU	$7F00
OLED_ADDR	EQU	$3C

; SMITHBUG
;MONITR  EQU     $E01A
;PUTC    EQU     $E205
;GETC    EQU     $E1EE
;GETHEX  EQU     $E072
;OUTHL   EQU     $E07D
;OUTHR   EQU     $E081

; for MIKBUG
MONITR  EQU     $E0E3
PUTC    EQU     $E075
GETC    EQU     $E078
GETHEX  EQU     $E0AA
OUTHL   EQU     $E067
OUTHR   EQU     $E06B

	ORG	$0100
; ------------------------------------------------------------ 
RESET	LDS	#STACK
	JMP	MAIN

ACIACS	EQU	$D800
ACIADA	EQU	$D801
KBHIT   LDAA    ACIACS
	ASRA
	RTS

1:      JSR     PUTC
	INX
PUTS    LDAA    ,X
	BNE     1b
	RTS

PUTHEX	PSHA
	JSR	OUTHL
	PULA
	JMP	OUTHR

; ------------------------------------------------------------ 
XSAVE		DS	2
ColStart:	DB	0
ColEnd:		DB	0
PageStart:	DB	0
PageEnd:	DB	0

	.include "i2c.inc"
	.include "font8x16.inc"

on	.asciz "on \r"
off	.asciz "off\r"

intro	.asciz "OLED Test\r\n"
msg	.asciz "!?@Aa|\r\n"


; ------------------------------------------------------------ 
MAIN:
	LDX	#intro
	JSR	PUTS

	JSR	oled_init
	JSR	oled_clear

	CLR	ColStart
	CLR	PageStart

	LDX	#msg
	JSR	PUTS

	LDX	#msg
	JSR	putstring

loop:
	LDX	#on
	JSR	PUTS
	LDX	#on
	JSR	putstring
	JSR	Delay

	LDX	#off
	JSR	PUTS
	LDX	#off
	JSR	putstring
	JSR	Delay

	JSR	KBHIT
	BCC	loop

	JMP	MONITR

; ------------------------------------------------------------ 
Delay:
	CLRA
	CLRB
1:
	NOP
	NOP
	NOP
	NOP
	DECB
	BNE     1b
	DECA
	BNE	1b
	RTS

TEMP	DS	2

; ------------------------------------------------------------ 
oled_init:
	PSHA
	PSHB
	STX	XSAVE

	JSR	i2c_init

	JSR	i2c_start
	LDAA	#(OLED_ADDR<<1)
	JSR	i2c_write

	LDX	#init_data
	LDAB	#(init_data_end - init_data)
2:
	LDAA	#$80
	JSR	i2c_write
	LDAA	,X
	JSR	i2c_write
	INX
	DECB
	BNE	2b

	JSR	i2c_stop

	LDX	XSAVE
	PULB
	PULA
	RTS

init_data:
	DB	$8D	; enable charge-pump regulator
	DB	$14
	DB	$AF	; display on
	DB	$20	; set memory addressing mode to Horizontal Addressing Mode
	DB	$00
	DB	$21	; reset column address
	DB	$00
	DB	$FF
	DB	$22	; reset page address
	DB	$00
	DB	$07
init_data_end:

; ------------------------------------------------------------ 
oled_clear:
	PSHA
	PSHB
	STX	XSAVE

	LDX	#64		; rows
1:
	JSR	i2c_start
	LDAA	#(OLED_ADDR<<1)
	JSR	i2c_write

	LDAA	#$40		; set start line to 0
	JSR	i2c_write

	LDAB	#16		; 16*8 columns
2:
	LDAA	#$00
	JSR	i2c_write
	DECB
	BNE	2b

	JSR	i2c_stop

	DEX
	BNE	1b

	LDX	XSAVE
	PULB
	PULA
	RTS

; ------------------------------------------------------------ 
; X=string
putstring:
	PSHA
1:
	LDAA	,X
	BEQ	2f
	JSR	putchar
	INX
	BRA	1b
2:
	PULA
	RTS

XHI	DS	1
XLO	DS	1

; ------------------------------------------------------------ 
; A=char
putchar:
	PSHA
	PSHB
	STX	XSAVE

	CMPA	#'\r'
	BNE	1f

	CLR	ColStart
	BRA	9f
1:
	CMPA	#'\n'
	BNE	2f

	LDAA	PageStart
	ADDA	#FONTHEIGHT
	STAA	PageStart
	BRA	9f
2:
	LDX	#Font		; Point to FontTable
	SUBA	#$20		; Table matching (Lookup table = ASCII table - Table Offset Value)
	BEQ	5f

	STX	XHI
3:				; ptr = Font + W*H*char
	LDAB	XLO
	ADDB	#(FONTWIDTH*FONTHEIGHT)
	STAB	XLO
	BCC	4f
	INC	XHI
4:
	DECA
	BNE	3b
	LDX	XHI
5:
	LDAA	ColStart		; check if ColStart > 128-FONTWIDTH+1
	CMPA	#(128-FONTWIDTH+1)
	BCS	6f

	CLR	ColStart
	LDAA	PageStart
	ADDA	#FONTHEIGHT
	STAA	PageStart
6:
	LDAA	ColStart
	ADDA	#(FONTWIDTH-1)
	STAA	ColEnd

	LDAA	PageStart
	ADDA	#(FONTHEIGHT-1)
	STAA	PageEnd

	JSR	SetColumn
	JSR	SetPage

	JSR	i2c_start
	LDAA	#(OLED_ADDR<<1)
	JSR	i2c_write

	LDAA	#$40
	JSR	i2c_write

	LDAB	#(FONTWIDTH*FONTHEIGHT)
7:
	LDAA	,X
	JSR	i2c_write
	INX
	DECB
	BNE	7b

	JSR	i2c_stop

	LDAA	ColStart
	ADDA	#FONTWIDTH
	STAA	ColStart
9:
	LDX	XSAVE
	PULB
	PULA

	RTS

; ------------------------------------------------------------ 
SetColumn:
	JSR	i2c_start
	LDAA	#(OLED_ADDR<<1)
	JSR	i2c_write

	LDAA	#$00		; command stream
	JSR	i2c_write

	LDAA	#$21		; set column address range
	JSR	i2c_write

	LDAA	ColStart
	JSR	i2c_write

	LDAA	ColEnd
	JSR	i2c_write

	JSR	i2c_stop

	RTS

; ------------------------------------------------------------ 
SetPage:
	JSR	i2c_start
	LDAA	#(OLED_ADDR<<1)
	JSR	i2c_write

	LDAA	#$00		; command stream
	JSR	i2c_write

	LDAA	#$22		; set page address range
	JSR	i2c_write

	LDAA	PageStart
	JSR	i2c_write

	LDAA	PageEnd
	JSR	i2c_write

	JSR	i2c_stop

	RTS

	END
