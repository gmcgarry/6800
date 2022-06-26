; RAM at 0x0000 -> 0x7FFF
; ROM monitor at 0xE000
; ROM monitor data page at 0x7F00

; testing interrupts using ACIA
; CLOCK = 3.6864MHz => 0.9216MHz
;	/16 = 57600 bps

ACIA	EQU	0D800H
ACIACS	EQU	ACIA+0
ACIADA	EQU	ACIA+1

	ORG	0x0100
START:
	LDS	#$00FF
	CLC

MAIN:
	BSR	INIT
	LDX	$A5A5
1:
	BRA	1b

INIT:
	SEI
	LDX	#ISR
	STX	$7F00	; set redirect from ROM monitor vector
        LDAA    #$03
        STAA    ACIACS
        NOP
        NOP
        NOP
        LDAA    #$95    ; 1,00,101,01: rx irq, RTS=low no tx irq, N81, /16
        STAA    ACIACS
	CLI
	RTS

ISR:
	LDAA	ACIACS
	ASLA
	BCC	9f	; not for us
	BSR	GETC
	BSR	PUTC
9:
	RTI

GETC:
1:
        LDAA    ACIACS
        ASRA
        BCC     1b      ; RECEIVE NOT READY
        LDAA    ACIADA  ; INPUT CHARACTER
        ANDA    #$7F    ; RESET PARITY BIT
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

	END
