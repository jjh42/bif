/***************************************************************************
                          soundcontrol.h  -  description
                             -------------------
    begin                : Mon Sep 17 2001
    copyright            : (C) 2001 by Jonathan Hunt
    email                : jhuntnz@users.sf.net
 ***************************************************************************/

/***************************************************************************
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 ***************************************************************************/

/* Because of Dynamic C all of the headers contents must go between Beginheader
 * and endheader.
 */

/*** Beginheader */

#include "compat.h"
#include "sounds.h"
/* This is the automatically generated file that all the automatically generated sounds
 * files include to allow us to control them. */
typedef struct {
        constparam xmem_ptr_t Text;
        constparam xmem_ptr_t Sounds;
        } sound_table_t;


#define TABLE_HEADER(name)      XSTRING_DECL(name)

#ifdef TARGET_RABBIT
#define TABLE_DECL(name)		xstring name {
#else /* !TARGET_RABBIT */
#define TABLE_DECL(name)                XSTRING(name) {
#endif

#define TABLE_END                       "", "" };


/* English control */
TABLE_HEADER(RecordedWord)
#define E_TABLE_DECL            TABLE_DECL(RecordedWord)
#define E_TABLE_END             TABLE_END

/* Matigsalug control */
TABLE_HEADER(MRecordedWord)
#define M_TABLE_DECL            TABLE_DECL(MRecordedWord)
#define M_TABLE_END             TABLE_END

TABLE_HEADER(RecordedSyllable)
#define S_TABLE_DECL            TABLE_DECL(RecordedSyllable)
#define S_TABLE_END             TABLE_END

/* Phonemes */
TABLE_HEADER(RecordedPhoneme)
#define P_TABLE_DECL            TABLE_DECL(RecordedPhoneme)
#define P_TABLE_END             TABLE_END

/*** endheader */
