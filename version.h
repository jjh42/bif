/***************************************************************************
                          version.h  -  description
                             -------------------
    begin                : Wed Jun 20 2001
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
/*** Beginheader */
#ifndef __ROBOT_VERSION
#define __ROBOT_VERSION

/* Overall robot version. */
#define ROBOT_VERSION_STRING "0.0.1.0"
#define ROBOT_VERSION 0010

#define VERSION_FIX(v) \
	(v % 10)
#define VERSION_REVISION(v) \
	((v / 10) % 10)
#define VERSION_MINOR(v) \
	((v / 100) % 10)
#define VERSION_MAJOR(v) \
	((v / 1000) % 10)

#endif

/*** endheader */
