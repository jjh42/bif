/***************************************************************************
                          common.h  -  description
                             -------------------
    begin                : Sun Jul 29 2001
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

#ifndef     COMMON_H
#define     COMMON_H

#define         STACK_CHECKBYTE         0x16

#define         CLOCK_SPEED             (OSC_SPEED / 12)

#define         LOW(b)                  (b)
#define         HIGH(b)                 (b >> 8)

/* Define the interupt vectors. */
#define         VTABLE_LEN              5 * 3
#define         UART_VECT               4 * 3

/* Address of registers */
#define         AR0                     0
#define         AR1                     1
#define         AR2                     2
#define         AR3                     3

#endif