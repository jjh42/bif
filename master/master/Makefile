INCLUDES = -I. -I.. -I../..
DEFINES = 
ALLOBJS = \
	alloc.o \
	brain.o \
	control.o \
	computercontrol.o \
	commonsubs.o \
	english.o \
	help.o \
	io.o \
	ircontrol.o \
	lcd.o \
	master.o \
	matigsalug.o \
	mytime.o \
	slave-base.o \
	slavecomms.o \
	slave-io.o \
	slave-ir.o \
	slave-speech.o \
	sounds_E.o \
	sounds_M.o \
	sounds_P.o \
	sounds_S.o \
	speak.o \
	tell.o 

RM = rm -f

all:	prebuild posix

prebuild: dirs

dirs: .deps

.deps:
	mkdir .deps

# Make a posix executable

POSIXCC = gcc -g -Wall
POSIXDEFINES = -DTARGET_POSIX -D_REENTRANT $(DEFINES)
POSIXINCLUDES = $(INCLUDES) 
POSIXLINK = gcc -lpthread
POSIXDEPS = gcc -M
POSIXOUT = master

POSIXOBJS = \
	posixmain.o \
	posixthreads.o \
	$(ALLOBJS)

posixclean:
	$(RM) $(POSIXOBJS)

posix: $(POSIXOUT) posixextras

$(POSIXOUT): $(POSIXOBJS) 
	$(POSIXLINK) $(POSIXOBJS) -o $(POSIXOUT)

%.o: %.c
	$(POSIXDEPS) $(POSIXINCLUDES) $(POSIXDEFINES) $< > .deps/$*.posix.d
	$(POSIXCC) $(POSIXINCLUDES) $(POSIXDEFINES) -c $< -o $@

posixextras: readslavecomms holdopen

readslavecomms: readslavecomms.o
	$(POSIXLINK) readslavecomms.o -o readslavecomms

holdopen: holdopen.o
	$(POSIXLINK) holdopen.o -o holdopen

clean:  posixclean
	$(RM) .deps/*.d

-include .deps/*.d

