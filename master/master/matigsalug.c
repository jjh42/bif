

/* Dummy headers for Dynamic C */
/*** Beginheader matigsalug_c */
#ifdef TARGET_RABBIT
void matigsalug_c();

#asm
xxxmatigsalug_c: equ matigsalug_c
#endasm
#endif /* TARGET_RABBIT */
/*** endheader */

#ifdef TARGET_RABBIT
void matigsalug_c () { }
#endif /* TARGET_RABBIT */


/*****************************************************
*
*	Name:	Matigsalug.c
*	Description: 
*	Adapted by: Robert Hunt
*	Created: September 2001
*
*	Mod. Number: 12
*	Last Modified: 14 October 2001
*	Modified By: Robert Hunt
*
* Current problems:
*	Doesn't handle long vowels
*	Doesn't handle special cases yet (might speak English instead)
*	Doesn't yet match ASCII characters, especially digits after a point
*	Sends a word pause immediately before a sentence pause
*	Not optimized at all
*
************************************************************************
**
**	Special symbols are:
**		_ for glottal stop (word beginning/end)
**		- for glottal stop (mid-word)
**		: indicates long vowel (e.g. pa:n)
**		# internal representation for ng
**	Breaks each word up into CV or CVC syllables
**		(Exclamation mark represents glottal stop)
**	Checks through the list for prerecorded syllables
**		else synthesises the syllable
**
**	The four vowels are a e i u.
**	The consonants are _ (glottal) b d g h k l m n ng p r s t w y.
**	The other letters are c f j o q v x z.
**
**********************************************************************/

#include <stdio.h>
#include <ctype.h>
#include <string.h>

#include "compat.h"
#include "sounds.h"
#include "speak.h"
#include "soundcontrol.h"


// In English.c
void OutRecordedWordString (constparam char *string);
void OutString (constparam char *string);
BOOL isvowel (char chr);
char makeupper(int character);


// Global variables for this module
static char *MTextPointer;
static int MChar, MChar1, MChar2, MChar3;

#define MAX_MS_SYLLABLE_LENGTH 8
#define MAX_MS_WORD_LENGTH 30

#define NG '#'
#define GLOTTAL '_'


XSTRING(LetterToPhoneme)
	{
	"AX", "b", "k", "d", "OX", "f", "g", "h", "IY", "j", "k", "l", "m",
	"n", "OX", "p", "q", "r", "s", "t", "UU", "v", "w", "x", "y", "z"
	};

// The following are still in English -- not finished yet ....... xxxxxx temp
XSTRING(Cardinals)
	{
	"zIHrOW ",	"wAHn ",	"tUW ",		"THrIY ",
	"fOWr ",	"fAYv ",	"sIHks ",	"sEHvAXn ",
	"EYt ",		"nAYn ",		
	"tEHn ",	"IYlEHvAXn ",	"twEHlv ",	"THERtIYn ",
	"fOWrtIYn ",	"fIHftIYn ", 	"sIHkstIYn ",	"sEHvEHntIYn ",
	"EYtIYn ",	"nAYntIYn "
	} ;

XSTRING(Twenties)
	{
	"twEHntIY ",	"THERtIY ",	"fAOrtIY ",	"fIHftIY ",
	"sIHkstIY ",	"sEHvEHntIY ",	"EYtIY ",	"nAYntIY "
	} ;

XSTRING(MOrdinals)
	{
	"zIHrOWEHTH ",	"fERst ",	"sEHkAHnd ",	"THERd ",
	"fOWrTH ",	"fIHfTH ",	"sIHksTH ",	"sEHvEHnTH ",
	"EYtTH ",	"nAYnTH ",		
	"tEHnTH ",	"IYlEHvEHnTH ",	"twEHlvTH ",	"THERtIYnTH ",
	"fAOrtIYnTH ",	"fIHftIYnTH ", 	"sIHkstIYnTH ",	"sEHvEHntIYnTH ",
	"EYtIYnTH ",	"nAYntIYnTH "
	} ;

XSTRING(MOrd_twenties)
	{
	"twEHntIYEHTH ","THERtIYEHTH ",	"fOWrtIYEHTH ",	"fIHftIYEHTH ",
	"sIHkstIYEHTH ","sEHvEHntIYEHTH ","EYtIYEHTH ",	"nAYntIYEHTH "
	} ;

XSTRING(MAscii)
	{
"nUWl ","stAArt AXv hEHdER ","stAArt AXv tEHkst ","EHnd AXv tEHkst ",
"EHnd AXv trAEnsmIHSHAXn",
"EHnkwAYr ","AEk ","bEHl ","bAEkspEYs ","tAEb ","lIHnIYfIYd ",
"vERtIHkAXl tAEb ","fAOrmfIYd ","kAErAYj rIYtERn ","SHIHft AWt ",
"SHIHft IHn ","dIHlIYt ","dIHvIHs kAAntrAAl wAHn ","dIHvIHs kAAntrAAl tUW ",
"dIHvIHs kAAntrAAl THrIY ","dIHvIHs kAAntrAAl fOWr ","nAEk ","sIHnk ",
"EHnd tEHkst blAAk ","kAEnsEHl ","EHnd AXv mEHsIHj ","sUWbstIHtUWt ",
"EHskEYp ","fAYEHld sIYpERAEtER ","grUWp sIYpERAEtER ","rIYkAOrd sIYpERAEtER ",
"yUWnIHt sIYpERAEtER ","spEYs ","EHksklAEmEYSHAXn mAArk ","dAHbl kwOWt ",
"nUWmbER sAYn ","dAAlER sAYn ","pERsEHnt ","AEmpERsAEnd ","kwOWt ",
"OWpEHn pEHrEHn ","klOWz pEHrEHn ","AEstEHrIHsk ","plAHs ","kAAmmAX ",
"mIHnAHs ","pIYrIYAAd ","slAESH ",

"zIHrOW ","wAHn ","tUW ","THrIY ","fOWr ",
"fAYv ","sIHks ","sEHvAXn ","EYt ","nAYn ",

"kAAlAXn ","sEHmIHkAAlAXn ","lEHs DHAEn ","EHkwAXl sAYn ","grEYtER DHAEn ",
"kwEHsCHAXn mAArk ","AEt sAYn ",

"EY ","bIY ","sIY ","dIY ","IY ","EHf ","jIY  ",
"EYtCH ","AY ","jEY ","kEY ","EHl ","EHm ","EHn ","AA ","pIY ",
"kw ","AAr ","EHz ","tIY ","AHw ","vIY ",
"dAHblyUWw ","EHks ","wAYIY ","zIY ",

"lEHft brAEkEHt ","bAEkslAESH ","rAYt brAEkEHt ","kAErEHt ",
"AHndERskAOr ","AEpAAstrAAfIH ",

"EY ","bIY ","sIY ","dIY ","IY ","EHf ","jIY  ",
"EYtCH ","AY ","jEY ","kEY ","EHl ","EHm ","EHn ","AA ","pIY ",
"kw ","AAr ","EHz ","tIY ","AHw ","vIY ",
"dAHblyUWw ","EHks ","wAYIY ","zIY ",

"lEHft brEYs ","vERtIHkAXl bAAr ","rAYt brEYs ","tAYld ","dEHl "
	};


const_xmem_ptr_t MatchPrerecordedMSWord (char *word) // Returns 0 if no match
{
	char lcWord[MAX_MS_WORD_LENGTH+1];
	unsigned int y;
	int CompareResult;
	char tmp[MAX_MS_WORD_LENGTH+1];
	const_xmem_ptr_t TheRecordedWord;

	//printf ("MatchPrecordedWord <%s> ", word);
	assert (strlen(word)<=MAX_MS_WORD_LENGTH);

	/* Check for prerecorded words */
	TheRecordedWord = XACCESS(MRecordedWord, 0);
	// Convert to lower case for comparisons
	y = 0;
	while (word[y] != '\0') {
		lcWord[y] = (char)tolower (word[y]);
		++y;
		}
	lcWord[y] = '\0'; // Append the final null

	y = 0;
        for(;;) {
                xmem2root(tmp, TheRecordedWord, sizeof(tmp));
                if(*tmp == 0)
                        break; // End of list
		CompareResult = strcmp (lcWord, tmp);
//printf (" Compare <%s> with <%s>=%d ", lcWord, tmp, CompareResult);
		if (CompareResult < 0) // gone too far in sorted list
			break;
		if (CompareResult == 0) {// matched
//printf ("Matched prerecorded MS word <%s> ", lcWord);
			return XACCESS(MRecordedWord, ((y * 2) + 1));
		}
	TheRecordedWord = XACCESS(MRecordedWord, ((++y) * 2));
	}

	// If we get here, we didn't get a match
	//printf (" No prerecorded MS <%s> ", lcWord);
	return 0;
}
/* End of MatchPrerecordedMSWord */


const_xmem_ptr_t MatchPrerecordedMSSyllable (char syllable[]) // Returns 0 if no match
{
	char lcSyllable[MAX_MS_SYLLABLE_LENGTH+1];
	unsigned int y;
	int CompareResult;
	char tmp[MAX_MS_SYLLABLE_LENGTH+1];
	const_xmem_ptr_t TheRecordedSyllable;

//printf (" MatchPrerecordedMSSyllable(%s) ", syllable);
	assert (strlen(syllable)<=MAX_MS_SYLLABLE_LENGTH);

	/* Check for prerecorded syllables */
	TheRecordedSyllable = XACCESS(RecordedSyllable, 0);

	// Convert to lower case for comparisons
	y = 0;
	while (syllable[y] != '\0') {
		lcSyllable[y] = (char)tolower (syllable[y]);
		++y;
		}
	lcSyllable[y] = '\0'; // Append the final null

	y = 0;
        for(;;) {
		xmem2root(tmp, TheRecordedSyllable, sizeof(tmp));
		if (*tmp == 0)	// Exit loop
			break;
		CompareResult = strcmp (lcSyllable, tmp);
//printf (" Compare <%s> with <%s>=%d ", lcSyllable, tmp, CompareResult);	
		if (CompareResult < 0) // gone too far in sorted list
			break;
		if (CompareResult == 0) {// matched
//printf ("Matched prerecorded syllable <%s> ", lcSyllable);
			return XACCESS(RecordedSyllable, ((y * 2) + 1));
		}
	TheRecordedSyllable = XACCESS(RecordedSyllable, ((++y) * 2));
	}

	// If we get here, we didn't get a match
	printf (" No prerecorded syllable <%s> ", lcSyllable);
	return 0;
}
/* End of MatchPrerecordedMSSyllable */


static void OutMSWordString (char *WordString, char *PhonemeString)
{
	const_xmem_ptr_t Result;
        char tmp[32];

	Result = MatchPrerecordedMSWord (WordString);
	if (Result == 0) {// no match
		OutString (PhonemeString);
		OutString (" ");
	}
	else {
                xmem2root(tmp, Result, sizeof(tmp));
		OutRecordedWordString (tmp);
	}
}
/* End of OutMSWordString */


BOOL isMSconsonant (char chr)
{
return (BOOL)((isupper(chr) && !isvowel(chr)) || chr=='-' || chr==GLOTTAL || chr==NG);
}
/* end of isMSconsonant */


void SayMSASCII (int character)
{
        char tmp[32];
        xmem2root(tmp, XACCESS(MAscii, (character & 0x7f)), sizeof(tmp));
	OutString(tmp);
}
/* End of SayMSASCII */


void SpellMSWord (char *word)
{
	for (word++ ; word[1] != '\0' ; word++)
		SayMSASCII(*word);
}
/* End of SpellMSWord */


/*
**              Integer to Readable ASCII Conversion Routine.
**
** Synopsis:
**
**      SayMSCardinal (value)
**      	long int     value;          -- The number to output
**
**	The number is translated into a string of phonemes
**
*/

/*
** Translate a number to phonemes.  This version is for CARDINAL numbers.
**	 Note: this is recursive.
*/
void SayMSCardinal (long value)
{
        char tmp[32];

	if (value < 0)
		{
		OutMSWordString ("minus", "mAYnAHs");
		value = (-value);
		if (value < 0)	/* Overflow!  -32768 */
			{
			OutMSWordString ("infinity", "IHnfIHnIHtIY");
			return;
			}
		}

	if (value >= 1000000000L)	/* Billions */
		{
		SayMSCardinal (value/1000000000L);
		OutMSWordString ("billion", "bIHlIYAXn");
		value = value % 1000000000;
		if (value == 0)
			return;		/* Even billion */
		if (value < 100)	/* as in THREE BILLION AND FIVE */
			OutMSWordString ("and", "AEnd");
		}

	if (value >= 1000000L)	/* Millions */
		{
		SayMSCardinal (value/1000000L);
		OutMSWordString ("million", "mIHlIYAXn");
		value = value % 1000000L;
		if (value == 0)
			return;		/* Even million */
		if (value < 100)	/* as in THREE MILLION AND FIVE */
			OutMSWordString ("and", "AEnd");
		}

	/* Thousands 1000..1099 2000..99999 */
	/* 1100 to 1999 is eleven-hunderd to ninteen-hunderd */
	if ((value >= 1000L && value <= 1099L) || value >= 2000L)
		{
		SayMSCardinal (value/1000L);
		OutMSWordString ("thousand", "THAWzAEnd");
		value = value % 1000L;
		if (value == 0)
			return;		/* Even thousand */
		if (value < 100)	/* as in THREE THOUSAND AND FIVE */
			OutMSWordString ("and", "AEnd");
		}

	if (value >= 100L)
		{
#ifdef USE_PRERECORDED_WORDS
		QueueSound (MW_zero[0] + value/100);
		QueueSound (WordPause[0]);
#else		
                xmem2root(tmp, XACCESS(Cardinals, (value / 100)), sizeof(tmp));
		OutString (tmp);
#endif
		OutMSWordString ("hundred", "hAHndrEHd");
		value = value % 100;
		if (value == 0)
			return;		/* Even hundred */
		}

	if (value >= 20)
		{
#ifdef USE_PRERECORDED_WORDS
		QueueSound (MW_twenty[0] + (value-20)/10);
		QueueSound (WordPause[0]);
#else		
                xmem2root(tmp, XACCESS(Twenties, ((value - 20) / 10)), sizeof(tmp));
		OutString (tmp);
#endif
		value = value % 10;
		if (value == 0)
			return;		/* Even ten */
		}

#ifdef USE_PRERECORDED_WORDS
	QueueSound (MW_zero[0] + value);
	QueueSound (WordPause[0]);
#else		
        xmem2root(tmp, XACCESS(Cardinals, value), sizeof(tmp));
        OutString (tmp);
#endif
	return;
} 
/* End of SayMSCardinal */


/*
** Translate a number to phonemes.  This version is for ORDINAL numbers.
**	 Note: this is recursive.
*/
void SayMSOrdinal (long value)
{
        char tmp[32];

	if (value < 0)
		{
		OutMSWordString ("minus", "mAHnAXs");
		value = (-value);
		if (value < 0)	/* Overflow!  -32768 */
			{
			OutMSWordString ("inifinity", "IHnfIHnIHtIY");
			return;
			}
		}

	if (value >= 1000000000L)	/* Billions */
		{
		SayMSCardinal (value/1000000000L);
		value = value % 1000000000;
		if (value == 0)
			{
			OutMSWordString ("billionth", "bIHlIYAXnTH");
			return;		/* Even billion */
			}
		OutMSWordString ("billion", "bIHlIYAXn");
		if (value < 100)	/* as in THREE BILLION AND FIVE */
			OutMSWordString ("and", "AEnd");
		}

	if (value >= 1000000L)	/* Millions */
		{
		SayMSCardinal (value/1000000L);
		value = value % 1000000L;
		if (value == 0)
			{
			OutMSWordString ("millionth", "mIHlIYAXnTH");
			return;		/* Even million */
			}
		OutMSWordString ("million", "mIHlIYAXn");
		if (value < 100)	/* as in THREE MILLION AND FIVE */
			OutMSWordString ("and", "AEnd");
		}

	/* Thousands 1000..1099 2000..99999 */
	/* 1100 to 1999 is eleven-hunderd to ninteen-hunderd */
	if ((value >= 1000L && value <= 1099L) || value >= 2000L)
		{
		SayMSCardinal (value/1000L);
		value = value % 1000L;
		if (value == 0)
			{
			OutMSWordString ("thousandth", "THAWzAEndTH");
			return;		/* Even thousand */
			}
		OutMSWordString ("thousand", "THAWzAEnd");
		if (value < 100)	/* as in THREE THOUSAND AND FIVE */
			OutMSWordString ("and", "AEnd");
		}

	if (value >= 100L)
		{
#ifdef USE_PRERECORDED_WORDS
		QueueSound (MW_zero[0] + value/100);
		QueueSound (WordPause[0]);
#else		
                xmem2root(tmp, XACCESS(Cardinals, (value / 100)), sizeof(tmp));
		OutString (tmp);
#endif
		value = value % 100;
		if (value == 0)
			{
			OutMSWordString ("hundredth", "hAHndrEHdTH");
			return;		/* Even hundred */
			}
		OutMSWordString ("hundred", "hAHndrEHd");
		}

	if (value >= 20)
		{
		if ((value%10) == 0)
			{
                        xmem2root(tmp, XACCESS(MOrd_twenties, ((value-20) / 10)),
                                sizeof(tmp));
		        OutString (tmp);
			return;		/* Even ten */
			}
#ifdef USE_PRERECORDED_WORDS
		QueueSound (MW_twenty[0] + (value-20)/10);
		QueueSound (WordPause[0]);
#else		
                xmem2root(tmp, XACCESS(Twenties, ((value - 20) / 10)), sizeof(tmp));
		OutString (tmp);
#endif
		value = value % 10;
		}

        xmem2root(tmp, XACCESS(MOrdinals, (value)), sizeof(tmp));
        OutString (tmp);
	return;
} 
/* End of SayMSOrdinal */


int NewMSChar (void)
{
	/*
	If the cache is full of newline, time to prime the look-ahead
	again.  If a null is found, fill the remainder of the queue with
	nulls.
	*/
	static BOOL InLiteral;

GetAnotherChar:
        if (MChar == '\n'  && MChar1 == '\n' && MChar2 == '\n' && MChar3 == '\n')
		{	/* prime the pump again */
                MChar = *MTextPointer++;
                if (MChar == '\0')

			{
			MChar1 = '\0';
			MChar2 = '\0';
			MChar3 = '\0';
                        return MChar;
			}
                if (MChar == '\n')
                        return MChar;

		MChar1 = *MTextPointer++;
		if (MChar1 == '\0')
			{
			MChar2 = '\0';
			MChar3 = '\0';
                        return MChar;
			}
		if (MChar1 == '\n')
                        return MChar;

		MChar2 = *MTextPointer++;
		if (MChar2 == '\0')
			{
			MChar3 = '\0';
                        return MChar;
			}

		if (MChar2 == '\n')
                        return MChar;

		MChar3 = *MTextPointer++;
		}
	else
		{
		/*
		Buffer not full of newline, shuffle the characters and
		either get a new one or propagate a newline or null.
		*/
                MChar = MChar1;
		MChar1 = MChar2;
		MChar2 = MChar3;
		if (MChar3 != '\n' && MChar3 != '\0')
			MChar3 = *MTextPointer++;
		}

//printf ("Char is <%x>", Char);
        if (MChar == '\0') {
		InLiteral = FALSE; // for next time
                return MChar;
	}

	if (InLiteral) {
                if (MChar == SP_LITERAL)
{
//printf ("finished literal");		
			InLiteral = FALSE;
}
		else
{
//printf ("literal is <%x>", MChar);
                        QueueSound ((U8)MChar);
}
		goto GetAnotherChar;
	}
	else {
                if (MChar == SP_LITERAL) {
//printf ("got literal");		
			InLiteral = TRUE;
			goto GetAnotherChar;
		}
                return MChar;
	}
printf ("Should nvr get here");
        return MChar;
}
/* End of NewMSChar */


#if NEED_CURRENCIES
void HaveMSDollars (void)
{
	long int value;

	value = 0L;
        for (NewMSChar() ; isdigit(MChar) || MChar == ',' ; NewMSChar())
		{
                if (MChar != ',')
                        value = 10 * value + (MChar-'0');
		}

	SayMSCardinal (value);	/* Say number of whole dollars */

	/* Found a character that is a non-digit and non-comma */

	/* Check for no decimal or no cents digits */
        if (MChar != '.' || !isdigit(MChar1))
		{
		if (value == 1L)
			OutMSWordString ("dollar", "dAAlER");
		else
			OutMSWordString ("dollars", "dAAlAArz");
		return;
		}

	/* We have '.' followed by a digit */

	NewMSChar();	/* Skip the period */

	/* If it is ".dd " say as " DOLLARS AND n CENTS " */
	if (isdigit(MChar1) && !isdigit(MChar2))
		{
		OutMSWordString ("pisu", "dAAlAArz");
                if (MChar == '0' && MChar1 == '0')
			{
			NewMSChar();	/* Skip tens digit */
			NewMSChar();	/* Skip units digit */
			return;
			}

		OutMSWordString ("and", "AAnd");
                value = (MChar-'0')*10 + MChar1-'0';
		SayMSCardinal (value);

		if (value == 1L)
			OutMSWordString ("cent", "sEHnt");
		else
			OutMSWordString ("cents", "sEHnts");
		NewMSChar();	/* Used Char (tens digit) */
		NewMSChar();	/* Used MChar1 (units digit) */
		return;
		}

	/* Otherwise say as "n POINT ddd DOLLARS " */

	OutMSWordString ("point", "pOYnt");
        for ( ; isdigit(MChar) ; NewMSChar())
		{
                SayMSASCII (MChar);
		}

	OutMSWordString ("pisu", "pisu");
}
/* End of HaveMSDollars */


void HaveMSPesos (void)
{
	long int value;

	value = 0L;
        for (NewMSChar() ; isdigit(MChar) || MChar == ',' ; NewMSChar())
		{
                if (MChar != ',')
                        value = 10 * value + (MChar-'0');
		}

	SayMSCardinal (value);	/* Say number of whole dollars */

	/* Found a character that is a non-digit and non-comma */

	/* Check for no decimal or no cents digits */
        if (MChar != '.' || !isdigit(MChar1))
		{
		if (value == 1L)
			OutMSWordString ("dollar", "dAAlER");
		else
			OutMSWordString ("dollars", "dAAlAArz");
		return;
		}

	/* We have '.' followed by a digit */

	NewMSChar();	/* Skip the period */

	/* If it is ".dd " say as " DOLLARS AND n CENTS " */
	if (isdigit(MChar1) && !isdigit(MChar2))
		{
		if (value == 1L)
			OutMSWordString ("dollar", "dAAlER");
		else
			OutMSWordString ("dollars", "dAAlAArz");
                if (MChar == '0' && MChar1 == '0')
			{
			NewMSChar();	/* Skip tens digit */

			NewMSChar();	/* Skip units digit */
			return;
			}

		OutMSWordString ("and", "AAnd");
                value = (MChar-'0')*10 + MChar1-'0';
		SayMSCardinal (value);

		if (value == 1L)
			OutMSWordString ("cent", "sEHnt");
		else
			OutMSWordString ("cents", "sEHnts");
		NewMSChar();	/* Used Char (tens digit) */
		NewMSChar();	/* Used MChar1 (units digit) */
		return;
		}

	/* Otherwise say as "n POINT ddd DOLLARS " */

	OutMSWordString ("point", "pOYnt");
        for ( ; isdigit(MChar) ; NewMSChar())
		{
                SayMSASCII (MChar);
		}

	OutMSWordString ("dollars", "dAAlAArz");
}
/* End of HaveMSPesos */
#endif // NEED_CURRENCIES


void HaveMSSpecial (void)
{
        if (!isspace(MChar)) {
		if (PronouncePunctuationMarks)
                   SayMSASCII (MChar);
		else if (MChar == ',')
			QueueSound (WordPause[0]); // Presumably there will also be another word pause for the space
		else if (MChar == '.' || MChar == ':' || MChar == ';')
			QueueSound (SentencePause[0]);
		else
                  SayMSASCII (MChar);
	}

	NewMSChar();
}
/* End of HaveMSSpecial */


void HaveMSNumber (void)
{
	long int value;
	int lastdigit;

        value = MChar - '0';
        lastdigit = MChar;

        for (NewMSChar() ; isdigit(MChar) ; NewMSChar())
		{
                value = 10 * value + (MChar-'0');
                lastdigit = MChar;
		}

	/* Recognize ordinals based on last digit of number */
	switch (lastdigit)
		{
	case '1':	/* ST */
                if (makeupper(MChar) == 'S' && makeupper(MChar1) == 'T' &&
		    !isalpha(MChar2) && !isdigit(MChar2))
			{
			SayMSOrdinal(value);
			NewMSChar();	/* Used Char */
			NewMSChar();	/* Used MChar1 */
			return;
			}
		break;

	case '2':	/* ND */
                if (makeupper(MChar) == 'N' && makeupper(MChar1) == 'D' &&
		    !isalpha(MChar2) && !isdigit(MChar2))
			{
			SayMSOrdinal(value);
			NewMSChar();	/* Used Char */
			NewMSChar();	/* Used MChar1 */
			return;
			}
		break;

	case '3':	/* RD */
                if (makeupper(MChar) == 'R' && makeupper(MChar1) == 'D' &&
		    !isalpha(MChar2) && !isdigit(MChar2))
			{
			SayMSOrdinal(value);
			NewMSChar();	/* Used Char */
			NewMSChar();	/* Used MChar1 */
			return;
			}
		break;

	case '0':	/* TH */
	case '4':	/* TH */
	case '5':	/* TH */
	case '6':	/* TH */
	case '7':	/* TH */
	case '8':	/* TH */
	case '9':	/* TH */
                if (makeupper(MChar) == 'T' && makeupper(MChar1) == 'H' &&
		    !isalpha(MChar2) && !isdigit(MChar2))
			{
			SayMSOrdinal(value);
			NewMSChar();	/* Used Char */
			NewMSChar();	/* Used MChar1 */
			return;
			}
		break;
		}

	SayMSCardinal (value);

	/* Recognize decimal points */
        if (MChar == '.' && isdigit(MChar1))
		{
		OutMSWordString ("point", "pOYnt");
                for (NewMSChar() ; isdigit(MChar) ; NewMSChar())
			{
                        //SayMSASCII (MChar);
                        SayMSCardinal (MChar - '0');
			}
		}

	/* Spell out trailing MSAbbreviations */
        if (isalpha(MChar))
		{
                while (isalpha(MChar))
			{
                        SayMSASCII (MChar);
			NewMSChar();
			}
		}
}
/* End of HaveMSNumber */


void XlateMSSyllable (char syllable[]) /* Note: syllable is upper case */
{
	int SourceIndex;
	char PhonemeString[10];
	const_xmem_ptr_t Result;

//printf ("\nXlateMSSyllable(%s) ", syllable);	
	Result = MatchPrerecordedMSSyllable (syllable);
	if (Result == 0) {// no match so need to output by phonemes
		SourceIndex = 0;
		PhonemeString[0] = '\0';
		while (syllable[SourceIndex] != '\0')
			{
			if (syllable[SourceIndex] == GLOTTAL)
				strcat (PhonemeString, SPX GlottalPause SPX);
			else if (syllable[SourceIndex] == NG)
				strcat (PhonemeString, "NG");
			else // strcat (PhonemeString, LetterToPhoneme + (syllable[SourceIndex]-'A'));
				xmem2root(PhonemeString + strlen(PhonemeString), XACCESS(LetterToPhoneme, (syllable[SourceIndex]-'A')), sizeof(PhonemeString) - strlen(PhonemeString));
			++SourceIndex;
			}
		OutString (PhonemeString);
		}
	else { // We matched a syllable -- the xmem address of the sound number is in Result
		xmem2root(PhonemeString, Result, 2);
		QueueSound (PhonemeString[0]);
		}
}
/* End of XlateMSSyllable */


void XlateMSWord (char word[]) /* Note: word is upper case and has a leading and a trailing blank */
{
	int index;	/* Current position in word */
	const_xmem_ptr_t Result;
	BOOL HaveVowel;
	unsigned int NumSyChars;
	char TempWord[MAX_MS_WORD_LENGTH+1];

	//printf ("\nXlateMSWord(%s) ", word);	
	assert (strlen(word)<=MAX_MS_WORD_LENGTH);

	/* Check for prerecorded words */
	strcpy (TempWord, word+1); /* Copy and remove the leading blank */
	TempWord[strlen(TempWord)-1] = '\0'; /* Remove the trailing blank */
	Result = MatchPrerecordedMSWord (TempWord);
	if (Result != 0) { // We matched one
		xmem2root(TempWord, Result, sizeof(TempWord));
		OutRecordedWordString (TempWord); // Output the recorded sound(s)
		return;
	}	
	else { // we didn't match a prerecorded word
		// Convert to syllables and then translate them
		index = 1;	/* Skip the initial blank */
		HaveVowel = FALSE;
		NumSyChars = 0;
		do	{
			// Precede leading vowels with a glottal stop
			if (NumSyChars==0 && isvowel(word[index])) {
				TempWord[0] = GLOTTAL;
				NumSyChars = 1;
				}

			// Convert n g to ng
			if (word[index]=='N' && word[index+1]=='G')
				word[++index] = NG;

			if (word[index]=='-' && isMSconsonant(word[index-1]) && isMSconsonant(word[index+1]))
				++index; // ignore hyphen between two consonants
			else if (!HaveVowel && isvowel(word[index])) {
				TempWord[NumSyChars++] = word[index++];
				HaveVowel = TRUE;
				}
			else if (HaveVowel) {
				if (isMSconsonant(word[index]) && !isvowel(word[index+1]))
					TempWord[NumSyChars++] = word[index++];
				if (TempWord[NumSyChars-1] == '-') // Convert hyphen to specific glottal
					TempWord[NumSyChars-1] = GLOTTAL;
				TempWord[NumSyChars] = '\0';
				XlateMSSyllable (TempWord);
				// Prepare for next syllable
				HaveVowel = FALSE;
				NumSyChars = 0;
				}
			else {// accept this letter
				TempWord[NumSyChars++] = word[index++];
				if (TempWord[NumSyChars-1] == '-') // Convert hyphen to specific glottal
					TempWord[NumSyChars-1] = GLOTTAL;
				}
			} while (word[index] != ' ');
		if (NumSyChars != 0) {
			TempWord[NumSyChars] = '\0';
			XlateMSSyllable (TempWord);
		}
	}
	QueueSound (WordPause[0]);
}
/* End of XlateMSWord */


/* Handle abbreviations.  Text in buff was followed by '.' */
void MSAbbrev (char buff[])
{
	if (strcmp(buff, " DR ") == 0)
		{
		XlateMSWord(" DOCTOR ");
		NewMSChar();
		}
	else
	if (strcmp(buff, " MR ") == 0)
		{
		XlateMSWord(" MISTER ");
		NewMSChar();
		}
	else
	if (strcmp(buff, " MRS ") == 0)
		{
		XlateMSWord(" MISSUS ");
		NewMSChar();
		}
	else
	if (strcmp(buff, " MS ") == 0)
		{
		XlateMSWord(" MIZ ");
		NewMSChar();
		}
	else
	if (strcmp(buff, " PHD ") == 0)
		{
		SpellMSWord(" PHD ");
		NewMSChar();
		}
	else
		XlateMSWord(buff);
}
/* End of MSAbbrev */


void HaveMSLetter (void)
{
	char buff[MAX_MS_WORD_LENGTH+1];
	int count;

	count = 0;
	buff[count++] = ' ';	/* Required initial blank */

        buff[count++] = makeupper(MChar);

        for (NewMSChar() ; isalpha(MChar) || MChar == '\'' || MChar=='-'; NewMSChar())
		{
		buff[count++] = makeupper(MChar);
		if (count > MAX_MS_WORD_LENGTH-2)
			{
			buff[count++] = ' ';
			buff[count++] = '\0';
			XlateMSWord (buff);
			count = 1;
			}
		}

	buff[count++] = ' ';	/* Required terminating blank */
	buff[count++] = '\0';

	/* Check for AAANNN type abbreviations */
        if (isdigit(MChar))
		{
		SpellMSWord (buff);
		return;
		}
#if 0	// messes up about one letter words such as a e
	else if (strlen(buff) == 3)	 /* one character, two spaces */
		SayMSASCII (buff[1]);
#endif		
        else if (MChar == '.')           /* Possible abbreviation */
		MSAbbrev(buff);
	else
		XlateMSWord(buff);

//      if (MChar == '-' && isalpha(MChar1))
//		NewMSChar();	/* Skip hyphens */

}
/* End of HaveMSLetter */


/*****************************************************
*
* Function Name: SayMatigsalugText
* Description: Queue a string to be said
* Arguments: 	Override = TRUE/FALSE
*			Text = string
*
*****************************************************/

void SayMatigsalugText (BOOL Override, char *Text)
{
	printf ("SayMS(%u,%s)\n", Override, Text);
	MTextPointer = Text; // Copy pointer
	InitSoundQueue ();

	if (Override)
		OutOverrideChar ();

	/* Prime the queue */
	MChar = '\n';
	MChar1 = '\n';
	MChar2 = '\n';
	MChar3 = '\n';
	NewMSChar();	/* Fill Char, MChar1, MChar2 and MChar3 */

	while (MChar != '\0')    /* All of the words in the string */
		{
		if (isdigit(MChar))
			HaveMSNumber();
		else if (isalpha(MChar) || MChar == '\'')
			HaveMSLetter();
#if NEED_CURRENCIES
		else if (MChar == '$' && isdigit(MChar1))
			HaveMSDollars();
		else if (MChar == 'P' && isdigit(MChar1))
			HaveMSPesos();
#endif // NEED_CURRENCIES
		else
			HaveMSSpecial();
		}
	FlushSoundQueue ();
}
/* End of SayMatigsalugText */


/***** End of Matigsalug.c *****/
