/***************************************************************************
                          slave-ir.c  -  description
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

 /* Dummy headers for Dynamic C */
/*** Beginheader slave_ir_c */
#ifdef TARGET_RABBIT
void slave_ir_c();

#asm
XXXslave_ir_c:	equ	slave_ir_c
#endasm

#endif /* TARGET_RABBIT */
/*** endheader */


#ifdef TARGET_RABBIT
void slave_ir_c () { }
#endif /* TARGET_RABBIT */


#ifdef TARGET_POSIX
#include <stdlib.h>
#include <stdio.h>
#endif

#include "compat.h"
#include "slavecomms.h"
#include "slave-ir.h"
#include "IRControl.h"
#include "control.h"
#include "commonsubs.h"
#include "alloc.h"

int ir_handler_ir(char *d);
int ir_handler_batterypower(char *d);
int ir_handler_charging(char *d);

const slaveresponse_handlertable_t infrared_handler_table[] =
{
        { 'B', 2, ir_handler_batterypower   },
        { 'C', 2, ir_handler_charging       },
        { 'D', CR_MSG, generic_handler_dump },
        { 'E', 6, generic_handler_error  },
        { 'F', 2, ir_handler_ir },
        { 'R', 2, ir_handler_ir },
        { 'V', 4, generic_handler_version },
        { 0, 0, NULL }
};

nodebug void ir_init()
{
sendir_ledmsg (IR_LEDMODE_NORMAL, IR_LEDMODE_NORMAL);
}

void sendir_ledmsg (U8 front, U8 back)
{
        char *d;

#ifdef REAL_COMPILER
		printf (" SendIR_LEDMsg(%u,%u) ", front, back);
#endif

        d = ialloc(sizeof(char) * 4);

        assert(front <= IR_LEDMODE_FASTFLASH);
        assert(back <= IR_LEDMODE_FASTFLASH);

        *d = 'L';
        printhexbyte(d + 1, ((front << 4) | back));

        add_slave_msg('I', PRIORITY_NORMAL_MSG, d, SM_FREEDATA);
}
/* End of sendir_ledmsg */


static const char standby[] = "P00"; // Power-down - the digits are just for validation
void sendir_standbymsg()
{
        add_slave_msg('I', PRIORITY_NORMAL_MSG, standby, 0);
}


static const char poweroff[] = "K99"; // Kill - the digits are just for validation
void sendir_poweroffmsg()
{
        add_slave_msg('I', PRIORITY_NORMAL_MSG, poweroff, 0);
}

int ir_handler_ir(char *d)
{
        S16 key;
        /* First get the data. */
        key = gethexbyte(d);
        if(key < 0)
                return -1;

        HandleIRKey(key, response_msg == 'F' ? IR_SOURCE_FRONT : IR_SOURCE_BACK);

        return 0;
}

int ir_handler_batterypower(char *d)
{
        S16 NewLevel;
        /* First get the data. */
        NewLevel = gethexbyte(d);
        if(NewLevel < 0)
                return -1;

        ActionNewBatteryLevel (NewLevel);
        return 0;
}

int ir_handler_charging(char *d)
{
        int NewLevel;
        /* First get the data. */
        NewLevel = gethexbyte(d);
        if(NewLevel < 0)
                return -1;

        ActionNewChargingLevel (NewLevel);
        return 0;
        return 0;
}

