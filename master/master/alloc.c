/***************************************************************************
                          alloc.c  -  description
                             -------------------
    begin                : Mon Sep 10 2001
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

/*** Beginheader */
// Amount of memory allocated
#define MEM_SIZE        3072
/*** endheader */

/* Dummy headers for Dynamic C */
/*** Beginheader alloc_c */
#ifdef TARGET_RABBIT
void alloc_c();

#asm
XXXalloc_c:	equ	alloc_c
#endasm

#endif /* TARGET_RABBIT */
/*** endheader */


#ifdef TARGET_RABBIT
void alloc_c () { }
#endif /* TARGET_RABBIT */

#include <stdio.h>

#include "compat.h"
#include "alloc.h"

/* This file is based on this from sdcc. (http://sdcc.sf.net).

 * Modified by Jonathan Hunt <jhuntnz@uses.sf.net>.
 */
//--------------------------------------------------------------------
//Written by Dmitry S. Obukhov, 1997
//dso@usa.net
//--------------------------------------------------------------------
//Modified for SDCC by Sandeep Dutta, 1999
            //sandeep.dutta@usa.net
//--------------------------------------------------------------------

// Memory Allocation Header
#ifndef TARGET_RABBIT
struct memheader_tag;
#endif

typedef struct memheader_tag {
#ifndef TARGET_RABBIT
        struct memheader_tag *next;
        struct memheader_tag *prev;
#else   /* TARGET_RABBIT */
        void *next;
        void *prev;
#endif
        unsigned int       len;
        } memheader_t;

#define HEADER_SIZE (sizeof(memheader_t))


memheader_t *first_memory_header;
U8 array[MEM_SIZE];

xmem void init_dynamic_memory()
{
        first_memory_header = (memheader_t*)array;

        //Reserve a mem for last header
        first_memory_header->next = (memheader_t*) (array + MEM_SIZE - HEADER_SIZE);
        ((memheader_t*)first_memory_header->next)->next = NULL; //And mark it as last
        first_memory_header->prev = NULL; //and mark first as first
        first_memory_header->len = 0; //Empty and ready.

}

xmem void  *ialloc (unsigned int memsize)
{
        register memheader_t *current_header;
        register memheader_t *new_header;

        if (memsize > (0xFFFF - HEADER_SIZE)) {
                assert(0);
                return NULL; //To prevent overflow in next line
        }
        // Size == 0 is okay as long as they don't write to
        // any memory. So return 1.
        if(memsize == 0)
                return (void*)1;

        memsize += HEADER_SIZE; //We need memory for header too

        current_header = first_memory_header;

        for(;;) {

        //    current

        //    |   len       next
        //    v   v         v
        //....*****.........******....
        //         ^^^^^^^^^
        //           spare

                if ( ( ((unsigned int)current_header->next) -
                     ((unsigned int)current_header) -
                     current_header->len ) >= memsize )
                        break; //if spare is more than needed

                current_header = current_header->next;    //else try next

                if (!current_header->next) {
                        printf("Out of dynamic memory\n");
                        return NULL;  //if end_of_list reached
                }
        }

        if (!current_header->len) { //This code works only for first_header in the list and only
                current_header->len = memsize; //for first allocation
                return (void*)(((char *)current_header) + HEADER_SIZE);
        } //else create new header at the begin of spare

        new_header = (memheader_t*) (((unsigned int)current_header) + current_header->len);
        new_header->next = current_header->next; //and plug it into the chain
        new_header->prev = current_header;
        current_header->next  = new_header;
        if (new_header->next)
                ((memheader_t*)new_header->next)->prev = new_header;

        new_header->len = memsize; //mark as used
        return (void*)(((char *)new_header) + HEADER_SIZE);
}

xmem void ifree (void *ptr)
{
        register memheader_t *prev_header;
        register memheader_t *p;

        p = (memheader_t*) (((U8 *)ptr) - HEADER_SIZE);

        if(p) {// For allocated pointers only

                if(p->prev) {// For the regular header
                        prev_header = p->prev;
                        prev_header->next = p->next;
                        if(p->next)
                                ((memheader_t*)p->next)->prev = prev_header;
                }
                else
                        p->len = 0; //For the first header
        }
}

#if 0
void *ialloc(int size)
{
        return malloc(size);
}
void ifree(void *ptr)
{
        free(ptr);
}

#endif