/*** Beginheader */
#ifndef Brain_H
#define Brain_H

/*****************************************************
*
*	Name: Brain.h
*	Description: Definitions for highest level control
*	Author: Robert Hunt
*	Created: August 2001
*
*	Mod. Number: 16
*	Last Modified: 8 October 2001
*	Modified by: Robert Hunt
*
******************************************************/

/*****************************************************
*
* Public Constants
*
*****************************************************/

// For some TELL routines
#define TELL_NORMAL 0
#define TELL_NEW_SETTING 1


/*****************************************************
*
* Global variables
*
*****************************************************/

BOOL DiagnosticMode;

U8 BrainMode;
#define BRAIN_M_HALTED 0
#define BRAIN_M_NORMAL 1
#define BRAIN_M_MANUAL 2
#define BRAIN_M_GO_HOME 3
#define BRAIN_M_SHOW_OFF 4
#define BRAIN_M_EXPLORE 5
#define BRAIN_M_CHASE_LIGHT 6
#define BRAIN_M_ESCAPE_LIGHT 7
#define BRAIN_M_CHASE_SOUND 8
#define BRAIN_M_ESCAPE_SOUND 9
#define BRAIN_M_RANDOM 10
#define BRAIN_M_REBEL 11
#define NUM_BRAIN_MODES 12

U8 BrainStatus;
#define BRAIN_S_STARTUP 0
#define BRAIN_S_IDLE 1
#define BRAIN_S_WFC 2 // Waiting For Completion of previous movement
#define BRAIN_S_WAM 3 // Wait a Moment

U8 BrainStage; // Used for modes that step through various stages

U8 Naughtiness; // 1..9 A factor that determines how naughty the robot is in REBEL mode

U8 Verbosity;
#define VERBOSITY_SILENT 0
#define VERBOSITY_QUIET 1
#define VERBOSITY_NORMAL 2
#define VERBOSITY_TALKATIVE 3


/*****************************************************
*
* Function Prototypes
*
*****************************************************/

// In Brain.c
void InitBrain (void); /* First time initialization */
void SetBrainMode (U8 NewMode);
void TellBrainMode (void);
void ReinitiateBrainFunction (void); // Restarts the activity depending on the mode
void UpdateBrain (void); /* Checks for what needs doing */

// In Tell.c
char *GetSwitchName (U16 SwitchID);

void Greet (void);
void TellVersion (void);

void TellPower (void);
void TellDefaultDistance (void);
void TellDefaultSpeed (void);
void TellDefaultAngle (U8 tdaSetting);
void TellLights (void);
void TellHeadlightIntensity (void);
void TellStealthMode (void);
void TellDiagnosticMode (void);
void TellFrontBack (void);
void TellFrontBackMode (void);
void TellAutostopMode (void);
void TellTravelMode (void);
void TellCompassOrientation (void);
void TellTime (void);
void TellDate (void);
void TellTemperature (void);

// In Help.c
void DoModeIRHelp (void);
void DoQueryIRHelp (void);
void DoPowerIRHelp (void);
void DoLightsIRHelp (void);


#endif


/***** End of Brain.h *****/
/*** endheader */