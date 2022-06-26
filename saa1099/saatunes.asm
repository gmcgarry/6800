; void tune_playnote(byte chan, byte note, byte volume);
; void tune_stopnote(byte chan);
; void tune_stepscore(void);

ACIACS	EQU	$D800
ACIADA	EQU	$D801

SAAREGS	EQU	$DC00
SAACTRL	EQU	SAAREGS+0
SAAADDR	EQU	SAAREGS+1

	ORG $0000
XSAVE	RMB	2
XTEMP	RMB	2
NOTE	RMB	3

	ORG $0100
start:
	LDS	#$FF
	LDX	#intro
	BSR	PUTS
main:
	BSR	saa_init
1:
	LDAA	#'\\'
	BSR	PUTC
	BSR	playtune

	LDAA	#$FF
	BSR	delay

	LDAA	#'/'
	BSR	PUTC

	BSR	playscale

	LDAA	#$FF
	BSR	delay

	BSR	KBHIT
	BCC	1b
	JMP	$E000

intro	FCC	"\r\nTune on SAA1099\r\n",0

saa_init:
	PSHA
	PSHB

	; Reset all the sound channels
	LDAA	#$1C
	STAA	SAAADDR
	LDAB	#$02
	NOP
	NOP
	NOP
	STAB	SAACTRL
	LDAB	#$00
	STAB	SAACTRL

	; Sound Enable
	LDAB	#$01
	STAB	SAACTRL

	; Disable frequencies
	LDAA	#$14
	STAA	SAAADDR
	LDAB	#$00
	STAB	SAACTRL
	
	; Disable noise channels
	LDAA	#$15
	STAA	SAAADDR
	LDAB	#$00
	STAB	SAACTRL
	
	; Disable envelopes
	LDAA	#$18
	STAA	SAAADDR
	LDAB	#$00
	STAB	SAACTRL

	LDAA	#$19
	STAA	SAAADDR
	LDAB	#$00
	STAB	SAACTRL

	PULB
	PULA

	RTS

	; apparently, these are midi notes, but should -1 first
	;  byte octave = (note / 12) - 1;
	;  byte noteVal = note - ((octave + 1) * 12);
Notes:
	;	octave, note, volume, delay
	FCB	(24/12)-1, 24-(24/12)*12, $0F, 32
	FCB	(48/12)-1, 48-(48/12)*12, $2D, 32
	FCB	(52/12)-1, 52-(52/12)*12, $4B, 32
	FCB	(55/12)-1, 55-(55/12)*12, $69, 32
	FCB	(60/12)-1, 60-(60/12)*12, $A6, 32
	FCB	(64/12)-1, 64-(64/12)*12, $C3, 32
	FCB	(64/12)-1, 64-(64/12)*12, $F0, 32
EndNotes:

playtune:
	LDAA	#((EndNotes - Notes) / 4)
	LDX	#Notes
2:
	BSR	playnote
	INX
	INX
	INX
	PSHA
	LDAA	,X
	BSR	delay
	PULA
	INX
	DECA
	BNE	2b
	BSR	stopnote

	RTS

playscale:
	LDX	#NOTE
	LDAA	#$FF
	STAA	2,X

	; enable channel0
	LDAA	#$14
	STAA	SAAADDR
	LDAA	#$01
	STAA	SAACTRL
	
	CLRA
	CLRB
1:
	STAA	0,X		; octave
	STAB	1,X		; tone
	BSR	playtone
	PSHA
	LDAA	#$05
	BSR	delay
	PULA
	INCB
	CMPB	#255
	BLO	1b
	INCA
	CMPA	#8
	BLO	1b
	BSR	stopnote
	RTS

; A: milliseconds
; NC = 2 + (2 + (2 + 4)*B + 2 + 4) * A
; 921.6 ~= (8 + 6B)
; B = 153
delay:
	PSHB
2:
	LDAB	#153	; 2 clock cycles
1:	DECB		; 2 clock cycles
	BNE	1b	; 4 clock cycles
	DECA		; 2 clock cycles
	BNE	2b	; 4 clock cycles
	PULB
	RTS

; The 12 note-within-an-octave values for the SAA1099, starting at B
NoteAddr	FCB	5, 32, 60, 85, 110, 132, 153, 173, 192, 210, 227, 243

; Start playing a note on channel 0
; X = [ octave, note, volume ]
playnote:
	PSHA
	PSHB
	STX	XSAVE

	; set volume
	LDAA	#00
	STAA	SAAADDR
	LDAA	2,X
	STAA	SAACTRL

	; set octave
	LDAA	#$10
	STAA	SAAADDR
	LDAA	,X
	STAA	SAACTRL

	; set note (frequency)
	LDAA	#$08
	STAA	SAAADDR
	LDAA	1,X
	ANDA	#$07
	CLRB
	ADDA	#(NoteAddr & $FF)
	ADCB	#(NoteAddr / 256)
	STAA	XTEMP+1
	STAB	XTEMP
	LDX	XTEMP
	LDAA	,X
	STAA	SAACTRL

	; enable channel0
	LDAA	#$14
	STAA	SAAADDR
	LDAA	#$01
	STAA	SAACTRL
	
	LDX	XSAVE
	PULB
	PULA

	RTS

; X = [ octave, tone, volume ]
playtone:
	PSHA
	PSHB
	STX	XSAVE

	; set volume
	LDAA	#$00
	STAA	SAAADDR
	LDAA	2,X
	STAA	SAACTRL

	; set octave
	LDAA	#$10
	STAA	SAAADDR
	LDAA	,X
	STAA	SAACTRL

	; set note (frequency)
	LDAA	#$08
	STAA	SAAADDR
	LDAA	1,X
	STAA	SAACTRL

	; enable channel0
;	LDAA	#$14
;	STAA	SAAADDR
;	LDAA	#$01
;	STAA	SAACTRL
	
	LDX	XSAVE
	PULB
	PULA

	RTS

stopnote:
	PSHA
	LDAA	#$14
	STAA	SAAADDR
	LDAA	#$00
	STAA	SAACTRL
	PULA
	RTS


KBHIT   LDAA    ACIACS
        ASRA
        RTS

GETC:
1:
	LDAA    ACIACS
        ASRA
        BCC     1b
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


1:	BSR	PUTC
	INX
PUTS	LDAA	,X
	BNE	1b
	RTS
