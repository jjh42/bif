/*** Beginheader */

/***************************************************************************
                          commonsubs.h  -  description
                             -------------------
    begin                : Tue Sep 4 2001
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

#ifndef _COMMON_SUBS_H
#define _COMMON_SUBS_H

#include "threads.h"

/* Doubly linked list support. */
#ifndef TARGET_RABBIT
struct listentry_tag;
#endif

typedef struct listentry_tag {
#ifndef TARGET_RABBIT
                struct listentry_tag *next;
                struct listentry_tag *previous;
#else
					void *next;
					void *previous;
#endif

        }
        listentry_t;

typedef struct {
                listentry_t *firstentry;
                listentry_t *lastentry;
                mutex_t lock;
        }
        list_t;


void list_init(list_t *list);
void list_add(list_t *list, listentry_t *entry);
void list_remove(list_t *list, listentry_t *entry);

extern U16 rndrange (U16 rr_bottom, U16 rr_top);
extern U8 rnd100 ();
extern char *SelectString (U8 ssNumChoices, char *choices[]);

/* Hex processing routines
 * Return the value or -1 on error.
 *
 * Note: These only work on lowercase hexadecimal digits (f works, F produces
 *       an error.
 *
 * Expect input to be MSB first.
 */
S8 gethexnibble(constparam char *str);
S16 gethexbyte(constparam char *str);
S32 gethexword(constparam char *str);
/* Returns false on failure. */

/* Hex formatting routines.
 * All add a ending 0 at the end. All format hex in lowercase with
 * leading zeroes if necessary.
 */
void printhexnibble(char *str, U8 data);
void printhexbyte(char *str, U8 data);
void printhexword(char *str, U16 data);
void printhexdword(char *str, U32 data);

#endif /* _COMMON_SUBS_H */

/*** endheader */

