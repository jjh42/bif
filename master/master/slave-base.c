

/* Dummy headers for Dynamic C */
/*** Beginheader slave_base_c */
#ifdef TARGET_RABBIT
void slave_base_c();

#asm
xxxslave_base_c: equ slave_base_c
#endasm
#endif /* TARGET_RABBIT */
/*** endheader */

#ifdef TARGET_RABBIT

void slave_base_c () { }
#endif /* TARGET_RABBIT */


/***************************************************************************
                          slave-base.c  -  description
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

/* This file doesn't have a whole lot of comments. Most of the routines are
 * fairly simple routines for sending a message. Mostly they set a variable and
 * then send a message. The end up calling add_slave_msg.
 */

#ifdef TARGET_POSIX
#include <stdlib.h>
#include <stdio.h>
#include <assert.h>
#include <math.h>
#endif

#include "compat.h"
#include "slavecomms.h"
#include "slave-base.h"
#include "control.h"
#include "alloc.h"
#include "commonsubs.h"

void updatebase_power();
void updatebase_travel();
int base_handler_movement(char *d);
int base_handler_switch(char *d);


const slaveresponse_handlertable_t base_handler_table[] =
{
        { 'D', CR_MSG, generic_handler_dump },
        { 'E', 6, generic_handler_error  },
        { 'M', 2, base_handler_movement  },
        { 'V', 4, generic_handler_version },
		{ 'Z', 4, base_handler_switch    },
        { 0, 0, NULL }
};

U8 base_power;
U8 base_travel;
U8 base_intensity;
U16 base_leftmotorspeed;
U16 base_rightmotorspeed;
U16 base_switches;
bool base_moving;

void base_init()
{
        base_power = BASE_LIGHTS_NORMAL | BASE_POWER_NORMAL;
        base_travel = BASE_SWITCH_AUTO | BASE_AUTOSTOP_ON;
        base_intensity = 0xff;
        base_leftmotorspeed = base_rightmotorspeed = 0;
        base_switches = 0xffff;
        base_moving = false;

        updatebase_power();
        updatebase_travel();
        sendbase_haltmsg();
}

void setbase_lights(U8 level)
{
        assert((level & (~BASE_LIGHTS_MASK)) == 0);
        printf (" setbase_lights(%u) ", level);
        base_power = (base_power & (~BASE_LIGHTS_MASK)) | level;
        updatebase_power();
}

U8 getbase_lights()
{
        return base_power & BASE_LIGHTS_MASK;
}

void setbase_power(U8 level)
{
        assert((level & (~BASE_POWER_MASK)) == 0);
        printf (" setbase_power(%u) ", level);
        base_power = (base_power & (~BASE_POWER_MASK)) | level;
        updatebase_power();
}

U8 getbase_power()
{
        return base_power & BASE_POWER_MASK;
}

void setbase_stealth(bool on)
{
        printf (" setbase_stealth(%d) ", on);
        base_power = (base_power & (~BASE_STEALTH_MASK)) | on ? BASE_STEALTH_ON :
                BASE_STEALTH_OFF;
        updatebase_power();
}

bool getbase_stealth()
{
        return base_power & BASE_STEALTH_MASK ? true : false;
}

void setbase_diagnostics(bool on)
{
        printf (" setbase_diagnostics(%d) ", on);
        base_power = (base_power & (~BASE_DIAGNOSTICS_MASK)) | on ? BASE_DIAGNOSTICS_ON :
                BASE_DIAGNOSTICS_OFF;
        updatebase_power();
}

bool getbase_diagnostics()
{
        return base_power & BASE_DIAGNOSTICS_MASK ? true : false;
}

void setbase_front(bool to_default)
{
        printf (" setbase_front(%d) ", to_default);
        base_travel = (base_travel & (~BASE_FRONT_MASK)) | to_default ? BASE_FRONT_DEFAULT :
                BASE_FRONT_REVERSE;
        updatebase_travel();
}

bool getbase_front() // returns TRUE if default front is the current front
{
        return base_travel & BASE_FRONT_MASK ? false : true;
}

void setbase_switchmode(bool automatic)
{
        printf (" setbase_switchmode(%d) ", automatic);
        base_travel = (base_travel & (~BASE_SWITCH_MASK)) | automatic ? BASE_SWITCH_AUTO :
                BASE_SWITCH_MANUAL;
        updatebase_travel();
}

bool getbase_switchmode()
{
        return base_travel & BASE_SWITCH_MASK ? true : false;
}

void setbase_travelmode(U8 mode)
{
        assert((mode & (~BASE_TRAVEL_MASK)) == 0);
        printf (" setbase_travelmode(%u) ", mode);
        base_travel = (base_travel & (~BASE_TRAVEL_MASK)) | mode;
        updatebase_travel();

}

U8 getbase_travelmode()
{
        return base_travel & BASE_TRAVEL_MASK;
}

void setbase_autostop(bool enabled)
{
        printf (" setbase_autostop(%d) ", enabled);
        base_travel = (base_travel & (~BASE_AUTOSTOP_MASK)) | enabled ?
                BASE_AUTOSTOP_ON : BASE_AUTOSTOP_OFF;
        updatebase_travel();
}

bool getbase_autostop()
{
        return base_travel & BASE_AUTOSTOP_MASK ? true : false;
}

void setbase_intensity(U8 intensity)
{
        char *d;

        d = ialloc(sizeof(char) * 4);

        *d = BINTENSITY_MSG;
        printhexbyte(d + 1, intensity);

        add_slave_msg(BASE_ID, PRIORITY_NORMAL_MSG, d, SM_FREEDATA);

        base_intensity = intensity;
}

U8 getbase_intensity()
{
        return base_intensity;
}

void setbase_leftmotorspeed(S16 motorspeed)
{
        char *d;

        d = ialloc(sizeof(char) * 4);

        assert(motorspeed >= -255 && motorspeed <= 255);

        *d =  motorspeed < 0 ? BGOLBWD_MSG : BGOLFWD_MSG;
        motorspeed = abs(motorspeed);

        printhexbyte(d + 1, (U8)motorspeed);

        add_slave_msg(BASE_ID, PRIORITY_NORMAL_MSG, d, 0);

        base_leftmotorspeed = motorspeed;

        base_moving = true;
}

S16 getbase_leftmotorspeed()

{
        return base_leftmotorspeed;
}

void setbase_rightmotorspeed(S16 motorspeed)
{
        char *d;

        d = ialloc(sizeof(char) * 4);

        assert(motorspeed >= -255 && motorspeed <= 255);

        *d =  motorspeed < 0 ? BGORBWD_MSG : BGORFWD_MSG;
        motorspeed = abs(motorspeed);

        printhexbyte(d + 1, (U8) motorspeed);

        add_slave_msg(BASE_ID, PRIORITY_NORMAL_MSG, d, 0);

        base_rightmotorspeed = motorspeed;

        base_moving = true;
}

S16 getbase_rightmotorspeed()


{
        return base_rightmotorspeed;
}

static const char haltmsg[] = { BHALT_MSG, 0 };
void sendbase_haltmsg()
{
        add_slave_msg(BASE_ID, PRIORITY_URGENT_MSG, haltmsg, 0);
        base_moving = false;
}

void sendbase_overridespeedmsg(U8 motorspeed)
{
        char *d;
        d = ialloc(sizeof(char) * 4);

        *d = BSPEED_MSG;
        printhexbyte(d + 1, (U8) motorspeed);

        add_slave_msg(BASE_ID, PRIORITY_NORMAL_MSG, d, SM_FREEDATA);
}

void sendbase_gomsg(U8 motorspeed, U16 angle, U16 distance)
{
        char *d; 
        char msg;

        d = ialloc(sizeof(char) * 10);
        if(angle > 180) {
                msg = BGOLEFT_MSG;
                angle = 360 - angle;
        }
        else
                msg = BGORIGHT_MSG;

        *d = msg;
        printhexbyte(d + 1, (U8) motorspeed);
        printhexbyte(d + 3, (U8) angle);
        printhexword(d + 5, (U16) distance);

        add_slave_msg(BASE_ID, PRIORITY_NORMAL_MSG, d, SM_FREEDATA);

        base_moving = true;
}

void sendbase_reversemsg(U8 motorspeed, U16 distance)
{
        char *d;

        d = ialloc(sizeof(char) * 8);

        *d = BREVERSE_MSG;
        printhexbyte(d + 1, motorspeed);
        printhexword(d + 3, distance);

        add_slave_msg(BASE_ID, PRIORITY_NORMAL_MSG, d, SM_FREEDATA);

        base_moving = false;
}

void updatebase_power()
{
        char *d;
        d = ialloc(sizeof(char) * 4);

        *d = BPOWER_MSG;
        printhexbyte(d + 1, base_power);

        add_slave_msg(BASE_ID, PRIORITY_NORMAL_MSG, d, SM_FREEDATA);
}

void updatebase_travel()
{
        char *d;

        d = ialloc(sizeof(char) * 4);

        *d = BTRAVEL_MSG;
        printhexbyte(d + 1, base_travel);

        add_slave_msg(BASE_ID, PRIORITY_NORMAL_MSG, d, SM_FREEDATA);
}

int base_handler_movement(char *d)
{
        S16 flags;

        flags =gethexbyte(d);
        if(flags < 0)
                return -1;

        ActionStoppedMoving((flags & 0x80) != 0, (flags & 0x01) != 0);

        base_moving = false;

        return 0;
}

int base_handler_switch(char *d)
{
        S32 new_switches;
        int i;
        bool old_sw;
        bool new_sw;

        new_switches = gethexword(d);
        if(new_switches < 0)
                return -1;
        // Have the new switch state. Compare with the old state.
        for(i = 0; i < 14;) {
                old_sw = (base_switches & (1 << i)) != 0;
                new_sw = (new_switches & (1 << i)) != 0;
                if(old_sw != new_sw) {
                        // Switch has changed so call handler
                        ActionSwitchChange ((1 << i), new_sw ? SWITCH_UP :
                                SWITCH_DOWN);
                }

                i++;
                if( i == 4)     // Skip to bumper switches
                        i = 8;

        }
	
	base_switches = (U16)new_switches;

        return 0;
}


bool isbase_moving()
{
        return base_moving;
}

bool isbase_switchdown(U16 sw)
{
        return (base_switches & sw) != 0;
}


/* End of slave-base.c */
