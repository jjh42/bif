/***************************************************************************
                          alloc.h  -  description
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

/* Because of Dynamic C all of the headers contents must go between Beginheader
 * and endheader.
 */

/*** Beginheader */

/* This is the header for alloc.c. Use ialloc and ifree to allocate and free data
 * inside the rabbits internal memory. Note: The buffer size is limited so don't
 * allocate large amounts of data.
 *
 * Implements a first-fit algorithm.
 */

void init_dynamic_memory();
void *ialloc(unsigned int memsize);
void ifree(void *ptr);


/*** endheader */
