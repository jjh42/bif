/***************************************************************************
                          makedump.c  -  description
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
#include <string.h>

#include "main.h"
#include "results.h"
#include "extras.h"
#include "pcadpcm.h"
#include "parse.h"

unsigned char *indexpointer;
unsigned char *datapointer;
FILE *header_file = NULL;
FILE *include_file = NULL;   /* Include file is the Atmel AVR Assembler compatible include file */
int num_files = 0;

unsigned int convertpointertoflashp(unsigned char *pointer)
{
	/* Converts the pointer which should point to somewhere in ByteBuffer */
	/* to a UINT pointer read to be programmed into the flash. */
	unsigned int page;
	unsigned int offset;
	unsigned int data = (unsigned int)pointer;
	data -= (unsigned int) flash_buffer; /* Take away ByteBuffer to get a zero offset pointer  */
	/* Now we need to convert to this format
	 0b 0000000 PPPPPPPP PPPPPPPO OOOOOOOO
	 Where P is the page and O is the offfset inside the 264 byte page. */
	
	page = data / 264;
	offset = data % 264;
	data = (page << 9) | offset;
	
	return data;
}

BOOL check_dup_filename(const char *filename)
{
	static char *names[MAX_SOUNDS];
	static int numsounds = 0;
	int i;
	
	/* Check for a duplicate filename */
	for(i = 0; i < numsounds; i++) {
		if(strcmp(filename, names[i]) == 0) {
			Failure();
			printf("\tDuplicate sound %s\n", filename);
			return FALSE;
		}
	}

	/* Add this filename to the list */
	names[numsounds] = strdup(filename);
	numsounds++;

	return TRUE;
}

BOOL check_dup_define(const char *define)
{
	static char *defs[MAX_SOUNDS];
	static int numdefs = 0;
	int i;
	
	/* Check for a duplicate filename */
	for(i = 0; i < numdefs; i++) {
		if(strcmp(define, defs[i]) == 0) {
			Failure();
			printf("\tDuplicate define %s\n", define);
			return FALSE;
		}
	}

	/* Add this filename to the list */
	defs[numdefs] = strdup(define);
	numdefs++;

	return TRUE;
}

BOOL check_dup_pause(unsigned int pauselen)
{
	static unsigned int pauses[MAX_SOUNDS];
	static int numpauses;
	int i;

	/* Check for a duplicate pause */
	for(i = 0; i < numpauses; i++) {
		if(pauselen == pauses[i]) {
			Failure();
			printf("\tDuplicate pause %d\n", pauselen);
			return FALSE;
		}
	}

	/* Add this pause to the list */
	pauses[numpauses] = pauselen;
	numpauses++;

	return TRUE;
}


#define INDEX_ENTRY_SIZE	5
BOOL addtoindex(unsigned int address, unsigned short length, const char *define)
{
	static int index = 1;

	/* Check for duplicate define. */
	if(!check_dup_define(define))
		return FALSE;

	if(index > MAX_SOUNDS) {
		Failure();
		printf("\tTo many sounds\n");
		return FALSE;
	}
	
	/* Add the definition to the Header file */
	fprintf(header_file, "#define %s \"\\x%x\" /* %d */\n", define, (index & 0xff), (index & 0xff));
	fprintf(include_file, ".equ %s = 0x%x ; %d\n", define, (index & 0xff), (index & 0xff));

	/* Add to index */
	/* First check that this will not overflow the flash */
	
	if((datapointer - indexpointer) < INDEX_ENTRY_SIZE) {
		Failure();
		printf("\tFlash buffer full\n");
		return FALSE;
	}

	// Okay now we can write to the buffer
	*indexpointer++ = *(((unsigned char *)&address) + 2); /* Write the high byte first */
	*indexpointer++ = *(((unsigned char *)&address) + 1); /* Write the middle byte next */
	*indexpointer++ = *(((unsigned char *)&address) + 0); /* Last put the low byte */

	// Now write the length
	*indexpointer++ = *(((unsigned char *)&length) + 1); /* Write the high byte first */
	*indexpointer++ = *(((unsigned char *)&length) + 0); /* And the low byte */

	/* Don't forget to increment the nIndex */
	index++;

	return TRUE;
}

/* Expected header of files. */
const char compare[0x2c] = 
{
    'R', 'I', 'F', 'F',  /* 0x04 */
    0, 0, 0, 0, /* 0x08 */
     'W', 'A', 'V', 'E', 'f', 'm', 't', /* 0x0f */
    0x20, 0x10,  /* 0x11 */
    0, 0, 0, /* 0x14 */
    0x01, 0, 0x01, 0x00,  /* 0x18 */
    0x40, 0x1f, 0, 0, /* 0x1c */
    0x80, 0x3e, 0x00, 0x00, /* 0x20 */
    0x02, 0, 0x10, 0, /* 0x24 */
    'd', 'a', 't', 'a', /* 0x28 */
    0, 0, 0, 0, /* 0x2c */
};
const char mask[0x2c] = 
{
    0xff, 0xff, 0xff, 0xff, /* 0x04 */
    0, 0, 0, 0,  /* 0x08 */
    0xff, 0xff,  0xff, 0xff, 0xff, 0xff, 0xff, /* 0x0f */
    0xff, 0xff, /* 0x11 */
    0xff, 0xff, 0xff, /* 0x14 */
    0xff, 0xff, 0xff, 0xff, /* 0x18 */
    0xff, 0xff, 0xff, 0xff, /* 0x1c */
    0xff, 0xff, 0xff, 0xff, /* 0x20 */
    0xff, 0xff, 0xff, 0xff, /* 0x24 */
    0xff, 0xff, 0xff, 0xff, /* 0x28 */
    0, 0, 0, 0,        /* 0x2c */
};

BOOL add_sound(const char *filename, const char *define)
{
 	int mod;
	FILE *soundfile;
	unsigned long length;
	unsigned short sample;
	unsigned char code;
	struct ADPCMstate state;
	unsigned char *storepointer;
	char header[0x2c];
	int i;
	
	num_files++;
	/* Check for a duplicate filename */
	if(!check_dup_filename(filename))
		return FALSE;

        if(task == parseOnly) {
                // Just add it to the index so it shows up in the sounds defs
        	return addtoindex(0, 0, define);
        }


	/* First try to open and compress the file */
	if((soundfile = fopen(filename, "r")) == NULL) {
		Failure();
		printf("\tError opening sound file %s\n", filename);
		return FALSE;
	}
	
	/* Check for the correct headers. */
	if(fread(header, 0x2c, 1, soundfile) != 1) {
badheader:;
	    Failure();
	    printf("\tBad sound file\n");
	    return FALSE;
	}
	
	/* Now begin to check header. */
	for(i = 0; i < 0x2c; i++) {
                if((header[i] & mask[i]) != compare[i]) {
        	    Failure();
	            printf("\tBad sound header at byte %d, should be 0x%.2x is 0x%.2x\n",
                        (int)i + 1, (int) header[i], (int) compare[i]);
        	    return FALSE;
                }
	}
	
	/* Now read the input file and compress it and add it to the data section*/
	
	/* Now check we have enough room for this file */
	if(!fsize((char*)filename, &length)) {
		Failure();
		printf( "\tError getting file size of %s\n", filename);
		fclose(soundfile);
		return FALSE;
	}
	
	length -= 0x2c; /* Subtract the header of the wav file */
  /* Length is divided by 4 (it takes 2 bytes for each sample
     and there is 2 samples per byte).
     If there is not an even number of samples length is
     incremented one to make up for it.
  */
  mod = length % 4;
  length /= 4;
  if(mod)
    length++;

	if(((unsigned long)(datapointer - indexpointer)) < length) {
		Failure();
		printf( "\tOut of room\n");
		fclose(soundfile);
		return FALSE;
	}
	
	/* There is enough room */
	datapointer -= length; /* Backup enough for the data */
	storepointer = datapointer;	
	state.prevsample=0;	/* Clear the state */
	state.previndex=0;
	/* Read input file and process */
	while (fread(&sample, sizeof(sample), 1, soundfile) == 1)
	{
		// Encode sample into lower 4-bits of code
		code = ADPCMEncoder(sample, &state);
		// Move ADPCM code to upper 4-bits
		code = (code << 4) & 0xf0;
		// Read new sample from file
		if(fread (&sample, sizeof(sample), 1, soundfile) != 1)
		{
			*storepointer++ = code;
			// No more samples, write code to file
			break;
		}

		// Encode sample and save in lower 4-bits of code
		code |= ADPCMEncoder(sample,&state);
		// Write code to file, code contains 2 ADPCM codes
		*storepointer++ = code;
	}
	/* We are done with the sound file */	
	fclose(soundfile);	
	// Check that we used the expected amount of room		
	if(storepointer != (datapointer + length)) {
		Failure();
		printf( "\tUsed invalid amount of room\n");
		return FALSE;
	}

	// If we did we add it to the index
	if(!addtoindex(convertpointertoflashp(datapointer), length, define))
		return FALSE;		
	
	return TRUE;
}

BOOL add_pause(unsigned int pause, const char *define)
{
        if(task == parseOnly)
                return addtoindex(0, pause, define);

        num_files ++;

	if(!check_dup_pause(pause))
		return FALSE;

	// Now convert the milliseconds to 8000hz
	pause *= 8;

	// Convert the file name to a number
	if(!addtoindex(0, pause, define))
		return FALSE;
	
	
	return TRUE;
}

BOOL open_header_file()
{
	printf("Opening header file");
	if((header_file = fopen(HEADER_FILE_NAME, "w")) == NULL) {
		Failure();
		printf( "\tError opening header file %s\n", HEADER_FILE_NAME);	
		return FALSE;
	}
	
	/* Print the "header" of the header file */
	fprintf(header_file,
		"/* This file is made automatically by linuxtoavr\n"
		" * (C) Jonathan Hunt. It is available under the GNU\n"
		" * license version 2 or any later version (at your option)\n"
		" *\n"
		" * Any changes made to this file will be overwritten\n"
		"*/\n"
		"\n"
		"/*** Beginheader */\n"
		"#ifndef _LINUX_TO_AVR_SOUNDS_H\n"
		"#define _LINUX_TO_AVR_SOUNDS_H\n"
		"\n"
		);

	printf("Opening include file");
	if((include_file = fopen(INCLUDE_FILE_NAME, "w")) == NULL) {
		Failure();
		printf( "\tError opening include file %s\n", INCLUDE_FILE_NAME);	
		return FALSE;
	}

	fprintf(include_file,
		"; This file is made automatically by linuxtoavr\n"
		"; (C) Jonathan Hunt. It is available under the GNU\n"
		"; license version 2 or any later version (at your option)\n"
		";\n"
		"; Any changes made to this file will be overwritten\n"
		";\n"
		";\n");
		
	Success();
	return TRUE;
}

FILE *open_input_file()
{
	FILE *input_file;
		
	printf("Opening input file");
	/* Now open the file. */
	if((input_file = fopen(INPUT_FILE_NAME, "r")) == NULL) {
		Failure();
		printf( "\tError opening input file %s\n", INPUT_FILE_NAME);
		return NULL;
	}
	
	Success();
	return input_file;
}

BOOL dodump()
{
	FILE *dumpfile;
	/* First open the dump file */
	if((dumpfile = fopen(DUMP_FILE_NAME, "w")) == NULL) {
		Failure();
		printf( "\tError opening dump file %s\n", DUMP_FILE_NAME);
		return FALSE;
	}
	/* Then write the dump */
	if(fwrite(flash_buffer, SIZE_OF_FLASH, 1,
		dumpfile) != 1) {
		fclose(dumpfile);
		/* There was some problem writing. */
		Failure();
		printf( "\tFailed to write dump file\n");
		return FALSE;
	}
	
	/* Now close the file */
	fclose(dumpfile);
	
	Success();
	
	return TRUE;	
}

BOOL make_dump()
{
	FILE *input_file;
	
	unsigned char *p = flash_buffer;
	int length = SIZE_OF_FLASH;
	
	unsigned int percent;
  unsigned int indexsize;
  unsigned int datasize;
  unsigned int totalsize;
	
     indexpointer = flash_buffer;
     datapointer = flash_buffer + (SIZE_OF_FLASH - 1);

	/* First set the flash_buffer to 0xff */
	while(length--) {
		*p++ = 0xff; /* Set the memory. */
	}
	
	/* Now parse the input file. */
	if((input_file = open_input_file()) == NULL)
		return FALSE;
		
	/* Open the header file. */
	if(!open_header_file())
		return FALSE;

        /* This is the main function for parsing input.conf. This will call us
         * back
         */
        if(!parse_input(input_file))
                return FALSE;

	
        if(task == parseOnly)
                goto Exit;

	printf("Writing dump file");
	
	if(num_files < 1) {
		Failure();
		printf("\tNo files were specified in input\n");
		fclose(input_file);
		fclose(header_file);
		fclose(include_file);
		return FALSE;
	}
	
	if(!dodump()) {
		fclose(input_file);		
		fclose(header_file);
		fclose(include_file);
		return FALSE;
	}

	/* Get the percentage of the flash used. */
  datasize = flash_buffer + SIZE_OF_FLASH - datapointer;
  indexsize = indexpointer - flash_buffer;
  totalsize = datasize + indexsize;
	percent =  (totalsize * 100) / SIZE_OF_FLASH;
	
	printf("\t%d files or pauses were added\n"
         "\t%u percent of the flash was used\n"
         "\t%u was used as data\n"
         "\t%u was used as index\n"
         "\t%u was used total out of %u\n",
  	     num_files, percent, datasize, indexsize, totalsize,
         SIZE_OF_FLASH);	
	 
	fprintf(header_file, "\n/*** endheader */\n");
	/* We are now down with the input file */
	fclose(input_file);

Exit:	
	/* Write the ending on the header file */
	fprintf(header_file,
		"\n"
		"#endif _LINUX_TO_AVR_SOUNDS_H\n");
	/* And close it. */
	fclose(header_file);
	fclose(include_file);
	
	return TRUE;	
}