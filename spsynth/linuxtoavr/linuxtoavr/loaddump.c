/***************************************************************************
                          loaddump.c  -  description
                             -------------------
    begin                : Wed Jan 17 2001
    copyright            : (C) 2001 by Jonathan Hunt
    email                : jhuntnz@users.sourceforge.net
 ***************************************************************************/

/***************************************************************************
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 ***************************************************************************/

#include <stdio.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/mman.h>

#include "main.h"
#include "results.h"

BOOL load_dump()
{
	int dump_file;
        int size;
	
	if((dump_file = open(DUMP_FILE_NAME, O_RDONLY)) == 0) {
	    Failure();
	    printf("\tFailed top open dump file%s\n", DUMP_FILE_NAME);
	    return FALSE;
	}
	
	/* Map file into memory. */
        size = SIZE_OF_FLASH;
        if(size % getpagesize() != 0)
                size = (size + getpagesize()) % getpagesize();

	flash_buffer = mmap(0, size, PROT_READ,
	    MAP_SHARED, dump_file, 0);
	    
	if(flash_buffer == ((void *)-1)) {
            perror("mmap");
	    Failure();
	    printf("\tFailed to map dump file\n");
	    return FALSE;
	}
		    
	return TRUE;
#if 0
	FILE *dump_file;
	
//	printf("Loading dump file");
	
	if((dump_file = fopen(DUMP_FILE_NAME, "r")) == NULL) {
		/* We failed to open the dump file */
		Failure();
		printf( "\tFailed to open dump file %s\n", DUMP_FILE_NAME);
		return FALSE;
	}
	
	/* We successfully opened the file. */
	if(fread(flash_buffer, sizeof(unsigned char),
		SIZE_OF_FLASH, dump_file) != SIZE_OF_FLASH) {
		/* There was a problem reading the buffer */
		Failure();
		printf( "\tProblem reading dump file\n");
		return FALSE;		
	}
	
	fclose(dump_file);
	/* Successfully load the dump buffer. */
//	Success();
#endif

		
	return TRUE;	
}