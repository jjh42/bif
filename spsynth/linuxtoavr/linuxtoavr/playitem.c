/***************************************************************************
                          playitem.c  -  description
                             -------------------
    begin                : Thu May 3 2001
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

#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include <stdio.h>

#include "bool.h"
#include "main.h"
#include "pcadpcm.h"

const unsigned char *index_to_pointer(unsigned int index) {
	/* The lower byte plus 1 bit contain the index into the
	   page. */
	unsigned int byteindex = index & 0x01ff;
	unsigned int page = index >> 9;
	byteindex += (page * 264);

	/* Now convert the index to a pointer. */
	return flash_buffer + byteindex;
}

BOOL write_file(const unsigned char *buf, unsigned int length, BOOL tostdio) {
	
        struct ADPCMstate state;
	
	/* Now decompress and write the data. */
	state.previndex = 0;
	state.prevsample = 0;

	while(length) {
		unsigned char data = *buf;
		short sample;

		buf++;	
		length --;
		/* Now decompress this data and write it to the file. */
		sample = ADPCMDecoder((data >> 4) & 0x0f, &state);		
                putchar((sample >> 8));
                sample = ADPCMDecoder((data & 0x0f), &state);
                putchar((sample >> 8));
	}

	return TRUE;
}

BOOL play_item(int item, BOOL tostdio)
{
	/* Load the item from the index and play it. */
	/* First load from the index. */
	unsigned int indexaddress;
	unsigned int playaddress = 0;
	unsigned int length = 0;
	const unsigned char *buf;

	/* First decrement item */
	item --;
	/* Load the index entry. */
	indexaddress = ((unsigned int) item) * 5;

	/* The index and length are stored MSB first  */
	*(((unsigned char *)&playaddress) + 2) = flash_buffer[indexaddress + 0];
	*(((unsigned char *)&playaddress) + 1) = flash_buffer[indexaddress + 1];
	*(((unsigned char *)&playaddress) + 0) = flash_buffer[indexaddress + 2];

	*(((unsigned char *)&length) + 1) = flash_buffer[indexaddress + 3];
	*(((unsigned char *)&length) + 0) = flash_buffer[indexaddress + 4];

        /* Check if it is a pause. */
        if(playaddress == 0) {
                /* Output nothing to pause. */
                while(length) {
                        length--;
                        putchar(0);
                }
        }
	/* Now convert the playaddress to a pointer inside the buffer */
	buf = index_to_pointer(playaddress);

	/* Now read out the data and write it to a file. */
	return write_file(buf, length, tostdio);
}

