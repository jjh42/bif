/*** Beginheader */

#ifndef SPEAK_H
#define SPEAK_H

/*****************************************************
*
*	Name: Speak.h
*	Description: Definitions for speech control
*	Author: Robert Hunt
*	Created: August 2001
*
*	Mod. Number: 14
*	Last Modified: 28 September 2001
*	Modified by: Robert Hunt
*
******************************************************/

#include "sounds.h"
#include "slave-speech.h"


/*****************************************************
*
* Public Constants
*
*****************************************************/

#define NEED_CURRENCIES 0 // We don't need currencies

// Note: These definitions assume a U8 field (not a 16-bit one)
#define SP_LITERAL 254
#define SP_OVERRIDE 255

#define SPO "\xff"
#define SPX "\xfe"


/*****************************************************
*
* Global variables
*
*****************************************************/

U8 CurrentOutputLanguage;
#define ENGLISH 0
#define MATIGSALUG 1

BOOL PronouncePunctuationMarks;

#define MAX_SPEAK_STRING_LENGTH 100 // Most utterances fit in this length
char MakeupSpeakString[MAX_SPEAK_STRING_LENGTH+1]; // Plus room for the terminating null

char *SayString; // A general pointer to a string to say


/*****************************************************
*
* Function Prototypes
*
*****************************************************/

void InitSpeak (void);

void InitSoundQueue (void);
void FlushSoundQueue (void);
void QueueSound (U8 SoundNumber);
void OutOverrideChar (void);

char *GetOffOnString (BOOL goosValue);
char *GetManAutoString (BOOL gmasValue);

void SayOff (BOOL Override);
void SayOn (BOOL Override);
void SayOffOn (BOOL Override, BOOL sooValue);
void SayManual (BOOL Override);
void SayAutomatic (BOOL Override);
void SayNormal (BOOL Override);
void SayLights (BOOL Override);

void SayMakeupSpeakString (BOOL Override);
void SayEnglishMakeupSpeakString (BOOL Override);
void xSay (BOOL Override, const_char_xmem_ptr_t xSString);
void xSayEnglish (BOOL Override, const_char_xmem_ptr_t xSString);


// In English.c
void SayEnglishText (BOOL Override, char *Text);
// In Matigsalug.c
void SayMatigsalugText (BOOL Override, char *Text);

//void SayASCII (int character);
//void SpellWord (char *word);
//void SayCardinal (long Value);
//void SayOrdinal (long Value);

#endif

/***** End of Speak.h *****/
/*** endheader */

