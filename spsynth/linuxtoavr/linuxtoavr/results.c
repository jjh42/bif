/***************************************************************************
                          result.c  -  description
                             -------------------
    begin                : Thu Jan 18 2001
    copyright            : (C) 2001 by Jonathan Hunt
    email                : jhuntnz@users.sourceforge.net
 ***************************************************************************/

/***************************************************************************
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 ***************************************************************************/

#ifdef HAVE_CONFIG_H
#include <config.h>
#endif
#include <stdio.h>

#include "results.h"
#include "bool.h"

BOOL colour = FALSE;	/* Set to true when we should print in colour. */

void Success() /* Put OK */
{
 	if(colour)
		printf(MOVE_TO_COL "[  " SETCOLOR_SUCCESS "OK" SETCOLOR_NORMAL "  ]\n");
	else
		printf(" [  OK  ]\n");
}

void Warning() /* Put PASSED */
{
	if(colour)
  	fprintf(stdout, MOVE_TO_COL "[" SETCOLOR_WARNING "PASSED" SETCOLOR_NORMAL "]\n");
	else
 		printf( " [PASSED]\n");
}

void Failure() /* Put FAILED */
{
	if(colour)
  	printf( MOVE_TO_COL "[" SETCOLOR_FAILURE "FAILED" SETCOLOR_NORMAL "]\n");
	else
 		printf( " [FAILED]\n");
}