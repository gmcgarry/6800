; I2C attached to PIA PortB
; (output only)
; SDA, pin 0
; SCL, pin 1
 
PORT	EQU	$D402

SDA	EQU	0
SCL	EQU	1

i2c_init:
	PSHA
	PSHB
	CLR	PORT+1			; select DDR
	LDAB	#(1<<SCL)|(1<<SDA)	; SCL/SDA high
	STAB	PORT
	LDAA	#$04
	STAA	PORT+1
	STAB	PORT
	PULB
	PULA
	RTS

; SCL/SDA will both be high
i2c_start:
	PSHB
	LDAB	#(1<<SCL)|(1<<SDA)	; SCL+SDA high
	STAB	PORT
	LDAB	#(1<<SCL)		; SDA low
	STAB	PORT
	LDAB	#$00			; SCL low
	STAB	PORT
	PULB
	RTS
 
i2c_stop:
	PSHB
	LDAB	#$00			; SCL+SDA low
	STAB	PORT
	LDAB	#(1<<SCL)		; SCL high
	STAB	PORT
	LDAB	#(1<<SCL)|(1<<SDA)	; SDA high
	STAB	PORT
	PULB
	RTS

I2CX	DS	2

; SCL/SDA will both be low after start
; carry set on error
i2c_write:
	PSHA
	PSHB
	STX	I2CX

	LDX	#8
	LDAB	#$00
1:
	ANDB	#~(1<<SCL)		; SCL low
	STAB	PORT

	CLRB				; setup SDA
	ASLA				; shift MSB into C
	ROLB				; shift C into LSB		; hardcoded SDA to bit 0
	STAB	PORT

	ORAB	#(1<<SCL)		; SCL high
	STAB	PORT

	; check for clock stretching???

	DEX
	BNE	1b

	ANDB	#~(1<<SCL)		; SCL low
	STAB	PORT

	LDAB	#(1<<SDA)		; SDA high
	STAB	PORT
	LDAB	#(1<<SCL)|(1<<SDA)	; SCL high
	STAB	PORT
;2:					; wait clock line to rise (clock stretching)
;	LDAB	PORT
;	BITB	#(1<<SCL)
;	BEQ	2b

;	LDAB	PORT			; read ACK
;	ASRB

	LDAB	#(1<<SDA)		; SCL low
	STAB	PORT

	LDX	I2CX
	PULB
	PULA
	RTS

; returns byte in A
i2c_read:
	PSHB
	STX	I2CX
	
	LDX 	#$08
1:
	LDAB	#(1<<SDA)		; SCL low
	STAB	PORT

	LDAB	#(1<<SCL)|(1<<SDA)	; SCL high
	STAB	PORT
2:					; wait clock line to rise (clock stretching)
	LDAB	PORT
	BITB	#(1<<SCL)
	BEQ	2b

	ASRB				; hardcoded SDA into bit 0
	ROLA
	DEX
	BNE	1b

	LDAB	#(1<<SDA)		; SCL low
	STAB	PORT

	LDX 	I2CX
	PULB

	RTS

i2c_ack:
	PSHB

	LDAB	#00			; SDA low (ACK)
	STAB	PORT

	LDAB	#(1<<SCL)		; SCL high
	STAB	PORT
;2:					; wait clock line to rise (clock stretching)
;	LDAB	PORT
;	BITB	#(1<<SCL)
;	BEQ	2b

	LDAB	#00			; SCL low
	STAB	PORT

	PULB
	RTS

i2c_nack:
	PSHB

	LDAB	#(1<<SDA)		; SDA high
	STAB	PORT

	LDAB	#(1<<SCL)|(1<<SDA)	; SCL high
	STAB	PORT
;2:					; wait clock line to rise (clock stretching)
;	LDAB	PORT
;	BITB	#(1<<SCL)
;	BEQ	2b

	LDAB	#(1<<SDA)		; SCL low
	STAB	PORT

	PULB	
	RTS
