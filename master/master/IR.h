/*** Beginheader */

#ifndef IR_H
#define IR_H

/*****************************************************
*
*	Name: InfraRed (IR.H)
*	Description: Definitions for InfraRed sensor
*	Author: Robert Hunt
*	Created: November 2000
*
*	Mod. Number: 10
*	Last Updated: 11 November 2001
*	Updated by: Robert Hunt
*
******************************************************/

/*****************************************************
*
* Public Constants
*
*****************************************************/

/* Infrared remote buttons by row and column starting from top-left */
/* Note: These are adjusted to be contiguous */
#define IR_R1_C1 32	//77
#define IR_R1_C2 38	//86
#define IR_R1_C3 34	//79
#define IR_R1_C4 16	//70
#define IR_R2_C1 33	//78
#define IR_R2_C2 35	//80
#define IR_R2_C3 37	//85
#define IR_R2_C4 36	//81
#define IR_R3_C1 1
#define IR_R3_C2 2
#define IR_R3_C3 3
#define IR_R3_C4 29
#define IR_R4_C1 4
#define IR_R4_C2 5
#define IR_R4_C3 6
#define IR_R5_C1 7
#define IR_R5_C2 8
#define IR_R5_C3 9
#define IR_R5_C4 12
#define IR_R6_C1 10
#define IR_R6_C2 0
#define IR_R6_C3 11
#define IR_R6_C4 13
#define IR_R7_C1 23
#define IR_R7_C2 22
#define IR_R7_C3 19
#define IR_R7_C4 18
#define IR_R8_C1 27
#define IR_R8_C2 26
#define IR_R8_C3 21
#define IR_R8_C4 20
#define IR_R9_C1 31
#define IR_R9_C2 30
#define IR_R9_C3 25
#define IR_R9_C4 24
#define IR_R10_C1 15
#define IR_R10_C2 14
#define IR_R10_C3 17
#define IR_R10_C4 28

#define NUM_IR_BUTTONS 39

/* Infrared remote buttons by original function name */
#define IR_0 IR_R6_C2
#define IR_1 IR_R3_C1
#define IR_2 IR_R3_C2
#define IR_3 IR_R3_C3
#define IR_4 IR_R4_C1
#define IR_5 IR_R4_C2
#define IR_6 IR_R4_C3
#define IR_7 IR_R5_C1
#define IR_8 IR_R5_C2
#define IR_9 IR_R5_C3

//#define IR_1MINUS IR_R6_C1
//#define IR_2MINUS IR_R6_C2

//#define IR_ALT IR_R3_C4
#define IR_UP IR_R5_C4
#define IR_DOWN IR_R6_C4

//#define IR_VOLUME_DOWN IR_R7_C1
//#define IR_VOLUME_UP IR_R7_C2
//#define IR_CHANNEL_DOWN IR_R7_C3
//#define IR_CHANNEL_UP IR_R7_C4
//#define IR_BRIGHTNESS_DOWN IR_R9_C1
//#define IR_BRIGHTNESS_UP IR_R9_C2
//#define IR_CONTRAST_DOWN IR_R10_C1
//#define IR_CONTRAST_UP IR_R10_C2
//#define IR_MUTE IR_R8_C3
//#define IR_TV_VIDEO IR_R8_C4
//#define IR_TRACKING IR_R10_C3
//#define IR_POWER IR_R10_C4


/* Infrared remote buttons by our robot function name */
#define IR_R_FORWARD IR_R1_C1
#define IR_R_STRAIGHT IR_R1_C2
#define IR_R_SPEED IR_R1_C3
#define IR_R_LIGHTS IR_R1_C4
#define IR_R_REVERSE IR_R2_C1
#define IR_R_ANGLE IR_R2_C2
#define IR_R_STEALTH IR_R2_C3
#define IR_R_INTENSITY IR_R2_C4
#define IR_R_ENTER IR_R3_C4
#define IR_R_CLEAR IR_R6_C1
#define IR_R_PLUS_MINUS IR_R6_C3
#define IR_R_LEFT IR_R7_C1
#define IR_R_RIGHT IR_R7_C2
#define IR_R_OFF IR_R7_C3
#define IR_R_ON IR_R7_C4
#define IR_R_QUERY IR_R8_C1
#define IR_R_DEMO IR_R8_C2
#define IR_R_MANUAL IR_R8_C3
#define IR_R_AUTO IR_R8_C4
#define IR_R_DIAGNOSTICS IR_R9_C1
#define IR_R_SPECIAL IR_R9_C2
//#define IR_R_AUTOSTOP IR_R9_C2
//#define IR_R_TRAVEL_MODE IR_R9_C3
//#define IR_R_FRONT_BACK_MODE IR_R9_C4
#define IR_R_HELP IR_R10_C1
#define IR_R_MODE IR_R10_C2
#define IR_R_POWER IR_R10_C3
#define IR_R_HALT IR_R10_C4


/*****************************************************
*
* Other definitions
*
*****************************************************/

#define IR_ERROR 0xFE
#define IR_REPEAT 0xFF

#endif


/***** End of IR.h *****/

/*** endheader */

