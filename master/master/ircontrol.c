

/* Dummy headers for Dynamic C */
/*** Beginheader ircontrol_c */
#ifdef TARGET_RABBIT
void ircontrol_c();
#asm
xxxircontrol_c: equ ircontrol_c
#endasm
#endif /* TARGET_RABBIT */
/*** endheader */

#ifdef TARGET_RABBIT
void ircontrol_c () { }
#endif /* TARGET_RABBIT */


/*****************************************************
*
*	Name:	IR Control Module (IRControl.C)
*	Description: Handles IR keypresses
*	Author: Robert Hunt
*	Created: August 2001
*
*	Mod. Number: 33
*	Last Modified: 16 October 2001
*	Modified by: Robert Hunt
*
*******************************************************
*
* To do yet:
*	Use up/down buttons
*	Add LCD display code
*
*******************************************************
*
* Handles the following key sequences:
*
*	At any time independent of mode and entry state:
*		<Halt>
*		<Clear>
*		<Help>
*
*	At any time independent of mode:
*		<Power><Off>
*		<Mode>
*			<Off> = Sets mode to HALTED
*			<Auto> = Sets mode to NORMAL
*			<Manual> = Sets mode to MANUAL
*			<Straight> = Sets mode to GO_HOME
*			<Demo> = Sets mode to SHOW_OFF
*			<Angle> = Sets mode to EXPLORE
*			<Lights> = Sets mode to CHASE_LIGHT
*			<Intensity> = Sets mode to ESCAPE_LIGHT
*			<Forward> = Sets mode to CHASE_SOUND
*			<Reverse> = Sets mode to ESCAPE_SOUND
*			<Speed> = Sets mode to RANDOM
*			<+/-> = Sets mode to REBEL
*
*			<Left> = Speak English
*			<Right> = Speak Matigsalug
*			<0>/<1>/<2>/<3> = Sets Verbosity
*			<4> = Pronounce punctuation marks off/on
*			<Diag> = Toggles special mode
*
*	In special mode
*			<Power> = Display battery level on
*			<+/-> = Display charging level on
*			<Off> = Turn off above displays
*			<1> = Time display off/on
*			<2> = Date display off/on
*
*		<Query> works before or after most parameters
*			Also press <Query> followed by:
*				<0> = version
*				<1> = time
*				<2> = date
*				<4> = temperature
*				<7> = bearing
*
*	<Enter/Go> works in most brain modes other than manual and rebel
*
*	<Lights> <Off>/<On>/<Auto>/<Manual>/<Demo>/<0>=All off
*	<Intensity> iii <Enter> or <Intensity><Demo>
*	<Stealth> <Off>/<On>
*
*	<Diag> PIN <Enter> (Press <Diag> again to leave diagnostic mode)
*
*	In MANUAL and REBEL brain mode
*		<Up> = manual forward
*		<Down> = manual reverse
*		<Forward> (Optional ddddd) <Enter>
*		<Reverse> (Optional ddddd) <Enter>
*		<Straight> (Sets angle to zero)
*		<Angle> aaa <Enter>
*		<Speed> sss <Enter> (Sets speed variable)
*		<Speed> <Speed> sss <Enter> (Overrides speed)
*
*		<Manual> or <Off> Start queuing forward/reverse commands
*		<Auto> or <On> Activate queued forward/reverse commands
*
*		<AS> <Off>/<On> (Autostop)
*		<TM> <Straight>=Turn&Straight/<Angle>=Circle/<2>=Extreme
*		<FB> <Forward>/<Reverse>/<Auto>
*		<Power> <1>=Low
*
*		<Demo> then
*			<Forward> Forward 10m
*			<Reverse> Reverse 10m
*			<Speed> Forward 500mm changing speeds
*			<0> = Forward/Reverse 500mm
*			<1> = Left 45 100mm
*			<2> = Zigzag
*			<3> = Right 45 100mm
*			<4> = Left 90 100mm
*			<5> = 200mm right rectangle
*			<6> = Right 90 100mm
*			<7> = Left 135 100mm
*			<8> = Reverse 500mm changing speeds
*			<9> = Right 135 100mm
*			<Lights> or <Intensity> = Lights test mode
*			<+/-> = Switch front/back
*			<Left> = Turn left on spot
*			<Right> = Turn right on spot
*			<Up> = Jerk forward
*			<Down> = Jerk back and forward (progressing backwards)
*
******************************************************
*
* The only keys which auto repeat are:
*	<Left>, <Right>, <Up>, <Down> xxxxxxxx NONE
*
******************************************************
*
*	PIN Number for diagnostic mode
*
*****************************************************/

#define DiagPIN 7894

/****************************************************/


/****************************************************/


#ifdef TARGET_POSIX
#include <stdio.h>
#include <ctype.h>
#endif
#ifdef TARGET_WIN32
#include <stdio.h>
#include <ctype.h>
#include <conio.h>
#endif


/* Our include files */
#include "compat.h"
#include "IR.h"
#include "IRControl.h"
#include "io.h"
#include "Brain.h"
#include "speak.h"
#include "LCD.h"
#include "Brain.h"
#include "slave-speech.h"
#include "slave-base.h"
#include "slave-ir.h"
#include "control.h"
#include "commonsubs.h"
#include "mytime.h"
#include "computercontrol.h"


/*****************************************************
*
*	Global variables
*
*****************************************************/

static U8 IRCommand;
static U8 IRLastValidCommand; /* Used when repeat is allowed */


static U8 IRControlStatus;
#define IR_S_IDLE 0
#define IR_S_FORWARD 1
#define IR_S_REVERSE 2
#define IR_S_ANGLE 3
#define IR_S_SPEED 4
#define IR_S_STEALTH 5
#define IR_S_LIGHTS 6
#define IR_S_INTENSITY 7
#define IR_S_DIAGNOSTICS 8
#define IR_S_AUTOSTOP 9
#define IR_S_TRAVEL_MODE 10
#define IR_S_FRONT_BACK_MODE 11
#define IR_S_HELP 12
#define IR_S_QUERY 13
#define IR_S_POWER 14
#define IR_S_DEMO 15
#define IR_S_MODE 16
#define NUM_IR_STATES 17

static long LastIRStatusChangeTime; // in seconds
#define IR_S_TIMEOUT 6 // seconds

static U8 IREntryStatus;
#define IR_E_IDLE 0
#define IR_E_DECIMAL 1
#define IR_E_PIN 2
#define IR_E_DONE 0xFF

static U8 MinIREntryCharacters;
static U8 MaxIREntryCharacters;
static long MinIRValue;
static long MaxIRValue;
static U8 NumEnteredIRCharacters;
static U8 IREntryBuffer[20];
static U8 IREnteredSign; /* 0=plus, non-zero=minus */
static long IREnteredValue;

#define MAX_QUEUE_ENTRIES 8
static struct {
	BOOL Forward;
	U8 Speed;
	U16 Distance;
	U16 Angle;
	} MyQueue[MAX_QUEUE_ENTRIES];
static U8 NumQueuedEntries;
static BOOL InQueueMode;

static BOOL InIRSpecialMode; /* Used for various special modes */
static U8 IRDisplayState;
#define IR_DISPLAY_OFF 0
#define IR_DISPLAY_BATT 1
#define IR_DISPLAY_CHRG 2

#define IR_USED_COMMAND 0xFD /* REPEAT and ERROR use FE and FF */
#define IR_NO_COMMAND IR_USED_COMMAND /* These two can be the same */

#ifdef TARGET_RABBIT
static int IRWatchdog;
#endif


/*****************************************************
*
* Function Name: InitIRControl
* Description: Initialise the IR Control Interface (called from main)
* Arguments: None
* Return Value: None
*
*****************************************************/

nodebug void InitIRControl (void)
{
IRLastValidCommand = IR_NO_COMMAND;
IRControlStatus = IR_S_IDLE;
InIRSpecialMode = FALSE;
IRDisplayState = IR_DISPLAY_OFF;

#ifdef TARGET_RABBIT
// IRWatchdog = VdGetFreeWd (5); // 5 * 62.5 msec = 313 msec ..... temp xxxxx
#endif

DiagnosticMode = TRUE; // for now ......... temp xxxxxxxxxxxxx
}

/* End of InitIRControl */


/*****************************************************
*
* Function Name: UpdateIRControl
* Description: Checks for timeouts in the IR UI
* Arguments: None
* Return Value: None
*
*****************************************************/

void UpdateIRControl (void)
{
char DStr[LCD_CHARS_PER_LINE+1]; // chars + final null

/* Check for a timeout */
if ((IRControlStatus != IR_S_IDLE) && ((getsectimer() - LastIRStatusChangeTime) > IR_S_TIMEOUT))
	{
	LEDOff (IRStatusLED);
	beep (SQUARE_WAVE, Beep400Hz, Beep0s1); /* Audible feedback to human */
	beep (SQUARE_WAVE, Beep300Hz, Beep0s1);
	switch (CurrentOutputLanguage) {
		case MATIGSALUG:
			SayMatigsalugText (TRUE, "Warad"); break;
		default: // default to English
			SayEnglishText (TRUE, "Timed out."); break;
		}
	LCDDisplay (IR_SUBSYSTEM, "IR Entry timed out", TRUE);
	IRControlStatus = IR_S_IDLE;
	}

// See if we need to update the LCD display
if (IRDisplayState!=IR_DISPLAY_OFF && LCDNumCharacters==0)
	{
	switch (IRDisplayState)
		{
		case IR_DISPLAY_BATT:
			sprintf (DStr, "Bat=%u %.1fv", BatteryLevel, BatteryVoltage);
			break;
		case IR_DISPLAY_CHRG:
			sprintf (DStr, "Chrg=%u %.1fv", ChargingLevel, ChargingVoltage);
			break;
		}
	LCDDisplay (IR_SUBSYSTEM, DStr, TRUE);
	}

#ifdef TARGET_RABBIT
// .... temp xxxxxx  VdHitWd (IRWatchdog); // Hit the virtual watchdog to say that this task is running ok
#endif
}

/* End of UpdateIRControl */


/*****************************************************
*
* Function Name: AcceptBrainMode
* Description: Accepts a IR key and sets the new brain mode
* Argument: New brain mode
* Return Value: None
*
*****************************************************/

nodebug static void AcceptBrainMode (U8 NewBrainMode)
{
if (NewBrainMode==BrainMode && Verbosity==VERBOSITY_TALKATIVE)
	{
	SayEnglishText (FALSE, "You tried to change to the same brain mode that I'm already in.");
	TellBrainMode ();
	}
else
	SetBrainMode (NewBrainMode);
IRControlStatus = IR_S_IDLE;
IRCommand = IR_USED_COMMAND;
}
/* End of AcceptBrainMode */


/*****************************************************
*
* Function Name: HandleIRHelp
* Description: Tries to give help to the user
* Arguments: None
* Return Value: None
*
*****************************************************/

static void HandleIRHelp (void)
{
assert (IRCommand==IR_R_HELP || IRControlStatus==IR_S_HELP);

#if 0 // to make some room in memory
// See if <Help> key pressed first
if (IRControlStatus == IR_S_IDLE && IRCommand == IR_R_HELP)
	{
	switch (CurrentOutputLanguage) {
		case MATIGSALUG:
			SayMatigsalugText (FALSE, "Bulig"); break;
		default: // default to English
			SayEnglishText (FALSE, "Help"); break;
		}
	IRControlStatus = IR_S_HELP;
	IRCommand = IR_USED_COMMAND;
	}

// See if <Help> pressed while in some other mode
else if (IRControlStatus != IR_S_IDLE && IRControlStatus != IR_S_HELP)
	{
	assert (IRCommand == IR_R_HELP);
	switch (IRControlStatus)
		{
		case IR_S_MODE:
			DoModeIRHelp ();
			IRCommand = IR_USED_COMMAND;
			break;

		case IR_S_QUERY:
			DoQueryIRHelp ();
			IRCommand = IR_USED_COMMAND;
			break;

		case IR_S_POWER:
			DoPowerIRHelp ();
			IRCommand = IR_USED_COMMAND;
			break;

		case IR_S_LIGHTS:
			DoLightsIRHelp ();
			IRCommand = IR_USED_COMMAND;
			break;
		}
	IRControlStatus = IR_S_IDLE;
	}

else // See if some other key pressed after <Help>
	{
	assert (IRControlStatus == IR_S_HELP);
	switch (IRCommand)
		{
		case IR_R_MODE:
			DoModeIRHelp ();
			IRCommand = IR_USED_COMMAND;
			break;

		case IR_R_QUERY:
			DoQueryIRHelp ();
			IRCommand = IR_USED_COMMAND;
			break;

		case IR_R_POWER:
			DoPowerIRHelp ();
			IRCommand = IR_USED_COMMAND;
			break;

		case IR_R_LIGHTS:
			DoLightsIRHelp ();
			IRCommand = IR_USED_COMMAND;
			break;
		}
	IRControlStatus = IR_S_IDLE;
	}

if (IRCommand != IR_USED_COMMAND)
	{
	SayEnglishText (FALSE, "Sorry, help for this not implemented yet.");
	IRControlStatus = IR_S_IDLE;
	IRCommand = IR_USED_COMMAND;
	}
#endif
}

/* End of HandleIRHelp */


/*****************************************************
*
* Function Name: HandleIRQuery
* Description: Handles a <Query> keypress when idle,
*			or  <Query> after some other keypress which was already allowed in that mode
*			or the keypress following <Query> in various modes
* Arguments: None
* Return Value: None
*
*****************************************************/

static void HandleIRQuery (void)
{
//printf ("HandleIRQuery %u ", IRControlStatus);
assert (IRCommand==IR_R_QUERY || IRControlStatus==IR_S_QUERY);

// See if <Query> key pressed first
if (IRControlStatus == IR_S_IDLE && IRCommand == IR_R_QUERY)
	{
	if (CurrentOutputLanguage == MATIGSALUG)
		SayMatigsalugText (FALSE, "Inse");
	else // default to English
		SayEnglishText (FALSE, "Query");
	IRControlStatus = IR_S_QUERY;
	IRCommand = IR_USED_COMMAND;
	}

// See if <Query> pressed while in some other mode
else if (IRControlStatus != IR_S_IDLE && IRControlStatus != IR_S_QUERY)
	{
	assert (IRCommand == IR_R_QUERY);
	if (BrainMode == BRAIN_M_MANUAL || BrainMode == BRAIN_M_REBEL)
		{ // These queries only work in certain modes
		switch (IRControlStatus)
			{
			case IR_S_FORWARD:
			case IR_S_REVERSE:
				TellDefaultDistance ();
				IRCommand = IR_USED_COMMAND;
				break;

			case IR_S_ANGLE:
				TellDefaultAngle (TELL_NORMAL);
				IRCommand = IR_USED_COMMAND;
				break;

			case IR_S_SPEED:
				TellDefaultSpeed ();
				IRCommand = IR_USED_COMMAND;
				break;

			case IR_S_AUTOSTOP:
				TellAutostopMode ();
				IRCommand = IR_USED_COMMAND;
				break;

			case IR_S_TRAVEL_MODE:
				TellTravelMode ();
				IRCommand = IR_USED_COMMAND;
				break;

			case IR_S_FRONT_BACK_MODE:
				TellFrontBackMode ();
				IRCommand = IR_USED_COMMAND;
				break;
			}
		}

	// These queries work in any brain mode (if the first keypress was allowed in that mode)
	switch (IRControlStatus)
		{
		case IR_S_MODE:
			TellBrainMode ();
			IRCommand = IR_USED_COMMAND;
			break;

		case IR_S_LIGHTS:
			TellLights ();
			IRCommand = IR_USED_COMMAND;
			break;

		case IR_S_INTENSITY:
			TellHeadlightIntensity ();
			IRCommand = IR_USED_COMMAND;
			break;

		case IR_S_STEALTH:
			TellStealthMode ();
			IRCommand = IR_USED_COMMAND;
			break;

		case IR_S_DIAGNOSTICS:
			TellDiagnosticMode ();
			IRCommand = IR_USED_COMMAND;
			break;

		case IR_S_POWER:
			TellPower ();
			IRCommand = IR_USED_COMMAND;
			break;
		}

	IRControlStatus = IR_S_IDLE;
	}
	
else // See if some other key pressed after <Query>
	{
	assert (IRControlStatus == IR_S_QUERY);
	if (BrainMode == BRAIN_M_MANUAL || BrainMode == BRAIN_M_REBEL)
		{ // These queries only work in certain modes
		switch (IRCommand)
			{
			case IR_R_FORWARD:
			case IR_R_REVERSE:
				TellDefaultDistance ();
				IRCommand = IR_USED_COMMAND;
				break;

			case IR_R_ANGLE:
				TellDefaultAngle (TELL_NORMAL);
				IRCommand = IR_USED_COMMAND;
				break;

			case IR_R_SPEED:
				TellDefaultSpeed ();
				IRCommand = IR_USED_COMMAND;
				break;

			case IR_R_AUTOSTOP:
				TellAutostopMode ();
				IRCommand = IR_USED_COMMAND;
				break;

			case IR_R_TRAVEL_MODE:
				TellTravelMode ();
				IRCommand = IR_USED_COMMAND;
				break;

			case IR_R_FRONT_BACK_MODE:
				TellFrontBackMode ();
				IRCommand = IR_USED_COMMAND;
				break;

			case IR_R_MANUAL: // All of the above
				TellDefaultDistance ();
				TellDefaultAngle (TELL_NORMAL);
				TellDefaultSpeed ();
				TellAutostopMode ();
				TellTravelMode ();
				TellFrontBackMode ();
				IRCommand = IR_USED_COMMAND;
				break;
			}
		}

	// These queries work in any mode
	switch (IRCommand)
		{
		case IR_R_MODE:
			TellBrainMode ();
			IRCommand = IR_USED_COMMAND;
			break;

		case IR_R_LIGHTS:
			TellLights ();
			IRCommand = IR_USED_COMMAND;
			break;

		case IR_R_INTENSITY:
			TellHeadlightIntensity ();
			IRCommand = IR_USED_COMMAND;
			break;

		case IR_R_STEALTH:
			TellStealthMode ();
			IRCommand = IR_USED_COMMAND;
			break;

		case IR_R_DIAGNOSTICS:
			TellDiagnosticMode ();
			IRCommand = IR_USED_COMMAND;
			break;

		case IR_R_POWER:
			TellPower ();
			IRCommand = IR_USED_COMMAND;
			break;

		case IR_0:
			TellVersion ();
			IRCommand = IR_USED_COMMAND;
			break;

		case IR_1:
			TellTime ();
			IRCommand = IR_USED_COMMAND;
			break;

		case IR_2:
			TellDate ();
			IRCommand = IR_USED_COMMAND;
			break;

		case IR_4:
			TellTemperature ();
			IRCommand = IR_USED_COMMAND;
			break;

		case IR_7:
			TellCompassOrientation ();
			IRCommand = IR_USED_COMMAND;
			break;
		}

	IRControlStatus = IR_S_IDLE;
	}
}

/* End of HandleIRQuery */


/*****************************************************
*
* Function Name: HandleDebuggingKey
* Description: Handles a keypress from the IR remote in special mode
* Arguments: None
* Return Value: None
*
*****************************************************/

static void HandleDebuggingKey (void)
{
assert (InIRSpecialMode);
if (IRControlStatus == IR_S_IDLE)
	switch (IRCommand)
		{
		case IR_R_POWER: // Battery level display
			IRDisplayState = IR_DISPLAY_BATT;
			IRCommand = IR_USED_COMMAND;
			break;	
		case IR_R_PLUS_MINUS: // Charge level display
			IRDisplayState = IR_DISPLAY_CHRG;
			IRCommand = IR_USED_COMMAND;
			break;
		case IR_R_OFF: // Turn off above displays
			IRDisplayState = IR_DISPLAY_OFF;
			LCDClear (IR_SUBSYSTEM_LINE);
			break;

		case IR_1: // Time display
			if (LCDTimeDisplay == LCD_TIME_OFF)
				LCDTimeDisplay = LCD_TIME_LINE_2;
			else // turn it off		
				LCDTimeOff (TRUE);
			IRControlStatus = IR_S_IDLE;
			IRCommand = IR_USED_COMMAND;
			break;
		case IR_2: // Date display
			if (LCDDateDisplay == LCD_DATE_OFF)
				LCDDateDisplay = LCD_DATE_LINE_1;
			else // turn it off
				LCDDateOff (TRUE);
			IRControlStatus = IR_S_IDLE;
			IRCommand = IR_USED_COMMAND;
			break;
		}
}
// End of HandleDebuggingKey


/*****************************************************
*
* Function Name: HandleMANUALKey
* Description: Handles a keypress from the IR remote in MANUAL or REBEL mode
* Arguments: None
* Return Value: None
*
*****************************************************/

static void HandleMANUALKey (void)
{
U8 jjj;
BOOL NewSetting;

if (BrainMode == BRAIN_M_REBEL) // Try a bit of naughtiness
	if (rndrange (1,50) < Naughtiness)
		switch (IRCommand)
			{
			case IR_UP: IRCommand = IR_DOWN; break;
			case IR_DOWN: IRCommand = IR_UP; break;
			case IR_R_LEFT: IRCommand = IR_R_RIGHT; break;
			case IR_R_RIGHT: IRCommand = IR_R_LEFT; break;
			case IR_R_FORWARD: IRCommand = IR_R_REVERSE; break;
			case IR_R_REVERSE: IRCommand = IR_R_FORWARD; break;
			case IR_R_SPEED: IRCommand = IR_R_INTENSITY; break;
			case IR_R_INTENSITY: IRCommand = IR_R_SPEED; break;
			}

switch (IRControlStatus)
{
case IR_S_IDLE:
	switch (IRCommand)
	{
	case IR_R_ENTER: // Let them get a new naughtiness factor in rebel mode
		if (BrainMode == BRAIN_M_REBEL) {
			ReinitiateBrainFunction ();
			IRCommand = IR_USED_COMMAND;
			}
		break;

	case IR_R_MANUAL:
	case IR_R_OFF: // Enter queue mode
		InQueueMode = (BOOL)!InQueueMode;
		//printf (" Queue mode is now %u. ", InQueueMode);
		NumQueuedEntries = 0;
		IRCommand = IR_USED_COMMAND;
		break;

	case IR_R_AUTO:
	case IR_R_ON: // Exit queue mode
		if (NumQueuedEntries == 0)
			switch (CurrentOutputLanguage) {
				case MATIGSALUG:
					SayMatigsalugText (TRUE, "Ware natahu neg gimuwen."); break;
				default: // default to English
					SayEnglishText (TRUE, "No queued entries to action."); break;
				}
		else {// have some queued entries
			switch (CurrentOutputLanguage) {
				case MATIGSALUG:
					sprintf (MakeupSpeakString, "Eggimuwen ku ka %u ne suhu.", NumQueuedEntries);
					break;
				default: // default to English
					sprintf (MakeupSpeakString, "Actioning %u queued entries.", NumQueuedEntries); break;
				}
			SayMakeupSpeakString (TRUE);
			for (jjj=0; jjj<NumQueuedEntries; ++jjj)
				{ // Send the queued commands to the base
				DefaultSpeed = MyQueue[jjj].Speed;
				DefaultDistance = MyQueue[jjj].Distance;
				DefaultAngle = MyQueue[jjj].Angle;
				if (MyQueue[jjj].Forward)
					DoGo ();
				else /* reverse */
					DoReverse ();
				}
			}
		InQueueMode = FALSE;
		IRCommand = IR_USED_COMMAND;
		break;

	// Low level manual commands
	case IR_UP:
		switch (CurrentOutputLanguage) {
			case MATIGSALUG:
				SayMatigsalugText (FALSE, "Hipanew"); break;
			default: // default to English
				SayEnglishText (FALSE, "Manual forward."); break;
			}
		if (! getbase_front ()) // front is reversed
			goto DoManualReverse;
DoManualForward:
			if (BumperSwitchesOk (CHECK_FRONT_BUMPER_SWITCHES)) {
				setbase_leftmotorspeed ((S16)DefaultSpeed); /* Forward left motor */
				setbase_rightmotorspeed ((S16)DefaultSpeed); /* Forward right motor */
				}
		IRCommand = IR_USED_COMMAND;
		break;

	case IR_DOWN:
		switch (CurrentOutputLanguage) {
			case MATIGSALUG:
				SayMatigsalugText (FALSE, "Isuos"); break;
			default: // default to English
				SayEnglishText (FALSE, "Manual reverse."); break;
			}
		if (! getbase_front ()) // front is reversed
			goto DoManualForward;
DoManualReverse:
			if (BumperSwitchesOk (CHECK_REAR_BUMPER_SWITCHES)) {
				setbase_leftmotorspeed ((S16)(-((S16)DefaultSpeed))); /* Reverse left motor */
				setbase_rightmotorspeed ((S16)(-((S16)DefaultSpeed))); /* Reverse right motor */
				}
		IRCommand = IR_USED_COMMAND;
		break;

	case IR_R_LEFT: /* Turn left */
DoTurnLeft:	// (If <demo><left> was pressed)
		switch (CurrentOutputLanguage) {
			case MATIGSALUG:
				SayMatigsalugText (FALSE, "Gibang"); break;
			default: // default to English
				SayEnglishText (FALSE, "Turn left."); break;
			}
		setbase_leftmotorspeed ((S16)(-((S16)DefaultSpeed))); /* Reverse left motor */
		setbase_rightmotorspeed ((S16)DefaultSpeed); /* Forward right motor */
		IRCommand = IR_USED_COMMAND;
		break;

	case IR_R_RIGHT: /* Turn right */
DoTurnRight: // (If <demo><right> was pressed)
		switch (CurrentOutputLanguage) {
			case MATIGSALUG:
				SayMatigsalugText (FALSE, "Kawanan"); break;
			default: // default to English
				SayEnglishText (FALSE, "Turn right."); break;
			}
		setbase_leftmotorspeed ((S16)DefaultSpeed); /* Forward left motor */
		setbase_rightmotorspeed ((S16)(-((S16)DefaultSpeed))); /* Reverse right motor */
		IRCommand = IR_USED_COMMAND;
		break;

	// High level manual commands
	case IR_R_FORWARD:
		switch (CurrentOutputLanguage) {
			case MATIGSALUG:
				SayMatigsalugText (FALSE, "Egpabulus"); break;
			default: // default to English
				SayEnglishText (FALSE, "Forward"); break;
			}
		IRControlStatus = IR_S_FORWARD;
		goto IDLE_FR_CONT;
	case IR_R_REVERSE:
		switch (CurrentOutputLanguage) {
			case MATIGSALUG:
				SayMatigsalugText (FALSE, "Eg-isuos"); break;
			default: // default to English
				SayEnglishText (FALSE, "Reverse"); break;
			}
		IRControlStatus = IR_S_REVERSE;
IDLE_FR_CONT:
		IREntryStatus = IR_E_DECIMAL; /* Accept a possible distance value */
		MaxIREntryCharacters = MAX_DISTANCE_DIGITS; /* default min is one */
		MaxIRValue = MAX_DISTANCE;
		MinIRValue = MIN_DISTANCE;
		//InIRSpecialMode = FALSE;
		IRCommand = IR_USED_COMMAND;
		break;

	case IR_R_STRAIGHT:
		switch (CurrentOutputLanguage) {
			case MATIGSALUG:
				SayMatigsalugText (FALSE, "Diritsu"); break;
			default: // default to English
				SayEnglishText (FALSE, "Straight"); break;
			}
		DefaultAngle = 0;
		IRCommand = IR_USED_COMMAND;
		break;

	case IR_R_ANGLE:
		switch (CurrentOutputLanguage) {
			case MATIGSALUG:
				SayMatigsalugText (FALSE, "angul"); break;
			default: // default to English
				SayEnglishText (FALSE, "Angle"); break;
			}
		IRControlStatus = IR_S_ANGLE;
		IREntryStatus = IR_E_DECIMAL; /* Accept a 0-359 degree angle */
		MaxIREntryCharacters = MAX_ANGLE_DIGITS; /* default min is one */
		MaxIRValue = MAX_ANGLE; /* default min is zero */
		IRCommand = IR_USED_COMMAND;
		break;
						
	case IR_R_SPEED:
		switch (CurrentOutputLanguage) {
			case MATIGSALUG:
				SayMatigsalugText (FALSE, "Keiyal"); break;
			default: // default to English
				SayEnglishText (FALSE, "Speed"); break;
			}
		IRControlStatus = IR_S_SPEED;
		IREntryStatus = IR_E_DECIMAL; /* Accept a speed value */
		MaxIREntryCharacters = MAX_SPEED_DIGITS; /* default min is one */
		MinIRValue = MIN_SPEED;
		MaxIRValue = MAX_SPEED;
		InIRSpecialMode = FALSE;
		IRCommand = IR_USED_COMMAND;
		break;

	case IR_R_AUTOSTOP:
		if (DiagnosticMode)
			{
			IRControlStatus = IR_S_AUTOSTOP;
			IRCommand = IR_USED_COMMAND;
			}
		break;

	case IR_R_TRAVEL_MODE:
		if (DiagnosticMode)
			{
			IRControlStatus = IR_S_TRAVEL_MODE;
			IRCommand = IR_USED_COMMAND;
			}
		break;

	case IR_R_FRONT_BACK_MODE:
		if (DiagnosticMode)
			{
			IRControlStatus = IR_S_FRONT_BACK_MODE;
			IRCommand = IR_USED_COMMAND;
			}
		break;

	case IR_R_DEMO:
		switch (CurrentOutputLanguage) {
			case MATIGSALUG:
				SayMatigsalugText (FALSE, "Egpapitew"); break;
			default: // default to English
				SayEnglishText (FALSE, "Demo"); break;
			}
		IRControlStatus = IR_S_DEMO;
		IRCommand = IR_USED_COMMAND;
		break;
	}
	break;
// End of Idle case for HandleMANUALKey

				
case IR_S_FORWARD:
	if (IRCommand == IR_R_FORWARD) // Act as if they've pressed Enter
		IRCommand = IR_R_ENTER;
	goto ForwRev_Cont;
case IR_S_REVERSE:
	if (IRCommand == IR_R_REVERSE) // Act as if they've pressed Enter
		IRCommand = IR_R_ENTER;
ForwRev_Cont:
	/* Accept an entered distance or ENTER which uses the previous distance */
	if ((IREntryStatus == IR_E_DONE) || (IRCommand == IR_R_ENTER))
		{
		if (IREntryStatus == IR_E_DONE)
			DefaultDistance = (U16)IREnteredValue;
		assert (DefaultDistance>=MIN_DISTANCE && DefaultDistance<=MAX_DISTANCE);
		if (InQueueMode)
			{
			if(NumQueuedEntries >= MAX_QUEUE_ENTRIES) {
				errorbeep ();
				SayEnglishText(TRUE, "I can't remember that many commands.");
				}
			MyQueue[NumQueuedEntries].Speed = DefaultSpeed;
			MyQueue[NumQueuedEntries].Distance = DefaultDistance;
			MyQueue[NumQueuedEntries].Angle = DefaultAngle;
			MyQueue[NumQueuedEntries].Forward = (BOOL)(IRControlStatus == IR_S_FORWARD);
			NumQueuedEntries++;
			//printf (" Queued %s command: %u entries now queued ", IRControlStatus==IR_S_FORWARD?"forward":"reverse", NumQueuedEntries);
			}
		else if (IRControlStatus == IR_S_FORWARD)
			DoGo ();
		else { /* reverse */
			assert (IRControlStatus==IR_S_REVERSE);
			DoReverse ();
			}
		IRControlStatus = IR_S_IDLE;
		IRCommand = IR_USED_COMMAND; /* Accept the ENTER press */
		}
	break;

case IR_S_ANGLE:
	if (IREntryStatus == IR_E_DONE)
		{
		DefaultAngle = (U16)IREnteredValue;
		TellDefaultAngle (TELL_NEW_SETTING);
		IRControlStatus = IR_S_IDLE;
		IRCommand = IR_USED_COMMAND; /* Accept the ENTER keypress */
		}
	break; /* from case IR_S_ANGLE */

case IR_S_SPEED:
	if (IRCommand == IR_R_SPEED)
		{
		InIRSpecialMode = (BOOL)!InIRSpecialMode;
		IRCommand = IR_USED_COMMAND;
		}
	else if (IREntryStatus == IR_E_DONE)
		{
		DefaultSpeed = (U8)IREnteredValue;
		TellDefaultSpeed ();
		if (InIRSpecialMode) /* i.e., pressed SPEED twice */
			{
			GetMyParameters ();
			sendbase_overridespeedmsg (MySpeed);
			SayEnglishText (FALSE, "Overriding current speed.");
			InIRSpecialMode = FALSE;
			}
		IRControlStatus = IR_S_IDLE;
		IRCommand = IR_USED_COMMAND; /* Accept the ENTER keypress */
		}
	break;

case IR_S_AUTOSTOP:
	assert (DiagnosticMode);
	if ((IRCommand == IR_R_OFF) || (IRCommand == IR_R_ON))
		{
		NewSetting = (BOOL)(IRCommand == IR_R_ON);
		setbase_autostop (NewSetting);
		SayOffOn (FALSE, NewSetting);
		IRControlStatus = IR_S_IDLE;
		IRCommand = IR_USED_COMMAND;
		}
	break;

case IR_S_TRAVEL_MODE:
	assert (DiagnosticMode);
	switch (IRCommand) {
		case IR_0:
		case IR_R_STRAIGHT:
			setbase_travelmode (BASE_TRAVEL_TURNANDSTRAIGHT);
			SayEnglishText (FALSE, "Turn and straight");
			IRControlStatus = IR_S_IDLE;
			IRCommand = IR_USED_COMMAND;
			break;
		case IR_1:
		case IR_R_ANGLE:
			setbase_travelmode (BASE_TRAVEL_CIRCLE);
			SayEnglishText (FALSE, "Circle");
			IRControlStatus = IR_S_IDLE;
			IRCommand = IR_USED_COMMAND;
			break;
		case IR_2:
			setbase_travelmode (BASE_TRAVEL_EXTREME);
			SayEnglishText (FALSE, "Extreme");
			IRControlStatus = IR_S_IDLE;
			IRCommand = IR_USED_COMMAND;
			break;
		}
	break;

case IR_S_FRONT_BACK_MODE:
	assert (DiagnosticMode);
	if ((IRCommand == IR_R_FORWARD) || (IRCommand == IR_R_REVERSE) || (IRCommand == IR_R_AUTO))
		{
		setbase_switchmode((BOOL)(IRCommand == IR_R_AUTO));
                setbase_front((BOOL)(IRCommand == IR_R_REVERSE));
		IRControlStatus = IR_S_IDLE;
		IRCommand = IR_USED_COMMAND;
		}
	break;

case IR_S_DEMO:
	switch (IRCommand)
	{
	case IR_R_FORWARD: // <demo><forward>
		SayEnglishText (FALSE, "Straight ahead 10 meters.");
		sendbase_gomsg (FULL_SPEED, STRAIGHT_AHEAD, 10000); /* Go straight ahead 10m */
		IRControlStatus = IR_S_IDLE;
		IRCommand = IR_USED_COMMAND;
		break;
						
	case IR_R_REVERSE: // <demo><reverse>
		SayEnglishText (FALSE, "Reverse 10 meters.");
		sendbase_reversemsg (FULL_SPEED, 10000); /* Reverse 10m */
		IRControlStatus = IR_S_IDLE;
		IRCommand = IR_USED_COMMAND;
		break;

	case IR_R_SPEED: // <demo><speed>
		SayEnglishText (FALSE, "Straight ahead a total of half a meter at various speeds.");
		sendbase_gomsg (FULL_SPEED, STRAIGHT_AHEAD, 100); /* Go straight ahead 100mm */
		sendbase_gomsg (200, STRAIGHT_AHEAD, 100); /* Go straight ahead 100mm */
		sendbase_gomsg (100, STRAIGHT_AHEAD, 100); /* Go straight ahead slowly 100mm */
		sendbase_gomsg (200, STRAIGHT_AHEAD, 100); /* Go straight ahead 100mm */
		sendbase_gomsg (FULL_SPEED, STRAIGHT_AHEAD, 100); /* Go straight ahead 100mm */
		IRControlStatus = IR_S_IDLE;
		IRCommand = IR_USED_COMMAND;
		break;
						
	case IR_R_PLUS_MINUS: // <demo><+/->
		SayEnglishText (FALSE, "Set to manual switch mode and reverse the front.");
		setbase_switchmode (FALSE);
		setbase_front ((BOOL)(!getbase_front()));
		IRControlStatus = IR_S_IDLE;
		IRCommand = IR_USED_COMMAND;
		break;

	case IR_R_LEFT: // <demo><left>
		goto DoTurnLeft;
	case IR_R_RIGHT: // <demo><right>
		goto DoTurnRight;

	case IR_R_LIGHTS: // <demo><lights>
	case IR_R_INTENSITY: // <demo><intensity>
		SetLightsAuto (FALSE);
		setbase_lights (BASE_LIGHTS_TEST);
		IRControlStatus = IR_S_IDLE;
		IRCommand = IR_USED_COMMAND;
		break;

	case IR_0: // <demo><0>
		SayEnglishText (FALSE, "Forward and then reverse half a meter.");
		sendbase_gomsg (FULL_SPEED, STRAIGHT_AHEAD, 500); /* Go straight ahead 500mm */
		sendbase_reversemsg (FULL_SPEED, 500); /* Reverse 500mm */
		IRControlStatus = IR_S_IDLE;
		IRCommand = IR_USED_COMMAND;
		break;

	case IR_1: // <demo><1>
		SayEnglishText (FALSE, "Turn 45 degrees left and go forward 4 inches.");
		sendbase_gomsg (FULL_SPEED, 315, 100); /* Go 45 left 100mm */
		IRControlStatus = IR_S_IDLE;
		IRCommand = IR_USED_COMMAND;
		break;

	case IR_2: // <demo><2>
		switch (CurrentOutputLanguage) {
			case MATIGSALUG:
				SayMatigsalugText (FALSE, "Tiku-tiku"); break;
			default: // default to English
				SayEnglishText (FALSE, "Zigzag"); break;
			}
		for (jjj=1; jjj<=5; ++jjj) /* Do this many zigs and zags */
			{
			sendbase_gomsg (FULL_SPEED, 315, 300); /* Go 300mm and then turn left 45 */
			sendbase_gomsg (FULL_SPEED, 45, 300); /* Go 300mm and then turn left 45 */
			}
		IRControlStatus = IR_S_IDLE;
		IRCommand = IR_USED_COMMAND;
		break;
						
	case IR_3: // <demo><3>
		SayEnglishText (FALSE, "Turn 45 degrees right and go forward 4 inches.");
		sendbase_gomsg (FULL_SPEED, 45, 100); /* Go 45 right 100mm */
		IRControlStatus = IR_S_IDLE;
		IRCommand = IR_USED_COMMAND;
		break;

	case IR_4: // <demo><4>
		SayEnglishText (FALSE, "Turn 90 degrees left and go forward 4 inches.");
		sendbase_gomsg (FULL_SPEED, 270, 100); /* Go 90 left 100mm */
		IRControlStatus = IR_S_IDLE;
		IRCommand = IR_USED_COMMAND;
		break;

	case IR_5: // <demo><5>
		SayEnglishText (FALSE, "Go right in an 8 inch square.");
		sendbase_gomsg (FULL_SPEED, STRAIGHT_AHEAD, 200); /* Go straight ahead 200mm */
		sendbase_gomsg (FULL_SPEED, 90, 200); /* Turn right and go 200mm */
		sendbase_gomsg (FULL_SPEED, 90, 200); /* Turn right and go 200mm */
		sendbase_gomsg (FULL_SPEED, 90, 200); /* Turn right and go 200mm */
		IRControlStatus = IR_S_IDLE;
		IRCommand = IR_USED_COMMAND;
		break;

	case IR_6: // <demo><6>
		SayEnglishText (FALSE, "Turn 90 degrees right and go forward 4 inches.");
		sendbase_gomsg (FULL_SPEED, 90, 100); /* Go 90 right 100mm */
		IRControlStatus = IR_S_IDLE;
		IRCommand = IR_USED_COMMAND;
		break;

	case IR_7: // <demo><7>
		SayEnglishText (FALSE, "Turn 135 degrees left and go forward 4 inches.");
		sendbase_gomsg (FULL_SPEED, 225, 100); /* Go 135 left 100mm */
		IRControlStatus = IR_S_IDLE;
		IRCommand = IR_USED_COMMAND;
		break;

	case IR_8: // <demo><8>
		SayEnglishText (FALSE, "Reverse speed demo.");
		sendbase_reversemsg (FULL_SPEED, 100); /* Reverse 100mm */
		sendbase_reversemsg (200, 100); /* Reverse 100mm */
		sendbase_reversemsg (100, 100); /* Slow reverse 100mm */
		sendbase_reversemsg (200, 100); /* Reverse 100mm */
		sendbase_reversemsg (FULL_SPEED, 100); /* Reverse 100mm */
		IRControlStatus = IR_S_IDLE;
		IRCommand = IR_USED_COMMAND;
		break;

	case IR_9: // <demo><9>
		SayEnglishText (FALSE, "Turn 135 degrees right and go forward 4 inches.");
		sendbase_gomsg (FULL_SPEED, 135, 100); /* Go 135 right 100mm */
		IRControlStatus = IR_S_IDLE;
		IRCommand = IR_USED_COMMAND;
		break;
	}
	break; /* from case IR_S_DEMO */
}
}
/* End of HandleMANUALKey */


/*****************************************************
*
* Function Name: HandleIRKey
* Description: Handles a keypress from the IR remote
* Arguments: Keypress value and Front/Back source marker
* Return Value: None
*
*****************************************************/

void HandleIRKey (U8 IRKeyValue, U8 IRSource)
{
U8 j;

#ifdef TARGET_WIN32
++IRSource; // just to get rid of compiler warning
#endif

LEDToggle (IRKeyLED);

/* Make a copy of the key value */
IRCommand = IRKeyValue; /* We'll set it to IR_USED_COMMAND if we use it */

/* Check first for special cases -- errors and repeats */
if (IRCommand == IR_ERROR)
	{ 
	IRLastValidCommand = IR_NO_COMMAND; /* Clear last valid command so can't repeat */
	IRCommand = IR_USED_COMMAND;
	}
else if (IRCommand == IR_REPEAT)
	{ /* Check for valid repeats */
#if 0 // disable repeats for now -- no real use for them
	/* only allow certain keys to repeat */
	if ((IRLastValidCommand == IR_UP)
	 || (IRLastValidCommand == IR_DOWN)
	 || (IRLastValidCommand == IR_R_LEFT)
	 || (IRLastValidCommand == IR_R_RIGHT))
		{
		LCDDisplay (IR_SUBSYSTEM, "Allow Repeat", TRUE);
		IRCommand = IRLastValidCommand;
		}
	else /* don't allow it to repeat */
#endif	
		IRCommand = IR_USED_COMMAND;
	}

if (IRCommand != IR_USED_COMMAND) /* we still have something */
	{
	/* Handle exception commands which are independent of status */
	if (IRCommand == IR_R_HALT) /* can be done at any time */
		{
		sendbase_haltmsg ();
		if (CurrentOutputLanguage == MATIGSALUG)
			SayMatigsalugText (TRUE, "Sanggol");
		else
			SayEnglishText (TRUE, "Halt");
		if (IRControlStatus == IR_S_HELP) // give help info as well
			HandleIRHelp ();
		IRControlStatus = IR_S_IDLE;
		IRCommand = IR_USED_COMMAND;
		}

	else if (IRCommand == IR_R_CLEAR) /* can be done at any time */
		{
		if (CurrentOutputLanguage == MATIGSALUG)
			SayMatigsalugText (TRUE, "Awe");
		else
			SayEnglishText (TRUE, "Clear");
		if (IRControlStatus == IR_S_HELP) // give help info as well
			HandleIRHelp ();
		IRControlStatus = IR_S_IDLE;
		IRCommand = IR_USED_COMMAND;
		}
	else if (IRCommand == IR_R_HELP || IRControlStatus == IR_S_HELP) /* can be done at any time */
		HandleIRHelp ();
	else if (IRCommand == IR_R_QUERY || IRControlStatus == IR_S_QUERY) /* can be done at any time */
		HandleIRQuery ();


	/* Set defaults */
	if (IRControlStatus == IR_S_IDLE)
		IREntryStatus = IR_E_IDLE; /* so don't have to reset both manually */
	if (IREntryStatus == IR_E_IDLE)
		{ /* set normal defaults */
		MinIRValue = 0;
		MinIREntryCharacters = 1;
		NumEnteredIRCharacters = 0;
		IREnteredSign = 0;
		}

	/* Process the command according to IREntryStatus */
	if ((IREntryStatus != IR_E_IDLE) && (IREntryStatus != IR_E_DONE))
		{
		// Try a bit of naughtiness if necessary
		if (BrainMode == BRAIN_M_REBEL && (IRCommand <= IR_9) && rndrange (1,50) < Naughtiness) {
			if (rnd100()>50) {
				if (IRCommand > IR_0)
					--IRCommand;
			}
			else if (IRCommand < IR_9)
				++IRCommand;
                }
		if ((IRCommand == IR_R_LEFT) && (NumEnteredIRCharacters > 0))
			{
			SayEnglishText (FALSE, "Backspace");
			--NumEnteredIRCharacters;
			IRCommand = IR_USED_COMMAND;
			}
		else if ((IRCommand == IR_R_ENTER) && (NumEnteredIRCharacters >= MinIREntryCharacters))
			{ /* Evaluate the entered characters */
			IREnteredValue = 0;
			for (j=0; j<NumEnteredIRCharacters; ++j) {
				IREnteredValue *= (long)10;
				IREnteredValue += (long)IREntryBuffer[j];
			}
			if (IREnteredSign != 0) IREnteredValue = -IREnteredValue;
			if (IREnteredValue < MinIRValue) {
				sprintf (MakeupSpeakString, "Your entered value of %lu is too small.", IREnteredValue);
				SayMakeupSpeakString (TRUE);
				}
			else if (IREnteredValue > MaxIRValue) {
				sprintf (MakeupSpeakString, "Your entered value of %lu is too large.", IREnteredValue);
				SayMakeupSpeakString (TRUE);
				}
			else // Must have been ok
				/* Change the status but leave the following code to accept the enter keypress */
				IREntryStatus = IR_E_DONE;
			}
		else if (/* (IRCommand>= IR_0) && */ (IRCommand <= IR_9) && (NumEnteredIRCharacters >= MaxIREntryCharacters))
			; /* Do nothing -- don't accept a digit */
		else switch (IREntryStatus)
			{
			case IR_E_DECIMAL:
				if ((IRCommand == IR_R_PLUS_MINUS) && (MinIRValue < 0))
					IREnteredSign = (U8)~IREnteredSign;
				/* Fall through to PIN code below */
			case IR_E_PIN:
				if (/* (IRCommand >= IR_0) && */ (IRCommand <= IR_9))
					{
					IREntryBuffer[NumEnteredIRCharacters++] = IRCommand;
					if (Verbosity >= VERBOSITY_NORMAL) {
						sprintf (MakeupSpeakString, "%u", IRCommand);
						SayMakeupSpeakString (FALSE);
						}
					IRCommand = IR_USED_COMMAND;
					}
				break;
			}
		}

	// Handle special debugging commands
	if (IRCommand != IR_USED_COMMAND && InIRSpecialMode)
		HandleDebuggingKey ();

	// Handle general commands that are independent of brain mode
	if (IRCommand != IR_USED_COMMAND) /* it wasn't a HALT or CLR etc. or used by the entry routine above */
		switch (IRControlStatus)
		{
		case IR_S_IDLE:
			switch (IRCommand)
			{
			case IR_R_MODE:
				switch (CurrentOutputLanguage) {
					case MATIGSALUG:
						SayMatigsalugText (FALSE, "Tuyu"); break;
					default: // default to English
						SayEnglishText (FALSE, "Mode"); break;
					}
				IRControlStatus = IR_S_MODE;
				IRCommand = IR_USED_COMMAND;
				break;

			case IR_R_POWER:
				switch (CurrentOutputLanguage) {
					case MATIGSALUG:
						SayMatigsalugText (FALSE, "Kuriyinti"); break;
					default: // default to English
						SayEnglishText (FALSE, "Power"); break;
					}
				IRControlStatus = IR_S_POWER;
				IRCommand = IR_USED_COMMAND;
				break;

			case IR_R_LIGHTS:
				SayLights (TRUE);
				IRControlStatus = IR_S_LIGHTS;
				IRCommand = IR_USED_COMMAND;
				break;
						
			case IR_R_INTENSITY:
				switch (CurrentOutputLanguage) {
					case MATIGSALUG:
						SayMatigsalugText (TRUE, "Kalayag te sulu."); break;
					default: // default to English
						SayEnglishText (TRUE, "Intensity"); break;
					}
				IRControlStatus = IR_S_INTENSITY;
				IREntryStatus = IR_E_DECIMAL; /* Accept a headlight intensity value */
				MaxIREntryCharacters = MAX_INTENSITY_DIGITS; /* default min is one */
				MinIRValue = MIN_INTENSITY;
				MaxIRValue = MAX_INTENSITY;
				IRCommand = IR_USED_COMMAND;
				break;

			case IR_R_STEALTH:
				switch (CurrentOutputLanguage) {
					case MATIGSALUG:
						SayMatigsalugText (TRUE, "Egmiyew"); break;
					default: // default to English
						SayEnglishText (TRUE, "Stealth mode"); break;
					}
				IRControlStatus = IR_S_STEALTH;
				IRCommand = IR_USED_COMMAND;
				break;
						
			case IR_R_DIAGNOSTICS:
				if (DiagnosticMode)
					{
					//LCDDisplay (IR_SUBSYSTEM, "Exited diag mode", TRUE);
					switch (CurrentOutputLanguage) {
						case MATIGSALUG:
							SayMatigsalugText (FALSE, "Warad para te tiknisyan."); break;
						default: // default to English
							SayEnglishText (FALSE, "Exited diagnostic mode."); break;
						}
					DiagnosticMode = FALSE;
					}
				else /* Not in diagnostic mode - need to accept a PIN */
					{
					switch (CurrentOutputLanguage) {
						case MATIGSALUG:
							SayMatigsalugText (FALSE, "Para te tiknisyan"); break;
						default: // default to English
							SayEnglishText (FALSE, "Diagnostic mode, please enter your PIN."); break;
						}
					IRControlStatus = IR_S_DIAGNOSTICS;
					IREntryStatus = IR_E_PIN;
					MinIREntryCharacters = 4;
					MaxIREntryCharacters = 4;
					MaxIRValue = 9999; /* default min is zero */
					}
				IRCommand = IR_USED_COMMAND;
				break;

			}
			break;

		case IR_S_MODE:
			switch (IRCommand)
			{
			// Accept a new mode
			case IR_R_OFF:
				AcceptBrainMode (BRAIN_M_HALTED); break;
			case IR_R_AUTO:
				AcceptBrainMode (BRAIN_M_NORMAL); break;
			case IR_R_MANUAL:
				AcceptBrainMode (BRAIN_M_MANUAL); break;
			case IR_R_STRAIGHT:
				AcceptBrainMode (BRAIN_M_GO_HOME); break;
			case IR_R_DEMO:
				AcceptBrainMode (BRAIN_M_SHOW_OFF); break;
			case IR_R_ANGLE:
				AcceptBrainMode (BRAIN_M_EXPLORE); break;
			case IR_R_LIGHTS:
				AcceptBrainMode (BRAIN_M_CHASE_LIGHT); break;
			case IR_R_INTENSITY:
				AcceptBrainMode (BRAIN_M_ESCAPE_LIGHT); break;
			case IR_R_FORWARD:
				AcceptBrainMode (BRAIN_M_CHASE_SOUND); break;
			case IR_R_REVERSE:
				AcceptBrainMode (BRAIN_M_ESCAPE_SOUND); break;
			case IR_R_SPEED:
				AcceptBrainMode (BRAIN_M_RANDOM); break;
			case IR_R_PLUS_MINUS:
				AcceptBrainMode (BRAIN_M_REBEL); break;

			// Also use the <Mode> button to change output language
			case IR_R_LEFT:
				CurrentOutputLanguage = ENGLISH;
				SayEnglishText (FALSE, "Speaking in English from now on.");
				IRControlStatus = IR_S_IDLE;
				IRCommand = IR_USED_COMMAND;
				break;
			case IR_R_RIGHT:
				CurrentOutputLanguage = MATIGSALUG;
				SayMatigsalugText (FALSE, "Eg-eleg-eleg a neg mematigsalug kuntee.");
				IRControlStatus = IR_S_IDLE;
				IRCommand = IR_USED_COMMAND;
				break;

			// Also use the <Mode> button to change verbosity
			case IR_0: // VERBOSITY_SILENT
			case IR_1: // VERBOSITY_QUIET
			case IR_2: // VERBOSITY_NORMAL
			case IR_3: // VERBOSITY_TALKATIVE
				Verbosity = IRCommand;
				sprintf (MakeupSpeakString, "Verbosity set to %u.", Verbosity);
				SayEnglishMakeupSpeakString (TRUE);
				IRControlStatus = IR_S_IDLE;
				IRCommand = IR_USED_COMMAND;
				break;

			// Also use the <Mode> button to change pronounciation of punctuation marks
			case IR_4: // Don't pronounce them
			case IR_5: // Pronounce them
				PronouncePunctuationMarks = (BOOL)(IRCommand == IR_5);
				sprintf (MakeupSpeakString, "Pronounciation of punctuation marks set to %u.", PronouncePunctuationMarks);
				SayEnglishMakeupSpeakString (TRUE);
				IRControlStatus = IR_S_IDLE;
				IRCommand = IR_USED_COMMAND;
				break;

			case IR_R_DIAGNOSTICS: // Toggle special mode
				InIRSpecialMode = (BOOL)!InIRSpecialMode;
				printf (" SM now %d ", InIRSpecialMode);
				IRControlStatus = IR_S_IDLE;
				IRCommand = IR_USED_COMMAND;
				break;
			}
			if (IRCommand != IR_USED_COMMAND) // must have been an invalid attempt to set the brain mode
				IRControlStatus = IR_S_IDLE;
			break;

		case IR_S_POWER:
			switch (IRCommand)
			{
			case IR_R_OFF:
				switch (CurrentOutputLanguage) {
					case MATIGSALUG:
						SayMatigsalugText (FALSE, "Egpatey a kuntee."); break;
					default: // default to English
						SayEnglishText (FALSE, "I'm powering myself off now."); break;
					}
				SetPowerAuto (FALSE);
				setbase_power(BASE_POWER_OFF);
				sendir_standbymsg ();
				IRControlStatus = IR_S_IDLE;
				IRCommand = IR_USED_COMMAND;
				break;

			case IR_R_ON:
				SetPowerAuto (FALSE);
				setbase_power (BASE_POWER_NORMAL);
				SayNormal (FALSE);
				IRControlStatus = IR_S_IDLE;
				IRCommand = IR_USED_COMMAND;
				break;

			case IR_0:
				SayEnglishText (FALSE, "Complete system power down.");
				SetPowerAuto (FALSE);
				setbase_power(BASE_POWER_OFF);
				sendir_poweroffmsg ();
				IRControlStatus = IR_S_IDLE;
				IRCommand = IR_USED_COMMAND;
				break;

			case IR_1:
				SetPowerAuto (FALSE);
				setbase_power (BASE_POWER_LOW);
				switch (CurrentOutputLanguage) {
					case MATIGSALUG:
						SayMatigsalugText (FALSE, "Kulang"); break;
					default: // default to English
						SayEnglishText (FALSE, "Low"); break;
					}
				IRControlStatus = IR_S_IDLE;
				IRCommand = IR_USED_COMMAND;
				break;

			case IR_R_AUTO:
				SetPowerAuto (TRUE);
				SayAutomatic (FALSE);
				IRControlStatus = IR_S_IDLE;
				IRCommand = IR_USED_COMMAND;
				break;

			case IR_R_MANUAL:
				SetPowerAuto (FALSE);
				SayManual (FALSE);
				IRControlStatus = IR_S_IDLE;
				IRCommand = IR_USED_COMMAND;
				break;
			}
			break;

		case IR_S_LIGHTS:
			switch (IRCommand)
			{
			case IR_R_LEFT:
				IRControlStatus = IR_S_IDLE;
				IRCommand = IR_USED_COMMAND;
				break;

			case IR_0:
				SetLightsAuto (FALSE);
				setbase_lights (BASE_LIGHTS_LOW);
				switch (CurrentOutputLanguage) {
					case MATIGSALUG:
						SayMatigsalugText (FALSE, "Eg-ebukan ka langun ne me sulu."); break;
					default: // default to English
						SayEnglishText (FALSE, "Lights all off."); break;
					}
				IRControlStatus = IR_S_IDLE;
				IRCommand = IR_USED_COMMAND;
				break;

			case IR_R_OFF:
				SetLightsAuto (FALSE);
				setbase_lights(BASE_LIGHTS_NORMAL);
				if (Verbosity == VERBOSITY_TALKATIVE)
					switch (CurrentOutputLanguage) {
						case MATIGSALUG:
							SayMatigsalugText (FALSE, "Eg-ebukan ka dakel ne sulu."); break;
						default: // default to English
							SayEnglishText (FALSE, "Head lights off."); break;
						}
				else // not talkative
					SayOff (FALSE);
				IRControlStatus = IR_S_IDLE;
				IRCommand = IR_USED_COMMAND;
				break;

			case IR_R_ON:
				SetLightsAuto (FALSE);
				setbase_lights(BASE_LIGHTS_FULL);
				if (Verbosity == VERBOSITY_TALKATIVE)
					switch (CurrentOutputLanguage) {
						case MATIGSALUG:
							SayMatigsalugText (FALSE, "Egpasiha te dakel ne sulu."); break;
						default: // default to English
							SayEnglishText (FALSE, "Head lights on."); break;
						}
				else // not talkative
					SayOn (FALSE);
				IRControlStatus = IR_S_IDLE;
				IRCommand = IR_USED_COMMAND;
				break;

			case IR_R_AUTO:
				SetLightsAuto (TRUE);
				SayAutomatic (FALSE);
				IRControlStatus = IR_S_IDLE;
				IRCommand = IR_USED_COMMAND;
				break;

			case IR_R_MANUAL:
				SetLightsAuto (FALSE);
				SayManual (FALSE);
				IRControlStatus = IR_S_IDLE;
				IRCommand = IR_USED_COMMAND;
				break;

			case IR_R_DEMO:
				SetLightsAuto (FALSE);
				setbase_lights(BASE_LIGHTS_TEST);
				switch (CurrentOutputLanguage) {
					case MATIGSALUG:
						SayMatigsalugText (FALSE, "Egpapitew-pitew te sulu."); break;
					default: // default to English
						SayEnglishText (FALSE, "Demo lights."); break;
					}
				IRControlStatus = IR_S_IDLE;
				IRCommand = IR_USED_COMMAND;
				break;
			}
			break; /* from case IR_S_LIGHTS */

		case IR_S_INTENSITY:
			if (IRCommand==IR_R_DEMO && NumEnteredIRCharacters==0)
				{
				SetLightsAuto (FALSE);
				setbase_lights (BASE_LIGHTS_TEST);
				IRControlStatus = IR_S_IDLE;
				IRCommand = IR_USED_COMMAND;
				}
			else if (IREntryStatus == IR_E_DONE)
				{
				HeadlightIntensity = (U8)IREnteredValue;
				setbase_intensity (HeadlightIntensity);
				TellHeadlightIntensity ();
				IRControlStatus = IR_S_IDLE;
				IRCommand = IR_USED_COMMAND;
				}
			break; /* from case IR_S_INTENSITY */

		case IR_S_STEALTH:
			switch (IRCommand)
			{
			case IR_R_OFF:
				setbase_stealth (TRUE);
				Verbosity = VERBOSITY_SILENT;
				// SayOff (FALSE);  NOT NEEDED HERE !!!
				IRControlStatus = IR_S_IDLE;
				IRCommand = IR_USED_COMMAND;
				break;

			case IR_R_ON:
                        setbase_stealth (TRUE);
				Verbosity = VERBOSITY_NORMAL;
				SayOn (FALSE);
				IRControlStatus = IR_S_IDLE;
				IRCommand = IR_USED_COMMAND;
				break;
			}
			break;

		case IR_S_DIAGNOSTICS:
			assert (! DiagnosticMode);
			if (IREntryStatus == IR_E_DONE)
				{ /* they've entered the four digit pin */
				if (IREnteredValue == DiagPIN)
				 	{
				 	SayEnglishText (FALSE, "Entered diagnostic mode.");
					//LCDDisplay (IR_SUBSYSTEM, "Entered diag mode", TRUE);
					DiagnosticMode = TRUE;
					Verbosity = VERBOSITY_TALKATIVE;
					beep (SQUARE_WAVE, Beep300Hz, Beep0s2);
					beep (SQUARE_WAVE, Beep600Hz, Beep0s2);
					beep (SQUARE_WAVE, Beep800Hz, Beep0s2);
					beep (SQUARE_WAVE, Beep1200Hz, Beep0s2);
					IRCommand = IR_USED_COMMAND;
					}
				else
					{
					SayEnglishText (FALSE, "Incorrect PIN.");
					LCDDisplay (IR_SUBSYSTEM, "Incorrect PIN", TRUE);
					errorbeep ();
					}
				IRControlStatus = IR_S_IDLE; /* either way */
				}
			break;

		}


	/* Process the command according to IRControlStatus depending on the mode */
	if (IRCommand != IR_USED_COMMAND) /* it wasn't a HALT or CLR etc. or used by the entry routine above */
		switch (BrainMode)
		{
		case BRAIN_M_MANUAL:
		case BRAIN_M_REBEL:
			HandleMANUALKey ();
			break;

		case BRAIN_M_NORMAL:
		case BRAIN_M_GO_HOME:
		case BRAIN_M_SHOW_OFF:
		case BRAIN_M_EXPLORE:
		case BRAIN_M_CHASE_LIGHT:
		case BRAIN_M_ESCAPE_LIGHT:
		case BRAIN_M_CHASE_SOUND:
		case BRAIN_M_ESCAPE_SOUND:
		case BRAIN_M_RANDOM:
			// Accept <Enter/Go> command and some query commands only
			switch (IRControlStatus)
			{
			case IR_S_IDLE:
				switch (IRCommand)
				{
				case IR_R_ENTER:
					ReinitiateBrainFunction ();
					IRCommand = IR_USED_COMMAND;
					break;

				}
				break;

			}
			break;

		case BRAIN_M_HALTED: // Accept no commands
			break;
		}


	/* See if we used the command or not */
	if (IRCommand == IR_USED_COMMAND) /* then we used the command */
		{
		if (IRKeyValue != IR_REPEAT)
			IRLastValidCommand = IRKeyValue; // for repeats
		LastIRStatusChangeTime = getsectimer();
		beep (SQUARE_WAVE, Beep200Hz, Beep0s1); /* Audible click feedback to human */
		//beep (SQUARE_WAVE, BeepSilent,Beep0s1);
		}
	else /* it was invalid */
		{
		switch (CurrentOutputLanguage) {
			case MATIGSALUG:
				SayMatigsalugText (TRUE, "Sayup"); break;
			default: // default to English
				SayEnglishText (TRUE, "Oops."); break;
			}
		errorbeep ();
		//if (IRCommand == IR_R_ENTER) /* Even invalid "Enter" should reset status */
			IRControlStatus = IR_S_IDLE;
		IRLastValidCommand = IR_NO_COMMAND; /* Don't allow a repeat */
		}
	}

if (IRControlStatus == IR_S_IDLE)
	LEDOff (IRStatusLED);
else
	LEDOn (IRStatusLED);
}
/* End of HandleIRKey */


#ifdef TARGET_WIN32

// Define some empty routines so won't get linking errors
void mutex_init(mutex_t *mutex) {++mutex;}
void mutex_lock(mutex_t *mutex) {++mutex;}
void mutex_unlock(mutex_t *mutex) {++mutex;}

void saysound (U8 x) {++x;}
void saysounds (constparam U8* x) {char y=*x; ++y;}

void sendir_standbymsg () {}
void sendir_poweroffmsg () {}

void beep(U8 waveform, U16 freq, U16 time) {Buzz(30); ++waveform; ++freq; ++time;}
void errorbeep () {Buzz(100);}

void sendbase_haltmsg() {printf ("{HALTBASE}");};
void sendbase_gomsg(U8 motorspeed, U16 angle, U16 distance) {printf ("{GO}");++motorspeed; ++angle; ++distance;}
void sendbase_reversemsg(U8 motorspeed, U16 distance) {printf ("{REVERSE}");++motorspeed; ++distance;}
void sendbase_overridespeedmsg(U8 motorspeed) {printf ("{OVERRIDE SPEED}");++motorspeed;}
void setbase_intensity (U8 intensity) {printf ("{SET INTENSITY}");++intensity;}
U8 getbase_intensity() {return 0;}
void setbase_leftmotorspeed(S16 motorspeed) {printf ("{LEFT SPEED}");++motorspeed;}
S16 getbase_leftmotorspeed() {return 0;}
void setbase_rightmotorspeed(S16 motorspeed) {printf ("{RIGHT SPEED}");++motorspeed;}
S16 getbase_rightmotorspeed() {return 0;}
void setbase_lights(U8 level) {printf ("{SET LIGHTS}");++level;}
U8 getbase_lights() {return 0;}
void setbase_power(U8 level) {++level;}
U8 getbase_power() {return BASE_POWER_NORMAL;}
void setbase_stealth(bool on) {++on;}
bool getbase_stealth() {return FALSE;}
void setbase_diagnostics(bool on) {++on;}
bool getbase_diagnostics() {return FALSE;}
void setbase_front(bool reverse) {++reverse;}
bool getbase_front() {return TRUE;} // returns TRUE if default front is the current front
void setbase_switchmode(bool automatic) {++automatic;}
bool getbase_switchmode() {return FALSE;}
void setbase_travelmode(U8 mode) {++mode;}
U8 getbase_travelmode() {return 0;}
void setbase_autostop(bool enabled) {++enabled;}
bool getbase_autostop() {return FALSE;}
bool isbase_moving () {return (bool)(rnd100()>50);}
bool isbase_switchdown(U16 sw) {++sw; return (bool)(rnd100()>50);}
#endif

static void PrintHelp (void)
{
printf ("\n\nRobert's IR interface test program\n\n");

printf ("IR key simulations are:\n");
printf ("  /=Help !=Stealth #=Diagnostics $=Autostop %%=Angle\n");
printf ("  ^=Up &=Down -=+/- |=Straight ;=FBMode [=Off ]=On <=Left >=Right\n");
printf ("  a=Auto c=Clear d=Demo f=Forward h=Halt i=Intensity l=Lights\n");
printf ("  m=Manual p=Power q=Query r=Reverse s=Speed t=TravelMode z=Mode\n");
printf ("  '=Repeat\n\n");

printf (" b to enter battery level (0..255), * to enter charging level\n\n");

printf ("Press ? for help or x to exit\n\n");
}
/* End of PrintHelp */


static int getU8 (void)
{
char Char;
unsigned int NumDigs;
int Value;

NumDigs = 0;
for (;;)
	{
#ifdef TARGET_WIN32
	Char = (char)getche ();
#endif	
	if (isdigit (Char) && NumDigs<3) {
		Value = 10*Value + (Char-'0');
		++NumDigs;
		}
	else if (Char==13 && NumDigs > 0)
		return Value;
	else
		return -1;
	}
}


/* Enter into ir mode which accepts commands from the keyboard. */
#ifdef TARGET_WIN32
main ()
#else
void irmode ()
#endif
{
char ThisChar;
unsigned int ThisKey;
int ThisValue;

static const char *KeyName[] = {
	"0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
	"Clear", "Plus/Minus", "Up", "Down", "Mode", "Help", "Lights", "Power",
	"On", "Off", "Auto", "Manual", "Right", "Left", "FB", "TM", "Demo", "Query",
	"Halt", "Enter", "AS", "Diag", "Forward", "Reverse", "Speed", "Angle",
	"Intensity", "Stealth", "Straight"};

PrintHelp ();
InitIO ();
InitLCD ();
InitSpeak ();
InitIRControl ();
InitControls ();
InitBrain ();
for (;;)
	{
#ifdef TARGET_WIN32
	ThisChar = (char)getche ();
#else
	ThisChar = getcomputerchar();
#endif
	ThisKey = 255;
	if (isdigit (ThisChar))
		ThisKey = ThisChar - '0';
	else switch (toupper(ThisChar))
		{
		case '?': ThisKey = 254; break; // will print help message
		case '\'': ThisKey = 252; break;
		case '/': ThisKey = IR_R_HELP; break;
		case '!': ThisKey = IR_R_STEALTH; break;
		case '#': ThisKey = IR_R_DIAGNOSTICS; break;
		case '$': ThisKey = IR_R_AUTOSTOP; break;
		case '%': ThisKey = IR_R_ANGLE; break;
		case '-': ThisKey = IR_R_PLUS_MINUS; break;
		case '[': ThisKey = IR_R_OFF; break;
		case ']': ThisKey = IR_R_ON; break;
		case '<': ThisKey = IR_R_LEFT; break;
		case '>': ThisKey = IR_R_RIGHT; break;
		case '|': ThisKey = IR_R_STRAIGHT; break;
		case '^': ThisKey = IR_UP; break;
		case '&': ThisKey = IR_DOWN; break;
		case ';': ThisKey = IR_R_FRONT_BACK_MODE; break;
		case 'A': ThisKey = IR_R_AUTO; break;
		case 'C': ThisKey = IR_R_CLEAR; break;
		case 'D': ThisKey = IR_R_DEMO; break;
		case 'F': ThisKey = IR_R_FORWARD; break;
		case 'H': ThisKey = IR_R_HALT; break;
		case 'I': ThisKey = IR_R_INTENSITY; break;
		case 'L': ThisKey = IR_R_LIGHTS; break;
		case 'M': ThisKey = IR_R_MANUAL; break;
		case 'P': ThisKey = IR_R_POWER; break;
		case 'Q': ThisKey = IR_R_QUERY; break;
		case 'R': ThisKey = IR_R_REVERSE; break;
		case 'S': ThisKey = IR_R_SPEED; break;
		case 'T': ThisKey = IR_R_TRAVEL_MODE; break;
		case 'X': goto ExitNow; break;
		case 'Z': ThisKey = IR_R_MODE; break;
		case 13: ThisKey = IR_R_ENTER; break;

		case 'B': ThisValue = getU8();
			if (ThisValue == -1)
				printf ("Battery level is %u.\n", BatteryLevel);
			else
				ActionNewBatteryLevel ((U8)ThisValue);
			ThisKey = 253; // so ignored later
			break;
		case '*': ThisValue = getU8();
			if (ThisValue == -1)
				printf ("Charging level is %u.\n", ChargingLevel);
			else
				ActionNewChargingLevel ((U8)ThisValue);
			ThisKey = 253; // so ignored later
			break;
		}

	if (ThisKey == 255)
		printf ("Nothing assigned -- key ignored\n");
	else if (ThisKey == 254)
		PrintHelp ();
	else if (ThisKey != 253)
		{
		if (ThisKey==252) {
			ThisKey=IR_REPEAT;
			printf ("<Repeat>  ");
			}
		else
			printf ("<%s> ", KeyName[ThisKey]);
		HandleIRKey ((U8)ThisKey, 0);
		printf (" BM=%u, BStat=%u, BStg=%u, IRStat=%u, ISM=%u, ES=%u, NEC=%u, DM=%u\n\n", BrainMode, BrainStatus, BrainStage, IRControlStatus, InIRSpecialMode, IREntryStatus, NumEnteredIRCharacters, DiagnosticMode);
		}

	UpdateIRControl ();
	UpdateControls ();
	UpdateBrain ();
	UpdateIO ();
	UpdateLCD ();
	}
ExitNow:;
}

/* End of main */


/***** End of IRControl.c *****/
