TRG = spsynth

SRCS = spsynth.S

###### define some variables based on the AVR base path in  #######
CC		= avr-gcc
AS		= avr-as	
LD		= ld
RM		= rm -f
RN		= mv
BIN		= objcopy
INCDIR		= -I. -I../../../ -I/usr/local/avr/include
LIBDIR		=
PP		= cpp -E 
DEP		= gcc -M


###### output format can be srec, ihex (avrobj is always created) #######
FORMAT = srec

########################## default mcu type #############################
MCU = at90s4433
MCUTYPE = avr44x4
####################### default compiler flags ##########################
CPFLAGS	= -g -O3 -Wall -Wstrict-prototypes -Wa,-ahlms=$(<:.c=.lst)
####################### default assembler flags #########################
ASFLAGS = -gstabs
########################## default linker flags #########################
LDFLAGS = -Map=$(TRG).map --cref -T $(TRG).sc

#define all project specific object files
#OBJS	= $(ASRCS:.s=.o) $(SRCS:.c=.o) 
OBJS = spsynth.o
CPFLAGS += -mmcu=$(MCU)
ASFLAGS += -mmcu=$(MCU)
LDFLAGS += -m $(MCUTYPE)


  
#this defines the aims of the make process
all:	dirs $(TRG).rom $(OBJS) $(TRG).elf

dirs:   .deps

.deps:
	mkdir .deps

#compile: instructions to create assembler and/or object files from C source
%.o: %.c Makefile
	$(CC) -c $(CPFLAGS) -I$(INCDIR) $< -o $@

%.o: %.S Makefile
	$(DEP) $< $(INCDIR) > .deps/$*.d
	$(PP) $< $(INCDIR) | $(AS) $(ASFLAGS) -a=$*.l2 -o $@
	$(PP) -P $< $(INCDIR) | $(AS) $(ASFLAGS) -a=$*.l -o $@

#assemble: instructions to create object file from assembler files
%.o: %.s
	$(AS) $(ASFLAGS) $(INCDIR) $< -a=$*.l -o $@

#link: instructions to create elf output file from object files
%.elf: $(OBJS) 
	$(LD) $(LIB) $(LDFLAGS) $(OBJS) -o $@

#create bin (ihex, srec) file from elf output file
%.rom: %.elf
	$(BIN) -j .text -O $(FORMAT) $< $@
	$(BIN) -j .data -O $(FORMAT) $< $(@:.rom=.eep)

# install using progavr
install: all
	../../../progavr $(TRG).rom $(TRG).eep


#make instruction to delete created files
clean:
	$(RM) $(OBJS)
	$(RM) $(ASRCS:.s=.l)
	$(RM) $(TRG).map
	$(RM) $(TRG).elf
	$(RM) $(TRG).obj
	$(RM) $(TRG).eep
	$(RM) $(TRG).rom
	$(RM) *.bak
	$(RM) *.log
	$(RM) $(TRG).elf?
	$(RM) *.l
	$(RM) .deps/*.d

-include .deps/*.d