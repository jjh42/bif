/***************************************************************************
                          mytime.h  -  description
                             -------------------
    begin                : Wed Sep 12 2001
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

/* Because of Dynamic C all of the headers contents must go between Beginheader
 * and endheader.
 */

/*** Beginheader */
#ifdef REAL_COMPILER
#include <time.h>
#endif

/* This is the header for mytime.c. Mytime.* is for compatibility in time functions. */
struct tm MyTimeDateStruct;

/* Return a millisecond value that is incremented every msec. */
extern TIME getmsectimer();
/* Return a second value. */
extern TIME getsectimer();
BOOL FillMyTimeDateStructure (void);

#ifdef REAL_COMPILER
extern int tm_rd(struct tm *t);
#endif

extern const char *EnglishMonthName[12];
extern const char *EnglishDayName[7];

/*** endheader */
