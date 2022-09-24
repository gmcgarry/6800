REGS	EQU	$D000
S1	EQU	REGS+0
S10	EQU	REGS+1
MI1	EQU	REGS+2
MI10	EQU	REGS+3
H1	EQU	REGS+4
H10	EQU	REGS+5
D1	EQU	REGS+6
D10	EQU	REGS+7
MO1	EQU	REGS+8
MO10	EQU	REGS+9
Y1	EQU	REGS+10
Y10	EQU	REGS+11
W	EQU	REGS+12
CD	EQU	REGS+13		; 30-sec adjust, IRQ, BUSY, HOLD
CE	EQU	REGS+14		; t1, t0, ITRPT/STND, MASK
CF	EQU	REGS+15		; TEST, 24/12, STOP, REST

; BOLD=1 inhibits the clock during read/write (much be set for less than 1 second)
; IRQ indicates the (inverted) level of the STD.P pin
; MASK=0 enables timing on STD.P; MASK=1 disables STD.P
; timing of STD.P is controlled by t0/t1 divisor: 00 = 1/64 second, 01=1second, 10=1minute, 11=1hour
; ITRPT/STND=1 (interrupt mode), then STD.P remains low until IRQ is reset to 0
; ITRPT/STND=0 (standard-pulse mode), then STD.P remains low until IRQ is reset to 0 (or the t0/t1 timer expires)

MONITR	EQU	$E0E3


ACIA	EQU	$D800
ACIACS	EQU	ACIA+0
ACIADA	EQU	ACIA+1

	ORG $0000
XTEMP	RMB	1

	ORG $0100
start:
	LDS	#$FF
main:
	LDX	#crlfs
	JSR	PUTS
	LDX	#intros
	JSR	PUTS

	JSR	reset

loop:
	LDAA	#'#'
	JSR	PUTC
	LDAA	#' '
	JSR	PUTC
	JSR	GETC
	JSR	PUTC
	PSHA
	LDX	#crlfs
	JSR	PUTS
	PULA
1:
	CMPA	#'D'		; dump
	BNE	1f
	JSR	dump
	BRA	loop
1:
	CMPA	#'R'		; reset
	BNE	1f
	JSR	reset
	BRA	loop
1:
	CMPA	#'T'		; time
	BNE	1f
	JSR	time
	BRA	loop
1:
	CMPA	#'I'		; interrupt
	BNE	1f
	JSR	interrupt
	BRA	loop
1:
	CMPA	#'2'		; 24-hour time
	BNE	1f
	JSR	hour24
	BRA	loop
1:
	CMPA	#'*'		; test mode
	BNE	1f
	JSR	testmode
	BRA	loop
1:
	CMPA	#'X'		; exit
	BNE	1f
	JMP	MONITR
1:
	LDX	#badcmds
	JSR	PUTS
	JMP	loop

intros	.asciz	"MSM6242B tester\r\n"
badcmds	.asciz	"unrecognised command\r\n"
crlfs	.asciz	"\r\n"

interrupt:
	SEI		; disable processor interrupts

	LDX	#isr	; setup interrupt handler
	STX	$7F00

	LDAA	#$6	; enable one-second clock interrupts
	STAA	CE

	CLR	CD	; clear clock interrupt

	CLI		; enable processor interrupts
	RTS

isr:
	LDAA	CD
	BITA	#$04
	BEQ	1f	; not for us

	CLR	CD	; clear interrupt

	LDAA	#'.'
	JSR	PUTC
1:
	RTI

testmode:
	LDAA	CF
	BITA	#$08
	BNE	1f

	ORAA	#$08	; TEST=1
	STAA	CF
	LDX	#testmodeon
	JMP	PUTS
1:
	ANDA	#$07	; TEST=0
	STAA	CF
	LDX	#testmodeoff
	JMP	PUTS

testmodeon	FCC	"Test-mode on\r\n",0
testmodeoff	FCC	"Test-mode off\r\n",0

reset:
	CLR	CD	; ADJ=0, IRQ=xxx, BUSY=xxx, HOLD=0
	LDAA	#$01	; TIMER=1/64, WAVE OUTPUT, MASK=1
	STAA	CE
	LDAA	#$05	; TEST=0, 24HOUR=1, STOP=0, REST=1
	STAA	CF
	LDAA	#$04	; TEST=0, 24HOUR=1, STOP=0, REST=0
	STAA	CF
	RTS

hour24:
	LDAA	CF
	BITA	#$04
	BEQ	1f

	ORAA	#$01	; REST=1
	STAA	CF
	ANDA	#$0B	; CLEAR 12/24
	STAA	CF
	ANDA	#$0E	; REST=0
	STAA	CF
	LDX	#hour24off
	JMP	PUTS
1:
	ORAA	#$01	; REST=1
	STAA	CF
	ORAA	#$4	; SET 12/24
	STAA	CF
	ANDA	#$0E	; REST=0
	STAA	CF
	LDX	#hour24on
	JMP	PUTS

hour24on	FCC	"Setting 24-hour time\r\n",0
hour24off	FCC	"Setting 12-hour time\r\n",0

time:
	LDAA	H10
	ANDA	#$3
	JSR	PUTDEC
	LDAA	H1
	JSR	PUTDEC
	LDAA	#':'
	JSR	PUTC
	LDAA	MI10
;	ANDA	#$7
	JSR	PUTDEC
	LDAA	MI1
	JSR	PUTDEC
	LDAA	#':'
	JSR	PUTC
	LDAA	S10
;	ANDA	#$7
	JSR	PUTDEC
	LDAA	S1
	JSR	PUTDEC

	LDAA	#' '
	JSR	PUTC

	LDAA	D10
;	ANDA	#$3
	JSR	PUTDEC
	LDAA	D1
	JSR	PUTDEC
	LDAA	#'/'
	JSR	PUTC
	LDAA	MO10
;	ANDA	#$01
	JSR	PUTDEC
	LDAA	MO1
	JSR	PUTDEC
	LDAA	#'/'
	JSR	PUTC
	LDAA	Y10
	JSR	PUTDEC
	LDAA	Y1
	JSR	PUTDEC

	LDAA	#' '
	JSR	PUTC

	CLRB
	LDAA	W
	ANDA	#$07
	LSLA
	ADDA	#(WEEKDAY & $FF)
	ADCB	#(WEEKDAY / 256)
	STAA	XTEMP+1
	STAB	XTEMP
	LDX	XTEMP
	LDX	,X
	JSR	PUTS

;	LDAA	XTEMP
;	JSR	PUTHEX
;	LDAA	XTEMP+1
;	JSR	PUTHEX

	LDX	#crlfs
	JMP	PUTS

WEEKDAY	FDB	SUNS, MONS, TUES, WEDS, THURS, FRIS, SATS, ERRORS
SUNS	FCC	"Sunday",0
MONS	FCC	"Monday",0
TUES	FCC	"Tuesday",0
WEDS	FCC	"Wednesday",0
THURS	FCC	"Thursday",0
FRIS	FCC	"Friday",0
SATS	FCC	"Saturday",0
ERRORS	FCC	"Badday",0

dump:
	CLRB
	LDX	#REGS
1:
	TBA
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
	CMPB	#$10
	BLO	1b

	RTS

GETC:
1:
        LDAA    ACIACS
        ASRA
        BCC     1b      ; RECEIVE NOT READY
        LDAA    ACIADA  ; INPUT CHARACTER
        ANDA    #$7F    ; RESET PARITY BIT
        CMPA    #$7F
        BEQ     1b      ; IF RUBOUT, GET NEXT CHAR
        RTS

1:
        JSR     PUTC
        INX
PUTS:
        LDAA    0,X
        BNE     1b
        RTS

PUTDEC:
	ANDA	#$0F
	ADDA	#$30
	BRA	PUTC

PUTHEX:
OUT2H	PSHA
	JSR     OUTHL   ; OUT LEFT HEX CHAR
        PULA
	BRA     OUTHR   ; OUTPUT RIGHT HEX CHAR AND R

OUTHL   LSRA    ; OUT HEX LEFT BCD DIGIT
        LSRA
        LSRA
        LSRA
OUT1H:
OUTHR   ANDA    #$F     ; OUT HEX RIGHT BCD DIGIT
        ADDA    #$30
        CMPA    #$39
        BLS     PUTC
        ADDA    #$7
	; fallthru

PUTC:
        PSHA
1:
        LDAA    ACIACS
        BITA    #$10
        BEQ     2f
        SWI
2:
        ASRA    
        ASRA    
        BCC     1b
        PULA    
        STAA    ACIADA
        RTS

	END
