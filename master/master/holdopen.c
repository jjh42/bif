/***************************************************************************
                          holdopen.c  -  description
                             -------------------
    begin                : Mon Aug 27 2001
    copyright            : (C) 2001 by Jonathan Hunt
    email                : jhuntnz@users.sf.net
 ***************************************************************************/

/***************************************************************************
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 ***************************************************************************/

/* Hold open is similar to cat except that it opens it input for reading and
 * writing but only reads. This is useful for holding open fifos that would
 * otherwise die.
 */
#include <unistd.h>
#include <fcntl.h>
#include <stdio.h>
#include <termios.h>

int main(int argc, char *argv[])
{
    char c;
    int file;

    for(;;) {
	usleep(1);
	file = open(argv[1], O_RDWR);

	if(file < 0) {
	    fprintf(stderr, "Unable to open file\n");
    	    continue;
        }	
	
        fprintf(stderr, "Opened fifo\n");
    
	while(read(file, &c, 1) == 1) {
//	    fprintf(stderr, "Got a char\n");
	    write(1, &c, 1);
//	    tcflush(1, TCOFLUSH);
	}	    

	fprintf(stderr, "Filed died\n");	    
    }
}

