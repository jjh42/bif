

/* Dummy headers for Dynamic C */
/*** Beginheader tell_c */
#ifdef TARGET_RABBIT
void tell_c();

#asm
xxxtell_c: equ tell_c
#endasm
#endif /* TARGET_RABBIT */
/*** endheader */

#ifdef TARGET_RABBIT
void tell_c () { }
#endif /* TARGET_RABBIT */


/*****************************************************
*
*	Name:	Brain Tell Module (Tell.c)
*	Description: Tells various internal parameters to the human
*	Author: Robert Hunt
*	Created: August 2001
*
*	Mod. Number: 18
*	Last Modified: 14 October 2001
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

#include <stdio.h>

#include "compat.h"
#include "control.h"
#include "speak.h"
#include "slavecomms.h"
#include "slave-base.h"
#include "Brain.h"
#include "master.h"
#include "commonsubs.h"
#include "mytime.h"


/*****************************************************
*
* Function Name: Greet
* Description: Give a time dependent greeting
* Argument: None
* Return Value: None
*
*****************************************************/

XSINGLESTRING (GSM1) {"Meupiya red. Sikeddi si rubut."};
XSINGLESTRING (GSE1) {"Hello. I am robot."};

void Greet (void)
{
switch (CurrentOutputLanguage)
	{
	case MATIGSALUG:
		xSay (FALSE, GSM1); break;
	default: // default to English
		xSay (FALSE, GSE1); break;
	}
}
/* End of Greet */


/*****************************************************
*
* Function Name: Tell Version
* Description: Tells the version number (and that of the slaves if in diagnostic mode)
* Argument: None
* Return Value: None
*
*****************************************************/

void TellVersion (void)
{
U8 tv;
constparam char *SlaveName;
U16 SlaveVersion;

//switch (CurrentOutputLanguage) {
//	case MATIGSALUG:
//		sprintf (MakeupSpeakString, "%s ka numiru ku.", MASTER_VERSION_STRING);
//		SayMakeupSpeakString (TRUE);
//		break;
//	default: // default to English
		sprintf (MakeupSpeakString, "My version number is %s.", MASTER_VERSION_STRING);
//		SayMakeupSpeakString (TRUE);
SayEnglishMakeupSpeakString (TRUE);
//		break;
//	}
if (DiagnosticMode) { // tell the slave version numbers also
//	switch (CurrentOutputLanguage) {
//		case MATIGSALUG:
//			SayMatigsalugText (FALSE, "Seini ka me numiru te me uripen:"); break;
//		default: // default to English
			SayEnglishText (FALSE, "The slave version numbers are:");
//			break;
//		}
	for (tv=0; tv<NUM_SLAVES; ++tv) {
#ifdef TARGET_WIN32	
		SlaveName = "temporary"; // temp ....... xxxxxxxxx
		assert (SlaveName!=NULL);
		SlaveVersion = 0x1234;
#else
		SlaveName = slaveconst_table[tv].name;
		assert (SlaveName!=NULL);
		SlaveVersion = slavedynamic_table[tv].version;
#endif
		if (SlaveVersion==0) // no response from slave yet
//			switch (CurrentOutputLanguage)
				{
//				case MATIGSALUG:
//					sprintf (MakeupSpeakString, "Ware nakatabak ka %s uripen,", SlaveName);
//					SayMakeupSpeakString (FALSE);
//					break;
//				default: // default to English
					sprintf (MakeupSpeakString, "The %s slave hasn't responded yet,", SlaveName);
//					SayMakeupSpeakString (FALSE);
SayEnglishMakeupSpeakString (TRUE);
//					break;
				}
		else // have a valid version number
//			switch (CurrentOutputLanguage)
				{
//				case MATIGSALUG:
//					sprintf (MakeupSpeakString, "%u.%u.%u.%u te %s uripen,", SlaveVersion>>12, SlaveVersion>>8 & 0xF, SlaveVersion>>4 & 0xF, SlaveVersion & 0xF, SlaveName);
//					SayMakeupSpeakString (FALSE);
//					break;
//				default: // default to English
					sprintf (MakeupSpeakString, "%s slave %u.%u.%u.%u,", SlaveName, SlaveVersion>>12, SlaveVersion>>8 & 0xF, SlaveVersion>>4 & 0xF, SlaveVersion & 0xF);
//					SayMakeupSpeakString (FALSE);
SayEnglishMakeupSpeakString (TRUE);
//					break;
				}
		}
	}
}
/* End of TellVersion */


/*****************************************************
*
* Function Name: GetSwitchName
* Description: Returns a pointer to a descriptive string
* Argument: U8 Switch ID
* Return Value: None
*
*****************************************************/

char *GetSwitchName (U16 SwitchID)
{
assert (SwitchID>=LOWEST_TILT_SWITCH && SwitchID<=HIGHEST_BUMPER_SWITCH);
switch (CurrentOutputLanguage)
	{
	case MATIGSALUG:
		switch (SwitchID)
		{
		case LEFT_FRONT_BUMPER_SWITCH:
			return "swits diye teg kahibang te tangkaan"; break;
		case RIGHT_FRONT_BUMPER_SWITCH:
			return "swits diye teg kakawanan te tangkaan"; break;
		case LEFT_REAR_BUMPER_SWITCH:
			return "swits diye teg kahibang te peka"; break;
		case RIGHT_REAR_BUMPER_SWITCH:
			return "swits diye teg kakawanan te peka"; break;
		case LEFT_SIDE_BUMPER_SWITCH:
			return "swits diye teg kahibang"; break;
		case RIGHT_SIDE_BUMPER_SWITCH:
			return "swits diye teg kakawanan"; break;
		case FRONT_TILT_SWITCH:
			return "swits diyet tangkaan"; break;
		case BACK_TILT_SWITCH:
			return "swits diyet peka"; break;
		case LEFT_TILT_SWITCH:
			return "swits diye teg kahibang"; break;
		case RIGHT_TILT_SWITCH:
			return "swits diye teg kakawanan"; break;
		default:
			return "invalid"; break;
		}
		break;

	default: // default to English
		switch (SwitchID)
		{
		case LEFT_FRONT_BUMPER_SWITCH:
			return "left front bumper switch"; break;
		case RIGHT_FRONT_BUMPER_SWITCH:
			return "right front bumper switch"; break;
		case LEFT_REAR_BUMPER_SWITCH:
			return "left rear bumper switch"; break;
		case RIGHT_REAR_BUMPER_SWITCH:
			return "right rear bumper switch"; break;
		case LEFT_SIDE_BUMPER_SWITCH:
			return "left side bumper switch"; break;
		case RIGHT_SIDE_BUMPER_SWITCH:
			return "right side bumper switch"; break;
		case FRONT_TILT_SWITCH:
			return "front tilt switch"; break;
		case BACK_TILT_SWITCH:
			return "rear tilt switch"; break;
		case LEFT_TILT_SWITCH:
			return "left tilt switch"; break;
		case RIGHT_TILT_SWITCH:
			return "right tilt switch"; break;
		default:
			return "invalid"; break;
		}
		break;
	}
}
/* End of GetSwitchName */


/*****************************************************
*
* Function Name: GetPowerString
* Description: Returns a pointer to a power string
* Argument: U8 Value
* Return Value: None
*
*****************************************************/

static char *GetPowerString (U8 gpsValue)
{
switch (CurrentOutputLanguage)
	{
	case MATIGSALUG:
		switch (gpsValue)
		{
		case BASE_POWER_OFF: return "ware"; break;
		case BASE_POWER_LOW: return "deisek"; break;
		case BASE_POWER_NORMAL: return "meupiya"; break;
		default: return "nekey-a"; break;
		}
		break;

	default: // default to English
		switch (gpsValue)
		{
		case BASE_POWER_OFF: return "off"; break;
		case BASE_POWER_LOW: return "low"; break;
		case BASE_POWER_NORMAL: return "normal"; break;
		default: return "invalid"; break;
		}
		break;
	}
}
/* End of GetPowerString */


/*****************************************************
*
* Function Name: TellPower
* Description: Tells the power levels
* Arguments: None
* Return Value: None
*
*****************************************************/

void TellPower (void)
{
switch (CurrentOutputLanguage) {
	case MATIGSALUG:
		sprintf (MakeupSpeakString, "%s ka kuriyinti te %s kuntrul.", GetPowerString (getbase_power()), GetManAutoString (PowerControlAuto));
		SayMakeupSpeakString (TRUE);
		break;
	default: // default to English
		sprintf (MakeupSpeakString, "The power is %s under %s control.", GetPowerString (getbase_power()), GetManAutoString (PowerControlAuto));
		SayMakeupSpeakString (TRUE);
		break;
	}
if (DiagnosticMode) // give more details
	{
//	switch (CurrentOutputLanguage) {
//		case MATIGSALUG:
//			sprintf (MakeupSpeakString, "%s ka kuriyinti te %s kuntrul.", GetPowerString (getbase_power()), GetManAutoString (PowerControlAuto));
//			SayMakeupSpeakString (FALSE);
//			break;
//		default: // default to English
			sprintf (MakeupSpeakString, "The power level is %u volts.", rndrange (11,14));
//			SayMakeupSpeakString (FALSE);
SayEnglishMakeupSpeakString (TRUE);
//			break;
//		}
	}
}

/* End TellPower */


/*****************************************************
*
* Function Name: TellDefaultDistance
* Description: Tells the default distance in mm
* Arguments: None
* Return Value: None
*
*****************************************************/

void TellDefaultDistance (void)
{
switch (CurrentOutputLanguage) {
	case MATIGSALUG:
		sprintf (MakeupSpeakString, "%u milimitru ka kariyuan.", DefaultDistance);
		SayMakeupSpeakString (TRUE);
		break;
	default: // default to English
		sprintf (MakeupSpeakString, "The default distance is %u millimetres.", DefaultDistance);
		SayMakeupSpeakString (TRUE);
		break;
	}
}

/* End TellDefaultDistance */


/*****************************************************
*
* Function Name: TellDefaultSpeed
* Description: Tells the default speed
* Arguments: None
* Return Value: None
*
*****************************************************/

void TellDefaultSpeed (void)
{
switch (CurrentOutputLanguage) {
	case MATIGSALUG:
		sprintf (MakeupSpeakString, "%u ka keiyal.", DefaultSpeed);
		SayMakeupSpeakString (TRUE);
		break;
	default: // default to English
		sprintf (MakeupSpeakString, "The default speed setting is %u%s.", DefaultSpeed, DefaultSpeed==255 ? " which is the maximum speed" : "");
		SayMakeupSpeakString (TRUE);
		break;
	}
}

/* End TellDefaultSpeed */


/*****************************************************
*
* Function Name: TellDefaultAngle
* Description: Tells the default angle in degrees
* Arguments: Setting
* Return Value: None
*
*****************************************************/

void TellDefaultAngle (U8 tdaSetting)
{
switch (CurrentOutputLanguage)
	{
	case MATIGSALUG:
		switch (tdaSetting) {
			case TELL_NEW_SETTING:
				sprintf (MakeupSpeakString, "%u digri e kag gendiyaan.", DefaultAngle);
				break;
			default: // TELL_NORMAL
				sprintf (MakeupSpeakString, "%u digri kag gendiyaan.", DefaultAngle);
				break;
			}
		SayMakeupSpeakString (TRUE);
		break;
	default: // default to English
		switch (tdaSetting) {
			case TELL_NEW_SETTING:
				sprintf (MakeupSpeakString, "Default angle set to %u degrees.", DefaultAngle);
				break;
			default: // TELL_NORMAL
				sprintf (MakeupSpeakString, "The default angle is %u degrees.", DefaultAngle);
				break;
			}
		SayMakeupSpeakString (TRUE);
		break;
	}
}

/* End TellDefaultAngle */


/*****************************************************
*
* Function Name: GetLightsString
* Description: Returns a pointer to a lights string
* Argument: U8 Value
* Return Value: None
*
*****************************************************/

static char *GetLightsString (U8 glsValue)
{
switch (CurrentOutputLanguage)
	{
	case MATIGSALUG:
		switch (glsValue)
		{
		case BASE_LIGHTS_LOW: return "ware"; break;
		case BASE_LIGHTS_NORMAL: return "nurmal"; break;
		case BASE_LIGHTS_FULL: return "eglayag"; break;
		case BASE_LIGHTS_TEST: return "egkelag"; break;
		default: return "nekey-a"; break;
		}
		break;

	default: // default to English
		switch (glsValue)
		{
		case BASE_LIGHTS_LOW: return "off"; break;
		case BASE_LIGHTS_NORMAL: return "normal"; break;
		case BASE_LIGHTS_FULL: return "full"; break;
		case BASE_LIGHTS_TEST: return "test"; break;
		default: return "invalid"; break;
		}
		break;
	}
}
/* End of GetLightsString */


/*****************************************************
*
* Function Name: TellLights
* Description: Tells the light settings
* Arguments: None
* Return Value: None
*
*****************************************************/

void TellLights (void)
{
switch (CurrentOutputLanguage) {
	case MATIGSALUG:
		sprintf (MakeupSpeakString, "%s ka sulu te %s kuntrul.", GetLightsString (getbase_lights()), GetManAutoString (LightsControlAuto));
		SayMakeupSpeakString (TRUE);
		break;
	default: // default to English
		sprintf (MakeupSpeakString, "The lights are %s under %s control.", GetLightsString (getbase_lights()), GetManAutoString (LightsControlAuto));
		SayMakeupSpeakString (TRUE);
		break;
	}
}

/* End TellLights */


/*****************************************************
*
* Function Name: TellHeadlightIntensity
* Description: Tells the headlight intensity
* Arguments: None
* Return Value: None
*
*****************************************************/

void TellHeadlightIntensity (void)
{
switch (CurrentOutputLanguage) {
	case MATIGSALUG:
		sprintf (MakeupSpeakString, "%u ka kalayag te sulu.", HeadlightIntensity);
		SayMakeupSpeakString (TRUE);
		break;
	default: // default to English
		sprintf (MakeupSpeakString, "The headlight intensity setting is %u%s.", HeadlightIntensity, HeadlightIntensity==255 ? " which is the maximum intensity" : "");
		SayMakeupSpeakString (TRUE);
		break;
	}
}

/* End TellHeadlightIntensity */


/*****************************************************
*
* Function Name: TellStealthMode
* Description: Tells the stealth mode setting
* Arguments: None
* Return Value: None
*
*****************************************************/

void TellStealthMode (void)
{
switch (CurrentOutputLanguage) {
	case MATIGSALUG:
		sprintf (MakeupSpeakString, "%s ka egpahanadganad.", GetOffOnString (getbase_stealth()));
		SayMakeupSpeakString (TRUE);
		break;
	default: // default to English
		sprintf (MakeupSpeakString, "Stealth mode is %s.", GetOffOnString (getbase_stealth()));
		SayMakeupSpeakString (TRUE);
		break;
	}
}

/* End TellStealthMode */


/*****************************************************
*
* Function Name: TellDiagnosticMode
* Description: Tells the diagnostic mode setting
* Arguments: None
* Return Value: None
*
*****************************************************/

void TellDiagnosticMode (void)
{
switch (CurrentOutputLanguage) {
	case MATIGSALUG:
		sprintf (MakeupSpeakString, "%s ka para te tiknisyan.", GetOffOnString (DiagnosticMode));
		SayMakeupSpeakString (TRUE);
		break;
	default: // default to English
		sprintf (MakeupSpeakString, "Diagnostic mode is %s.", GetOffOnString (DiagnosticMode));
		SayMakeupSpeakString (TRUE);
		break;
	}
}

/* End TellDiagnosticMode */


/*****************************************************
*
* Function Name: TellAutostopMode
* Description: Tells the autostop mode
* Arguments: None
* Return Value: None
*
*****************************************************/

void TellAutostopMode (void)
{
switch (CurrentOutputLanguage) {
	case MATIGSALUG:
		sprintf (MakeupSpeakString, "%s kag sanggel.", GetManAutoString (getbase_autostop()));
		SayMakeupSpeakString (TRUE);
		break;
	default: // default to English
		sprintf (MakeupSpeakString, "Auto stop mode is %s.", GetManAutoString (getbase_autostop()));
		SayMakeupSpeakString (TRUE);
		break;
	}
}

/* End TellAutostopMode */


/*****************************************************
*
* Function Name: GetTravelModeString
* Description: Returns a pointer to a travel mode string
* Argument: U8 Value
* Return Value: None
*
*****************************************************/

static char *GetTravelModeString (U8 gtmsValue)
{
switch (CurrentOutputLanguage)
	{
	case MATIGSALUG:
		switch (gtmsValue)
		{
		case BASE_TRAVEL_TURNANDSTRAIGHT: return "egpatangke human eggipanew"; break;
		case BASE_TRAVEL_CIRCLE: return "eggipanew minsan kenen istrayt"; break;
		case BASE_TRAVEL_EXTREME: return "diritsuritsu"; break;
		default: return "nekey-a"; break;
		}
		break;

	default: // default to English
		switch (gtmsValue)
		{
		case BASE_TRAVEL_TURNANDSTRAIGHT: return "turn and straight"; break;
		case BASE_TRAVEL_CIRCLE: return "circle"; break;
		case BASE_TRAVEL_EXTREME: return "extreme"; break;
		default: return "invalid"; break;
		}
		break;
	}
}
/* End of GetTravelModeString */


/*****************************************************
*
* Function Name: TellTravelMode
* Description: Tells the travel mode
* Arguments: None
* Return Value: None
*
*****************************************************/

void TellTravelMode (void)
{
switch (CurrentOutputLanguage) {
	case MATIGSALUG:
		sprintf (MakeupSpeakString, "%s ka istayil teg gipanew.", GetTravelModeString (getbase_travelmode()));
		SayMakeupSpeakString (TRUE);
		break;

	default: // default to English
		sprintf (MakeupSpeakString, "Travel mode is %s.", GetTravelModeString (getbase_travelmode()));
		SayMakeupSpeakString (TRUE);
		break;
	}
}

/* End TellTravelMode */


/*****************************************************
*
* Function Name: TellFrontBack
* Description: Tells which is the front of the robot
* Arguments: None
* Return Value: None
*
*****************************************************/

void TellFrontBack (void)
{
switch (CurrentOutputLanguage) {
	case MATIGSALUG:
		sprintf (MakeupSpeakString, "Ka tangkaan kuntee ka an-anayan ne %s.", getbase_front() ? "tangkaan" : "peka");
		SayMakeupSpeakString (TRUE);
		break;

	default: // default to English
		sprintf (MakeupSpeakString, "Current front is the default %s.", getbase_front() ? "front" : "back");
		SayMakeupSpeakString (TRUE);
		break;
	}
}

/* End TellFrontBack */


/*****************************************************
*
* Function Name: TellFrontBackMode
* Description: Tells the Front/Back mode
* Arguments: None
* Return Value: None
*
*****************************************************/

void TellFrontBackMode (void)
{
switch (CurrentOutputLanguage) {
	case MATIGSALUG:
		sprintf (MakeupSpeakString, "%s ka tangkaan wey peka.", GetManAutoString (getbase_autostop()));
		SayMakeupSpeakString (TRUE);
		break;

	default: // default to English
		sprintf (MakeupSpeakString, "Front back switch mode is %s.", GetManAutoString (getbase_autostop()));
		SayMakeupSpeakString (TRUE);
		break;
	}
}

/* End TellFrontBackMode */


/*****************************************************
*
* Function Name: GetDirectionString
* Description: Returns a pointer to a compass direction string
* Argument: unsigned int Value 0..359
* Return Value: None
*
*****************************************************/

static char *GetDirectionString (unsigned int gdsValue)
{
switch (CurrentOutputLanguage)
	{
	case MATIGSALUG:
		switch (gdsValue)
		{
		case 90: return "igsile"; break;
		case 270: return "iglineb"; break;
		default: return "nekey-a"; break;
		}
		break;

	default: // default to English
		switch (gdsValue)
		{
		case 0: return "north"; break;
		case 45: return "north east"; break;
		case 90: return "east"; break;
		case 135: return "south east"; break;
		case 180: return "south"; break;
		case 225: return "south west"; break;
		case 270: return "west"; break;
		case 315: return "north west"; break;
		default: return "invalid"; break;
		}
		break;
	}
}
/* End of GetDirectionString */


/*****************************************************
*
* Function Name: TellCompassOrientation
* Description: Tells the compass orientation
* Arguments: None
* Return Value: None
*
*****************************************************/

void TellCompassOrientation (void)
{
unsigned int degrees; //0..359
BOOL Exact90Multiple; // True if 0, 90, 180, 270 degrees
BOOL Exact45Multiple; // True if 0, 45, 90, 135, ... degrees

// xxxxxxxxxxxxx temp ..............
degrees=rndrange (0, 360);
assert (degrees>=0 && degrees<360);
Exact90Multiple = (BOOL)((degrees % 90) == 0);
Exact45Multiple = (BOOL)((degrees % 45) == 0);

switch (CurrentOutputLanguage) {
	case MATIGSALUG:
		if (degrees==90 || degrees==270)
			sprintf (MakeupSpeakString, "Diya a nakatangke te %s.", GetDirectionString (degrees));
		else
			sprintf (MakeupSpeakString, "Diya a nakatangke te %u digri.", degrees);
		SayMakeupSpeakString (TRUE);
		break;
	default: // default to English
		if (Exact45Multiple)
			sprintf (MakeupSpeakString, "I am currently facing %s.", GetDirectionString (degrees));
		else
			sprintf (MakeupSpeakString, "I am currently %u degree%s off north.", degrees, degrees==1?"":"s");
		SayMakeupSpeakString (TRUE);
		break;
	}
}

/* End TellCompassOrientation */


/*****************************************************
*
* Function Name: TellTime
* Description: Tells the time
* Arguments: None
* Return Value: None
*
*****************************************************/

void TellTime (void)
{
if (! FillMyTimeDateStructure ())
	return;
assert (MyTimeDateStruct.tm_hour>=0 && MyTimeDateStruct.tm_hour<=23);
assert (MyTimeDateStruct.tm_min>=0 && MyTimeDateStruct.tm_min<=59);

switch (CurrentOutputLanguage) {
	case MATIGSALUG:
		sprintf (MakeupSpeakString, "alas %u %u.", MyTimeDateStruct.tm_hour, MyTimeDateStruct.tm_min);
		SayMakeupSpeakString (TRUE);
		break;
	default: // default to English
		sprintf (MakeupSpeakString, "The time is %u %u.", MyTimeDateStruct.tm_hour, MyTimeDateStruct.tm_min);
		SayMakeupSpeakString (TRUE);
		break;
	}
}

/* End TellTime */


/*****************************************************
*
* Function Name: TellDate
* Description: Tells the date
* Arguments: None
* Return Value: None
*
*****************************************************/

//XSTRING(MSMonthName)
static const char *MSMonthName[12] =
		{"Iniru","Pibriru","Marsu","Abril","Mayu","Hunyu",
		 "Hulyu","Agustu","Siptimbri","Uktubri","Nuvimbri","Disimbri"};
		 
static const char *MSDayName[7] =
		{"Duminggu", "Lunis", "Martis", "Mirkulis", "Huwibis", "Biyirnis", "Sebaddu"};


void TellDate (void)
{
if (! FillMyTimeDateStructure ())
	return;
assert (MyTimeDateStruct.tm_mday>=1 && MyTimeDateStruct.tm_mday<=31);
assert (MyTimeDateStruct.tm_mon>=1 && MyTimeDateStruct.tm_mon<=12);
assert (MyTimeDateStruct.tm_wday>=0 && MyTimeDateStruct.tm_wday<=6);

switch (CurrentOutputLanguage) {
	case MATIGSALUG:
		sprintf (MakeupSpeakString, "%s, pitsa %u te %s kuntee.", MSDayName[MyTimeDateStruct.tm_wday], MyTimeDateStruct.tm_mday, MSMonthName[MyTimeDateStruct.tm_mon+1]);
		SayMakeupSpeakString (TRUE);
		break;
	default: // default to English
		sprintf (MakeupSpeakString, "It is %s, %s %u today.", EnglishDayName[MyTimeDateStruct.tm_wday], EnglishMonthName[MyTimeDateStruct.tm_mon+1], MyTimeDateStruct.tm_mday);
		SayMakeupSpeakString (TRUE);
		break;
	}
}

/* End TellDate */


/*****************************************************
*
* Function Name: TellTemperature
* Description: Tells the temperature
* Arguments: None
* Return Value: None
*
*****************************************************/

void TellTemperature (void)
{
float temp;

// xxxxxxxxxxxxx temp ..............
#ifdef TARGET_WIN32
temp = (float)rndrange (200, 450) / 10.0F;
#else
temp = (float)rndrange (200, 450) / 10.0;
#endif

switch (CurrentOutputLanguage) {
	case MATIGSALUG:
		sprintf (MakeupSpeakString, "%2.1f ka keinit.", temp);
		SayMakeupSpeakString (TRUE);
		break;
	default: // default to English
		sprintf (MakeupSpeakString, "The temperature is %2.1f degrees Celsius.", temp);
		SayMakeupSpeakString (TRUE);
		break;
	}
}

/* End TellTemperature */


/**** End of Tell.c ****/
