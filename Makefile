# Makefile for the entire robot
# Just cd to subdirs and make


all:
	cd spsynth && $(MAKE)
	cd base && $(MAKE)
	cd mcs51 && $(MAKE)

clean:
	cd spsynth && $(MAKE) clean
	cd base && $(MAKE) clean
	cd mcs51 && $(MAKE) clean