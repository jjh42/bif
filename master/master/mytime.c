/***************************************************************************
                          mytime.c  -  description
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


/* Dummy headers for Dynamic C */
/*** Beginheader mytime_c */
#ifdef TARGET_RABBIT
void mytime_c();

#asm
XXXmytime_c:	equ	mytime_c
#endasm

#endif /* TARGET_RABBIT */
/*** endheader */


#ifdef TARGET_RABBIT
void mytime_c () { }
#endif /* TARGET_RABBIT */

#include "compat.h"
#include "mytime.h"
#include "slave-speech.h" // for errorbeep

#include "stdio.h" // for printf
#ifdef TARGET_POSIX
#include <sys/time.h>
#endif

const char *EnglishMonthName[12] =
		{"January","February","March","April","May","June",
		 "July","August","September","October","November","December"};

const char *EnglishDayName[7] =
		{"Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"};


#ifdef TARGET_POSIX
/* Return a millisecond value that is incremented every msec. */
TIME getmsectimer()
{
        struct timeval t;
        gettimeofday(&t, NULL);
        // 1000 microseconds in a millisecond
        return t.tv_usec / 1000;
}

/* Return a second value. */
TIME getsectimer()
{
        return time(NULL);
}

int tm_rd(struct tm *t)
{
        time_t tv;
        struct tm *ret;
        tv = time(NULL);
        ret = localtime(&tv);
        if(ret == NULL)
                return -1;
        *t = *ret;

        return 0;
}
#endif

#ifdef TARGET_WIN32
/* Return a millisecond value that is incremented every msec. */
TIME getmsectimer()
{
static TIME MS_TIMER;
MS_TIMER += 500; // temp ......... xxxxxxxxx
return MS_TIMER;
//        struct timeval t;
//        gettimeofday(&t, NULL);
//        // 1000 microseconds in a millisecond
//        return t.tv_usec / 1000;
}

/* Return a second value. */
TIME getsectimer()
{
        return time(NULL);
}

int tm_rd(struct tm *t)
{
        time_t tv;
        struct tm *ret;
        tv = time(NULL);
        ret = localtime(&tv);
        if(ret == NULL)
                return -1;
        *t = *ret;

        return 0;
}
#endif

#ifdef TARGET_RABBIT
TIME getsectimer()
{
        return SEC_TIMER;
}

TIME getmsectimer()
{
        return MS_TIMER;
}
#endif


/*****************************************************
*
* Function Name: Fill My Time Date Structure
* Description: Updates MyTimeDateStruct with current values
* Arguments: None
* Return Value: TRUE if successful
*
*****************************************************/

BOOL FillMyTimeDateStructure (void)
{
BOOL FResult;
FResult = (BOOL)((tm_rd (&MyTimeDateStruct)==0) ? TRUE : FALSE);
if (! FResult) {
	printf ("Error: Can't read system time\n");
	errorbeep ();
	}
return FResult;
}
/* End of FillMyTimeDateStructure */


/* End of MyTime.c */
