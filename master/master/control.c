

/* Dummy headers for Dynamic C */
/*** Beginheader control_c */
#ifdef TARGET_RABBIT
void control_c();

#asm
XXXcontrol_c: equ control_c
#endasm
#endif /* TARGET_RABBIT */
/*** endheader */

#ifdef TARGET_RABBIT
void control_c () { }
#endif /* TARGET_RABBIT */


/*****************************************************
*
*	Name:	Control Module (Control.c)
*	Description: Updates various "mid-level" controls
*	Author: Robert Hunt
*	Created: September 2001
*
*	Mod. Number: 18
*	Last Modified: 11 November 2001
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
*	Battery levels and charging voltages
*
*****************************************************/

#include <stdio.h>

#include "compat.h"
#include "control.h"
#include "speak.h"
#include "Brain.h"
#include "slave-base.h"
#include "slave-ir.h"
#include "commonsubs.h"
#include "mytime.h"


/*****************************************************
*
* Global Variables
*
*****************************************************/

#define BATTERY_NORMAL_LEVEL 195 // 12V level used for startup

#define LOW_LIGHT_THRESHOLD 160
#define HIGH_LIGHT_THRESHOLD 180

// Note: Adjustments here will have to be made twice
//*****

#ifdef TARGET_WIN32
#define BATTERY_CALIBRATION_FACTOR 16.2F
#define CHARGING_CALIBRATION_FACTOR 16.2F

#define NOT_CHARGING_THRESHOLD 2.0F // to handle AC
#define CHARGING_THRESHOLD 12.1F

#define LOW_POWER_THRESHOLD 11.5F
#define FULL_POWER_THRESHOLD 12.3F

#else // not TARGET_WIN32

#define BATTERY_CALIBRATION_FACTOR 16.2
#define CHARGING_CALIBRATION_FACTOR 16.2

#define NOT_CHARGING_THRESHOLD 2.0 // to handle AC
#define CHARGING_THRESHOLD 12.1

#define LOW_POWER_THRESHOLD 11.5
#define FULL_POWER_THRESHOLD 12.3
#endif


/*****************************************************
*
* Function Name: GetMyParameters
* Description: Gets "my parameters" from the default parameters
*			depending on "naughtiness" if in "rebel" mode
* Arguments: None
* Return Value: None
*
*****************************************************/

void GetMyParameters (void)
{
long Variance, TempResult;

// Copy defaults
MyDistance = DefaultDistance;
MyAngle = DefaultAngle;
MySpeed = DefaultSpeed;
MyHeadlightIntensity = HeadlightIntensity;

if (BrainMode == BRAIN_M_REBEL)
	{ // We might be a bit naughty here
	if (rndrange (1, 10) < Naughtiness)
		{ // Mess with the distance
		Variance = (long)DefaultDistance * (long)Naughtiness / (long)rndrange (10,500);
		if (rnd100() > 50) Variance = -Variance;
		TempResult = (long)DefaultDistance + Variance;
		if (TempResult < MIN_DISTANCE) TempResult = MIN_DISTANCE;
		if (TempResult > MAX_DISTANCE) TempResult = MAX_DISTANCE;
		MyDistance = (U16)TempResult;
		//printf ("Nau=%u, DDis=%u, Var=%ld, MyDis=%u\n", Naughtiness, DefaultDistance, Variance, MyDistance);
		}

	if (rndrange (1, 10) < Naughtiness)
		{ // Mess with the angle
		Variance = 360 * (long)Naughtiness / (long)rndrange (10,500);
		if (rnd100() > 50) Variance = -Variance;
		TempResult = (long)DefaultAngle + Variance;
		if (TempResult < MIN_ANGLE) TempResult = MIN_ANGLE;
		if (TempResult > MAX_ANGLE) TempResult = MAX_ANGLE;
		MyAngle = (U16)TempResult;
		//printf ("Nau=%u, DAng=%u, Var=%ld, MyAng=%u\n", Naughtiness, DefaultAngle, Variance, MyAngle);
		}

	if (rndrange (1, 10) < Naughtiness)
		{ // Mess with the speed
		Variance = (long)DefaultSpeed * (long)Naughtiness / (long)rndrange (10,500);
		if (rnd100() > 50) Variance = -Variance;
		TempResult = (long)DefaultSpeed + Variance;
		if (TempResult < MIN_SPEED) TempResult = MIN_SPEED;
		if (TempResult > MAX_SPEED) TempResult = MAX_SPEED;
		MySpeed = (U8)TempResult;
		//printf ("Nau=%u, DSp=%u, Var=%ld, MySp=%u\n", Naughtiness, DefaultSpeed, Variance, MySpeed);
		}
	}
}
/* End of GetMyParameters */


/*****************************************************
*
* Function Name: BumperSwitchesOk
* Description: Checks and tells if a bumper switch is down (before moving)
* Arguments: Which Switches FRONT/REAR/SIDE/ALL_BUMPER_SWITCHES
* Return Value:  Returns TRUE if no bumper switches down
*
*****************************************************/

BOOL BumperSwitchesOk (U8 WhichSwitches)
{
//printf (" Check bumper switches ");
// Need to check here that the bumper switches aren't already hitting
if (WhichSwitches & CHECK_FRONT_BUMPER_SWITCHES)
	if (!isbase_switchdown ((U16)(getbase_front() ? FRONT_BUMPER_SWITCHES : REAR_BUMPER_SWITCHES))) {
		if (Verbosity == VERBOSITY_TALKATIVE)
			SayEnglishText (FALSE, "Front bumper switch on");
		return FALSE;
		}
if (WhichSwitches & CHECK_REAR_BUMPER_SWITCHES)
	if (!isbase_switchdown ((U16)(getbase_front() ? REAR_BUMPER_SWITCHES : FRONT_BUMPER_SWITCHES))) {
		if (Verbosity == VERBOSITY_TALKATIVE)
			SayEnglishText (FALSE, "Rear bumper switch on");
		return FALSE;
		}
if (WhichSwitches & CHECK_SIDE_BUMPER_SWITCHES)
	if (!isbase_switchdown (SIDE_BUMPER_SWITCHES)) {
		if (Verbosity == VERBOSITY_TALKATIVE)
			SayEnglishText (FALSE, "Side bumper switch on");
		return FALSE;
		}

// Assume all ok
printf (" Bumper switches OK ");
return TRUE;
}
/* End of BumperSwitchesOk */


/*****************************************************
*
* Function Name: DoGo
* Description: Sends a go message to the base
* Arguments: None
* Uses: DefaultSpeed, DefaultAngle, DefaultDistance (Updates "my" parameters)
* Return Value: Success flag
*
*****************************************************/

BOOL DoGo (void)
{
if (! BumperSwitchesOk (CHECK_FRONT_BUMPER_SWITCHES))
	return FALSE;

GetMyParameters ();
if (Verbosity == VERBOSITY_TALKATIVE)
	switch (CurrentOutputLanguage) {
#ifdef INCLUDE_MATIGSALUG
		case MATIGSALUG:
			sprintf (MakeupSpeakString, "Egpabulus kag gipanew.");
			SayMakeupSpeakString (TRUE);
			break;
#endif
		default: // default to English
			if (MyAngle == 0)
				sprintf (MakeupSpeakString, "Going forward %u millimeters at speed %u.", MyDistance, MySpeed);
			else
				sprintf (MakeupSpeakString, "Turning %u degree%s then going forward %u millimeters at speed %u.", MyAngle, MyAngle==1?"":"s", MyDistance, MySpeed);
			SayMakeupSpeakString (TRUE);
			break;
		}
sendbase_gomsg (MySpeed, MyAngle, MyDistance);
return TRUE;
}
/* End of DoGo */


/*****************************************************
*
* Function Name: DoReverse
* Description: Sends a reverse message to the base
* Arguments: None
* Uses: DefaultSpeed, DefaultDistance (Updates "my" parameters)
* Return Value: Success flag
*
*****************************************************/

BOOL DoReverse (void)
{
if (! BumperSwitchesOk (CHECK_REAR_BUMPER_SWITCHES))
	return FALSE;

GetMyParameters ();
if (Verbosity == VERBOSITY_TALKATIVE)
	switch (CurrentOutputLanguage) {
#ifdef INCLUDE_MATIGSALUG
		case MATIGSALUG:
			sprintf (MakeupSpeakString, "Eg-isuos e kag gipanew.");
			SayMakeupSpeakString (TRUE);
			break;
#endif
		default: // default to English
			sprintf (MakeupSpeakString, "Reversing %u millimeters at speed %u.", MyDistance, MySpeed);
			SayMakeupSpeakString (TRUE);
			break;
		}
sendbase_reversemsg (MySpeed, MyDistance);
return TRUE;
}
/* End of DoReverse */


/*****************************************************
*
* Function Name: DoStandbyPowerDown
* Description: Puts me into standby mode (Can be woken by IR keypress)
* Argument: None
* Return Value: None
*
*****************************************************/

void DoStandbyPowerDown (void)
{
switch (CurrentOutputLanguage) {
#ifdef INCLUDE_MATIGSALUG
	case MATIGSALUG:
		SayMatigsalugText (FALSE, "Egpatey a kuntee."); break;
#endif
	default: // default to English
		SayEnglishText (FALSE, "I'm powering myself off now."); break;
	}
SetPowerAuto (FALSE);
setbase_power(BASE_POWER_OFF);
sendir_standbymsg ();
}
/* End of DoStandbyPowerDown */


/*****************************************************
*
* Function Name: UpdateLightsControl
* Description: Updates lights control
* Argument: None
* Return Value: True if something changed
*
*****************************************************/

static BOOL UpdateLightsControl (void)
{
U8 LightLevel; // temp
BOOL LCChanged;
LCChanged = FALSE;

// temp
//LightLevel = (U8)rndrange (150, 255);
LightLevel = 255; // .... temp xxxxxxxxxx Assume it's always bright
if (LightsControlAuto)
	{
	if ((getbase_lights()!=BASE_LIGHTS_NORMAL) && LightLevel > HIGH_LIGHT_THRESHOLD)
		{ // It's just got bright out there
		LCChanged = TRUE;
		setbase_lights (BASE_LIGHTS_NORMAL);
		if (Verbosity == VERBOSITY_TALKATIVE)
			switch (CurrentOutputLanguage) {
#ifdef INCLUDE_MATIGSALUG
				case MATIGSALUG:
					SayMatigsalugText (FALSE, "Eg-ebukan ka sulu su malayag e.");
					break;
#endif
				default: // default to English
					SayEnglishText (FALSE, "Getting bright so switched off headlight.");
					break;
				}
		}
	else if ((getbase_lights()!=BASE_LIGHTS_FULL) && LightLevel < LOW_LIGHT_THRESHOLD)
		{ // The ambient light's just gone bad
		setbase_lights (BASE_LIGHTS_FULL);
		LCChanged = TRUE;
		if (Verbosity == VERBOSITY_TALKATIVE)
			switch (CurrentOutputLanguage) {
#ifdef INCLUDE_MATIGSALUG
				case MATIGSALUG:
					SayMatigsalugText (FALSE, "Egpasiha te sulu su marukilem e kuntee.");
					break;
#endif
				default: // default to English
					SayEnglishText (FALSE, "Getting dark so switched on headlight.");
					break;
				}
		}
	}
return LCChanged;
}
/* End of UpdateLightsControl */


/*****************************************************
*
* Function Name: UpdatePowerControl
* Description: Updates power control
* Argument: None
* Return Value: True if something changed
*
*****************************************************/

static BOOL UpdatePowerControl (void)
{
BOOL PCChanged;
PCChanged = FALSE;
if (PowerControlAuto)
	{
	if ((getbase_power()!=BASE_POWER_NORMAL) && BatteryVoltage > FULL_POWER_THRESHOLD)
		{ // The power's just got good
		setbase_power (BASE_POWER_NORMAL);
		PCChanged = TRUE;
		switch (CurrentOutputLanguage) {
#ifdef INCLUDE_MATIGSALUG
			case MATIGSALUG:
				SayMatigsalugText (FALSE, "Eleg e ka kuriyinti.");
				break;
#endif
			default: // default to English
				SayEnglishText (FALSE, "Power returned to normal.");
				break;
			}
		}
	else if ((getbase_power()!=BASE_POWER_LOW) && BatteryVoltage < LOW_POWER_THRESHOLD)
		{ // The power's just gone bad
		setbase_power (BASE_POWER_LOW);
		PCChanged = TRUE;
		switch (CurrentOutputLanguage) {
#ifdef INCLUDE_MATIGSALUG
			case MATIGSALUG:
				SayMatigsalugText (FALSE, "Kulang e ka kuriyinti te batiriya.");
				break;
#endif
			default: // default to English
				SayEnglishText (FALSE, "Battery power low.");
				break;
			}
		}
	}
return PCChanged;
}
/* End of UpdatePowerControl */


/*****************************************************
*
* Function Name: SetLightsAuto
* Description: Sets the light control to AUTO or MANUAL
* Argument: FALSE=Manual, TRUE=Auto
* Return Value: None
*
*****************************************************/

void SetLightsAuto (bool onauto)
{
LightsControlAuto = onauto;
if (LightsControlAuto)
	UpdateLightsControl ();
}
/* End of SetLightsAuto */


/*****************************************************
*
* Function Name: SetPowerAuto
* Description: Sets the power control to AUTO or MANUAL
* Argument: FALSE=Manual, TRUE=Auto
* Return Value: None
*
*****************************************************/

void SetPowerAuto (bool onauto)
{
PowerControlAuto = onauto;
if (PowerControlAuto)
	UpdatePowerControl ();
}
/* End of SetPowerAuto */


/*****************************************************
*
* Function Name: InitControls
* Description: Initialize "mid-level" controls, such as lights, power, etc.
* Argument: None
* Return Value: None
*
*****************************************************/

void InitControls (void)
{
SetPowerAuto (TRUE);
SetLightsAuto (TRUE);
AutoOff = TRUE;

ActionNewBatteryLevel (BATTERY_NORMAL_LEVEL); // start by assuming it's normal
BatteryCharging = FALSE;
ActionNewChargingLevel (1); // assume not charging

setbase_power (BASE_POWER_NORMAL);

/* Do any updates now */
UpdateControls ();
}
/* End of InitControls */


/*****************************************************
*
* Function Name: ActionNewBatteryLevel
* Description: Accepts and actions a new battery level reading
* Argument: New battery level reading
* Return Value: None
*
*****************************************************/

void ActionNewBatteryLevel (U8 anblLevel)
{
//printf (" ActionNwBattLvl ");

// Check if the battery level has changed
if (anblLevel != BatteryLevel)
	{
	BatteryVoltage = (float)anblLevel / BATTERY_CALIBRATION_FACTOR;
	BatteryLevel = anblLevel;
#if 0
	printf ("Temp Code: Battery level is %.1f volts.", BatteryVoltage);
	//sprintf (MakeupSpeakString, "Temp Code Battery level is %u or %.1f volts.", BatteryLevel, BatteryVoltage);
	//SayMakeupSpeakString (TRUE);
#endif
	if (UpdatePowerControl () && DiagnosticMode) {
		switch (CurrentOutputLanguage) {
#ifdef INCLUDE_MATIGSALUG
			case MATIGSALUG:
				sprintf (MakeupSpeakString, "%.1f vult ka batiriya.", BatteryVoltage);
				SayMakeupSpeakString (FALSE);
				break;
#endif
			default: // default to English
				sprintf (MakeupSpeakString, "Battery level is %.1f volts.", BatteryVoltage);
				SayMakeupSpeakString (FALSE);
				break;
			}
		}
	}
}
/* End of ActionNewBatteryLevel */


/*****************************************************
*
* Function Name: ActionNewChargingLevel
* Description: Accepts and actions a new charging level reading
* Argument: New charging level reading
* Return Value: None
*
*****************************************************/

void ActionNewChargingLevel (U8 anclLevel)
{
float LastChargingVoltage;
	
//printf (" ActionNwChrgLvl ");

// Check if the charging level has changed
if (anclLevel != ChargingLevel)
	{
	LastChargingVoltage = ChargingVoltage;
	ChargingVoltage = (float)anclLevel / CHARGING_CALIBRATION_FACTOR;
	ChargingLevel = anclLevel;
	if (LastChargingVoltage < NOT_CHARGING_THRESHOLD && ChargingVoltage >= CHARGING_THRESHOLD)
		{ // Just started charging
		BatteryCharging = TRUE;
		switch (CurrentOutputLanguage) {
#ifdef INCLUDE_MATIGSALUG
			case MATIGSALUG:
				SayMatigsalugText (FALSE, "Egkatahuan e te kuriyinti ka batiriya.");
				break;
#endif
			default: // default to English
				SayEnglishText (FALSE, "Battery now charging.");
				break;
			}
		if (DiagnosticMode)
			switch (CurrentOutputLanguage) {
#ifdef INCLUDE_MATIGSALUG
				case MATIGSALUG:
					sprintf (MakeupSpeakString, "%.1f ka kuriyinti.", ChargingVoltage);
					SayMakeupSpeakString (FALSE);
					break;
#endif
				default: // default to English
					sprintf (MakeupSpeakString, "Charging level is %.1f volts.", ChargingVoltage);
					SayMakeupSpeakString (FALSE);
					break;
				}
		}
	else if (LastChargingVoltage >= CHARGING_THRESHOLD && ChargingVoltage < NOT_CHARGING_THRESHOLD)
		{ // Just finished charging
		BatteryCharging = FALSE;
		switch (CurrentOutputLanguage) {
#ifdef INCLUDE_MATIGSALUG
			case MATIGSALUG:
				SayMatigsalugText (FALSE, "Kenad egkatahuan te kuriyinti ka batiriya.");
				break;
#endif
			default: // default to English
				SayEnglishText (FALSE, "Disconnected from charger.");
				break;
			}
		}
	}
}
/* End of ActionNewChargingLevel */


/*****************************************************
*
* Function Name: Action Switch Change
* Description: Handles a bumper or tilt switch change
* Arguments: Switch ID and new state
* Return Value: None
*
* Note: if isbase_switchdown() is called from here,
*		it won't give the latest settings
*
*****************************************************/

void ActionSwitchChange (U16 SwitchID, U8 SwitchState)
{
printf (" ActionSwitchChange ");
if (Verbosity == VERBOSITY_TALKATIVE)
	SayEnglishText (FALSE, "Action Switch Down");
assert (SwitchState==SWITCH_DOWN || SwitchState==SWITCH_UP);

// Check which is the default front before talking
if (!getbase_front()) // We're backwards so reverse states before talking
	switch (SwitchID) {
		case LEFT_FRONT_BUMPER_SWITCH: SwitchID = RIGHT_REAR_BUMPER_SWITCH; break;
		case RIGHT_FRONT_BUMPER_SWITCH: SwitchID = LEFT_REAR_BUMPER_SWITCH; break;
		case LEFT_REAR_BUMPER_SWITCH: SwitchID = RIGHT_FRONT_BUMPER_SWITCH; break;
		case RIGHT_REAR_BUMPER_SWITCH: SwitchID = LEFT_FRONT_BUMPER_SWITCH; break;
		case LEFT_SIDE_BUMPER_SWITCH: SwitchID = RIGHT_SIDE_BUMPER_SWITCH; break;
		case RIGHT_SIDE_BUMPER_SWITCH: SwitchID = LEFT_SIDE_BUMPER_SWITCH; break;
		case FRONT_TILT_SWITCH: SwitchID = BACK_TILT_SWITCH; break;
		case BACK_TILT_SWITCH: SwitchID = FRONT_TILT_SWITCH; break;
		case LEFT_TILT_SWITCH: SwitchID = RIGHT_TILT_SWITCH; break;
		case RIGHT_TILT_SWITCH: SwitchID = LEFT_TILT_SWITCH; break;
		}

if (SwitchState == SWITCH_DOWN)
	{
	if (SwitchID>=LOWEST_BUMPER_SWITCH && SwitchID<=HIGHEST_BUMPER_SWITCH)
		switch (CurrentOutputLanguage) {
#ifdef INCLUDE_MATIGSALUG
			case MATIGSALUG:
				SayMatigsalugText (TRUE, "Etuwey!");
				if (DiagnosticMode) {
					sprintf (MakeupSpeakString, "Nakabangga ka %s.", GetSwitchName(SwitchID));
					SayMakeupSpeakString (FALSE);
					}
				break;
#endif
			default: // default to English
				SayEnglishText (TRUE, "Ouch!");
				if (DiagnosticMode) {
					sprintf (MakeupSpeakString, "Hit on %s.", GetSwitchName(SwitchID));
					SayMakeupSpeakString (FALSE);
					}
				break;
			}
	else if (SwitchID>=LOWEST_TILT_SWITCH && SwitchID<=HIGHEST_TILT_SWITCH)
		switch (CurrentOutputLanguage) {
#ifdef INCLUDE_MATIGSALUG
			case MATIGSALUG:
				SayMatigsalugText (TRUE, "Etuwey!");
				if (DiagnosticMode) {
					sprintf (MakeupSpeakString, "Due prublima diyet %s.", GetSwitchName(SwitchID));
					SayMakeupSpeakString (FALSE);
					}
				break;
#endif
			default: // default to English
				SayEnglishText (TRUE, "Help!");
				if (DiagnosticMode) {
					sprintf (MakeupSpeakString, "%s is sinking.", GetSwitchName(SwitchID));
					SayMakeupSpeakString (FALSE);
					}
				break;
			}
	}
else // must be up
	{
	assert (SwitchState==SWITCH_UP);
	if (SwitchID>=LOWEST_BUMPER_SWITCH && SwitchID<=HIGHEST_BUMPER_SWITCH)
		switch (CurrentOutputLanguage) {
#ifdef INCLUDE_MATIGSALUG
			case MATIGSALUG:
				SayMatigsalugText (TRUE, "Meupiya!");
				if (DiagnosticMode) {
					sprintf (MakeupSpeakString, "Inlekaan e ka %s.", GetSwitchName(SwitchID));
					SayMakeupSpeakString (FALSE);
					}
				break;
#endif
			default: // default to English
				SayEnglishText (TRUE, "Good!");
				if (DiagnosticMode) {
					sprintf (MakeupSpeakString, "%s released.", GetSwitchName(SwitchID));
					SayMakeupSpeakString (FALSE);
					}
				break;
			}
	else if (SwitchID>=LOWEST_TILT_SWITCH && SwitchID<=HIGHEST_TILT_SWITCH)
		switch (CurrentOutputLanguage) {
#ifdef INCLUDE_MATIGSALUG
			case MATIGSALUG:
				SayMatigsalugText (TRUE, "Meupiya!");
				if (DiagnosticMode) {
					sprintf (MakeupSpeakString, "Warad prublima te %s.", GetSwitchName(SwitchID));
					SayMakeupSpeakString (FALSE);
					}
				break;
#endif
			default: // default to English
				SayEnglishText (TRUE, "Phew!");
				if (DiagnosticMode) {
					sprintf (MakeupSpeakString, "%s back to normal.", GetSwitchName(SwitchID));
					SayMakeupSpeakString (FALSE);
					}
				break;
			}
	}
}
/* End of ActionSwitchChange */


/*****************************************************
*
* Function Name: Action Stopped Moving
* Description: Handles a movement stopped message from the base
* Arguments: ???
* Return Value: None
*
*****************************************************/

void ActionStoppedMoving (bool WasGoingForwards, bool CompletedGo)
{
#ifdef TARGET_WIN32
++WasGoingForwards; // Just to get rid of compiler warning
#endif

if (CompletedGo) // stopped because completed (not because of a switch activating)
	switch (CurrentOutputLanguage) {
#ifdef INCLUDE_MATIGSALUG
		case MATIGSALUG:
			SayMatigsalugText (FALSE, "Neimpusan e.");
			break;
#endif
		default: // default to English
			SayEnglishText (FALSE, "Command completed.");
			break;
		}
}
/* End of ActionStoppedMoving */


/*****************************************************
*
* Function Name: UpdateControls
* Description: Updates "mid-level" controls, such as lights, power, etc.
* Argument: None
* Return Value: None
*
*****************************************************/

root void UpdateControls (void)
{
}
/* End of UpdateControls */


/* End of Control.c */
