/*** Beginheader */

#ifndef IRControl_H
#define IRControl_H

/*****************************************************
*
*	Name: IR Control
*	Description: Definitions for IR Control
*	Author: Robert Hunt
*	Created: August 2001
*
*	Mod. Number: 1
*	Last Modified: 8 August 2001
*	Modified by: Robert Hunt
*
******************************************************/

/*****************************************************
*
* Public Constants
*
*****************************************************/
#define IR_SOURCE_FRONT        0
#define IR_SOURCE_BACK         1


/*****************************************************
*
* Global variables
*
*****************************************************/



/*****************************************************
*
* Function Prototypes
*
*****************************************************/

void InitIRControl (void); /* First time initialization */
void HandleIRKey (U8 IRKeyValue, U8 IRSource); /* Handles key presses */
void UpdateIRControl (void); /* Checks for timeouts */
void irmode (); /* Handle irmode. */

#endif


/***** End of IRControl.h *****/

/*** endheader */

