/***************************************************************************
                          slave-io.c  -  description
                             -------------------
    begin                : Mon Oct 1 2001
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


/* Dummy headers for Dynamic C */
/*** Beginheader slave_io_c */
#ifdef TARGET_RABBIT
void slave_io_c();

#asm
XXXslave_io_c:	equ	slave_io_c
#endasm

#endif /* TARGET_RABBIT */
/*** endheader */


#ifdef TARGET_RABBIT
void slave_io_c () { }
#endif /* TARGET_RABBIT */


#include "compat.h"
#include "slavecomms.h"
#include "slave-io.h"

int io_handler_forward(char *d);

const slaveresponse_handlertable_t io_supervisor_handler_table[] =
{
        { '>', CR_MSG, io_handler_forward },
        { 'D', CR_MSG, generic_handler_dump },
        { 'E', 6, generic_handler_error  },
        { 'V', 4, generic_handler_version },
        { 0, 0, NULL }
};

const slaveresponse_handlertable_t io_slave_handler_table[] =
{
        { '<', CR_MSG, io_handler_forward },
        { 'D', CR_MSG, generic_handler_dump },
        { 'E', 6, generic_handler_error  },
        { 'V', 4, generic_handler_version },
        { 0, 0, NULL }
};


/* This is called for the messages the two io slaves send to each other.
 * It just ignores them.
 */
int io_handler_forward(char *d)
{
        return 0;
}

void io_supervisor_init()
{
}

void io_slave_init()
{
}
