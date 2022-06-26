; runs in ROM

	.base	0xE000

	.org	0xE000
start:
	.fill	(0x2000 - 10),0x01

	.org	0xFFF6
	.byte	0x01
	.byte	0x7e		; jump
	.org	0xFFF8
irq:
	.word	start
soft:
	.word	start
nmi:
	.word	start
reset:
	.word	start
