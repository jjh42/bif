/***************************************************************************
                          mcscomms.h  -  description
                             -------------------
    begin                : Mon Jul 30 2001
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

#ifndef MSCCOMMS_H
#define MSCCOMMS_H

#include <comms.h>

#ifdef C_CODE
void setup_comms();


/* Define what a comms table look likes */
typedef void (*COMMSHANDLER)();
typedef struct
        {
        char length;
        COMMSHANDLER handler;
        } COMMSTABLE;
/* The comms table is a lookup table 28 characters long (all the uppercase
 * characters plus < and >. */
#define COMMSTABLESTART '<'
#define COMMSTABLESIZE  28

/* Default handlers. */
void handleVersion();
void handleDump();
void handleSet();

#endif

#define COMMS_IDLE      0

#endif