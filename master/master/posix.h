/*** Beginheader */

/***************************************************************************
                          posix.h  -  description
                             -------------------
    begin                : Tue Aug 28 2001
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

#ifndef _POSIX_H
#define _POSIX_H

/*Definitions common to the posix section. */

/* String with the path of our executable file. No / is on the end. */
extern char *execpath;

/* Definition of files used */
#define STDIO_IN                0
#define STDIO_OUT               1
#define STDIO_ERROR             2
#define SLAVE_COMMS_READ_FILE   3
#define SLAVE_COMMS_WRITE_FILE  4

#endif /* _POSIX_H */

/*** endheader */

