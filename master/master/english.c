

/* Dummy headers for Dynamic C */
/*** Beginheader english_c */
#ifdef TARGET_RABBIT
void english_c();

#asm
xxxenglish_c: equ english_c
#endasm
#endif /* TARGET_RABBIT */
/*** endheader */

#ifdef TARGET_RABBIT
void english_c () { }
#endif /* TARGET_RABBIT */


/*****************************************************
*
*	Name:	English.c
*	Description: 
*	Adapted by: Robert Hunt
*	Created: August 2001
*
*	Mod. Number: 16
*	Last Modified: 14 October 2001
*	Modified By: Robert Hunt
*
* Current problems:
*	Doesn't yet match ASCII characters, especially digits after a point
*	Sends a word pause immediately before a sentence pause
*
******************************************************/

/*
**	English to Phoneme rules.
**
**	Derived from: 
**
**	     AUTOMATIC TRANSLATION OF ENGLISH TEXT TO PHONETICS
**	            BY MEANS OF LETTER-TO-SOUND RULES
**
**			NRL Report 7948
**
**		      January 21st, 1976
**	    Naval Research Laboratory, Washington, D.C.
**
**
**	Published by the National Technical Information Service as
**	document "AD/A021 929".
**
**
**
**	The Phoneme codes:
**
**		IY	bEEt		IH	bIt
**		EY	gAte		EH	gEt
**		AE	fAt		AA	fAther
**		AO	lAWn		OW	lOne
**		UH	fUll		UW	fOOl
**		ER	mURdER		AX	About
**		AH	bUt		AY	hIde
**		AW	hOW		OY	tOY
**	
**		p	Pack		b	Back
**		t	Time		d	Dime
**		k	Coat		g	Goat
**		f	Fault		v	Vault
**		TH	eTHer		DH	eiTHer
**		s	Sue		z	Zoo
**		SH	leaSH		ZH	leiSure
**		h	How		m	suM
**		n	suN		NG	suNG
**		l	Laugh		w	Wear
**		y	Young		r	Rate
**		CH	CHar		j	Jar
**		WH	WHere
**
**
**	Rules are made up of four parts:
**	
**		The left context.
**		The text to match.
**		The right context.
**		The phonemes to substitute for the matched text.
**
**	Procedure:
**
**		Separate each block of letters (apostrophes included) 
**		and add a space on each side.  For each unmatched 
**		letter in the word, look through the rules where the 
**		text to match starts with the letter in the word.  If 
**		the text to match is found and the right and left 
**		context patterns also match, output the phonemes for 
**		that rule and skip to the next unmatched letter.
**
**
**	Special Context Symbols:
**
**		#	One or more vowels
**		:	Zero or more consonants
**		^	One consonant.
**		.	One of B, D, V, G, J, L, M, N, R, W or Z (voiced 
**			consonants)
**		%	One of ER, E, ES, ED, ING, ELY (a suffix)
**			(Found in right context only)
**		+	One of E, I or Y (a "front" vowel)
**
*/


#include <stdio.h>
#include <string.h>
#include <ctype.h>

#include "compat.h"
#include "sounds.h"
#include "speak.h"
#include "soundcontrol.h"


// Global variables for this module
static char *TextPointer;
static int Char, Char1, Char2, Char3;

#define MAX_LENGTH 128

/* Context definitions */
#define Anything ""	/* No context requirement */
#define Nothing " "	/* Context is beginning or end of word */

/* Phoneme definitions */
#define Pause " "	/* Short silence */
#define Silent ""	/* No phonemes */

#define LEFT_PART	0
#define MATCH_PART	1
#define RIGHT_PART	2
#define OUT_PART	3

typedef xmem_ptr_t Rule[4];	/* Rule is an array of 4 character pointers */

/*0 = Punctuation */
/*
**	LEFT_PART	MATCH_PART	RIGHT_PART	OUT_PART
*/
XSTRING(punct_rules)
	{
	Anything,	" ",		Anything,	Pause	,
	Anything,	"-",		Anything,	Silent	,
	".",		"'S",		Anything,	"z"	,
	"#:.E",	"'S",		Anything,	"z"	,
	"#",		"'S",		Anything,	"z"	,
	Anything,	"'",		Anything,	Silent	,
	Anything,	",",		Anything,	Pause	,
	Anything,	".",		Anything,	Pause	,
	Anything,	"?",		Anything,	Pause	,
	Anything,	"!",		Anything,	Pause	,
	Anything,	"",		Anything,	Silent	
	};

/*
**	LEFT_PART	MATCH_PART	RIGHT_PART	OUT_PART
*/
XSTRING(A_rules)
	{
	Anything,	"A",		Nothing,	"AX"	,
	Nothing,	"ARE",		Nothing,	"AAr"	,
	Nothing,	"AR",		"O",		"AXr"	,
	Anything,	"AR",		"#",		"EHr"	,
	"^",		"AS",		"#",		"EYs"	,
	Anything,	"A",		"WA",		"AX"	,
	Anything,	"AW",		Anything,	"AO"	,
	" :",		"ANY",		Anything,	"EHnIY"	,
	Anything,	"A",		"^+#",		"EY"	,
	"#:",		"ALLY",		Anything,	"AXlIY"	,
	Nothing,	"AL",		"#",		"AXl"	,
	Anything,	"AGAIN",	Anything,	"AXgEHn",
	"#:",		"AG",		"E",		"IHj"	,
	Anything,	"A",		"^+:#",		"AE"	,
	" :",		"A",		"^+ ",		"EY"	,
	Anything,	"A",		"^%",		"EY"	,
	Nothing,	"ARR",		Anything,	"AXr"	,
	Anything,	"ARR",		Anything,	"AEr"	,
	" :",		"AR",		Nothing,	"AAr"	,
	Anything,	"AR",		Nothing,	"ER"	,
	Anything,	"AR",		Anything,	"AAr"	,
	Anything,	"AIR",		Anything,	"EHr"	,
	Anything,	"AI",		Anything,	"EY"	,
	Anything,	"AY",		Anything,	"EY"	,
	Anything,	"AU",		Anything,	"AO"	,
	"#:",		"AL",		Nothing,	"AXl"	,
	"#:",		"ALS",		Nothing,	"AXlz"	,
	Anything,	"ALK",		Anything,	"AOk"	,
	Anything,	"AL",		"^",		"AOl"	,
	" :",		"ABLE",		Anything,	"EYbAXl",
	Anything,	"ABLE",		Anything,	"AXbAXl",
	Anything,	"ANG",		"+",		"EYnj"	,
	Anything,	"A",		Anything,	"AE"	,
 	Anything,	"",		Anything,	Silent	
	};

/*
**	LEFT_PART	MATCH_PART	RIGHT_PART	OUT_PART
*/
XSTRING(B_rules)
	{
	Nothing,	"BE",		"^#",		"bIH"	,
	Anything,	"BEING",	Anything,	"bIYIHNG",
	Nothing,	"BOTH",		Nothing,	"bOWTH"	,
	Nothing,	"BUS",		"#",		"bIHz"	,
	Anything,	"BUIL",		Anything,	"bIHl"	,
	Anything,	"B",		Anything,	"b"	,
	Anything,	"",		Anything,	Silent	
	};

/*
**	LEFT_PART	MATCH_PART	RIGHT_PART	OUT_PART
*/
XSTRING(C_rules)
	{
	Nothing,	"CH",		"^",		"k"	,
	"^E",		"CH",		Anything,	"k"	,
	Anything,	"CH",		Anything,	"CH"	,
	" S",		"CI",		"#",		"sAY"	,
	Anything,	"CI",		"A",		"SH"	,
	Anything,	"CI",		"O",		"SH"	,
	Anything,	"CI",		"EN",		"SH"	,
	Anything,	"C",		"+",		"s"	,
	Anything,	"CK",		Anything,	"k"	,
	Anything,	"COM",		"%",		"kAHm"	,
	Anything,	"C",		Anything,	"k"	,
	Anything,	"",		Anything,	Silent	
	};

/*
**	LEFT_PART	MATCH_PART	RIGHT_PART	OUT_PART
*/
XSTRING(D_rules)
	{
	"#:",		"DED",		Nothing,	"dIHd"	,
	".E",		"D",		Nothing,	"d"	,
	"#:^E",	"D",		Nothing,	"t"	,
	Nothing,	"DE",		"^#",		"dIH"	,
	Nothing,	"DO",		Nothing,	"dUW"	,
	Nothing,	"DOES",		Anything,	"dAHz"	,
	Nothing,	"DOING",	Anything,	"dUWIHNG",
	Nothing,	"DOW",		Anything,	"dAW"	,
	Anything,	"DU",		"A",		"jUW"	,
	Anything,	"D",		Anything,	"d"	,
	Anything,	"",		Anything,	Silent	
	};

/*
**	LEFT_PART	MATCH_PART	RIGHT_PART	OUT_PART
*/
XSTRING(E_rules)
	{
	"#:",		"E",		Nothing,	Silent	,
	"':^",		"E",		Nothing,	Silent	,
	" :",		"E",		Nothing,	"IY"	,
	"#",		"ED",		Nothing,	"d"	,
	"#:",		"E",		"D ",		Silent	,
	Anything,	"EV",		"ER",		"EHv"	,
	Anything,	"E",		"^%",		"IY"	,
	Anything,	"ERI",		"#",		"IYrIY"	,
	Anything,	"ERI",		Anything,	"EHrIH"	,
	"#:",		"ER",		"#",		"ER"	,
	Anything,	"ER",		"#",		"EHr"	,
	Anything,	"ER",		Anything,	"ER"	,
	Nothing,	"EVEN",		Anything,	"IYvEHn",
	"#:",		"E",		"W",		Silent	,
	"T",		"EW",		Anything,	"UW"	,
	"S",		"EW",		Anything,	"UW"	,
	"R",		"EW",		Anything,	"UW"	,
	"D",		"EW",		Anything,	"UW"	,
	"L",		"EW",		Anything,	"UW"	,
	"Z",		"EW",		Anything,	"UW"	,
	"N",		"EW",		Anything,	"UW"	,
	"J",		"EW",		Anything,	"UW"	,
	"TH",		"EW",		Anything,	"UW"	,
	"CH",		"EW",		Anything,	"UW"	,
	"SH",		"EW",		Anything,	"UW"	,
	Anything,	"EW",		Anything,	"yUW"	,
	Anything,	"E",		"O",		"IY"	,
	"#:S",		"ES",		Nothing,	"IHz"	,
	"#:C",		"ES",		Nothing,	"IHz"	,
	"#:G",		"ES",		Nothing,	"IHz"	,
	"#:Z",		"ES",		Nothing,	"IHz"	,
	"#:X",		"ES",		Nothing,	"IHz"	,
	"#:J",		"ES",		Nothing,	"IHz"	,
	"#:CH",	"ES",		Nothing,	"IHz"	,
	"#:SH",	"ES",		Nothing,	"IHz"	,
	"#:",		"E",		"S ",		Silent	,
	"#:",		"ELY",		Nothing,	"lIY"	,
	"#:",		"EMENT",	Anything,	"mEHnt"	,
	Anything,	"EFUL",		Anything,	"fUHl"	,
	Anything,	"EE",		Anything,	"IY"	,
	Anything,	"EARN",		Anything,	"ERn"	,
	Nothing,	"EAR",		"^",		"ER"	,
	Anything,	"EAD",		Anything,	"EHd"	,
	"#:",		"EA",		Nothing,	"IYAX"	,
	Anything,	"EA",		"SU",		"EH"	,
	Anything,	"EA",		Anything,	"IY"	,
	Anything,	"EIGH",		Anything,	"EY"	,
	Anything,	"EI",		Anything,	"IY"	,
	Nothing,	"EYE",		Anything,	"AY"	,
	Anything,	"EY",		Anything,	"IY"	,
	Anything,	"EU",		Anything,	"yUW"	,
	Anything,	"E",		Anything,	"EH"	,
	Anything,	"",		Anything,	Silent	
	};

/*
**	LEFT_PART	MATCH_PART	RIGHT_PART	OUT_PART
*/
XSTRING(F_rules)
	{
	Anything,	"FUL",		Anything,	"fUHl"	,
	Anything,	"F",		Anything,	"f"	,
	Anything,	"",		Anything,	Silent	
	};

/*
**	LEFT_PART	MATCH_PART	RIGHT_PART	OUT_PART
*/
XSTRING(G_rules)
	{
	Anything,	"GIV",		Anything,	"gIHv"	,
	Nothing,	"G",		"I^",		"g"	,
	Anything,	"GE",		"T",		"gEH"	,
	"SU",		"GGES",		Anything,	"gjEHs"	,
	Anything,	"GG",		Anything,	"g"	,
	" B#",		"G",		Anything,	"g"	,
	Anything,	"G",		"+",		"j"	,
	Anything,	"GREAT",	Anything,	"grEYt"	,
	"#",		"GH",		Anything,	Silent	,
	Anything,	"G",		Anything,	"g"	,
	Anything,	"",		Anything,	Silent	
	};

/*
**	LEFT_PART	MATCH_PART	RIGHT_PART	OUT_PART
*/
XSTRING(H_rules)
	{
	Nothing,	"HAV",		Anything,	"hAEv"	,
	Nothing,	"HERE",		Anything,	"hIYr"	,
	Nothing,	"HOUR",		Anything,	"AWER"	,
	Anything,	"HOW",		Anything,	"hAW"	,
	Anything,	"H",		"#",		"h"	,
	Anything,	"H",		Anything,	Silent	,
	Anything,	"",		Anything,	Silent	
	};

/*
**	LEFT_PART	MATCH_PART	RIGHT_PART	OUT_PART
*/
XSTRING(I_rules)
	{
	Nothing,	"IN",		Anything,	"IHn"	,
	Nothing,	"I",		Nothing,	"AY"	,
	Anything,	"IN",		"D",		"AYn"	,
	Anything,	"IER",		Anything,	"IYER"	,
	"#:R",		"IED",		Anything,	"IYd"	,
	Anything,	"IED",		Nothing,	"AYd"	,
	Anything,	"IEN",		Anything,	"IYEHn"	,
	Anything,	"IE",		"T",		"AYEH"	,
	" :",		"I",		"%",		"AY"	,
	Anything,	"I",		"%",		"IY"	,
	Anything,	"IE",		Anything,	"IY"	,
	Anything,	"I",		"^+:#",		"IH"	,
	Anything,	"IR",		"#",		"AYr"	,
	Anything,	"IZ",		"%",		"AYz"	,
	Anything,	"IS",		"%",		"AYz"	,
	Anything,	"I",		"D%",		"AY"	,
	"+^",		"I",		"^+",		"IH"	,
	Anything,	"I",		"T%",		"AY"	,
	"#:^",		"I",		"^+",		"IH"	,
	Anything,	"I",		"^+",		"AY"	,
	Anything,	"IR",		Anything,	"ER"	,
	Anything,	"IGH",		Anything,	"AY"	,
	Anything,	"ILD",		Anything,	"AYld"	,
	Anything,	"IGN",		Nothing,	"AYn"	,
	Anything,	"IGN",		"^",		"AYn"	,
	Anything,	"IGN",		"%",		"AYn"	,
	Anything,	"IQUE",		Anything,	"IYk"	,
	Anything,	"I",		Anything,	"IH"	,
	Anything,	"",		Anything,	Silent	
	};

/*
**	LEFT_PART	MATCH_PART	RIGHT_PART	OUT_PART
*/
XSTRING(J_rules)
	{
	Anything,	"J",		Anything,	"j"	,
	Anything,	"",		Anything,	Silent	
	};
/*
**	LEFT_PART	MATCH_PART	RIGHT_PART	OUT_PART
*/
XSTRING(K_rules)
	{
	Nothing,	"K",		"N",		Silent	,
	Anything,	"K",		Anything,	"k"	,
	Anything,	"",		Anything,	Silent	
	};

/*
**	LEFT_PART	MATCH_PART	RIGHT_PART	OUT_PART
*/
XSTRING(L_rules)
	{
	Anything,	"LO",		"C#",		"lOW"	,
	"L",		"L",		Anything,	Silent	,
	"#:^",		"L",		"%",		"AXl"	,
	Anything,	"LEAD",		Anything,	"lIYd"	,
	Anything,	"L",		Anything,	"l"	,
	Anything,	"",		Anything,	Silent	
	};

/*
**	LEFT_PART	MATCH_PART	RIGHT_PART	OUT_PART
*/
XSTRING(M_rules)
	{
	Anything,	"MOV",		Anything,	"mUWv"	,
	Anything,	"M",		Anything,	"m"	,
	Anything,	"",		Anything,	Silent	
	};

/*
**	LEFT_PART	MATCH_PART	RIGHT_PART	OUT_PART
*/
XSTRING(N_rules)
	{
	"E",		"NG",		"+",		"nj"	,
	Anything,	"NG",		"R",		"NGg"	,
	Anything,	"NG",		"#",		"NGg"	,
	Anything,	"NGL",		"%",		"NGgAXl",
	Anything,	"NG",		Anything,	"NG"	,
	Anything,	"NK",		Anything,	"NGk"	,
	Nothing,	"NOW",		Nothing,	"nAW"	,
	Anything,	"N",		Anything,	"n"	,
	Anything,	"",		Anything,	Silent	
	};

/*
**	LEFT_PART	MATCH_PART	RIGHT_PART	OUT_PART
*/
XSTRING(O_rules)
	{
	Anything,	"OF",		Nothing,	"AXv"	,
	Anything,	"OROUGH",	Anything,	"EROW"	,
	"#:",		"OR",		Nothing,	"ER"	,
	"#:",		"ORS",		Nothing,	"ERz"	,
	Anything,	"OR",		Anything,	"AOr"	,
	Nothing,	"ONE",		Anything,	"wAHn"	,
	Anything,	"OW",		Anything,	"OW"	,
	Nothing,	"OVER",		Anything,	"OWvER"	,
	Anything,	"OV",		Anything,	"AHv"	,
	Anything,	"O",		"^%",		"OW"	,
	Anything,	"O",		"^EN",		"OW"	,
	Anything,	"O",		"^I#",		"OW"	,
	Anything,	"OL",		"D",		"OWl"	,
	Anything,	"OUGHT",	Anything,	"AOt"	,
	Anything,	"OUGH",		Anything,	"AHf"	,
	Nothing,	"OU",		Anything,	"AW"	,
	"H",		"OU",		"S#",		"AW"	,
	Anything,	"OUS",		Anything,	"AXs"	,
	Anything,	"OUR",		Anything,	"AOr"	,
	Anything,	"OULD",		Anything,	"UHd"	,
	"^",		"OU",		"^L",		"AH"	,
	Anything,	"OUP",		Anything,	"UWp"	,
	Anything,	"OU",		Anything,	"AW"	,
	Anything,	"OY",		Anything,	"OY"	,
	Anything,	"OING",		Anything,	"OWIHNG",
	Anything,	"OI",		Anything,	"OY"	,
	Anything,	"OOR",		Anything,	"AOr"	,
	Anything,	"OOK",		Anything,	"UHk"	,
	Anything,	"OOD",		Anything,	"UHd"	,
	Anything,	"OO",		Anything,	"UW"	,
	Anything,	"O",		"E",		"OW"	,
	Anything,	"O",		Nothing,	"OW"	,
	Anything,	"OA",		Anything,	"OW"	,
	Nothing,	"ONLY",		Anything,	"OWnlIY",
	Nothing,	"ONCE",		Anything,	"wAHns"	,
	Anything,	"ON'T",		Anything,	"OWnt"	,
	"C",		"O",		"N",		"AA"	,
	Anything,	"O",		"NG",		"AO"	,
	" :^",		"O",		"N",		"AH"	,
	"I",		"ON",		Anything,	"AXn"	,
	"#:",		"ON",		Nothing,	"AXn"	,
	"#^",		"ON",		Anything,	"AXn"	,
	Anything,	"O",		"ST ",		"OW"	,
	Anything,	"OF",		"^",		"AOf"	,
	Anything,	"OTHER",	Anything,	"AHDHER",
	Anything,	"OSS",		Nothing,	"AOs"	,
	"#:^",		"OM",		Anything,	"AHm"	,
	Anything,	"O",		Anything,	"AA"	,
	Anything,	"",		Anything,	Silent	
	};

/*
**	LEFT_PART	MATCH_PART	RIGHT_PART	OUT_PART
*/
XSTRING(P_rules)
	{
	Anything,	"PH",		Anything,	"f"	,
	Anything,	"PEOP",		Anything,	"pIYp"	,
	Anything,	"POW",		Anything,	"pAW"	,
	Anything,	"PUT",		Nothing,	"pUHt"	,
	Anything,	"P",		Anything,	"p"	,
	Anything,	"",		Anything,	Silent	
	};

/*
**	LEFT_PART	MATCH_PART	RIGHT_PART	OUT_PART
*/
XSTRING(Q_rules)
	{
	Anything,	"QUAR",		Anything,	"kwAOr"	,
	Anything,	"QU",		Anything,	"kw"	,
	Anything,	"Q",		Anything,	"k"	,
	Anything,	"",		Anything,	Silent	
	};

/*
**	LEFT_PART	MATCH_PART	RIGHT_PART	OUT_PART
*/
XSTRING(R_rules)
	{
	Nothing,	"RE",		"^#",		"rIY"	,
	Anything,	"R",		Anything,	"r"	,
	Anything,	"",		Anything,	Silent	
	};

/*
**	LEFT_PART	MATCH_PART	RIGHT_PART	OUT_PART
*/
XSTRING(S_rules)
	{
	Anything,	"SH",		Anything,	"SH"	,
	"#",		"SION",		Anything,	"ZHAXn"	,
	Anything,	"SOME",		Anything,	"sAHm"	,
	"#",		"SUR",		"#",		"ZHER"	,
	Anything,	"SUR",		"#",		"SHER"	,
	"#",		"SU",		"#",		"ZHUW"	,
	"#",		"SSU",		"#",		"SHUW"	,
	"#",		"SED",		Nothing,	"zd"	,
	"#",		"S",		"#",		"z"	,
	Anything,	"SAID",		Anything,	"sEHd"	,
	"^",		"SION",		Anything,	"SHAXn"	,
	Anything,	"S",		"S",		Silent	,
	".",		"S",		Nothing,	"z"	,
	"#:.E",	"S",		Nothing,	"z"	,
	"#:^##",	"S",		Nothing,	"z"	,
	"#:^#",	"S",		Nothing,	"s"	,
	"U",		"S",		Nothing,	"s"	,
	" :#",		"S",		Nothing,	"z"	,
	Nothing,	"SCH",		Anything,	"sk"	,
	Anything,	"S",		"C+",		Silent	,
	"#",		"SM",		Anything,	"zm"	,
	"#",		"SN",		"'",		"zAXn"	,
	Anything,	"S",		Anything,	"s"	,
	Anything,	"",		Anything,	Silent	
	};

/*
**	LEFT_PART	MATCH_PART	RIGHT_PART	OUT_PART
*/
XSTRING(T_rules)
	{
	Nothing,	"THE",		Nothing,	"DHAX"	,
	Anything,	"TO",		Nothing,	"tUW"	,
	Anything,	"THAT",		Nothing,	"DHAEt"	,
	Nothing,	"THIS",		Nothing,	"DHIHs"	,
	Nothing,	"THEY",		Anything,	"DHEY"	,
	Nothing,	"THERE",	Anything,	"DHEHr"	,
	Anything,	"THER",		Anything,	"DHER"	,
	Anything,	"THEIR",	Anything,	"DHEHr"	,
	Nothing,	"THAN",		Nothing,	"DHAEn"	,
	Nothing,	"THEM",		Nothing,	"DHEHm"	,
	Anything,	"THESE",	Nothing,	"DHIYz"	,
	Nothing,	"THEN",		Anything,	"DHEHn"	,
	Anything,	"THROUGH",	Anything,	"THrUW"	,
	Anything,	"THOSE",	Anything,	"DHOWz"	,
	Anything,	"THOUGH",	Nothing,	"DHOW"	,
	Nothing,	"THUS",		Anything,	"DHAHs"	,
	Anything,	"TH",		Anything,	"TH"	,
	"#:",		"TED",		Nothing,	"tIHd"	,
	"S",		"TI",		"#N",		"CH"	,
	Anything,	"TI",		"O",		"SH"	,
	Anything,	"TI",		"A",		"SH"	,
	Anything,	"TIEN",		Anything,	"SHAXn"	,
	Anything,	"TUR",		"#",		"CHER"	,
	Anything,	"TU",		"A",		"CHUW"	,
	Nothing,	"TWO",		Anything,	"tUW"	,
	Anything,	"T",		Anything,	"t"	,
	Anything,	"",		Anything,	Silent	
	};

/*
**	LEFT_PART	MATCH_PART	RIGHT_PART	OUT_PART
*/
XSTRING(U_rules)
	{
	Nothing,	"UN",		"I",		"yUWn"	,
	Nothing,	"UN",		Anything,	"AHn"	,
	Nothing,	"UPON",		Anything,	"AXpAOn",
	"T",		"UR",		"#",		"UHr"	,
	"S",		"UR",		"#",		"UHr"	,
	"R",		"UR",		"#",		"UHr"	,
	"D",		"UR",		"#",		"UHr"	,
	"L",		"UR",		"#",		"UHr"	,
	"Z",		"UR",		"#",		"UHr"	,
	"N",		"UR",		"#",		"UHr"	,
	"J",		"UR",		"#",		"UHr"	,
	"TH",		"UR",		"#",		"UHr"	,
	"CH",		"UR",		"#",		"UHr"	,
	"SH",		"UR",		"#",		"UHr"	,
	Anything,	"UR",		"#",		"yUHr"	,
	Anything,	"UR",		Anything,	"ER"	,
	Anything,	"U",		"^ ",		"AH"	,
	Anything,	"U",		"^^",		"AH"	,
	Anything,	"UY",		Anything,	"AY"	,
	" G",		"U",		"#",		Silent	,
	"G",		"U",		"%",		Silent	,
	"G",		"U",		"#",		"w"	,
	"#N",		"U",		Anything,	"yUW"	,
	"T",		"U",		Anything,	"UW"	,
	"S",		"U",		Anything,	"UW"	,
	"R",		"U",		Anything,	"UW"	,
	"D",		"U",		Anything,	"UW"	,
	"L",		"U",		Anything,	"UW"	,
	"Z",		"U",		Anything,	"UW"	,
	"N",		"U",		Anything,	"UW"	,
	"J",		"U",		Anything,	"UW"	,
	"TH",		"U",		Anything,	"UW"	,
	"CH",		"U",		Anything,	"UW"	,
	"SH",		"U",		Anything,	"UW"	,
	Anything,	"U",		Anything,	"yUW"	,
	Anything,	"",		Anything,	Silent	
	};

/*
**	LEFT_PART	MATCH_PART	RIGHT_PART	OUT_PART
*/
XSTRING(V_rules)
	{
	Anything,	"VIEW",		Anything,	"vyUW"	,
	Anything,	"V",		Anything,	"v"	,
	Anything,	"",		Anything,	Silent	
	};

/*
**	LEFT_PART	MATCH_PART	RIGHT_PART	OUT_PART
*/
XSTRING(W_rules)
	{
	Nothing,	"WERE",		Anything,	"wER"	,
	Anything,	"WA",		"S",		"wAA"	,
	Anything,	"WA",		"T",		"wAA"	,
	Anything,	"WHERE",	Anything,	"WHEHr"	,
	Anything,	"WHAT",		Anything,	"WHAAt"	,
	Anything,	"WHOL",		Anything,	"hOWl"	,
	Anything,	"WHO",		Anything,	"hUW"	,
	Anything,	"WH",		Anything,	"WH"	,
	Anything,	"WAR",		Anything,	"wAOr"	,
	Anything,	"WOR",		"^",		"wER"	,
	Anything,	"WR",		Anything,	"r"	,
	Anything,	"W",		Anything,	"w"	,
	Anything,	"",		Anything,	Silent	
	};

/*
**	LEFT_PART	MATCH_PART	RIGHT_PART	OUT_PART
*/
XSTRING(X_rules)
	{
	Anything,	"X",		Anything,	"ks"	,
	Anything,	"",		Anything,	Silent	
	};

/*
**	LEFT_PART	MATCH_PART	RIGHT_PART	OUT_PART
*/
XSTRING(Y_rules)
	{
	Anything,	"YOUNG",	Anything,	"yAHNG"	,
	Nothing,	"YOU",		Anything,	"yUW"	,
	Nothing,	"YES",		Anything,	"yEHs"	,
	Nothing,	"Y",		Anything,	"y"	,
	"#:^",		"Y",		Nothing,	"IY"	,
	"#:^",		"Y",		"I",		"IY"	,
	" :",		"Y",		Nothing,	"AY"	,
	" :",		"Y",		"#",		"AY"	,
	" :",		"Y",		"^+:#",		"IH"	,
	" :",		"Y",		"^#",		"AY"	,
	Anything,	"Y",		Anything,	"IH"	,
	Anything,	"",		Anything,	Silent	
	};

/*
**	LEFT_PART	MATCH_PART	RIGHT_PART	OUT_PART
*/
XSTRING(Z_rules)
	{
	Anything,	"Z",		Anything,	"z"	,
	Anything,	"",		Anything,	Silent	
	};

XDATA(Rules)
	{
	(const_xmem_ptr_t)punct_rules,
	(const_xmem_ptr_t)A_rules, (const_xmem_ptr_t)B_rules, (const_xmem_ptr_t)C_rules,
	(const_xmem_ptr_t)D_rules, (const_xmem_ptr_t)E_rules, (const_xmem_ptr_t)F_rules, (const_xmem_ptr_t)G_rules, 
	(const_xmem_ptr_t)H_rules, (const_xmem_ptr_t)I_rules, (const_xmem_ptr_t)J_rules,
	(const_xmem_ptr_t)K_rules, (const_xmem_ptr_t)L_rules, (const_xmem_ptr_t)M_rules, (const_xmem_ptr_t)N_rules, 
	(const_xmem_ptr_t)O_rules, (const_xmem_ptr_t)P_rules, (const_xmem_ptr_t)Q_rules,
	(const_xmem_ptr_t)R_rules, (const_xmem_ptr_t)S_rules, (const_xmem_ptr_t)T_rules, (const_xmem_ptr_t)U_rules, 
	(const_xmem_ptr_t)V_rules, (const_xmem_ptr_t)W_rules, (const_xmem_ptr_t)X_rules,
	(const_xmem_ptr_t)Y_rules, (const_xmem_ptr_t)Z_rules
	};

XSTRING(Ordinals)
	{
	"zIHrOWEHTH ",	"fERst ",	"sEHkAHnd ",	"THERd ",
	"fOWrTH ",	"fIHfTH ",	"sIHksTH ",	"sEHvEHnTH ",
	"EYtTH ",	"nAYnTH ",		
	"tEHnTH ",	"IYlEHvEHnTH ",	"twEHlvTH ",	"THERtIYnTH ",
	"fAOrtIYnTH ",	"fIHftIYnTH ", 	"sIHkstIYnTH ",	"sEHvEHntIYnTH ",
	"EYtIYnTH ",	"nAYntIYnTH "
	} ;

XSTRING(Ord_twenties)
	{
	"twEHntIYEHTH ","THERtIYEHTH ",	"fOWrtIYEHTH ",	"fIHftIYEHTH ",
	"sIHkstIYEHTH ","sEHvEHntIYEHTH ","EYtIYEHTH ",	"nAYntIYEHTH "
	} ;

XSTRING(Ascii)
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


/*
**	English to Phoneme translation.
**
**	Rules are made up of four parts:
**	
**		The left context.
**		The text to match.
**		The right context.
**		The phonemes to substitute for the matched text.
**
**	Procedure:
**
**		Seperate each block of letters (apostrophes included) 
**		and add a space on each side.  For each unmatched 
**		letter in the word, look through the rules where the 
**		text to match starts with the letter in the word.  If 
**		the text to match is found and the right and left 
**		context patterns also match, output the phonemes for 
**		that rule and skip to the next unmatched letter.
**
**
**	Special Context Symbols:
**
**		#	One or more vowels
**		:	Zero or more consonants
**		^	One consonant.
**		.	One of B, D, V, G, J, L, M, N, R, W or Z (voiced 
**			consonants)
**		%	One of ER, E, ES, ED, ING, ELY (a suffix)
**			(Right context only)
**		+	One of E, I or Y (a "front" vowel)
*/

void OutRecordedWordString (constparam char *string)
{
while (*string != '\0')
	QueueSound (*string++);		
QueueSound (WordPause[0]);	
}
/* End of OutRecordedWordString */


void OutString (constparam char *string)
{
	unsigned char Hanging;
	BOOL InLiteral;
	unsigned char ThisChar, ThisPhoneme;
	unsigned int x;
	BOOL Matched;
	char tmp[3];

//printf (" OutString(%s) ", string);
	Hanging = 0;
	InLiteral = FALSE;
	while (*string != '\0') {
		Matched = FALSE;
		ThisChar = *string++;
		if (ThisChar == ' ') {
			ThisPhoneme = WordPause[0];
			Matched = TRUE;
			}
		else if (ThisChar == SP_LITERAL) {
//printf (" InLiteral=%u ", InLiteral);		
			InLiteral = (BOOL)!InLiteral;
			}
		else if (InLiteral) {
			ThisPhoneme = ThisChar;
			Matched = TRUE;
			}
		else if (Hanging == '\0' && isupper(ThisChar))
			Hanging = ThisChar;
		else if (Hanging != '\0') { // Need to match two (upper case) letters
			/* Check for prerecorded phoneme */
			x = 0;
			for(;;) {
//printf ("ThisChar is <%c>, Hanging is <%c>", ThisChar, Hanging);
				xmem2root(tmp, XACCESS(RecordedPhoneme, x * 2), 2);
				if(tmp[0] == 0)
					break; // End of list
				if (tmp[1] != '\0') { // Then the phoneme name is not just one letter
					if (tmp[0] == Hanging
					 && tmp[1] == ThisChar) { // Have a match
//printf ("Matched <%c%c> @ %d ", Hanging, ThisChar, x);
						xmem2root(&ThisPhoneme, XACCESS(RecordedPhoneme, ((x * 2)+1)), 1);
						Matched = TRUE;
						break;
					}
					if (Hanging < tmp[0]) { // Gone too far in sorted table -- no match
						break;
					}
				}
				x++;
			}
			if (! Matched) printf ("\nOutString couldn't match \"%c%c\" ", Hanging, ThisChar);
			Hanging = '\0';
		}
		else { // Should just be one (lower case) letter to match
			/* Check for prerecorded phoneme */
			x = 0;
			for(;;) {
				xmem2root(tmp, XACCESS(RecordedPhoneme, x * 2), 2);
				if(tmp[0] == 0)
					break; // No match
				if (tmp[1] == '\0') { // Then the phoneme name is only one letter
					if (tmp[0] == ThisChar) { // Have a match
//printf ("Matched <%c> @ %d ", ThisChar, x);
						xmem2root(&ThisPhoneme, XACCESS(RecordedPhoneme, ((x * 2)+1)), 1);
						Matched = TRUE;
						break;
					}
					if (ThisChar < tmp[0]) { // Gone too far in sorted table -- no match
						break;
					}
				}
				x++;
			}
			if (! Matched) printf ("\nOutString couldn't match \"%c\" ", ThisChar);
		}
		if (! Hanging) {
			if (Matched) {
				// Send char to sound slave
				QueueSound (ThisPhoneme);
			}
		}
	}
	if (InLiteral)
		printf ("Unfinished literal");
}
/* End of OutString */


const_xmem_ptr_t MatchPrerecordedWord (char word[]) // Returns 0 if no match
{
	char lcWord[MAX_LENGTH];
	unsigned int y;
	int CompareResult;
        char tmp[32];
	
	/* Check for prerecorded words */
	xmem_ptr_t TheRecordedWord;

//printf (" MatchPrerecordedWord(%s) ", word);
	TheRecordedWord = XACCESS(RecordedWord, 0);

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
                if (*tmp == 0)	// Exit loop
                	break;
		CompareResult = strcmp (lcWord, tmp);
// printf (" Compare <%s> with <%s>=%d ", lcWord, tmp, CompareResult);
		if (CompareResult < 0) // gone too far in sorted list
			break;
		if (CompareResult == 0) {// matched
//printf ("Matched prerecorded word <%s> ", lcWord);
			// Deref pointer once so we return a pointer to the string
			return XACCESS(RecordedWord, ((y * 2) + 1));
		}
	TheRecordedWord = XACCESS(RecordedWord, ((++y) * 2));
	}

	// If we get here, we didn't get a match
	printf (" No precorded <%s> ", lcWord);
	return 0;
}
/* End of MatchPrerecordedWord */


void OutWordString (char *WordString, char *PhonemeString)
{
	const_xmem_ptr_t Result;
        char tmp[32];

	Result = MatchPrerecordedWord (WordString);
	if (Result == 0) {// no match
		OutString (PhonemeString);
		OutString (" ");
	}
	else {
		xmem2root(tmp, Result, sizeof(tmp));
		OutRecordedWordString (tmp);
	}
}
/* End of OutWordString */


nodebug BOOL isvowel (char chr)
{
return (BOOL)(chr == 'A' || chr == 'E' || chr == 'I' || chr == 'O' || chr == 'U');
}
/* end of isvowel */


nodebug BOOL isconsonant (char chr)
{
	return (BOOL)(isupper(chr) && !isvowel(chr));
}
/* end of isconsonant */


BOOL LeftMatch (constparam char *pattern, char *context)
	/* first char of pattern to match in text */
	/* last char of text to be matched */
{
	const char *pat;
	char *text;
	int count;
//printf ("LeftMatch(%s,%s)", pattern, context);

	if (*pattern == '\0')	/* null string matches any context */
		{
		return TRUE;
		}

	/* point to last character in pattern string */
	count = strlen(pattern);
	pat = pattern + (count - 1);

	text = context;

	for (; count > 0; pat--, count--)
		{
		/* First check for simple text or space */
		if (isalpha(*pat) || *pat == '\'' || *pat == ' ') {
			if (*pat != *text)
				return FALSE;
			else
				{
				text--;
				continue;
				}
                }

		switch (*pat)
			{
		case '#':	/* One or more vowels */
			if (!isvowel(*text))
				return FALSE;

			text--;

			while (isvowel(*text))
				text--;
			break;

		case ':':	/* Zero or more consonants */
			while (isconsonant(*text))
				text--;
			break;

		case '^':	/* One consonant */
			if (!isconsonant(*text))
				return FALSE;
			text--;
			break;

		case '.':	/* B, D, V, G, J, L, M, N, R, W, Z */
			if (*text != 'B' && *text != 'D' && *text != 'V'
			   && *text != 'G' && *text != 'J' && *text != 'L'
			   && *text != 'M' && *text != 'N' && *text != 'R'
			   && *text != 'W' && *text != 'Z')
				return FALSE;
			text--;
			break;

		case '+':	/* E, I or Y (front vowel) */
			if (*text != 'E' && *text != 'I' && *text != 'Y')
				return FALSE;
			text--;
			break;

		case '%':
		default:
			printf("Bad chr in lft rule: '%c'\n", *pat);
			return FALSE;
			}
		}

	return TRUE;
}
/* End of LeftMatch */


BOOL RightMatch (constparam char *pattern, char *context)
	/* first char of pattern to match in text */
	/* last char of text to be matched */
{
	const char *pat;
	char *text;
//printf ("RightMatch(%s,%s)", pattern, context);

	if (*pattern == '\0')	/* null string matches any context */
		return TRUE;

	pat = pattern;
	text = context;

	for (pat = pattern; *pat != '\0'; pat++)
		{
		/* First check for simple text or space */
		if (isalpha(*pat) || *pat == '\'' || *pat == ' ') {
			if (*pat != *text)
				return FALSE;
			else
				{
				text++;
				continue;
				}
                }

		switch (*pat)
			{
		case '#':	/* One or more vowels */
			if (!isvowel(*text))
				return FALSE;

			text++;

			while (isvowel(*text))
				text++;
			break;

		case ':':	/* Zero or more consonants */
			while (isconsonant(*text))
				text++;
			break;

		case '^':	/* One consonant */
			if (!isconsonant(*text))
				return FALSE;
			text++;
			break;

		case '.':	/* B, D, V, G, J, L, M, N, R, W, Z */
			if (*text != 'B' && *text != 'D' && *text != 'V'
			   && *text != 'G' && *text != 'J' && *text != 'L'
			   && *text != 'M' && *text != 'N' && *text != 'R'
			   && *text != 'W' && *text != 'Z')
				return FALSE;
			text++;
			break;

		case '+':	/* E, I or Y (front vowel) */
			if (*text != 'E' && *text != 'I' && *text != 'Y')
				return FALSE;
			text++;
			break;

		case '%':	/* ER, E, ES, ED, ING, ELY (a suffix) */
			if (*text == 'E')
				{
				text++;
				if (*text == 'L')
					{
					text++;
					if (*text == 'Y')
						{
						text++;
						break;
						}
					else
						{
						text--; /* Don't gobble L */
						break;
						}
					}
				else
				if (*text == 'R' || *text == 'S' 
				   || *text == 'D')
					text++;
				break;
				}
			else
			if (*text == 'I')
				{
				text++;
				if (*text == 'N')
					{
					text++;
					if (*text == 'G')
						{
						text++;
						break;
						}
					}
				return FALSE;
				}
			else
			return FALSE;

		default:
			printf("Bad chr in rght rule:'%c'\n", *pat);
			return FALSE;
			}
		}

	return TRUE;
}
/* End of RightMatch */


static int FindRule (char word[], int index, const_char_xmem_ptr_t rules)
{
	const_xmem_ptr_t rule;
	char left[10];
	char right[10];
	char _match[10];
	char *match;
	char output[10];
	int remainder;
//printf ("FindRule(%s,%u,??)", word, index);

	for (;;)	/* Search for the rule */
		{
		rule = rules;
		rules = rules + (XPTR_SIZE * 4);
		xmem2root(_match, XACCESS(rule, 1), sizeof(_match));
		match = _match;

		if ((*match) == 0)	/* bad symbol! */
			{
			printf ("Can't fnd rule for: '%c' in \"%s\"\n", word[index], word);
			return index+1;	/* Skip it! */
			}

		for (remainder = index; *match != '\0'; match++, remainder++)
			{
			if (*match != word[remainder])
				break;
			}

		if (*match != '\0')	/* found missmatch */
			continue;
//printf("\nWord: \"%s\", Index:%4d, Trying: \"%s/%s/%s\" = \"%s\"\n",
//    word, index, (*rule)[0], (*rule)[1], (*rule)[2], (*rule)[3]);
		xmem2root(left, XACCESS(rule, 0), sizeof(left));
		xmem2root(right, XACCESS(rule, 2), sizeof(right));

		if (!LeftMatch(left, &word[index-1]))
			continue;
//printf("LeftMatch(\"%s\",\"...%c\") succeeded!\n", left, word[index-1]);
		if (!RightMatch(right, &word[remainder]))
			continue;
//printf("RightMatch(\"%s\",\"%s\") succeeded!\n", right, &word[remainder]);
		xmem2root(output, XACCESS(rule, 3), sizeof(output));
//printf("Success: ");
		OutString(output);
		return remainder;
		}
}
/* End of FindRule */


char makeupper(int character)
{
	if (islower(character))
		return (char)toupper(character);
	else
		return (char)character;
}
/* End of makeupper */


void SayASCII (int character)
{
	char tmp[32];
	xmem2root(tmp, XACCESS(Ascii, (character & 0x7f)), sizeof(tmp));
	OutString(tmp);
}
/* End of SayASCII */


void SpellWord (char *word)
{
	for (word++ ; word[1] != '\0' ; word++)
		SayASCII(*word);
}
/* End of SpellWord */


/*
**              Integer to Readable ASCII Conversion Routine.
**
** Synopsis:
**
**      SayCardinal (value)
**      	long int     value;          -- The number to output
**
**	The number is translated into a string of phonemes
**
*/

/*
** Translate a number to phonemes.  This version is for CARDINAL numbers.
**	 Note: this is recursive.
*/
void SayCardinal (long value)
{
	if (value < 0)
		{
		OutWordString ("minus", "mAYnAHs");
		value = (-value);
		if (value < 0)	/* Overflow!  -32768 */
			{
			OutWordString ("infinity", "IHnfIHnIHtIY");
			return;
			}
		}

	if (value >= 1000000000L)	/* Billions */
		{
		SayCardinal (value/1000000000L);
		OutWordString ("billion", "bIHlIYAXn");
		value = value % 1000000000;
		if (value == 0)
			return;		/* Even billion */
		if (value < 100)	/* as in THREE BILLION AND FIVE */
			OutWordString ("and", "AEnd");
		}

	if (value >= 1000000L)	/* Millions */
		{
		SayCardinal (value/1000000L);
		OutWordString ("million", "mIHlIYAXn");
		value = value % 1000000L;
		if (value == 0)
			return;		/* Even million */
		if (value < 100)	/* as in THREE MILLION AND FIVE */
			OutWordString ("and", "AEnd");
		}

	/* Thousands 1000..1099 2000..99999 */
	/* 1100 to 1999 is eleven-hunderd to ninteen-hunderd */
	if ((value >= 1000L && value <= 1099L) || value >= 2000L)
		{
		SayCardinal (value/1000L);
		OutWordString ("thousand", "THAWzAEnd");
		value = value % 1000L;
		if (value == 0)
			return;		/* Even thousand */
		if (value < 100)	/* as in THREE THOUSAND AND FIVE */
			OutWordString ("and", "AEnd");
		}

	if (value >= 100L)
		{
		QueueSound ((U8)(EW_zero[0] + value/100));
		QueueSound (WordPause[0]);
		OutWordString ("hundred", "hAHndrEHd");
		value = value % 100;
		if (value == 0)
			return;		/* Even hundred */
		}

	if (value >= 20)
		{
		QueueSound ((U8)(EW_twenty[0] + (value-20)/10));
		QueueSound (WordPause[0]);
		value = value % 10;
		if (value == 0)
			return;		/* Even ten */
		}

	QueueSound ((U8)(EW_zero[0] + value));
	QueueSound (WordPause[0]);
	return;
} 
/* End of SayCardinal */


/*
** Translate a number to phonemes.  This version is for ORDINAL numbers.
**	 Note: this is recursive.
*/
void SayOrdinal (long value)
{
        char tmp[16];

	if (value < 0)
		{
		OutWordString ("minus", "mAHnAXs");
		value = (-value);
		if (value < 0)	/* Overflow!  -32768 */
			{
			OutWordString ("inifinity", "IHnfIHnIHtIY");
			return;
			}
		}

	if (value >= 1000000000L)	/* Billions */
		{
		SayCardinal (value/1000000000L);
		value = value % 1000000000;
		if (value == 0)
			{
			OutWordString ("billionth", "bIHlIYAXnTH");
			return;		/* Even billion */
			}
		OutWordString ("billion", "bIHlIYAXn");
		if (value < 100)	/* as in THREE BILLION AND FIVE */
			OutWordString ("and", "AEnd");
		}

	if (value >= 1000000L)	/* Millions */
		{
		SayCardinal (value/1000000L);
		value = value % 1000000L;
		if (value == 0)
			{
			OutWordString ("millionth", "mIHlIYAXnTH");
			return;		/* Even million */
			}
		OutWordString ("million", "mIHlIYAXn");
		if (value < 100)	/* as in THREE MILLION AND FIVE */
			OutWordString ("and", "AEnd");
		}

	/* Thousands 1000..1099 2000..99999 */
	/* 1100 to 1999 is eleven-hunderd to ninteen-hunderd */
	if ((value >= 1000L && value <= 1099L) || value >= 2000L)
		{
		SayCardinal (value/1000L);
		value = value % 1000L;
		if (value == 0)
			{
			OutWordString ("thousandth", "THAWzAEndTH");
			return;		/* Even thousand */
			}
		OutWordString ("thousand", "THAWzAEnd");
		if (value < 100)	/* as in THREE THOUSAND AND FIVE */
			OutWordString ("and", "AEnd");
		}

	if (value >= 100L)
		{
		QueueSound ((U8)(EW_zero[0] + value/100));
		QueueSound (WordPause[0]);
		value = value % 100;
		if (value == 0)
			{
			OutWordString ("hundredth", "hAHndrEHdTH");
			return;		/* Even hundred */
			}
		OutWordString ("hundred", "hAHndrEHd");
		}

	if (value >= 20)
		{
		if ((value%10) == 0)
			{
                        xmem2root(tmp, XACCESS(Ord_twenties, ((value-20)/ 10)), sizeof(tmp));
               		OutString(tmp);
        		return;		/* Even ten */
			}
		QueueSound ((U8)(EW_twenty[0] + (value-20)/10));
		QueueSound (WordPause[0]);
		value = value % 10;
		}

        xmem2root(tmp, XACCESS(Ordinals, value), sizeof(tmp));
        OutString(tmp);

//	OutString(Ordinals + (value));
	return;
} 
/* End of SayOrdinal */


int NewChar (void)
{
	/*
	If the cache is full of newline, time to prime the look-ahead
	again.  If a null is found, fill the remainder of the queue with
	nulls.
	*/
	static BOOL InLiteral;

GetAnotherChar:
	if (Char == '\n'  && Char1 == '\n' && Char2 == '\n' && Char3 == '\n')
		{	/* prime the pump again */
		Char = *TextPointer++;
		if (Char == '\0')
			{
			Char1 = '\0';
			Char2 = '\0';
			Char3 = '\0';
			return Char;
			}
		if (Char == '\n')
			return Char;

		Char1 = *TextPointer++;
		if (Char1 == '\0')
			{
			Char2 = '\0';
			Char3 = '\0';
			return Char;
			}
		if (Char1 == '\n')
			return Char;

		Char2 = *TextPointer++;
		if (Char2 == '\0')
			{
			Char3 = '\0';
			return Char;
			}
		if (Char2 == '\n')
			return Char;

		Char3 = *TextPointer++;
		}
	else
		{
		/*
		Buffer not full of newline, shuffle the characters and
		either get a new one or propagate a newline or null.
		*/
		Char = Char1;
		Char1 = Char2;
		Char2 = Char3;
		if (Char3 != '\n' && Char3 != '\0')
			Char3 = *TextPointer++;
		}

//printf ("Char is <%x>", Char);
	if (Char == '\0') {
		InLiteral = FALSE; // for next time
		return Char;
	}

	if (InLiteral) {
		if (Char == SP_LITERAL)
{
//printf ("finished literal");		
			InLiteral = FALSE;
}
		else
{
//printf ("literal is <%x>", Char);
			QueueSound ((U8)Char);
}
		goto GetAnotherChar;
	}
	else {
		if (Char == SP_LITERAL) {
//printf ("got literal");		
			InLiteral = TRUE;
			goto GetAnotherChar;
		}
		return Char;
	}
printf ("Should nvr get here");
	return Char;
}
/* End of NewChar */


#if NEED_CURRENCIES
void HaveDollars (void)
{
	long int value;

	value = 0L;
	for (NewChar() ; isdigit(Char) || Char == ',' ; NewChar())
		{
		if (Char != ',')
			value = 10 * value + (Char-'0');
		}

	SayCardinal (value);	/* Say number of whole dollars */

	/* Found a character that is a non-digit and non-comma */

	/* Check for no decimal or no cents digits */
	if (Char != '.' || !isdigit(Char1))
		{
		if (value == 1L)
			OutWordString ("dollar", "dAAlER");
		else
			OutWordString ("dollars", "dAAlAArz");
		return;
		}

	/* We have '.' followed by a digit */

	NewChar();	/* Skip the period */

	/* If it is ".dd " say as " DOLLARS AND n CENTS " */
	if (isdigit(Char1) && !isdigit(Char2))
		{
		if (value == 1L)
			OutWordString ("dollar", "dAAlER");
		else
			OutWordString ("dollars", "dAAlAArz");
		if (Char == '0' && Char1 == '0')
			{
			NewChar();	/* Skip tens digit */
			NewChar();	/* Skip units digit */
			return;
			}

		OutWordString ("and", "AAnd");
		value = (Char-'0')*10 + Char1-'0';
		SayCardinal (value);

		if (value == 1L)
			OutWordString ("cent", "sEHnt");
		else
			OutWordString ("cents", "sEHnts");
		NewChar();	/* Used Char (tens digit) */
		NewChar();	/* Used Char1 (units digit) */
		return;
		}

	/* Otherwise say as "n POINT ddd DOLLARS " */

	OutWordString ("point", "pOYnt");
	for ( ; isdigit(Char) ; NewChar())
		{
		SayASCII (Char);
		}

	OutWordString ("dollars", "dAAlAArz");
}
/* End of HaveDollars */
#endif // NEED_CURRENCIES


void HaveSpecial (void)
{
	if (!isspace(Char)) {
		if (PronouncePunctuationMarks)
			SayASCII (Char);
		else if (Char == ',')
			QueueSound (WordPause[0]); // Presumably there will also be another word pause for the space
		else if (Char == '.' || Char == ':' || Char == ';')
			QueueSound (SentencePause[0]);
		else
			SayASCII (Char);
	}

	NewChar();
}
/* End of HaveSpecial */


void HaveNumber (void)
{
	long int value;
	int lastdigit;

	value = Char - '0';
	lastdigit = Char;

	for (NewChar() ; isdigit(Char) ; NewChar())
		{
		value = 10 * value + (Char-'0');
		lastdigit = Char;
		}

	/* Recognize ordinals based on last digit of number */
	switch (lastdigit)
		{
	case '1':	/* ST */
		if (makeupper(Char) == 'S' && makeupper(Char1) == 'T' &&
		    !isalpha(Char2) && !isdigit(Char2))
			{
			SayOrdinal(value);
			NewChar();	/* Used Char */
			NewChar();	/* Used Char1 */
			return;
			}
		break;

	case '2':	/* ND */
		if (makeupper(Char) == 'N' && makeupper(Char1) == 'D' &&
		    !isalpha(Char2) && !isdigit(Char2))
			{
			SayOrdinal(value);
			NewChar();	/* Used Char */
			NewChar();	/* Used Char1 */
			return;
			}
		break;

	case '3':	/* RD */
		if (makeupper(Char) == 'R' && makeupper(Char1) == 'D' &&
		    !isalpha(Char2) && !isdigit(Char2))
			{
			SayOrdinal(value);
			NewChar();	/* Used Char */
			NewChar();	/* Used Char1 */
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
		if (makeupper(Char) == 'T' && makeupper(Char1) == 'H' &&
		    !isalpha(Char2) && !isdigit(Char2))
			{
			SayOrdinal(value);
			NewChar();	/* Used Char */
			NewChar();	/* Used Char1 */
			return;
			}
		break;
		}

	SayCardinal (value);

	/* Recognize decimal points */
	if (Char == '.' && isdigit(Char1))
		{
		OutWordString ("point", "pOYnt");
		for (NewChar() ; isdigit(Char) ; NewChar())
			{
			//SayASCII (Char);
			SayCardinal (Char-'0');
			}
		}

	/* Spell out trailing abbreviations */
	if (isalpha(Char))
		{
		while (isalpha(Char))
			{
			SayASCII (Char);
			NewChar();
			}
		}
}
/* End of HaveNumber */


void XlateWord (char word[]) /* Note: word is upper case and has a leading and a trailing blank */
{
	int index;	/* Current position in word */
	int type;	/* First letter of match part */
	const_xmem_ptr_t Result;
        char tmp[32];
#ifdef TARGET_RABBIT
        long *ruleptr;
#endif
	char TempWord[MAX_LENGTH];
//printf ("\nXlateWord <%s> ", word);	

	/* Check for prerecorded words */
	strcpy (TempWord, word+1); /* Copy and remove the leading blank */
	TempWord[strlen(TempWord)-1] = '\0'; /* Remove the trailing blank */
	Result = MatchPrerecordedWord (TempWord);
	if (Result != 0) {
		xmem2root(tmp, Result, sizeof(tmp));
		OutRecordedWordString (tmp); // Output the recorded sounds
		return;
	}	

	// Otherwise convert to phonemes using the rules
	index = 1;	/* Skip the initial blank */
	do	{
		if (isupper(word[index]))
			type = word[index] - 'A' + 1;
		else
			type = 0;

#ifdef TARGET_RABBIT
		Result = Rules + (type * sizeof(long *));
		xmem2root(&ruleptr, Result, sizeof(long *));
		// Ruleptr now hopefully contains a ptr to the rules we're looking for
		index = FindRule (word, index, *((xmem_ptr_t*)ruleptr));
#else /* ! TARGET_RABBIT */
                index = FindRule (word, index, Rules[type]);
#endif
		}
	while (word[index] != '\0');
}
/* End of XlateWord */


/* Handle abbreviations.  Text in buff was followed by '.' */
void abbrev (char buff[])
{
	if (strcmp(buff, " DR ") == 0)
		{
		XlateWord(" DOCTOR ");
		NewChar();
		}
	else
	if (strcmp(buff, " MR ") == 0)
		{
		XlateWord(" MISTER ");
		NewChar();
		}
	else
	if (strcmp(buff, " MRS ") == 0)
		{
		XlateWord(" MISSUS ");
		NewChar();
		}
	else
	if (strcmp(buff, " MS ") == 0)
		{
		XlateWord(" MIZ ");
		NewChar();
		}
	else
	if (strcmp(buff, " PHD ") == 0)
		{
		SpellWord(" PHD ");
		NewChar();
		}
	else
		XlateWord(buff);
}
/* End of abbrev */


void HaveLetter (void)
{
	char buff[MAX_LENGTH];
	int count;

	count = 0;
	buff[count++] = ' ';	/* Required initial blank */

	buff[count++] = makeupper(Char);

	for (NewChar() ; isalpha(Char) || Char == '\'' ; NewChar())
		{
		buff[count++] = makeupper(Char);
		if (count > MAX_LENGTH-2)
			{
			buff[count++] = ' ';
			buff[count++] = '\0';
			XlateWord (buff);
			count = 1;
			}
		}

	buff[count++] = ' ';	/* Required terminating blank */
	buff[count++] = '\0';

	/* Check for AAANNN type abbreviations */
	if (isdigit(Char))
		{
		SpellWord (buff);
		return;
		}

	else
	if (strlen(buff) == 3)	 /* one character, two spaces */
		SayASCII (buff[1]);
	else
	if (Char == '.')		/* Possible abbreviation */
		abbrev(buff);
	else
		XlateWord(buff);

	if (Char == '-' && isalpha(Char1))
		NewChar();	/* Skip hyphens */

}
/* End of HaveLetter */


/*****************************************************
*
* Function Text: SayEnglishText
* Description: Queue a string to be said
* Arguments: 	Override = TRUE/FALSE
*			Text = string
*
*****************************************************/

void SayEnglishText (BOOL Override, char *Text)
{
	printf ("SayEng(%u,%s)\n", Override, Text);
	TextPointer = Text; // Copy pointer
	InitSoundQueue ();

	if (Override)
		OutOverrideChar ();

	/* Prime the queue */
	Char = '\n';
	Char1 = '\n';
	Char2 = '\n';
	Char3 = '\n';
	NewChar();	/* Fill Char, Char1, Char2 and Char3 */

	while (Char != '\0')	/* All of the words in the string */
		{
		if (isdigit(Char))
			HaveNumber();
		else
		if (isalpha(Char) || Char == '\'')
			HaveLetter();
#if NEED_CURRENCIES
		else if (Char == '$' && isdigit(Char1))
			HaveDollars();
#endif // NEED_CURRENCIES
		else
			HaveSpecial();
		}
	FlushSoundQueue ();
}
/* End of SayEnglishText */


/***** End of English.c *****/
