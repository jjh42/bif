/***************************************************************************
                          program.c  -  description
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
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <termios.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#include "main.h"
#include "results.h"
#include "bool.h"

/* baudrate settings are defined in <asm/termbits.h>, which is
included by <termios.h> */
#define BAUDRATE B19200
#define _POSIX_SOURCE 1 /* POSIX compliant source */


#define NUM_WRITE_AT_ONCE	20

int commdev;
struct termios oldtio,newtio;

BOOL opencomms()
{
	printf("Opening comm port");
	/* Open the port. */
	commdev = open(TTY_FILE_NAME, O_RDWR | O_NOCTTY | O_NDELAY);
	if (commdev <0) {
		Failure();
		return FALSE;
	}
	
	/* Now set the settings. */
	tcgetattr(commdev, &oldtio); /* save current serial port settings */
	memset(&newtio, 0, sizeof(newtio)); /* clear struct for new port settings */

  /*
    BAUDRATE: Set bps rate. You could also use cfsetispeed and cfsetospeed.
    CRTSCTS : output hardware flow control (only used if the cable has
              all necessary lines. See sect. 7 of Serial-HOWTO)
    CS8     : 8n1 (8bit,no parity,1 stopbit)
    CLOCAL  : local connection, no modem contol
    CREAD   : enable receiving characters
  */
  newtio.c_cflag = BAUDRATE | CS8 | CLOCAL | CREAD;

  /*
    IGNPAR  : ignore bytes with parity errors
    ICRNL   : map CR to NL (otherwise a CR input on the other computer
              will not terminate input)
    otherwise make device raw (no other input processing)
  */
  newtio.c_iflag = IGNPAR | ICRNL;

  /*
   Raw output.
  */
  newtio.c_oflag = 0;

  /*
    ICANON  : enable canonical input
    disable all echo functionality, and don't send signals to calling program
  */
  newtio.c_lflag = ICANON;

  /*
    initialize all control characters
    default values can be found in /usr/include/termios.h, and are given
    in the comments, but we don't need them here
  */
  newtio.c_cc[VINTR]    = 0;     /* Ctrl-c */
  newtio.c_cc[VQUIT]    = 0;     /* Ctrl-\ */
  newtio.c_cc[VERASE]   = 0;     /* del */
  newtio.c_cc[VKILL]    = 0;     /* @ */
  newtio.c_cc[VEOF]     = 0;     /* Ctrl-d */
  newtio.c_cc[VTIME]    = 1;     /* inter-character timer unused */
  newtio.c_cc[VMIN]     = 0;     /* blocking read until 1 character arrives */
  newtio.c_cc[VSWTC]    = 0;     /* '\0' */
  newtio.c_cc[VSTART]   = 0;     /* Ctrl-q */
  newtio.c_cc[VSTOP]    = 0;     /* Ctrl-s */
  newtio.c_cc[VSUSP]    = 0;     /* Ctrl-z */
  newtio.c_cc[VEOL]     = '\r';     /* '\0' */
  newtio.c_cc[VREPRINT] = 0;     /* Ctrl-r */
  newtio.c_cc[VDISCARD] = 0;     /* Ctrl-u */
  newtio.c_cc[VWERASE]  = 0;     /* Ctrl-w */
  newtio.c_cc[VLNEXT]   = 0;     /* Ctrl-v */
  newtio.c_cc[VEOL2]    = 0;     /* '\0' */
  /*
    now clean the modem line and activate the settings for the port
  */
  tcflush(commdev, TCIFLUSH | TCOFLUSH);
  tcsetattr(commdev, TCSANOW,&newtio);

	Success();
	
	return TRUE;
}

BOOL closecomms()
{
	printf("Closing comm port");
	/* restore the old port settings */
  tcsetattr(commdev, TCSANOW, &oldtio);
  // Close the port
  close(commdev);

  Success();

	return TRUE;
}

BOOL programsegment(const char *segment)
{
	/* First write the segment. */
 	char buffer[264 * 2 + 7] = "SP"; // SP (2) + Address (4) + Data (264 * 2) + CR (1)
 	unsigned int count = 0;
	char *bufp;
 	ssize_t length;

	printf("Programming segment %d", ((unsigned int)((unsigned int)segment -
		(unsigned int)flash_buffer) / 264));

        tcflush(commdev, TCIFLUSH | TCOFLUSH);
	// Get the address
	sprintf((buffer + 2), "%.4x", ((unsigned int)((unsigned int)segment -
		(unsigned int)flash_buffer) / 264) );
	// Now convert the data
	while(count < 264) {
		sprintf(buffer + (count * 2) + 6, "%.2x", (unsigned int)(unsigned char)(*segment));
		count++;
		segment++;
	}
	// And lastly put on a CR
	buffer[(264 * 2) + 6] = '\r';

	// And write it
//        write(commdev, buffer, sizeof(buffer));
        // First make the serial device O_SYNC so it waits for writes
        fcntl(commdev, F_SETFL, O_SYNC);

	for(bufp = buffer; bufp < buffer + sizeof(buffer); bufp += NUM_WRITE_AT_ONCE) {
	    int numtowrite = buffer + sizeof(buffer) - bufp;
	    if(numtowrite > NUM_WRITE_AT_ONCE)
		numtowrite = NUM_WRITE_AT_ONCE;
	    if(write(commdev, bufp, numtowrite) != numtowrite) {
		printf("\n\tFailed to write segment");
		Failure();
		return FALSE;
	    }
	    usleep(((unsigned long)600) * ((unsigned long)
                numtowrite));
	}
	
#if 0
	if(write(commdev, buffer, sizeof(buffer)) !=
                    sizeof(buffer)) {		    
	    printf("\n\tFailed to write segment");
	    Failure();
	    return FALSE;
	}
#endif
#if 0
	for(bufp = buffer; bufp < buffer + sizeof(buffer); bufp++) {	    
	    if(write(commdev, bufp, 1) != 1) {
		printf("\n\tFailed to write segment");
		Failure();
		return FALSE;
	    }
	    usleep(600);
	}
#endif	
        fcntl(commdev, F_SETFL, O_ASYNC | O_NONBLOCK);
//        usleep(((unsigned long) 600) * ((unsigned long) sizeof(buffer)));	
	usleep(25000);
	
	// Now wait for a 'Q'
	if((length = read(commdev, buffer, 10)) <= 0) {
		printf("\n\tFailed to receive anything");
		Failure();
		return FALSE;
	}
	else if((length != 2) || (strncmp(buffer, "Q\n", 2)))
	{
		buffer[length] = 0;
		printf("\n\tFailed to read valid Q message\nRecieved instead %s\n", buffer);
		Failure();
		return FALSE;
	}
	// Received a Q
	Success();
	
	return TRUE;
}

BOOL programbuffer()
{
	const char *p = flash_buffer;
	const char *end = flash_buffer + SIZE_OF_FLASH;
	BOOL haderrors = FALSE;
	
	// Go through the buffer. Any segments that are not 0xff must
	// be programmed.
	while(p < end) {
		/* Go through the segment looking a non ff */
		const char *segment = p;
		int i;
		for(i = 0; i < 264; i++, segment++) {
			// Check for a non ff
			unsigned char data = (*segment);
			if( data != 0xff) { // We need to program this segment
				int i;
				for(i = 0; i < 10; i++)  {// Try to program segment up 
							  // to 10 times
				    if(programsegment(p))
					break;
				    haderrors = TRUE;				    
				}		
				if(i >= 9) {
				    Failure();
				    return FALSE;
				}				  
				break;
			}
		}
    p += 264; // Go to the next segment
	}
	
	printf("Completed programming");
	if(haderrors)	
		Warning();
	else
		Success();
		
	return TRUE;
}

BOOL do_program()
{
	if(!opencomms())
		return FALSE;
	
	/* Program each page */
	if(!programbuffer()) {
		closecomms();
		return FALSE;
	}
		
	if(!closecomms())
		return TRUE;
	
	return TRUE;	
}
