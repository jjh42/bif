/*** Beginheader */

#ifndef _IO_H
#define IO_H

/*****************************************************
*
*	Name:	IO control globals (IO.h)
*	Description: Global declarations for JackRabbit IO control
*	Author: Robert Hunt
*	Created: September 2001
*
*	Mod. Number: 3
*	Last Modified: 5 October 2001
*	Modified by: Robert Hunt
*
*****************************************************/

/*****************************************************
*
* Public Constants
*
*****************************************************/

/***************************************************************
  predefines for the leds and switches
  
   On the Jackrabbit board:
	   s1-s4   = PBDR 2-5	switches
	   ds1-ds8 = PADR 0-7	leds
	   ls1	  = PEDR 0		buzzer

****************************************************************/

// LEDs
#define DS1 0
#define DS2 1
#define DS3 2
#define DS4 3
#define DS5 4
#define DS6 5
#define DS7 6
#define DS8 7

#define SlaveLED0 DS1 // thru to DS5
#define IRStatusLED DS6
#define IRKeyLED DS7
#define IORunningLED DS8

// Switches
#define Switch1	2
#define Switch2	3
#define Switch3	4
#define Switch4	5


/*****************************************************
*
* Function Prototypes
*
*****************************************************/

extern void InitIO (void);
extern void UpdateIO (void);

void LCDNibbleOut (U8 Nibble);
void LCDCommandByteOut (U8 Byte);
void LCDDataByteOut (U8 Byte);

void BuzzerOff (void);
void BuzzerOn (void);

void LEDOff (U8 LedNumber);
void LEDOn (U8 LedNumber);
BOOL LEDToggle (U8 LedNumber);

BOOL SwitchDown (U8 SwitchNumber);

void Buzz (unsigned long BuzzTime);

#endif

/* End of IO.h */
/*** endheader */

