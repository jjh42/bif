

/* Dummy headers for Dynamic C */
/*** Beginheader brain_c */
#ifdef TARGET_RABBIT
void brain_c();

#asm
XXXbrain_c:	equ	brain_c
#endasm

#endif /* TARGET_RABBIT */
/*** endheader */


#ifdef TARGET_RABBIT
void brain_c () { }
#endif /* TARGET_RABBIT */


/*****************************************************
*
*	Name:	Brain Control Module (Brain.c)
*	Description: Handles highest level control
*	Author: Robert Hunt
*	Created: August 2001
*
*	Mod. Number: 25
*	Last Modified: 14 October 2001
*	Modified by: Robert Hunt
*
*******************************************************
*
* To do yet:
*	Lots and lots
*
*******************************************************
*
* Handles the following:
*	Most high level brain work
*
*******************************************************
*
* Note:
*	Need to check what happens when base lights are set but we are in auto lights mode
*
*****************************************************/

#include <stdio.h>

#include "compat.h"
#include "Brain.h"
#include "speak.h"
#include "commonsubs.h"
#include "slave-base.h"
#include "control.h"
#include "mytime.h"
#include "lcd.h"


const char *BrainNameString[] = {
	"halted", "normal", "manual", "go home",
	"show off", "explore", "chase light", "escape light", 
	"chase sound", "escape sound", "random", "special manual"};


TIME LastBrainStatusChangeTime; // in msecs
TIME MomentLength; // in msecs


/*****************************************************
*
* Function Name: InitBrain
* Description: Initialise the Brain subsystem (called from main)
* Arguments: None
* Return Value: None
*
*****************************************************/

nodebug void InitBrain (void)
{
Verbosity = VERBOSITY_NORMAL;
//Verbosity = VERBOSITY_TALKATIVE;

LCDTimeDisplay = LCD_TIME_LINE_2 | LCD_TIME_OVERRIDE; // Display the time on line 2
LCDDisplay (BRAIN_SUBSYSTEM, "New Robot Master", TRUE);

BrainMode = BRAIN_M_HALTED;
BrainStatus = BRAIN_S_STARTUP;
Greet ();
UpdateBrain (); /* Do an immediate update */
}

/* End InitBrain */


/*****************************************************
*
* Function Name: SetBrainMode
* Description: Handles the change of brain mode
* Argument: New Mode
* Return Value: None
*
*****************************************************/

void SetBrainMode (U8 NewMode)
{
sendbase_haltmsg ();

assert (NewMode < NUM_BRAIN_MODES);
BrainMode = NewMode;
BrainStatus = BRAIN_S_STARTUP;

sprintf (MakeupSpeakString, "%s%s brain mode.", Verbosity==VERBOSITY_TALKATIVE?"Switched into ":"", BrainNameString[NewMode]);
SayEnglishMakeupSpeakString (TRUE);

UpdateBrain (); /* Do an immediate update */
}

/* End of SetBrainMode */


/*****************************************************
*
* Function Name: TellBrainMode
* Description: Tells the current brain mode
* Argument: New Mode
* Return Value: None
*
*****************************************************/

nodebug void TellBrainMode (void)
{
assert (BrainMode < NUM_BRAIN_MODES);
switch (CurrentOutputLanguage) {
	case MATIGSALUG:
		sprintf (MakeupSpeakString, "%s ka utek ku.", BrainNameString[BrainMode]);
		SayMakeupSpeakString (TRUE);
		break;
	default: // default to English
		sprintf (MakeupSpeakString, "We are in %s brain mode.", BrainNameString[BrainMode]);
		SayMakeupSpeakString (TRUE);
		break;
	}
}

/* End of TellBrainMode */


/*****************************************************
*
* Function Name: ReinitiateBrainFunction
* Description: Restarts the activity
* Argument: New Mode
* Return Value: None
*
*****************************************************/

void ReinitiateBrainFunction (void)
{
assert (BrainMode < NUM_BRAIN_MODES);

BrainStatus = BRAIN_S_STARTUP;

sprintf (MakeupSpeakString, "Reinitiated %s brain mode.", BrainNameString[BrainMode]);
SayEnglishMakeupSpeakString (TRUE);

UpdateBrain (); /* Do an immediate update */
}
/* End of ReinitiateBrainFunction */


/*****************************************************
*
* Function Name: UpdateBrainGoHome
* Description: Checks for things that need doing in go home mode
*	Note: Startup is handled already by UpdateBrain
* Arguments: None
* Return Value: None
*
*****************************************************/

static void UpdateBrainGoHome (void)
{
if (BrainStatus == BRAIN_S_IDLE) // Need to choose a manouver
	switch (BrainStage) {
		case 0: // Go forward
			setbase_lights (BASE_LIGHTS_NORMAL);
			DefaultDistance = 300; // 300mm = 0.3m
			DefaultAngle = 0;
			DefaultSpeed = MAX_SPEED;
			HeadlightIntensity = MAX_INTENSITY;
			setbase_intensity (HeadlightIntensity);
GHGo:
			if (DoGo ())
				BrainStatus = BRAIN_S_WFC; // now Wait For Completion
			else // can't do it
				BrainStatus = BRAIN_S_WAM; // Just Wait A Moment
			break;
		case 1: // Turn half around
		case 2: //  twice so a complete turn
			DefaultAngle = 180;
			DefaultDistance = 0;
			goto GHGo;
		case 3: // Tell them I'm lost
			switch (CurrentOutputLanguage) {
				case MATIGSALUG:
					sprintf (MakeupSpeakString, "Nalaag ad e.");
					SayMakeupSpeakString (FALSE);
					break;
				default: // default to English
					sprintf (MakeupSpeakString, "I'm lost.");
					SayMakeupSpeakString (FALSE);
					break;
				}
			BrainStatus = BRAIN_S_WAM; // Just Wait A Moment
			break;
		case 4: // Give up
			SetBrainMode (BRAIN_M_HALTED);
			break;
		}
}
/* End of UpdateBrainGoHome */


/*****************************************************
*
* Function Name: UpdateBrainShowOff
* Description: Checks for things that need doing in show off mode
*	Note: Startup is handled already by UpdateBrain
* Arguments: None
* Return Value: None
*
*****************************************************/

static void UpdateBrainShowOff (void)
{
if (BrainStatus == BRAIN_S_IDLE) // Need to choose a manouver
	switch (BrainStage) {
		case 0: // Go forward
			setbase_lights (BASE_LIGHTS_NORMAL);
			DefaultDistance = 500; // 500mm = 0.5m
			DefaultSpeed = MAX_SPEED;
			HeadlightIntensity = MAX_INTENSITY;
			setbase_intensity (HeadlightIntensity);
SOGoStraight:
			DefaultAngle = 0;
SOGo:			
			if (DoGo ())
				BrainStatus = BRAIN_S_WFC; // now Wait For Completion
			else // can't do it
				BrainStatus = BRAIN_S_WAM; // Just Wait A Moment
			break;
		case 1: // Reverse
SOReverse:
			if (DoReverse ())
				BrainStatus = BRAIN_S_WFC; // now Wait For Completion
			else // can't do it
				BrainStatus = BRAIN_S_WAM; // Just Wait A Moment
			break;
		case 2: // Turn left
			DefaultDistance = 0;
			DefaultAngle = 270;
			goto SOGo;
		case 3: // Turn right again
			DefaultAngle = 180;
			goto SOGo;
		case 4: // Turn back
			DefaultAngle = 270;
			goto SOGo;
		case 5: // Turn headlights on
			setbase_lights (BASE_LIGHTS_FULL);
			BrainStatus = BRAIN_S_WAM; // Just Wait A Moment
			break;
		case 6: // Turn half around
		case 7: //  twice so a complete turn
			DefaultAngle = 180;
			goto SOGo;
		case 8: // Show off lights
			setbase_lights (BASE_LIGHTS_TEST);
			BrainStatus = BRAIN_S_WAM; // Just Wait A Moment
			break;
		case 9: // Jiggle left
		case 11: case 13:
		case 16: case 18: 	case 20:
		case 23: case 25: 	case 27:
			DefaultDistance = 0;
			DefaultAngle = 350;
			goto SOGo;
		case 10: // Jiggle back right
		case 12: case 14:
		case 17: case 19: 	case 21:
		case 24: case 26: case 28:
			DefaultAngle = 10;
			goto SOGo;
		case 15: // Go forward 100mm
			DefaultDistance= 100;
			goto SOGoStraight;
		case 22: // Reverse 100mm
			DefaultDistance= 100;
			goto SOReverse;
		case 29:
			setbase_lights (BASE_LIGHTS_NORMAL);
			BrainStatus = BRAIN_S_WAM; // Just Wait A Moment
			break;
		default:
			BrainStage = 0; // and now repeat some more
			break;
		}
}
/* End of UpdateBrainShowOff */


/*****************************************************
*
* Function Name: UpdateBrainExplore
* Description: Checks for things that need doing in explore mode
*	Note: Startup is handled already by UpdateBrain
* Arguments: None
* Return Value: None
*
*****************************************************/

static void UpdateBrainExplore (void)
{
static BOOL TurnRight;
if (BrainStatus == BRAIN_S_IDLE) // Need to choose a manouver
	switch (BrainStage) {
		case 0:
			DefaultDistance = MAX_DISTANCE;
			DefaultAngle = 0;
			DefaultSpeed = MAX_SPEED;
			HeadlightIntensity = MAX_INTENSITY;
			setbase_intensity (HeadlightIntensity);
			if (DoGo ())
				BrainStatus = BRAIN_S_WFC; // now Wait For Completion
			else // can't do it
				BrainStatus = BRAIN_S_WAM; // Just Wait A Moment
			break;
		case 1:
		case 3:
		case 5:
		case 7:
			DefaultDistance = 400; // Backup 0.4m
			if (DoReverse ())
				BrainStatus = BRAIN_S_WFC; // now Wait For Completion
			else // can't do it
				BrainStatus = BRAIN_S_WAM; // Just Wait A Moment
			break;
		case 2:
		case 4:
		case 6:
		case 8:
			DefaultDistance = MAX_DISTANCE;
			DefaultAngle = (U16)(TurnRight ? rndrange(85,95) : rndrange(265,275));
			if (DoGo ())
				BrainStatus = BRAIN_S_WFC; // now Wait For Completion
			else // can't do it
				BrainStatus = BRAIN_S_WAM; // Just Wait A Moment
			break;
		default:
			BrainStage = 1; // and now repeat some more (start by backing up)
			TurnRight = (BOOL)!TurnRight; // turning the other way
			break;
		}
}
/* End of UpdateBrainExplore */


/*****************************************************
*
* Function Name: UpdateBrainChaseEscape
* Description: Checks for things that need doing in chase or escape sound or lights modes
*	Note: Startup is handled already by UpdateBrain
* Arguments: DoChase: TRUE=Chase, FALSE=Escape
*		 DoLight: TRUE=Light, FALSE=Sound
* Return Value: None
*
*****************************************************/

static void UpdateBrainChaseEscape (BOOL DoChase, BOOL DoLight)
{
if (BrainStatus == BRAIN_S_IDLE) // Need to choose a manouver
	switch (BrainStage) {
		case 0: // Turn 180 degrees
			DefaultDistance = 0;
			DefaultSpeed = MAX_SPEED;
			HeadlightIntensity = MAX_INTENSITY;
			setbase_intensity (HeadlightIntensity);
			MomentLength = 100; // 100 msec = 0.1 seconds
			DefaultAngle = 180;
		case 1: // and then 180 degrees again (complete circle)
			if (DoGo ())
				BrainStatus = BRAIN_S_WFC; // now Wait For Completion
			else // can't do it
				BrainStatus = BRAIN_S_WAM; // Just Wait A Moment
			break;
		case 2: // Tell them I give up
			switch (CurrentOutputLanguage) {
				case MATIGSALUG:
					sprintf (MakeupSpeakString, "Eg-engked ad e.");
					SayMakeupSpeakString (FALSE);
					break;
				default: // default to English
					sprintf (MakeupSpeakString, "I give up %s %s.", DoChase?"chasing":"escaping", DoLight?"light":"sound");
					SayMakeupSpeakString (FALSE);
					break;
				}
			BrainStatus = BRAIN_S_WAM; // Just Wait A Moment
			break;
		case 3: // Give up
			SetBrainMode (BRAIN_M_HALTED);
			break;
		}
}
/* End of UpdateBrainChaseEscape */


/*****************************************************
*
* Function Name: UpdateBrainRandom
* Description: Checks for things that need doing in random mode
*	Note: Startup is handled already by UpdateBrain
* Arguments: None
* Return Value: None
*
*****************************************************/

static void UpdateBrainRandom (void)
{
U8 ThisRnd100;

if (BrainStatus == BRAIN_S_IDLE) // Need to choose a manouver
	{
	DefaultDistance = rndrange (500,1500);
	DefaultAngle = rndrange (0,360);
	DefaultSpeed = (U8)rndrange (200,MAX_SPEED+1);
	HeadlightIntensity = (U8)rndrange (MIN_INTENSITY, MAX_INTENSITY+1);

	ThisRnd100 = rnd100 ();
	if (ThisRnd100 > 40) // go forward 60% of time
		{
		if (DoGo ())
			BrainStatus = BRAIN_S_WFC; // now Wait For Completion
		else
			BrainStatus = BRAIN_S_WAM; // Wait A Moment
		}
	else if (ThisRnd100 > 20) // go backwards 20% of time
		{
		if (DoReverse ())
			BrainStatus = BRAIN_S_WFC; // now Wait For Completion
		else
			BrainStatus = BRAIN_S_WAM; // Wait A Moment
		}
	else // do something else 20% of time
		{
		//printf ("Set lights randomly");
		setbase_intensity (HeadlightIntensity);
		if (ThisRnd100>15)
			setbase_lights (BASE_LIGHTS_LOW);
		else if (ThisRnd100>9)
			setbase_lights (BASE_LIGHTS_NORMAL);
		else if (ThisRnd100>3)
			setbase_lights (BASE_LIGHTS_FULL);
		else
			setbase_lights (BASE_LIGHTS_TEST);
		BrainStatus = BRAIN_S_WAM; // now Wait A Moment
		}
	}
}
/* End of UpdateBrainRandom */


/*****************************************************
*
* Function Name: UpdateBrain
* Description: Checks for things that need doing
* Arguments: None
* Return Value: None
*
*****************************************************/

XSINGLESTRING(UBSM1) {"Egkeupian e neg unggel-unggel kuntee piru"};
XSINGLESTRING(UBSE1) {"I am feeling rather naughty today but"};
XSINGLESTRING(UBSM2) {"Egkeupian e neg kekelag kuntee piru"};
XSINGLESTRING(UBSE2) {"I am feeling a little mischievious today but"};
XSINGLESTRING(UBSM3) {"Andam ad e ke nekey ka igsuhu nu keddi."};
XSINGLESTRING(UBSE3) {"I am ready and waiting for your command."};

root void UpdateBrain (void)
{

// Remember the current status so we can tell if it changes
U8 LastBrainStatus;
LastBrainStatus = BrainStatus;

switch (BrainStatus) {
  case BRAIN_S_STARTUP:
  	// Setup hardware
  	SetPowerAuto (TRUE);
  	SetLightsAuto (TRUE);
	setbase_autostop (TRUE);

	// Set defaults
	DefaultSpeed = FULL_SPEED;
	DefaultAngle = 0;
	DefaultDistance = 500; // 0.5m
	HeadlightIntensity = 255;
	setbase_intensity (HeadlightIntensity);

	MomentLength = 1000; // 1000msec = 1 second

	switch (BrainMode)
		{
		case BRAIN_M_SHOW_OFF:
			MomentLength = 100; // 100 msec = 0.1 seconds
			break;

		case BRAIN_M_GO_HOME:
			if (Verbosity == VERBOSITY_TALKATIVE)
				SayEnglishText (FALSE, "How can I go home when I have no compass yet -- get on with it guys!");
			break;
		case BRAIN_M_CHASE_LIGHT:
			if (Verbosity == VERBOSITY_TALKATIVE)
				SayEnglishText (FALSE, "How can I chase the light when I have nothing to see with yet?");
			break;
		case BRAIN_M_ESCAPE_LIGHT:
			if (Verbosity == VERBOSITY_TALKATIVE)
				SayEnglishText (FALSE, "How can I run from the light when I have nothing to see with yet?");
			break;
		case BRAIN_M_CHASE_SOUND:
			if (Verbosity == VERBOSITY_TALKATIVE)
				SayEnglishText (FALSE, "How can I chase sound when I have nothing to listen with yet?");
			break;
		case BRAIN_M_ESCAPE_SOUND:
			if (Verbosity == VERBOSITY_TALKATIVE)
				SayEnglishText (FALSE, "How can I run from sound when I have nothing to hear with yet?");
			break;

		case BRAIN_M_REBEL:
			Naughtiness = (U8)rndrange (1, 10); // Set "naughtiness" factor
			if (Naughtiness>7 && Verbosity==VERBOSITY_TALKATIVE)
				switch (CurrentOutputLanguage) {
					case MATIGSALUG:
						xSay (FALSE, UBSM1); break;
					default: // default to English
						xSay (FALSE, UBSE1); break;
					}
			else if (Naughtiness>3 && Verbosity==VERBOSITY_TALKATIVE)
				switch (CurrentOutputLanguage) {
					case MATIGSALUG:
						xSay (FALSE, UBSM2); break;
					default: // default to English
						xSay (FALSE, UBSE2); break;
					}
			// Then fall through to manual below

		case BRAIN_M_MANUAL:
			if (Verbosity == VERBOSITY_TALKATIVE)
				switch (CurrentOutputLanguage) {
					case MATIGSALUG:
						xSay (FALSE, UBSM3); break;
					default: // default to English
						xSay (FALSE, UBSE3); break;
					}
			break;
		}
	BrainStage = 0; // Always start at stage zero
	BrainStatus = BRAIN_S_IDLE;
	break;

  case BRAIN_S_WFC: // Wait For Completion
	if(!isbase_moving()) {
          	BrainStatus = BRAIN_S_WAM; // Now Wait A Moment
          	if (Verbosity > VERBOSITY_QUIET)
			beep (SQUARE_WAVE, Beep400Hz, Beep0s1); /* Audible feedback to human */
          	}
  	break;

  case BRAIN_S_WAM: // Wait A Moment
  	if ((getmsectimer() - LastBrainStatusChangeTime) > MomentLength)
  		{
  		++BrainStage; // Increment to next stage (only used for some modes)
	  	BrainStatus = BRAIN_S_IDLE;
	  	}
  	break;
}


switch (BrainMode) {
	case BRAIN_M_HALTED:
		break;

	case BRAIN_M_NORMAL:
		break;

	case BRAIN_M_MANUAL:
	case BRAIN_M_REBEL:
		// Not much to do here because mostly handled directly by IRControl module
		break;

	case BRAIN_M_GO_HOME:
		UpdateBrainGoHome ();
		break;

	case BRAIN_M_SHOW_OFF:
		UpdateBrainShowOff ();
		break;

	case BRAIN_M_EXPLORE:
		UpdateBrainExplore ();
		break;

	case BRAIN_M_CHASE_LIGHT:
		UpdateBrainChaseEscape (TRUE, TRUE);
		break;

	case BRAIN_M_ESCAPE_LIGHT:
		UpdateBrainChaseEscape (FALSE, TRUE);
		break;

	case BRAIN_M_CHASE_SOUND:
		UpdateBrainChaseEscape (TRUE, FALSE);
		break;

	case BRAIN_M_ESCAPE_SOUND:
		UpdateBrainChaseEscape (FALSE, FALSE);
		break;

	case BRAIN_M_RANDOM:
		UpdateBrainRandom ();
		break;

	default:
		printf ("UnknwnBrainMde");
		break;
	}

// Check for a status change
if (BrainStatus != LastBrainStatus)
	LastBrainStatusChangeTime = getmsectimer();
}
/* End of UpdateBrain */


/**** End of Brain.c ****/
