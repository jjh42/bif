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
*	Mod. Number: 16
*	Last Modified: 5 November 2001
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
* Notes
*
*****************************************************/

// Frequencies in Hz
#define A_1 220
#define Bb_1 233
#define B_1 247
#define C_1 262
#define Db_1 277
#define D_1 294
#define Eb_1 311
#define E_1 330
#define F_1 349
#define Gb_1 370
#define G_1 392
#define Ab_1 415
#define A_2 440
#define Bb_2 466
#define B_2 494
#define C_2 523
#define Db_2 554
#define D_2 587
#define Eb_2 622
#define E_2 659
#define F_2 698
#define Gb_2 740
#define G_2 784
#define Ab_2 831
#define A_3 880
#define Bb_3 932
#define B_3 988
#define C_3 1047
#define Db_3 1109
#define D_3 1175
#define Eb_3 1245
#define E_3 1319
#define F_3 1397
#define Gb_3 1480
#define G_3 1568
#define Ab_3 1661
#define A_4 1760
#define Bb_4 1865
#define B_4 1975

// Times in tenths of seconds
#define SEMIQUAVER 1
#define QUAVER (2*SEMIQUAVER)
#define CROTCHET (4*SEMIQUAVER)
#define MINIM (8*SEMIQUAVER)
#define DOTTED_MINIM (12*SEMIQUAVER)
#define SEMIBREVE (16*SEMIQUAVER)


/*****************************************************
*
* Global variables
*
*****************************************************/

U8 CurrentOutputLanguage;
#define ENGLISH 0
#ifdef INCLUDE_MATIGSALUG
#define MATIGSALUG 1
#endif

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

//void InitSoundQueue (void);
void FlushSoundQueue (void);
void QueueSound (U8 SoundNumber);
void OutOverrideChar (void);

#define Beep beep
//void Beep (U8 Waveform, U16 Freq, U8 Time); // Interrupts
void ErrorBeep (void);
void Tone (U8 Waveform, U16 Freq, U8 Time); // Queued -- call FlushSoundQueue after this

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

#ifdef INCLUDE_MATIGSALUG
// In Matigsalug.c
void SayMatigsalugText (BOOL Override, char *Text);
#endif

//void SayASCII (int character);
//void SpellWord (char *word);
//void SayCardinal (long Value);
//void SayOrdinal (long Value);

#endif

/***** End of Speak.h *****/
/*** endheader */

