/*** Beginheader */

#ifndef _CONTROL_H
#define _CONTROL_H

/*****************************************************
*
*	Name:	Control globals (Control.h)
*	Description: Global declarations for "mid-level" control
*	Author: Robert Hunt
*	Created: September 2001
*
*	Mod. Number: 7
*	Last Modified: 11 November 2001
*	Modified by: Robert Hunt
*
*****************************************************/

/*****************************************************
*
* Public Constants
*
*****************************************************/


/*****************************************************
*
* Global variables
*
*****************************************************/

bool PowerControlAuto;
bool LightsControlAuto;
bool AutoOff;

U8 BatteryLevel, ChargingLevel;
float BatteryVoltage, ChargingVoltage;
bool BatteryCharging;


/******************************************************
*
*	Travel control variables
*
******************************************************/

U16 DefaultDistance, MyDistance; /* 0..65535mm */
#define MIN_DISTANCE 5 // mm
#define MAX_DISTANCE 65535 // = 65.535m
#define MAX_DISTANCE_DIGITS 5

U16 DefaultAngle, MyAngle; /* 0..359 degrees */
#define MIN_ANGLE 0
#define MAX_ANGLE 359
#define MAX_ANGLE_DIGITS 3
#define STRAIGHT_AHEAD 0

U8 DefaultSpeed, MySpeed; /* 0..255 */
#define MIN_SPEED 10 /* Don't let it go all the way to zero ??? */
#define MAX_SPEED 255
#define MAX_SPEED_DIGITS 3
#define FULL_SPEED 255

U8 HeadlightIntensity, MyHeadlightIntensity; /* 0..255 */
#define MIN_INTENSITY 10 /* Don't let the lights go right off ??? */
#define MAX_INTENSITY 255
#define MAX_INTENSITY_DIGITS 3
#define FULL_INTENSITY 255


/*****************************************************
*
* Function Prototypes
*
*****************************************************/

void GetMyParameters (void);

BOOL BumperSwitchesOk (U8 WhichSwitches);
#define CHECK_FRONT_BUMPER_SWITCHES 0x01
#define CHECK_REAR_BUMPER_SWITCHES 0x02
#define CHECK_SIDE_BUMPER_SWITCHES 0x04
#define CHECK_ALL_BUMPER_SWITCHES 0x07

BOOL DoGo (void);
BOOL DoReverse (void);
void DoStandbyPowerDown (void);

void SetLightsAuto (bool onauto);
void SetPowerAuto (bool onauto);

void ActionNewBatteryLevel (U8 anblLevel);
void ActionNewChargingLevel (U8 anclLevel);

void ActionSwitchChange (U16 SwitchID, U8 SwitchState);
void ActionStoppedMoving (bool WasGoingForwards, bool CompletedGo);

void InitControls (void);
void UpdateControls (void);

#endif

/* End of Control.h */
/*** endheader */
