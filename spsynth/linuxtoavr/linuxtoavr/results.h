/***************************************************************************
                          results.h  -  description
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
#include "bool.h"

/* Define some of the ANSI color constants */
#define	MOVE_TO_COL				"\033[60G"
#define SETCOLOR_SUCCESS	"\033[1;32m"
#define SETCOLOR_FAILURE	"\033[1;31m"
#define SETCOLOR_WARNING	"\033[1;33m"
#define SETCOLOR_NORMAL		"\033[0;39m"

extern BOOL colour;	/* Set to true when we should print in colour. */

void Success(); /* Put OK */
void Failure(); /* Put Failed */
void Warning(); /* Put warning */