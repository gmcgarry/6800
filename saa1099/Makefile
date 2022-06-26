all:

clean:
	$(RM) *.hex *.s19 *.lst

.SUFFIXES:	.hex .asm .s19

.asm.hex:
	pasm-6800 -d1000 -F hex -o $@ $< > $@.lst

.asm.s19:
	pasm-6800 -d1000 -F srec2 -o $@ $< > $@.lst
