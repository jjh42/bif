/*** Beginheader */

/***************************************************************************
                          slave-ir.h  -  description
                             -------------------
    begin                : Fri Aug 31 2001
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

#ifndef _SLAVE_IR_H
#define _SLAVE_IR_H

extern void ir_init();

#define IR_LEDMODE_ALWAYSOFF    0
#define IR_LEDMODE_ALWAYSON     1
#define IR_LEDMODE_NORMAL       2
#define IR_LEDMODE_INVERSE      3
#define IR_LEDMODE_SLOWFLASH    4
#define IR_LEDMODE_FASTFLASH    5
extern void sendir_ledmsg(U8 front, U8 back);
extern void sendir_standbymsg();
extern void sendir_poweroffmsg();

#endif /* _SLAVE_IR_H */

/*** endheader */

