

/* Dummy headers for Dynamic C */
/*** Beginheader help_c */
#ifdef TARGET_RABBIT
void help_c();

#asm
xxxhelp_c: equ help_c
#endasm
#endif /* TARGET_RABBIT */
/*** endheader */

#ifdef TARGET_RABBIT
void help_c () { }
#endif /* TARGET_RABBIT */


/*****************************************************
*
*	Name:	Help Module (Help.c)
*	Description: Handles highest level control
*	Author: Robert Hunt
*	Created: September 2001
*
*	Mod. Number: 13
*	Last Modified: 17 November 2001
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
*	Virtually nothing yet
*
*****************************************************/

#include "compat.h"
#include "Brain.h"
#include "speak.h"


/*****************************************************
*
* Function Name: DoModeIRHelp
* Description: Gives help advice for the IR mode button
* Arguments: None
* Return Value: None
*
*****************************************************/

XSINGLESTRING(MHE1) {
	"Press Mode then one of the following:" \
		"Off to enter halt mode," \
		"Auto to enter normal mode," \
		"Manual to enter manual mode," \
		"Straight to go straight home," \
		"Demo to enter show off mode," \
		"Angle to enter explore mode," \
		"Lights to enter chase light mode," \
		"Intensity to enter escape light mode," \
		"Forward to enter chase sound mode," \
		"Reverse to enter escape sound mode," \
		"Speed to enter random mode," \
		"Plus minus to enter special manual mode." \
	"Also use left to switch to English or right to switch to Matigsalug."};

nodebug void DoModeIRHelp (void)
{
xSayEnglish (TRUE, MHE1);
}


/*****************************************************
*
* Function Name: DoQueryIRHelp
* Description: Gives help advice for the IR query button
* Arguments: None
* Return Value: None
*
*****************************************************/

XSINGLESTRING(QHE1) {
	"Query can be pressed before or after many keys to find out the current setting." \
	"Also, you may press Query then one of the following:" \
		"0 to find my version number," \
		"1 to find out the time," \
		"2 to find out the date," \
		"4 to find out the temperature," \
		"or 7 to find which direction I am facing."};

nodebug void DoQueryIRHelp (void)
{
xSayEnglish (TRUE, QHE1);
}
/* End DoQueryIRHelp */


/*****************************************************
*
* Function Name: DoPowerIRHelp
* Description: Gives help advice for the IR power button
* Arguments: None
* Return Value: None
*
*****************************************************/

XSINGLESTRING(PHE1) {
	"Press the power button then one of the following:" \
		"Off to turn me off," \
		"Auto to enable automatic mode," \
		"Manual to disable automatic mode," \
		"Query to find the current setting." \
	"Also for testing, press:" \
		"On to force normal mode," \
		"1 to force low power mode," \
		"0 for a complete system power down."};

nodebug void DoPowerIRHelp (void)
{
xSayEnglish (TRUE, PHE1);
}
/* End DoPowerIRHelp */


/*****************************************************
*
* Function Name: DoLightsIRHelp
* Description: Gives help advice for the IR lights button
* Arguments: None
* Return Value: None
*
*****************************************************/

XSINGLESTRING(LHE1) {
	"Press the lights button then one of the following:" \
		"Off or on to turn the head lights off or on," \
		"0 to turn off all the lights," \
		"Auto to enable automatic mode," \
		"Manual to disable automatic mode," \
		"Demo to demonstrate the lights," \
		"Query to find the current setting."};

nodebug void DoLightsIRHelp (void)
{
xSayEnglish (TRUE, LHE1);
}
/* End DoLightsIRHelp */


/* End of Help.c */