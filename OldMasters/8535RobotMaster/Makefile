# Standard AVR ASM makefile

# the output filename
APP = master.hex

# the source file
SRC = Master.asm
    

# the asmmbler
ASM = avrasm

$(APP) : $(SRC)
	$(ASM) `echo $< | sed s/\.asm//`


clean:
	rm $(APP)
	rm *.lst
	rm *.o
