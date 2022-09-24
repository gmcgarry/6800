;
; Calculate CPU clock using MSM4262B clock
;

REGS	EQU	$D000
CD	EQU	REGS+13		; 30-sec adjust, IRQ, BUSY, HOLD
CE	EQU	REGS+14		; t1, t0, ITRPT/STND, MASK
CF	EQU	REGS+15		; TEST, 24/12, STOP, REST

; for MIKBUG
PUTC	EQU	$E075
MONITR	EQU	$E0E3

; for SMITHBUG
;PUTC	EQU	$E205
;MONITR	EQU	$E01A

	ORG $0000
BIGNUM	RMB	4

	ORG $0100
start:
	LDS	#$FF
main:
	LDX	#crlfs
	BSR	PUTS
	LDX	#intros
	BSR	PUTS

	SEI		; disable interrupts

	CLR	CE	; TIMER=1/64 (33% duty cycle), ITRPT/STD=0 (wave output), MASK=0
	CLR	CD	; ADJ=0, IRQ=xxx, BUSY=xxx, HOLD=0
	LDX	#$0000

1:			; wait for wave to go high
	LDAA	CD
	BITA	#$04
	BEQ	1b
1:			; wait for wave to go low
	LDAA	CD
	BITA	#$04
	BNE	1b
1:
	NOP		; 2T
	INX		; 4T
	LDAA	CD	; 4T
	BITA	#$04	; 2T
	BEQ	1b	; 4T wait for wave to go high
1:
	NOP		; 2T
	INX		; 4T
	LDAA	CD	; 4T
	BITA	#$04	; 2T
	BNE	1b	; 4T wait for wave to go low

	CLC

	; at this point, X is the number of times round the loop

	STX	BIGNUM
	CLR	BIGNUM+2
	CLR	BIGNUM+3

	; MHz = X * 64 * 16
	; shift is 10 bits

	LDAA	#6
1:
	LSR	BIGNUM
	ROR	BIGNUM+1
	ROR	BIGNUM+2
	ROR	BIGNUM+3
	DECA
	BNE	1b

	LDX	#msgs
	BSR	PUTS

	LDX	#BIGNUM
	BSR	PUTDEC32

	LDX	#hzs
	BSR	PUTS

	LDAA	#$01
	STAA	CE	; mask interrupt
	CLR	CD	; clear interrupt

	CLI		; enable interrupts

	JMP	MONITR

intros	.asciz	"Speed Checker\r\n"
crlfs	.asciz	"\r\n"
msgs	.asciz	"CPU Speed is "
hzs	.asciz	" Hz\r\n"

1:
	BSR	PUTC
	INX
PUTS:
        LDAA    0,X
        BNE     1b
        RTS

; print 32-bit number at 0,X
PUTDEC32:
	CLRA		; stack terminator
	PSHA
1:
	LDAB	#32
	CLRA		; Remainder=0
2:
	ADDA	#-5
	BCS	3f
	ADDA	#5
	CLC
3:
	ROL	3,X
	ROL	2,X
	ROL	1,X
	ROL	0,X
	ROLA		; Shift bits of input into acc (input mod 10)
	DECB
	BNE	2b

	; quotient in 0,X:1,X; remainder in A

	ORAA	#'0'
	PSHA		; Push low digit 0-9 to print
	LDAA	0,X
	ORAA	1,X
	ORAA	2,X
	ORAA	3,X
	BNE	1b
	PULA		; Pop character left to right
4:
	BSR	PUTC	; Print it
	PULA
	CMPA	#$0
	BNE	4b
	RTS

	END
