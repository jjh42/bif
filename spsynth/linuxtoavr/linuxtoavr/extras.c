/***************************************************************************
                          extras.c  -  description
                             -------------------
    begin                : Thu Jan 18 2001
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
#include <sys/stat.h>

#include "bool.h"

BOOL fsize(char *filename, unsigned long *size)
{
	/* Return the size of the file in bytes */
	struct stat stbuf;
	
	if(stat(filename, &stbuf) == -1) {
		/* We failed to get the file length. */
		return FALSE;		
	}

	/* Set the size */	
	(*size) = stbuf.st_size;
	
	return TRUE;
}
