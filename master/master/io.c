

/* Dummy headers for Dynamic C */
/*** Beginheader io_c */
#ifdef TARGET_RABBIT
void io_c();

#asm
XXXio_c: equ io_c
#endasm
#endif /* TARGET_RABBIT */
/*** endheader */

#ifdef TARGET_RABBIT
void io_c () { }
#endif /* TARGET_RABBIT */


/*****************************************************
*
*	Name:	IO control Module (IO.c)
*	Description: Updates various JackRabbit IO controls
*	Author: Robert Hunt
*	Created: September 2001
*
*	Mod. Number: 12
*	Last Modified: 27 October 2001
*	Modified by: Robert Hunt
*
*******************************************************
*
* To do yet:
*	Everything
*
*******************************************************
*
* Handles the following:
*	LEDs and buzzer
*
***************************************************************
*
* On the Jackrabbit board:
*
* On the prototyping board:
*	s1-s4		= PBDR 2-5	Switches
*	ds1-ds8	= PADR 0-7	LEds
*	ls1		= PEDR 0	Buzzer
*
* Our additions:
*	LCD Data	= PB0,6,7,3	4-bits of data
*	LCD Enable	= PB6		Falling edge sensitive
*	LCD RS		= PB7		0=Commands, 1=Data
*
***************************************************************
*
* Port-A: All outputs (LEDs DS1..DS8 on prototyping board)
*
* Port-B0-5 are always inputs, Port-B6-7 are always outputs
* Port-B0-1:
* Port-B2-5: Inputs (Switches 1..4 on prototyping board)
* Port-B6: Output LCD EN (Falling edge sensitive)
* Port-B7: Output LCD RS (0=Commands, 1=Data)
*
* Port-C even numbers (0,2,4,6) are always outputs
* Port-C odd numbers (1,3,5,7) are always inputs
* Port-C: Used for serial IO
*
* Port-D bits can be programmed individually to be inputs or outputs
* Port-D0: Output LCD Data 0
* Port-D3: Output LCD Data 3
* Port-D6: Output LCD Data 1
* Port-D7: Output LCD Data 2
*
* Port-E bits can be programmed individually to be inputs or outputs
* Port-E has a higher drive than most of the other ports
* Port-E0: Output for buzzer on prototype board
* Port-E1-7:
*
****************************************************************/

#include <stdio.h>

#include "compat.h"
#include "io.h"
#include "mytime.h"


/*****************************************************
*
* Global Variables
*
*****************************************************/

static BOOL BuzzerIsOn;
static unsigned long BuzzerOnTime, BuzzTime;


/*****************************************************
*
* Function Name: InitIO
* Description: Initialize JackRabbit controls, such as LEDs, buzzer, etc.
* Argument: None
* Return Value: None
*
*****************************************************/

nodebug void InitIO (void)
{
#ifdef TARGET_RABBIT
// Write 0x80 in the slave port control register to make port-A inputs, 0x84 for outputs
WrPortI (SPCR, &SPCRShadow, 0x84);	// Setup parallel port A as outputs for LEDs

// Port-B0-5 are always inputs, Port-B6-7 are always outputs
// No setup is needed here -- the two outputs are set low on reset

// Port-C even numbers (0,2,4,6) are always outputs
// Port-C odd numbers (1,3,5,7) are always inputs
// Port-C Function Register (PCFR) determines whether each bit is IO or used by the serial ports

// Port-D bits can be programmed individually to be inputs or outputs
// We need to ensure that D0,3,6,7 are programmed as outputs for the LCD
WrPortI (PDDDR, &PDDDRShadow, PDDDRShadow | 0xC9); // A 1 makes the pin an output

// Port-E bits can be programmed individually to be inputs or outputs
WrPortI (PEFR, &PEFRShadow, 0);	// Setup parallel port e bit 1..7 inputs, 0 output for buzzer
WrPortI (PEDDR, &PEDDRShadow, 0x01);
WrPortI (PECR, &PECRShadow, 0);

// Write 1's to Port-A Data Register to turn off the LEDs, 0's to turn them on
WrPortI (PADR, &PADRShadow, 0xff);	// Turn off all LEDs
#endif
}
/* End of InitIO */


/*****************************************************
*
* Function Name: LCDNibbleOut
* Description: 
* Argument: None
* Return Value: None
*
* Note: The upper nibble is completely ignored -- it doesn't need to be zeroed
*
* Port-D0: Output LCD Data 0
* Port-D6: Output LCD Data 1
* Port-D7: Output LCD Data 2
* Port-D3: Output LCD Data 3
* Port-B6: Output LCD EN (Falling edge sensitive)
*
*****************************************************/

nodebug root void LCDNibbleOut (U8 Nibble)
{
#ifdef TARGET_RABBIT
// Output the lower nibble of our parameter to various pins on ports B & D
WrPortI (PDDR, &PDDRShadow,
	(PDDRShadow & 0x36) // Clear bits 7,6,3,0
	| (Nibble & 0x09) // Set bits 3,0 to nibble bits 3,0
	| ((Nibble << 5) & 0xC0)); // Set bits 7,6 to nibble bits 2,1

// Need a 250nsec delay here after outputting data before the enable
BitWrPortI (PBDR, &PBDRShadow, 1, 6); // Set the enable (PB6) high
// Need a 450nsec delay  here
BitWrPortI (PBDR, &PBDRShadow, 0, 6); // Set the enable (PB6) low again to latch the data in
// The data stays stable as we return
#else // not TARGET_RABBIT
++Nibble; // Just to get rid of compiler warnings
#endif
}
/* End of LCDNibbleOut */


/*****************************************************
*
* Function Name: LCDCommandByteOut
* Description: 
* Argument: None
* Return Value: None
*
* Note: The MS nibble has to be sent first
*
* Port-B7: Output LCD RS (0=Commands, 1=Data)
*
*****************************************************/

nodebug root void LCDCommandByteOut (U8 CByte)
{
#ifdef TARGET_RABBIT
BitWrPortI (PBDR, &PBDRShadow, 0, 7); // Set RS (PB7) low for commands
LCDNibbleOut (CByte >> 4); // Out MS nibble first
LCDNibbleOut (CByte); // Out LS nibble
#else // not on Rabbit hardware
++CByte; // Just to get rid of compiler warnings
#endif
}
/* End of LCDCommandByteOut */


/*****************************************************
*
* Function Name: LCDDataByteOut
* Description: 
* Argument: None
* Return Value: None
*
* Note: The MS nibble has to be sent first
*
* Port-B7: Output LCD RS (0=Commands, 1=Data)
*
*****************************************************/

nodebug root void LCDDataByteOut (U8 DByte)
{
#ifdef TARGET_RABBIT
BitWrPortI (PBDR, &PBDRShadow, 1, 7); // Set RS (PB7) high for data
LCDNibbleOut (DByte >> 4); // Out MS nibble first
LCDNibbleOut (DByte); // Out LS nibble
#else // not on Rabbit hardware
++DByte; // Just to get rid of compiler warnings
#endif
}
/* End of LCDDataByteOut */


/*****************************************************
*
* Function Name: BuzzerOff
* Description: Turns off the buzzer
* Arguments: None
* Return Value: None
*
*****************************************************/

nodebug void BuzzerOff (void)
{
#ifdef TARGET_RABBIT
BitWrPortI (PEDR, &PEDRShadow, 0, 0);
#else // not on Rabbit hardware
printf (" BuzzerOff ");
#endif
if (! BuzzerIsOn) printf ("BuzzerWasn'tOn");
BuzzerIsOn = FALSE;
}
/* End of BuzzerOff */


/*****************************************************
*
* Function Name: BuzzerOn
* Description: Turns on the buzzer
* Arguments: None
* Return Value: None
*
*****************************************************/

nodebug void BuzzerOn (void)
{
#ifdef TARGET_RABBIT
BitWrPortI (PEDR, &PEDRShadow, 1, 0);
#else // not on Rabbit hardware
printf (" BuzzerOn ");
#endif
//if (BuzzerIsOn) printf (" Warning: Buzzer was already on! ");
BuzzerIsOn = TRUE;
}
/* End of BuzzerOn */


/*****************************************************
*
* Function Name: Buzz
* Description: Turns on the buzzer
* Arguments: Specified number of milliseconds
* Return Value: None
*
*****************************************************/

nodebug void Buzz (unsigned long BBuzzTime)
{
assert (BBuzzTime>0);
BuzzerOn ();
BuzzerOnTime = getmsectimer ();
BuzzTime = BBuzzTime;
}
/* End of Buzz */


/*****************************************************
*
* Function Name: LEDOff
* Description: Turns off the specified LED
* Argument: LED Number DS1..DS8
* Return Value: None
*
*****************************************************/

nodebug void LEDOff (U8 LEDNumber)
{
assert (LEDNumber<=DS8);
#ifdef TARGET_RABBIT
BitWrPortI (PADR, &PADRShadow, 1, LEDNumber);
#else // not on Rabbit hardware
//printf (" LED %u Off ", LEDNumber);
#endif
}
/* End of LEDOff */


/*****************************************************
*
* Function Name: LEDOn
* Description: Turns on the specified LED
* Argument: LED Number DS1..DS8
* Return Value: None
*
*****************************************************/

nodebug void LEDOn (U8 LEDNumber)
{
assert (LEDNumber<=DS8);
#ifdef TARGET_RABBIT
BitWrPortI (PADR, &PADRShadow, 0, LEDNumber);
#else // not on Rabbit hardware
//printf (" LED %u On ", LEDNumber);
#endif
}
/* End of LEDOn */


/*****************************************************
*
* Function Name: LEDToggle
* Description: Toggles the specified LED
* Argument: LED Number DS1..DS8
* Return Value: New State: FALSE=off, TRUE=on
*
*****************************************************/

nodebug BOOL LEDToggle (U8 LEDNumber)
{
#ifdef TARGET_RABBIT
nonauto U8 ThisState;
assert (LEDNumber<=DS8);
ThisState = PADRShadow & (1<<LEDNumber);
BitWrPortI (PADR, &PADRShadow, !ThisState, LEDNumber);
return ThisState; // Remember 1=was OFF so now ON
#else // not on Rabbit hardware
assert (LEDNumber<=DS8);
//printf (" LED %u Toggled ", LEDNumber);
return 1;
#endif
}
/* End of LEDToggle */


/*****************************************************
*
* Function Name: SwitchDown
* Description: Returns the (undebounced) state of the specified switch
* Argument: Switch Number Switch1..Switch4
* Return Value: State: FALSE=up, TRUE=down
*
* Note: Switches return 1 if up, 0 if down
*
*****************************************************/

nodebug BOOL SwitchDown (U8 SwitchNumber)
{
assert (SwitchNumber>=Switch1 && SwitchNumber<=Switch4);

#ifdef TARGET_RABBIT
return (BOOL)!BitRdPortI(PBDR, SwitchNumber);
#else // not on Rabbit hardware
return FALSE;
#endif
}
/* End of SwitchDown */


/*****************************************************
*
* Function Name: UpdateIO
* Description: Updates JackRabbit controls, such as LEDs, buzzer, etc.
* Argument: None
* Return Value: None
*
*****************************************************/

nodebug void UpdateIO (void)
{
// Toggle IO-Running LED every 256 times through
static unsigned int UIOCount;
if ((++UIOCount & 0x0FF) == 0)
	LEDToggle (IORunningLED);

// Turn off buzzer if time is up
if (BuzzerIsOn)
	if ((getmsectimer() - BuzzerOnTime) > BuzzTime)
		BuzzerOff ();
}
/* End of UpdateIO */


/* End of IO.c */
