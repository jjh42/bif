

/* Dummy headers for Dynamic C */
/*** Beginheader commonsubs_c */
#ifdef TARGET_RABBIT
void commonsubs_c();

#asm
XXXCommonsubs_c:	equ	commonsubs_c
#endasm

#endif /* TARGET_RABBIT */
/*** endheader */

#ifdef TARGET_RABBIT
void commonsubs_c () { }
#endif /* TARGET_RABBIT */



/***************************************************************************
                          commonsubs.c  -  description
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

#include <stdlib.h>
#include <stdio.h>

#include "compat.h"
#include "threads.h"
#include "commonsubs.h"


/*****************************************************
*
* Function Name: 
* Description: 
* Argument: None
* Return Value: None
*
*****************************************************/

/* Generic list routines. */
void list_init(list_t *list)
{
        list->firstentry = NULL;
        list->lastentry = NULL;
        mutex_init(&list->lock);
}

void list_add(list_t *list, listentry_t *entry)
{
        mutex_lock(&list->lock);

        entry->next = NULL;

        if(list->lastentry) {
                ((listentry_t*)entry)->previous = list->lastentry;
                list->lastentry->next = entry;
        }
        else {
                entry->previous = NULL;
                list->firstentry = entry;
        }


        list->lastentry = entry;

        mutex_unlock(&list->lock);
}


void list_remove(list_t *list, listentry_t *entry)
{
        mutex_lock(&list->lock);

        if(entry->next) {
                ((listentry_t*)entry->next)->previous = (listentry_t*)entry->previous;
        }

        if(entry->previous) {
                ((listentry_t*)entry->previous)->next = entry->next;
        }

        if(list->firstentry == entry) {
                list->firstentry = entry->next;
        }

        if(list->lastentry == entry) {
                list->lastentry = entry->previous;
        }

        mutex_unlock(&list->lock);
}


/*****************************************************
*
* Function Name: rnd100
* Description: Returns a random number from 0..99
* Argument: None
* Return Value: Random integer
*
*****************************************************/

U8 rnd100 ()
{
#ifdef TARGET_WIN32
float rrr;
U8 sss;
rrr = (float)rand() / 32768.0F;
sss = (U8)(rrr * 100.0);
printf (" rnd100=%u ", sss);
return sss;
#else
return (U8)(rand() * 100.0);
#endif
}
/* end of rnd100 */


/*****************************************************
*
* Function Name: rndrange
* Description: Returns a random number  so that bottom <= number < top
* Arguments: bottom of range, top of range
* Return Value: Random integer
*
*****************************************************/

U16 rndrange (U16 rr_bottom, U16 rr_top)
{
#ifdef TARGET_WIN32
float rrr;
U16 sss;
rrr = (float)rand() / 32768.0F;
sss = (U16)(rrr * (float)(rr_top - rr_bottom) + rr_bottom);
printf (" rnd(%u,%u)=%u ", rr_bottom, rr_top, sss);
return sss;
#else
return (U16)(rand() * (float)(rr_top - rr_bottom) + rr_bottom);
#endif
}
/* end of rndrange */


/*****************************************************
*
* Function Name: SelectString
* Description: Returns a pointer to a randomly selected string
* Arguments: number of choices, pointer to array of string pointers
* Return Value: Pointer to selected character string
*
*****************************************************/

char *SelectString (U8 ssNumChoices, char *choices[])
{
return choices[rndrange(0, ssNumChoices)];
}
/* End of SelectString */


nodebug S8 gethexnibble(constparam char *str)
{
        if(*str >= '0' && *str <= '9')
                return (S8)(*str - '0');
        else if(*str >= 'a' && *str <= 'f')
                return (S8)(*str - 'a' + 0x0a);

        return (S8)-1;
}


nodebug S16 gethexbyte(constparam char *str)
{
        S16 result;

        result = gethexnibble(str);
        if(result < 0)
                return -1;
        result <<= 4;

        result |= gethexnibble(str + 1);
        if(result < 0)
                return -1;

        return result;
}

nodebug S32 gethexword(constparam char *str)
{
        S32 result;

        result = gethexbyte(str);
        if(result < 0)
                return -1;
        result <<= 8;

        result |= gethexbyte(str + 2);
        if(result < 0)
                return -1;

        return result;
}

nodebug void printhexnibble(char *str, U8 data)
{
        assert(data < 16);
        if(data < 0x0a)
                data += '0';
        else
                data += 'a' - 0x0a;

        *str = (char)data;
        *(str + 1) = 0;
}

nodebug void printhexbyte(char *str, U8 data)
{
        printhexnibble(str, (U8)(data >> 4));
        printhexnibble(str + 1, (U8)(data & 0x0f));
}

nodebug void printhexword(char *str, U16 data)
{

        printhexbyte(str, (U8) (data >> 8));
	printhexbyte(str + 2, (U8)(data & 0xff));
}

nodebug void printhexdword(char *str, U32 data)
{
        printhexword(str, (U16)(data >> 16));
        printhexword(str + 4, (U16)(data & 0xffff));
}


/* End of commonsubs.c */
