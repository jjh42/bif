/*** Beginheader */

#ifndef LCD_H
#define LCD_H

/*****************************************************
*
*	Name: LCD.h
*	Description: Definitions for LCD subsystem
*	Author: Robert Hunt
*	Created: August 2001
*
*	Mod. Number: 7
*	Last Modified: 15 October 2001
*	Modified by: Robert Hunt
*
******************************************************/

#include "brain.h"

/*****************************************************
*
* Public Constants
*
*****************************************************/

#define LCD_COMMAND 0xFF

#define LCD_INIT		0x28 // Initialize in 4-bit mode with 2 display lines
#define LCD_INCREMENT	0x06 // Increment cursor position after writing a character
#define LCD_CLS		0x01 // Clear screen
#define LCD_HOME		0x02 // Home cursor -- 1st line
#define LCD_HOME_1	0x80 // Home cursor -- 1st line -- can add offset to this command
#define LCD_HOME_2	0xC0 // Home cursor -- 2nd line -- can add offset to this command
#define LCD_DISPLAY_OFF	0x08 // Display off, cursor off, blinking off
#define LCD_CURSOR_ON	0x0E // Display on, cursor on, blinking off
#define LCD_CURSOR_OFF	0x0C // Display on, cursor off, blinking off
#define LCD_SHIFT_LEFT	0x18 // Shift display left

#define LCD_NUM_LINES 2
#define LCD_CHARS_PER_LINE 16

#define LCD_ENTIRE_DISPLAY 0
#define LCD_LINE_1 1
#define LCD_LINE_2 2


// Subsystem definitions
#define BRAIN_SUBSYSTEM 1
#define IR_SUBSYSTEM 2
#define NUM_SUBSYSTEMS 2

#define BRAIN_SUBSYSTEM_HOME LCD_HOME_1
#define BRAIN_SUBSYSTEM_LINE LCD_LINE_1
#define BRAIN_SUBSYSTEM_COLUMN 1
#define BRAIN_SUBSYSTEM_NUM_CHARS LCD_CHARS_PER_LINE

#define IR_SUBSYSTEM_HOME LCD_HOME_2
#define IR_SUBSYSTEM_LINE LCD_LINE_2
#define IR_SUBSYSTEM_COLUMN 1
#define IR_SUBSYSTEM_NUM_CHARS LCD_CHARS_PER_LINE


/*****************************************************
*
* Global variables
*
*****************************************************/

U8 LCDTimeDisplay;
#define LCD_TIME_OFF 0
#define LCD_TIME_LINE_1 LCD_LINE_1
#define LCD_TIME_LINE_2 LCD_LINE_2
#define LCD_TIME_OVERRIDE 0x80

U8 LCDDateDisplay;
#define LCD_DATE_OFF 0
#define LCD_DATE_LINE_1 LCD_LINE_1
#define LCD_DATE_LINE_2 LCD_LINE_2
#define LCD_DATE_OVERRIDE 0x80

// msec timers
TIME LCDLastUpdateTime[NUM_SUBSYSTEMS+1]; // 0 is global, subsystems start at 1
#define LCD_PERSISTENCE_TIME 3000 // msecs

U8 LCDNumCharacters; // 0 is LCD system is idle


/*****************************************************
*
* Function Prototypes
*
*****************************************************/

void InitLCD (void); /* First time initialization */
void BufferLCDString (constparam U8 *TheString);
void LCDClear (U8 ClearWhat);
void LCDDateOff (BOOL DoClear);
void LCDTimeOff (BOOL DoClear);
void LCDDisplay (U8 SubsystemID, constparam char *DisplayString, BOOL BlankFill);
void UpdateLCD (void); /* Checks for timeouts */

#endif


/***** End of LCD.h *****/

/*** endheader */

