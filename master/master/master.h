/*** Beginheader */

/***************************************************************************
                          master.h  -  description
                             -------------------
    begin                : Mon Aug 27 2001
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

/* Architecture independant things. */

#ifndef _MASTER_H
#define _MASTER_H

#include <version.h>

#include "threads.h"

#define MASTER_VERSION  0010
#define MASTER_VERSION_STRING "0.0.1.0"

#ifdef TARGET_POSIX
/* This is the start of the architecture independant program. */
extern void mastermain();
#endif /* TARGET_POSIX */

#endif /* _MASTER_H */

/*** endheader */

