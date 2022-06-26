	.base	0xE000

	.org	0xE000
start:
	BRA	.

	.org	0xFFF8
irq:
	.word	start
soft:
	.word	start
nmi:
	.word	start
reset:
	.word	start
