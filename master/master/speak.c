

/* Dummy headers for Dynamic C */
/*** Beginheader speak_c */
#ifdef TARGET_RABBIT
void speak_c();

#asm
xxxspeak_c: equ speak_c
#endasm
#endif /* TARGET_RABBIT */
/*** endheader */

#ifdef TARGET_RABBIT
void speak_c () { }
#endif /* TARGET_RABBIT */


/*****************************************************
*
*	Name:	Speech synthesis (Speak.c)
*	Description: Speech synthesiser code
*	Author: Robert Hunt
*	Created: August 2001
*
*	Mod. Number: 18
*	Last Modified: 10 November 2001
*	Modified By: Robert Hunt
*
******************************************************/

#include <stdio.h>
#include <string.h>

/* Our include files */
#include "compat.h"
#include "speak.h"
#include "Brain.h"


#define SB_LENGTH 20
static unsigned char SoundBuffer[SB_LENGTH+1];


/*****************************************************/


#if 0
nodebug void InitSoundQueue (void)
{
//printf (" InitSQ ");
SoundBuffer[0] = '\0';
}
/* End of InitSoundQueue */
#endif


/*****************************************************

* Function Name: FlushSoundQueue
* Description: Sends the sound/tone queue contents to the speech slave
* Argument: None
* Return Value: None
*
*****************************************************/

void FlushSoundQueue (void)
{
#ifndef TARGET_RABBIT // for diagnostics
unsigned int kk;
const char *SoundName[] = {
/*   1 */	"GLOT ", "SHRTP ", " WRDP ", " SENTP ",
/*   5 */	"IY", "EY", "AE", "AO", "UH", "ER", "AH", "AW", "IH",
/*  14 */	"EH", "AA", "OW", "UW", "AX", "AY", "OY", "OX", "UU",
/*  23 */	"p", "t", "k", "f", "TH", "s", "SH", "h", "n", "l", "y", "CH",
/*  35 */	"WH", "b", "d", "g", "v", "DH", "z", "ZH", "m", "NG", "w", "r", "j",
/*  48 */	"point ", "zero ", "one ", "two ", "three ", "four ", "five ", "six ", "seven ",
/*  57 */	"eight ", "nine ", "ten ", "eleven ", "twelve ", "thirteen ", "fourteen ", "fifteen ",
/*  65 */	"sixteen ", "seventeen ", "eighteen ", "nineteen ", "twenty ", "thirty ", "forty ",
/*  72 */	"fifty ", "sixty ", "seventy ", "eighty ", "ninety ", "hundred ", "thousand ", "million ",
/*  80 */	"first ", "second ", "third ",
/*  83 */	"day ", "Mon", "chews ", "Wednes", "Thurs", "fry ", "Satur", "sun ",
/*  91 */	"January ", "February ", "march ", "April ", "may ", "June ",
/*  97 */	"July ", "August ", "September ", "October ", "November ", "December ",
/* 103 */	"a ", "the ", "am ", "is ", "are ", "and ", "but ", "not ", "yet ", "at ", "in ",
/* 114 */	"yes ", "no ", "off ", "on ", "low ", "high ", "left ", "right ", "forward ", "reverse ",
/* 124 */	"stop ", "go ", "front ", "back ", "automatic ", "manual ",
/* 130 */	"big ", "small ", "chase ", "escape ",
/* 134 */	"attack ", "retreat ", "reset ", "clear ", "enter ", "number ", "digit ", "letter ",
/* 142 */	"valid ", "correct ", "random ", "normal ", "test ", "full ",
/* 148 */	"query ", "speak ", "mode ", "diagnostic ", "light ", "power ", "speed ", "stealth ",
/* 156 */	"intensity ", "distance ", "position ", "switch ", "bumper ", "tilt ", "battery ",
/* 163 */	"level ", "charge ", "charging ", "travel ", "turn ", "straight ", "angle ", "circle ",
/* 171 */	"extreme ", "demo ", "help ", "error ", "hello ", "halt ", "sorry ", "name ",
/* 179 */	"robot ", "brain ", "version ", "date ", "time ",
/* 184 */	"lattitude ", "longitude ", "bearing ", "temperature ", "Celsius ", "Fahrenheit ",
/* 190 */	" millimetre ", "degree ", "hour ", "minute ", "oops ", "Ouch ",
/* 196 */	"_eg ", "_ig", "ka ", "kag ", "ke ", "keg ", "ki ", "ku ", "kun ",
/* 205 */	"lug ", "ma ", "me ", "mig ", "na ", "ne ", "neg ", "ni ",
/* 213 */	"pa ", "pe ", "sa ", "se ", "si ", "su ", "te ", "teg ", "tig ", "wey ",
/* 223 */	"ware ", "sabeka ", "daruwa ", "tatelu ", "hep_at ", "lalimma ",
/* 229 */	"hen_em ", "pitu ", "walu ", "siyam ", "sapulu ",
/* 234 */	"pulu ", "gatus ", "libu ", "dakel ", "deisek ", "diye ", "kayi ",
/* 241 */	"kene ", "keneg ", "kenen ", "kuntee ", "meupiya ", "sulu ",
/* 247 */	"tuyu ", "uya ", "warad "
	};
if (SoundBuffer[0] != '\0') { // There's something in it
	printf ("Saying ");
	for (kk=0; kk<strlen(SoundBuffer); ++kk)
		if (SoundBuffer[kk]<=sizeof(SoundName)/sizeof(char *))
			printf (SoundName[SoundBuffer[kk]-1]);
		else
			printf ("%u ", SoundBuffer[kk]);
	}
#endif

if (SoundBuffer[0] != '\0') { // There's something in it
	saysounds (SoundBuffer);
	SoundBuffer[0] = '\0'; // Empty the buffer
	}
}
/* End of FlushSoundQueue */


/*****************************************************

* Function Name: QueueSound
* Description: Queues a sound to go to the speech slave
* Argument: Sound ID to be queued
* Return Value: None
*
* The purpose of this routine is to reduce the number of short messages to
*	the sound slave by combining them into a queue first
* Must call FlushSoundQueue after this to send queued sounds to the speech slave
*
*****************************************************/

void QueueSound (U8 SoundNumber)
{
int QueueLength;
if (Verbosity != VERBOSITY_SILENT) {
	QueueLength = strlen (SoundBuffer);
	//printf (" QL is %d, added %u ", QueueLength, SoundNumber);

	// Append the sound to the buffer
	if ((QueueLength > 0)
	 && (SoundNumber == SentencePause[0])
	 && (SoundBuffer[QueueLength-1] == WordPause[0]))
		// Replace word pause with sentence pause
	 	SoundBuffer[QueueLength-1] = SentencePause[0];
	 	// Of course this code might miss some if the buffer was just flushed but it's not important
	else { // not sentence pause
		SoundBuffer[QueueLength] = SoundNumber;
		SoundBuffer[++QueueLength] = '\0';
		}

	// Send the buffer if it's full
	if (QueueLength >= SB_LENGTH)
		FlushSoundQueue ();
	}
}
/* End of QueueSound */


/*****************************************************

* Function Name: OutOverrideChar
* Description: Clears the speech queue
* Argument: None
* Return Value: None
*
*****************************************************/

void OutOverrideChar (void)
{
QueueSound (SP_OVERRIDE);
}
/* End of OutOverrideChar */


/*****************************************************

* Function Name: Tone
* Description: Queues a tone (after any speech in progress)
* Arguments: Waveform, Frequency, Time
* Return Value: None
*
* Must call FlushSoundQueue after this
*
*****************************************************/

void Tone (U8 Waveform, U16 Freq, U8 Time) // Queues after anything in progress -- must call FlushSoundQueue after this
{
QueueSound (0xFE); // Tone
QueueSound ((U8)(Waveform + 1));
QueueSound ((U8)((Freq >> 8) + 1));
QueueSound ((U8)((Freq & 0xFF) + 1));
QueueSound ((U8)(Time + 1));
}
/* End of Tone */


/*****************************************************

* Function Name: ErrorBeep
* Description: Does an error beep
* Argument: None
* Return Value: None
*
*****************************************************/

void ErrorBeep (void)
{
	Beep (SQUARE_WAVE, Beep800Hz, Beep0s2);
	Beep (SQUARE_WAVE, Beep1200Hz, Beep0s2);
}
/* End of ErrorBeep */


/*****************************************************

* Function Name: SaySayString
* Description: Says SayString in the current output language
* Argument: None
* Return Value: None
*
*****************************************************/

void SaySayString (BOOL Override)
{
switch (CurrentOutputLanguage)
	{
#ifdef INCLUDE_MATIGSALUG
	case MATIGSALUG:
		SayMatigsalugText (Override, SayString); break;
#endif
	default: // default to English
		SayEnglishText (Override, SayString); break;
	}
}
/* End of SaySayString */


/*****************************************************

* Function Name: SayMakeupSpeakString
* Description: Says MakeupSpeakString in the current output language
* Argument: TRUE to override any still unfinished utterances
* Return Value: None
*
*****************************************************/

void SayMakeupSpeakString (BOOL Override)
{
assert (strlen(MakeupSpeakString)<=MAX_SPEAK_STRING_LENGTH);
SayString = MakeupSpeakString;
SaySayString (Override);
}
/* End of SayMakeupSpeakString */


/*****************************************************

* Function Name: SayEnglishMakeupSpeakString
* Description: Says MakeupSpeakString in English
* Argument: TRUE to override any still unfinished utterances
* Return Value: None
*
*****************************************************/

void SayEnglishMakeupSpeakString (BOOL Override)
{
assert (strlen(MakeupSpeakString)<=MAX_SPEAK_STRING_LENGTH);
SayEnglishText (Override, MakeupSpeakString);
}
/* End of SayEnglishMakeupSpeakString */


/*****************************************************

* Function Name: xSay
* Description: Says the string in the current output language
* Arguments: TRUE to override any still unfinished utterances
*		 Xmem pointer to character string in xmem
* Return Value: None
*
* Note: Automatically breaks up long strings so no limit on parameter string length
*
*****************************************************/

void xSay (BOOL Override, const_char_xmem_ptr_t xSString)
{
char *LastCharPointer;

// Copy the string into root memory and then say it
for (;;) {
	// Get a section of the string
	xmem2root (MakeupSpeakString, xSString, sizeof(MakeupSpeakString)-1); // Leave room to add a null
	MakeupSpeakString[sizeof(MakeupSpeakString)-1] = '\0'; // Add a terminating null so strlen always works
	if (strlen(MakeupSpeakString)<sizeof(MakeupSpeakString)-1) {
		// This is the final section because it fitted completely in MakeupSpeakString
		//printf (" xSay (done) MuSS=<%s>", MakeupSpeakString);
		SayMakeupSpeakString (Override);
		break; // done
		}
	// There's still more of the string to go -- we've only got a portion of it
	printf (" xsay got MuSS=<%s>", MakeupSpeakString);
	// Work back from the end until we find a space (so don't try to pronounce half a word)
	LastCharPointer = MakeupSpeakString + sizeof(MakeupSpeakString)-1; // Point to the null we predecrement the pointer below
	assert (*LastCharPointer == '\0');
	while (--LastCharPointer != MakeupSpeakString) {
		if (*LastCharPointer == ' '){
			*LastCharPointer = '\0'; // Truncate the string (loosing the space)
			xSString += strlen(MakeupSpeakString) + 1; // Go to next char after space
			break;
			}
		}
	assert (LastCharPointer != MakeupSpeakString); // Presumably there should have always been a space
	//printf (" xSay MuSS=<%s>", MakeupSpeakString);
	SayMakeupSpeakString (Override);
	}
}
/* End of xSay */


/*****************************************************

* Function Name: xSayEnglish
* Description: Says the string in English (regardless of the current output language)
* Arguments: TRUE to override any still unfinished utterances
*		 Xmem pointer to character string in xmem
* Return Value: None
*
* Note: xSay automatically breaks up long strings so no limit on parameter string length
*
*****************************************************/

void xSayEnglish (BOOL Override, const_char_xmem_ptr_t xSEString)
{
U8 SavedOutputLanguage;

// Temporarily switch to English, say it, then switch back
SavedOutputLanguage = CurrentOutputLanguage;
CurrentOutputLanguage = ENGLISH;
xSay (Override, xSEString);
CurrentOutputLanguage = SavedOutputLanguage; // Restore it again
}
/* End of xSayEnglish */


/*****************************************************
*
* Function Name: InitSpeak
* Description: Initialise the speech synthesis (called from main)
* Arguments: None
* Return Value: None
*
*****************************************************/

nodebug void InitSpeak (void)
{
SoundBuffer[0] = '\0';

PronouncePunctuationMarks = FALSE;

CurrentOutputLanguage = ENGLISH;
}

/* End of InitSpeak */


/*****************************************************
*
* Function Name: GetOffOnString
* Description: Returns a pointer to an "off" or "on" string
* Argument: BOOL Value (FALSE = off, TRUE = on)
* Return Value: Pointer to string in current output language
*
*****************************************************/

nodebug char *GetOffOnString (BOOL goosValue)
{
switch (CurrentOutputLanguage)
	{
#ifdef INCLUDE_MATIGSALUG
	case MATIGSALUG:
		return goosValue ? "un" : "uf"; break;
#endif
	default: // default to English
		return goosValue ? "on" : "off"; break;
	}
}
/* End of GetOffOnString */


/*****************************************************
*
* Function Name: GetManAutoString
* Description: Returns a pointer to an "manual" or "automatic" string
* Argument: BOOL Value (FALSE = manual, TRUE = automatic)
* Return Value: Pointer to string in current output language
*
*****************************************************/

nodebug char *GetManAutoString (BOOL gmasValue)
{
switch (CurrentOutputLanguage)
	{
#ifdef INCLUDE_MATIGSALUG
	case MATIGSALUG:
		return gmasValue ? "automatic" : "manual"; break;
#endif
	default: // default to English
		return gmasValue ? "automatic" : "manual"; break;
	}
}
/* End of GetManAutoString */


/*****************************************************
*
* Function Name: SayOff
* Description: Says "Off" in the current output language
* Argument: TRUE to override any still unfinished utterances
* Return Value: None
*
*****************************************************/

nodebug void SayOff (BOOL Override)
{
SayString = GetOffOnString (FALSE);
SaySayString (Override);
}
/* End of SayOff */


/*****************************************************
*
* Function Name: SayOn
* Description: Says "On" in the current output language
* Argument: TRUE to override any still unfinished utterances
* Return Value: None
*
*****************************************************/

nodebug void SayOn (BOOL Override)
{
SayString = GetOffOnString (TRUE);
SaySayString (Override);
}
/* End of SayOn */


/*****************************************************
*
* Function Name: SayOffOn
* Description: Says "Off" or "On" in the current output language
* Arguments: TRUE to override any still unfinished utterances
*		 Boolean value (0=Off)
* Return Value: None
*
*****************************************************/

void SayOffOn (BOOL Override, BOOL sooValue)
{
SayString = GetOffOnString (sooValue);
SaySayString (Override);
}
/* End of SayOffOn */


/*****************************************************
*
* Function Name: SayManual
* Description: Says "Manual" in the current output language
* Argument: TRUE to override any still unfinished utterances
* Return Value: None
*
*****************************************************/

void SayManual (BOOL Override)
{
SayString = GetManAutoString (FALSE);
SaySayString (Override);
}
/* End of SayManual */


/*****************************************************
*
* Function Name: SayAutomatic
* Description: Says "Automatic" in the current output language
* Argument: TRUE to override any still unfinished utterances
* Return Value: None
*
*****************************************************/

void SayAutomatic (BOOL Override)
{
SayString = GetManAutoString (TRUE);
SaySayString (Override);
}
/* End of SayAutomatic */


/*****************************************************
*
* Function Name: SayNormal
* Description: Says "Normal" in the current output language
* Argument: TRUE to override any still unfinished utterances
* Return Value: None
*
*****************************************************/

void SayNormal (BOOL Override)
{
switch (CurrentOutputLanguage)
	{
#ifdef INCLUDE_MATIGSALUG
	case MATIGSALUG:
		SayString = "nurmal"; break;
#endif
	default: // default to English
		SayString = "normal"; break;
	}
SaySayString (Override);
}
/* End of SayNormal */


/*****************************************************
*
* Function Name: SayLights
* Description: Says "Lights" in the current output language
* Argument: TRUE to override any still unfinished utterances
* Return Value: None
*
*****************************************************/

nodebug void SayLights (BOOL Override)
{
switch (CurrentOutputLanguage)
	{
#ifdef INCLUDE_MATIGSALUG
	case MATIGSALUG:
		SayString = "sulu"; break;
#endif
	default: // default to English
		SayString = "lights"; break;
	}
SaySayString (Override);
}
/* End of SayLights */


/***** End of Speak.c *****/
