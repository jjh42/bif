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
#include "speak.h" // for errorbeep
#include "control.h"
#include "Brain.h"

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
	ErrorBeep ();
	}
return FResult;
}
/* End of FillMyTimeDateStructure */


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

#if 0
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
* Function Name: InitTimers
* Description: Initializing timer variables, etc.
* Arguments: None
* Return Value: None
*
*****************************************************/

void InitTimers (void)
{
LastManualActionTime = LastAutoActionTime = getsectimer();

AlarmSet = ALARM_OFF;
TalkingClockOn = FALSE;

UpdateTimers ();
}
/* End of InitTimers */


/*****************************************************
*
* Function Name: UpdateTimers (called from MainLoop)
* Description: Update timer variables, etc.
* Arguments: None
* Return Value: None
*
*****************************************************/

#define IDLE_OFF_TIME 600 // seconds = 10 minutes
#define ONE_MINUTE 60 // seconds

root void UpdateTimers (void)
{
if (tm_rd (&MyTimeDateStruct) !=0) {
	printf ("Error: Can't read system time\n");
	ErrorBeep ();
	return;
	}

// Check alarm clock
if (AlarmSet != ALARM_OFF)
	if (getsectimer() >= AlarmTime) {
		assert (MyTimeDateStruct.tm_hour>=0 && MyTimeDateStruct.tm_hour<=23);
		assert (MyTimeDateStruct.tm_min>=0 && MyTimeDateStruct.tm_min<=59);

		Tone (SINE_WAVE, C_2, CROTCHET);
		Tone (SINE_WAVE, D_2, CROTCHET);
		Tone (SINE_WAVE, E_2, CROTCHET);
		Tone (SINE_WAVE, F_2, CROTCHET);
		Tone (SINE_WAVE, G_2, MINIM);

		// Convert to 12 hour time
		if (MyTimeDateStruct.tm_hour>=13)
			MyTimeDateStruct.tm_hour -= 12;

		switch (CurrentOutputLanguage) {
#ifdef INCLUDE_MATIGSALUG
			case MATIGSALUG:
				sprintf (MakeupSpeakString, "alas %u %u.", MyTimeDateStruct.tm_hour, MyTimeDateStruct.tm_min);
				SayMakeupSpeakString (FALSE);
				break;
#endif
			default: // default to English
				sprintf (MakeupSpeakString, "Alarm at %u %u.", MyTimeDateStruct.tm_hour, MyTimeDateStruct.tm_min);
				SayMakeupSpeakString (FALSE);
				break;
			}
		switch (AlarmSet) {
			case ALARM_ONCE:
				AlarmSet = ALARM_OFF; break;
			case ALARM_REPEAT:
				AlarmTime += AlarmIncrement; break;
			default:
				printf ("UnknwnAlarmSetting"); break;
			}
		LastAutoActionTime = getsectimer();
		}

// Check talking clock
if (TalkingClockOn)
	if (getsectimer() >= NextTalkingClockTime) {
		TellTime();
		NextTalkingClockTime += TalkingClockIncrement;
		LastAutoActionTime = getsectimer();
		}

// Check for system timeout
if (AutoOff
 && (AlarmSet == ALARM_OFF)
 && ((getsectimer()-LastManualActionTime) > IDLE_OFF_TIME)) {
	// 10 minutes with nothing happening -- turn off the power
	DoStandbyPowerDown ();

	// Check again in a minute (so we don't repeat endlessly if the power should somehow stay on)
	LastManualActionTime = getsectimer() - (IDLE_OFF_TIME - ONE_MINUTE);
	}
}
/* End of UpdateTimers */


/* End of MyTime.c */
