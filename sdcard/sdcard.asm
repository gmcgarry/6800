; ROM @ $F000
; USES FDOS-based DRIVE/TRACK/SECTOR
; USES MINIDOS-based jump table

; 256 bytes per sector
; 256 sectors per track
; 256 sectors per disk

; SDCARD over SPI (on 6821 Port B)

; CS  : active low
; DAT : active high
; CLK : low-to-high transition

PIA	EQU	$D400
DATA	EQU	PIA+2
CTRL	EQU	PIA+3

; pin assignments
CS	EQU	0
SCK	EQU	1
DO	EQU	2	; MOSI
DI	EQU	3	; MISO

	.BASE	$E000
	ORG	$F000

; MINIDOS-compatible
	JMP	BOOT
SDINIT	JMP	HW_INIT
RDSECT	JMP	READ_SECTOR
WRSECT	JMP	WRITE_SECTOR

; FDOS-compatible
SECTOR0	EQU	0	; #0
SECTOR1	EQU	0x0D	; NDRIVE
SECTOR2	EQU	0x00	; TRACK
SECTOR3	EQU	0x01	; SECTOR

; ------------------------------------------------------------ 
BOOT	BSR	HW_INIT
	CLRA
	STAA	SECTOR1
	STAA	SECTOR2
	STAA	SECTOR3
	LDX	#$2400
	JSR	READ_SECTOR
	INC	SECTOR3
	LDX	#$2500
	JSR	READ_SECTOR
	JMP	$2400
;	JMP	$E0E3

; ------------------------------------------------------------ 
HW_INIT PSHA
	PSHB
	JSR	PIA_INIT
	JSR	SD_INIT
	PULB
	PULA
	RTS

; ------------------------------------------------------------ 
PIA_INIT:
	CLR	CTRL		; access PortB DDR
	LDAA	#(1<<CS)|(1<<SCK)|(1<<DO)
	STAA	DATA
	LDAA	#$04		; access PortB DAT
	STAA	CTRL
	LDAA	#(1<<CS)|(1<<SCK)|(1<<DO)
	STAA	DATA
	RTS

; ------------------------------------------------------------ 
SD_INIT:
	; Apply 80 clock pulses with CS and MOSI high to switch
	; the card to SPI mode.
	LDAA	#(1<<CS)|(1<<DO)|(1<<SCK)
	LDX	#160
1:	EORA	#(1<<SCK)
	STAA	DATA
	DEX
	BNE	1b

	; CMD0 reset card to idle state, and SPI mode
	LDAB	#10
1:	LDX	#cmd0
	JSR	SENDCMD
	CMPA	#$01
	BEQ	2f
	DECB
	BNE	1b
	BRA	.initfailed

	; CMD8 tell the card how we want it to operate (3.3V, etc)
2:	LDX	#cmd8
	JSR	SENDCMD
	CMPA	#$01
	BNE	.initfailed

	JSR	READBYTE
	JSR	READBYTE
	JSR	READBYTE
	JSR	READBYTE

	; APP_CMD required prefix for ACMD commands
1:	LDX	#cmd55
	JSR	SENDCMD
	CMPA	#$01
	BNE	.initfailed

	; send operating conditions, initialize card
	LDX	#cmd41
	JSR	SENDCMD
	CMPA	#$00
	BEQ	2f

	CMPA	#$01
	BNE	.initfailed

	LDAA	#1
	JSR	DELAYMS

	JMP	1b

2:	CLC
	RTS

cmd0	.byte $40, $00, $00, $00, $00, $95
cmd8	.byte $48, $00, $00, $01, $aa, $87
cmd55	.byte $77, $00, $00, $00, $00, $01
cmd41	.byte $69, $40, $00, $00, $00, $01

.initfailed:
	SEC
	RTS

; ------------------------------------------------------------ 
; Write a sector from the SD card.  A sector is 512 bytes.
;
; Parameters:
;    SECTOR:   32-bit sector number
;    X: address of data buffer
WRITE_SECTOR:
	PSHA
	LDAA	#(1<<DO)|(1<<SCK)	; CS low
	STAA	DATA

;	LDAA	#'<'
;	JSR	OUTCH
;	LDAA	#'W'
;	JSR	OUTCH
;
;	STX	$FE
;	LDAA	$FE
;	JSR	PUTHEX
;	LDAA	$FF
;	JSR	PUTHEX
;	LDAA	#'-'
;	JSR	OUTCH
;	LDAA	#'>'
;	JSR	OUTCH
;
;	LDAA	#SECTOR0
;	JSR	PUTHEX
;	LDAA	SECTOR1
;	JSR	PUTHEX
;	LDAA	SECTOR2
;	JSR	PUTHEX
;	LDAA	SECTOR3
;	JSR	PUTHEX
;	LDAA	#'>'
;	JSR	OUTCH

	LDAA	#$58		; CMD24 - WRITE_SINGLE_BLOCK
	JSR	WRITEBYTE

	LDAA	#SECTOR0	; sector 24:31
	JSR	WRITEBYTE

	LDAA	SECTOR1		; sector 16:23
	JSR	WRITEBYTE

	LDAA	SECTOR2		; sector 8:15
	JSR	WRITEBYTE

	LDAA	SECTOR3		; sector 0:7
	JSR	WRITEBYTE

	CLRA			; crc
	JSR	WRITEBYTE

	JSR	WAITRESULT
	CMPA	#$00
	BNE	.fail

	LDAA	#$FE		; data token
	JSR	WRITEBYTE

	; write 512 bytes - two pages of 256 bytes each
	JSR	WRITEPAGE
	JSR	WRITEZEROPAGE

	CLRA			; crc
	JSR	WRITEBYTE
	JSR	WRITEBYTE

	JSR	WAITRESULT
;	JSR	PUTHEX
	CMPA	#$05
	BNE	.fail

1:	JSR	READBYTE
	CMPA	#$00
	BEQ	1b

	LDAA	#(1<<CS)|(1<<DO)|(1<<SCK)	; End command
	STAA	DATA

	CLC
	PULA
	RTS

; Write 256 bytes from address in X
WRITEPAGE:
	PSHA
	PSHB
	CLRB
1:	LDAA	,X
	JSR	WRITEBYTE
	INX
	DECB
	BNE	1b
	PULB
	PULA
	RTS

WRITEZEROPAGE:
	PSHA
	PSHB
	CLRB
1:	CLRA
	JSR	WRITEBYTE
	DECB
	BNE	1b
	PULB
	PULA
	RTS

.fail:
	SEC
	PULA
	RTS

; ------------------------------------------------------------ 
; Read a sector from the SD card.  A sector is 512 bytes.
;
; Parameters:
;    SECTOR:   32-bit sector number
;    X: address of buffer to receive data
READ_SECTOR:
	PSHA
	LDAA	#(1<<DO)|(1<<SCK)	; CS low
	STAA	DATA

;	LDAA	#'<'
;	JSR	OUTCH
;	LDAA	#'R'
;	JSR	OUTCH

;	LDAA	#SECTOR0
;	JSR	PUTHEX
;	LDAA	SECTOR1
;	JSR	PUTHEX
;	LDAA	SECTOR2
;	JSR	PUTHEX
;	LDAA	SECTOR3
;	JSR	PUTHEX
;	LDAA	#'-'
;	JSR	OUTCH
;	LDAA	#'>'
;	JSR	OUTCH

;	STX	$FE
;	LDAA	$FE
;	JSR	PUTHEX
;	LDAA	$FF
;	JSR	PUTHEX
;	LDAA	#'>'
;	JSR	OUTCH

	LDAA	#$51			; CMD17 - READ_SINGLE_BLOCK
	JSR	WRITEBYTE

	LDAA	#SECTOR0	; sector 24:31
	JSR	WRITEBYTE

	LDAA	SECTOR1		; sector 16:23
	JSR	WRITEBYTE

	LDAA	SECTOR2		; sector 8:15
	JSR	WRITEBYTE

	LDAA	SECTOR3		; sector 0:7
	JSR	WRITEBYTE

	LDAA	#$01		; crc (not checked)
	JSR	WRITEBYTE

	JSR	WAITRESULT
	CMPA	#$00
	BNE	.fail

	JSR	WAITRESULT	; wait for data
	CMPA	#$FE
	BNE	.fail

	; Need to read 512 bytes - two pages of 256 bytes each
	JSR	READPAGE
	JSR	SKIPPAGE

	LDAA	#(1<<CS)|(1<<DO)|(1<<SCK)	; End command
	STAA	DATA

	CLC
	PULA
	RTS

; Read 256 bytes to the address in X
READPAGE:
	PSHA
	PSHB
	CLRB
1:	JSR	READBYTE
	STAA	,X
	INX
	DECB
	BNE	1b
	PULB
	PULA
	RTS

SKIPPAGE:
	PSHA
	PSHB
	CLRB
1:	JSR	READBYTE
	DECB
	BNE	1b
	PULB
	PULA
	RTS

; X=pointer to command
SENDCMD:
	LDAA	#$FF
	JSR	WRITEBYTE

	LDAA	#(1<<DO)|(1<<SCK)	; pull CS low to begin command
	STAA	DATA

	LDAA	0,X		; command byte
	JSR	WRITEBYTE

	LDAA	1,X		; data 1
	JSR	WRITEBYTE

	LDAA	2,X		; data 2
	JSR	WRITEBYTE

	LDAA	3,X		; data 3
	JSR	WRITEBYTE

	LDAA	4,X		; data 4
	JSR	WRITEBYTE

	LDAA	5,X		; crc
	JSR	WRITEBYTE

	JSR	WAITRESULT

	PSHA			; store result code

	LDAA	#(1<<CS)|(1<<SCK)|(1<<DO)	; set CS high again
	STAA	DATA

	PULA			; restore result code
	RTS

; Wait for the SD card to return something other than $ff
WAITRESULT:
	PSHB
	CLRB			; 256 loops may not be enough
1:	JSR	READBYTE
	CMPA	#$FF
	BNE	2f
	DECB
	BNE	1b
2:	PULB
	RTS

; A=data
READBYTE:
	PSHB
	LDAB	#$FE		; Preloaded with seven ones and a zero, so we stop after eight bits
1:	LDAA	#(1<<DO)	; enable card (CS low), set MOSI (resting state), SCK low
	STAA	DATA
	LDAA	#(1<<DO)|(1<<SCK)	; toggle the clock high
	STAA	DATA
	LDAA	DATA		; read next bit
	ANDA	#(1<<DI)
	CLC			; default to clearing the bottom bit
	BEQ	2f		; unless MISO was set
	SEC			; in which case get ready to set the bottom bit
2:	ROLB			; rotate carry bit into read result, and loop bit into carry
  	BCS	1b		; loop if we need to read more bits
	TBA
	PULB
	RTS

; A=data
WRITEBYTE:
	PSHA
	PSHB
	LDAB	#8		; send 8 bits
1:	ASLA			; shift next bit into carry
	PSHA			; save remaining bits for later
	LDAA	#(1<<SCK)
	BCC	2f		; if carry clear, don't set MOSI for this bit
	ORAA	#(1<<DO)
2:	STAA	DATA		; set MOSI (or not) first
	EORA	#(1<<SCK) 	; raise SCK keeping MOSI the same, to send the bit
	STAA	DATA
	EORA	#(1<<SCK)
	STAA	DATA		; raise SCK keeping MOSI the same, to send the bit
	PULA			; restore remaining bits to send
	DECB
	BNE	1b		; loop if there are more bits to send
	PULB
	PULA
	RTS

DELAYMS	PSHB
1:	LDAB	#(3686/4 / 6)	; assuming 3.686MHz clock
2:	DECB			; 2
	BNE	2b		; 4
	DECA
	BNE	1b
	PULB
	RTS

; https://github.com/gfoot/sdcard6502/blob/master/src/libsd.s
; http://elm-chan.org/docs/mmc/mmc_e.html

;OUTCH	EQU     $E075
;
;PUTHEX	PSHA
;	PSHA
;	JSR OUTHL
;	PULA
;        JSR OUTHR
;	PULA
;	RTS
;
;OUTS    LDAA #$20
;        JMP OUTCH
;OUTHL   LSRA
;        LSRA
;        LSRA
;        LSRA
;OUTHR   ANDA #$0F
;        ADDA #'0'
;        CMPA #'9'
;        BLS 1f
;        ADDA #$7
;1:	JMP OUTCH

	END
