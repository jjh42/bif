

/* Dummy headers for Dynamic C */
/*** Beginheader lcd_c */
#ifdef TARGET_RABBIT
void lcd_c();
#asm
xxxlcd_c: equ lcd_c
#endasm
#endif /* TARGET_RABBIT */
/*** endheader */

#ifdef TARGET_RABBIT
void lcd_c () { }
#endif /* TARGET_RABBIT */


/*****************************************************
*
*	Name: LCD
*	Description: LCD Display routines
*	Author: Robert Hunt
*	Created: August 2001
*
*	Mod. Number: 14
*	Last Modified: 6 October 2001
*	Modified by: Robert Hunt
*
******************************************************/

#include <stdio.h>
#include <string.h>

#include "compat.h"
#include "LCD.h"
#include "io.h"
#include "mytime.h"
#include "slave-speech.h" // for errorbeep


/*****************************************************
*
*	Globals
*
*****************************************************/

#define LCD_BUFFER_LENGTH 100 // Must be less than 128 because only 8-bit pointers are used
static U8 LCDBuffer[LCD_BUFFER_LENGTH]; // No trailing null
static U8 LCDStartIndex;

static unsigned long LastLCDCommandTime; // in msec
static unsigned long LCDCommandWaitTime; // in msec
static U8 LastSecs, LastMins;


/*****************************************************
*
* Function Name: BufferLCDString
* Description: 
* Argument: None
* Return Value: None
*
*****************************************************/

nodebug void BufferLCDString (constparam U8 *TheString)
{
U8 Index;

while (*TheString != 0)
	{
	if (LCDNumCharacters < LCD_BUFFER_LENGTH) {
		Index = (U8)(LCDStartIndex + LCDNumCharacters);
		if (Index >= LCD_BUFFER_LENGTH)
			Index -= LCD_BUFFER_LENGTH;
		LCDBuffer[Index] = *TheString;
		++LCDNumCharacters;	
		}
	else {
		printf ("LCDbuffovrflw");
		errorbeep ();
		break;
		}
	++TheString;
	}
UpdateLCD (); // See if the characters can be sent immediately
}
/* End of BufferLCDString */



/*****************************************************
*
* Function Name: BufferLCDCommand
* Description: 
* Argument: None
* Return Value: None
*
*****************************************************/

nodebug static void BufferLCDCommand (U8 Command)
{
U8 tmp[3];
tmp[0] = LCD_COMMAND;
tmp[1] = Command;
tmp[2] = '\0';
BufferLCDString (tmp);
}
/* End of BufferLCDCommand */


/*****************************************************
*
* Function Name: LCDClear
* Description: 
* Argument: 
* Return Value: None
*
*****************************************************/

nodebug void LCDClear (U8 ClearWhat)
{
static const char ClearString[16+1] = "                ";

if (ClearWhat == LCD_LINE_1) {
	BufferLCDCommand (LCD_HOME_1);
	BufferLCDString (ClearString);
	}
else if (ClearWhat == LCD_LINE_2) {
	BufferLCDCommand (LCD_HOME_2);
	BufferLCDString (ClearString);
	}
else // assume it's everything
	BufferLCDCommand (LCD_CLS); // Clear all
}
/* End of LCDClear */


/*****************************************************
*
*
*
*****************************************************/

nodebug void LCDDateOff (BOOL DoClear)
{
if (DoClear) // Clear the correct line
	LCDClear (LCDDateDisplay & 0x0F);
LCDDateDisplay = LCD_DATE_OFF;
LastMins = 255;
}
// End of LCDDateOff


/*****************************************************
*
*
*
*****************************************************/

nodebug void LCDTimeOff (BOOL DoClear)
{
if (DoClear) // Clear the correct line
	LCDClear (LCDTimeDisplay & 0x0F);
LCDTimeDisplay = LCD_TIME_OFF;
LastSecs = 255;
}
// End of LCDTimeOff


/*****************************************************
*
*
*
*****************************************************/

nodebug void InitLCD (void)
{
U8 ii;
for (ii=0; ii<=NUM_SUBSYSTEMS; ++ii)
	LCDLastUpdateTime[ii] = 0; // 0 is global, subsystems start at 1

LCDStartIndex = 0;
LCDNumCharacters = 0;

LCDDateOff (FALSE);
LCDTimeOff (FALSE);

#ifdef TARGET_RABBIT
BitWrPortI (PBDR, &PBDRShadow, 0, 7); // Make sure RS (PB7) is set low for commands
LCDNibbleOut (LCD_INIT >> 4); // Out MS nibble only
#endif
LastLCDCommandTime = getmsectimer ();
LCDCommandWaitTime = 6; // Be sure to wait at least 4.1 msec

BufferLCDCommand (LCD_INIT); // Set up
BufferLCDCommand (LCD_INIT); // (Need to send this
BufferLCDCommand (LCD_INIT); //		three times)
BufferLCDCommand (LCD_INIT); //		three times)
BufferLCDCommand (LCD_INCREMENT); // Set into cursor increment mode
BufferLCDCommand (LCD_CURSOR_OFF); // Don't display a cursor
LCDClear (LCD_ENTIRE_DISPLAY);
}
/* End of InitLCD */


#if 0
/*****************************************************
*
*
* For some reason this is more reliable if we do it twice
*
*****************************************************/

nodebug void InitLCD (void)
{
InitLCD1 ();
//InitLCD1 ();
}
// End of InitLCD
#endif


/*****************************************************
*
*
*
*****************************************************/

nodebug void LCDDisplay (U8 SubsystemID, constparam char *DisplayString, BOOL BlankFill)
{
U8 MaxLength;
assert (SubsystemID>0 && SubsystemID<=NUM_SUBSYSTEMS);

// Put the cursor into the right line and column
switch (SubsystemID) {
	case BRAIN_SUBSYSTEM:
		BufferLCDCommand (BRAIN_SUBSYSTEM_HOME + BRAIN_SUBSYSTEM_COLUMN - 1);
		MaxLength = BRAIN_SUBSYSTEM_NUM_CHARS;
		break;
	case IR_SUBSYSTEM:
		BufferLCDCommand (IR_SUBSYSTEM_HOME + IR_SUBSYSTEM_COLUMN - 1);
		MaxLength = IR_SUBSYSTEM_NUM_CHARS;
		break;
	}
if (BlankFill)
	while (strlen(DisplayString) < MaxLength)
		strcat (DisplayString, " ");
assert (strlen(DisplayString)<=MaxLength); // Could be wrong if have other command characterss
BufferLCDString (DisplayString);
LCDLastUpdateTime[SubsystemID] = getmsectimer(); // Remember when we did this
}
/* End of LCDDisplay */


/*****************************************************
*
* Checks for display timeouts
* Automatically displays the date & time as requested
*
*****************************************************/

nodebug root void UpdateLCD (void)
{
U8 ThisChar;
char MyLCDString[LCD_CHARS_PER_LINE+2+1]; // 2 extra for a command plus 1 for a null

if (LCDNumCharacters==0)
	{
	// TIME display
	if (LCDTimeDisplay!=LCD_TIME_OFF) {
		// See if the other possible displays have timed out
		if (((getmsectimer () - LCDLastUpdateTime[LCDTimeDisplay & 0x0F]) > LCD_PERSISTENCE_TIME)
		|| ((LCDTimeDisplay & LCD_TIME_OVERRIDE) != 0))
			{
			if (FillMyTimeDateStructure ()) {
				assert (MyTimeDateStruct.tm_hour>=0 && MyTimeDateStruct.tm_hour<=23);
				assert (MyTimeDateStruct.tm_min>=0 && MyTimeDateStruct.tm_min<=59);
				assert (MyTimeDateStruct.tm_sec>=0 && MyTimeDateStruct.tm_sec<=59);
				if (MyTimeDateStruct.tm_sec != LastSecs) {
					ThisChar = (LCDTimeDisplay & 0xF)==LCD_TIME_LINE_1 ? LCD_HOME_1 : LCD_HOME_2;
					if (LCDDateDisplay == LCD_DATE_OFF) {
						sprintf (MyLCDString, "%c%c%2u:%02u:%02u %.3s %u", LCD_COMMAND, ThisChar,
						 MyTimeDateStruct.tm_hour, MyTimeDateStruct.tm_min, MyTimeDateStruct.tm_sec, EnglishDayName[MyTimeDateStruct.tm_wday], MyTimeDateStruct.tm_mday);
						if (MyTimeDateStruct.tm_mday >= 10) // Need one more character
							strcat (MyLCDString, " "); // Pad out with a space
						else // Need two more characters
							switch (MyTimeDateStruct.tm_mday) {
								case 1:
									strcat (MyLCDString, "st");
									break;
								case 2:
									strcat (MyLCDString, "nd");
									break;
								case 3:
									strcat (MyLCDString, "rd");
									break;
								default:
									strcat (MyLCDString, "th");
									break;
								}
						}
					else // we're already displaying the date anyway -- just display the time in the centre
						sprintf (MyLCDString, "%c%c    %2u:%02u:%02u    ", LCD_COMMAND, ThisChar,
						 MyTimeDateStruct.tm_hour, MyTimeDateStruct.tm_min, MyTimeDateStruct.tm_sec);
					BufferLCDString (MyLCDString);
#ifdef TARGET_RABBIT // structure members are chars
					LastSecs = MyTimeDateStruct.tm_sec;
#else // structure members are ints
					LastSecs = (U8)MyTimeDateStruct.tm_sec;
#endif
					}
				}
			}
		}
	// DATE display
	if (LCDDateDisplay!=LCD_DATE_OFF) {
		// See if the other possible displays have timed out
		if (((getmsectimer () - LCDLastUpdateTime[LCDDateDisplay & 0x0F]) > LCD_PERSISTENCE_TIME)
		|| ((LCDDateDisplay & LCD_DATE_OVERRIDE) != 0))
			{
			if (FillMyTimeDateStructure ()) {
				assert (MyTimeDateStruct.tm_wday>=0 && MyTimeDateStruct.tm_wday<=6);
				assert (MyTimeDateStruct.tm_year>=80 && MyTimeDateStruct.tm_year<=147);
				assert (MyTimeDateStruct.tm_mon>=1 && MyTimeDateStruct.tm_mon<=12);
				assert (MyTimeDateStruct.tm_mday>=1 && MyTimeDateStruct.tm_mday<=31);
				if (MyTimeDateStruct.tm_min != LastMins) {
					ThisChar = (LCDDateDisplay & 0xF)==LCD_DATE_LINE_1 ? LCD_HOME_1 : LCD_HOME_2;
					sprintf (MyLCDString, "%c%c%.3s, %u %.3s %u", LCD_COMMAND, ThisChar, EnglishDayName[MyTimeDateStruct.tm_wday], MyTimeDateStruct.tm_mday, EnglishMonthName[MyTimeDateStruct.tm_mon], MyTimeDateStruct.tm_year+1900);
					if (MyTimeDateStruct.tm_mday < 10) // Need one more character
						strcat (MyLCDString, " "); // Pad out with a space
					BufferLCDString (MyLCDString);
#ifdef TARGET_RABBIT // structure members are chars
					LastMins = MyTimeDateStruct.tm_min;
#else // structure members are ints
					LastMins = (U8)MyTimeDateStruct.tm_min;
#endif
					}
				}
			}
		}
	}


if (LCDNumCharacters > 0) {
	// We have something still to be displayed
	do {
		if ((getmsectimer () - LastLCDCommandTime) >= LCDCommandWaitTime) {
			// Ok to go ahead again now
			ThisChar = LCDBuffer[LCDStartIndex];
			if (++LCDStartIndex == LCD_BUFFER_LENGTH)
				LCDStartIndex = 0;
			--LCDNumCharacters;
			if (ThisChar == LCD_COMMAND) {
				assert (LCDNumCharacters > 0);
				ThisChar = LCDBuffer[LCDStartIndex];
				if (++LCDStartIndex == LCD_BUFFER_LENGTH)
					LCDStartIndex = 0;
				--LCDNumCharacters;
				LCDCommandByteOut (ThisChar);
				LastLCDCommandTime = getmsectimer();
				// Delay for the correct number of msecs
				switch (ThisChar) {
					case LCD_INIT:
					case LCD_CLS:
					case LCD_HOME:
						LCDCommandWaitTime = 6; // 4.1msec min
						break;
					default: // Actual 40usec would do here
						LCDCommandWaitTime = 2; // Will wait 1 to 2 msec
						break;
					}
				}
			else { // not a command so must be a data byte
				LCDDataByteOut (ThisChar);
				for (ThisChar=0; ThisChar<9; ++ThisChar); // Delay 100 usec (for doubled 7.3MHz crystal)
				}
			}
		else // not time yet -- exit from here and do other things for now instead
			break;
		}
		while (LCDNumCharacters > 0);
	}
}
/* End of UpdateLCD */

/***** End of LCD.c *****/
