SUBDIRS = ioslave1 supervisor1

all:	
	cd ioslave1 && $(MAKE)
	cd supervisor1 && $(MAKE)

clean:
	for i in $(SUBDIRS); do \
	    cd $$i && $(MAKE) clean; \
	    cd ..; \
	done
    
