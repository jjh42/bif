/***************************************************************************
                          config.h  -  description
                             -------------------
    begin                : Thu Jul 26 2001
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

#ifndef CONFIG_H
#define CONFIG_H

/* Defines before including common. */
#define     	SLAVE		0

#define         OSC_SPEED     11059200

#define         STACK_SIZE      16

/* Length of the comms buffer. */
#define         COMMSBUFSIZE       16

/* There are 4 register banks. 3 are reserved for ISRs. */
#define         COMMON_BANK     0
#define         COMMS_BANK      1

#include "common.h"

#ifdef  C_CODE
#include <at89S8252.h>
#endif

#endif