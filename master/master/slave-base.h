/*** Beginheader */

/***************************************************************************
                          slave-base.h  -  description
                             -------------------
    begin                : Tue Aug 14 2001
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

#ifndef _SLAVE_BASE_H
#define _SLAVE_BASE_H

extern void base_init();

extern void sendbase_haltmsg();
extern void sendbase_gomsg(U8 motorspeed, U16 angle, U16 distance);
extern void sendbase_reversemsg(U8 motorspeed, U16 distance);
extern void sendbase_overridespeedmsg(U8 motorspeed);

extern void setbase_intensity(U8 intensity);
extern U8 getbase_intensity();
/* Negative motor speeds indicate reverse. */
extern void setbase_leftmotorspeed(S16 motorspeed);
extern S16 getbase_leftmotorspeed();
extern void setbase_rightmotorspeed(S16 motorspeed);
extern S16 getbase_rightmotorspeed();

#define BASE_LIGHTS_LOW         0x00
#define BASE_LIGHTS_NORMAL      0x04
#define BASE_LIGHTS_FULL        0x08
#define BASE_LIGHTS_TEST        0x0c
#define BASE_LIGHTS_MASK        0x0c

#define BASE_POWER_OFF          0x00
#define BASE_POWER_LOW          0x01
#define BASE_POWER_NORMAL       0x02
#define BASE_POWER_MASK         0x03

#define BASE_STEALTH_OFF        0x00
#define BASE_STEALTH_ON         0x10
#define BASE_STEALTH_MASK       0x10

#define BASE_DIAGNOSTICS_OFF    0x00
#define BASE_DIAGNOSTICS_ON     0x20
#define BASE_DIAGNOSTICS_MASK   0x20

extern void setbase_lights(U8 level);
extern U8 getbase_lights();
extern void setbase_power(U8 level);
extern U8 getbase_power();
extern void setbase_stealth(bool on);
extern bool getbase_stealth();
extern void setbase_diagnostics(bool on);
extern bool getbase_diagnostics();

#define BASE_FRONT_DEFAULT      0x00
#define BASE_FRONT_REVERSE      0x01
#define BASE_FRONT_MASK         0x01

#define BASE_SWITCH_AUTO        0x02
#define BASE_SWITCH_MANUAL      0x00
#define BASE_SWITCH_MASK        0x02

#define BASE_TRAVEL_TURNANDSTRAIGHT     0x00
#define BASE_TRAVEL_CIRCLE              0x04
#define BASE_TRAVEL_EXTREME             0x08
#define BASE_TRAVEL_MASK                0x0c

#define BASE_AUTOSTOP_ON        0x10
#define BASE_AUTOSTOP_OFF       0x00
#define BASE_AUTOSTOP_MASK      0x10

extern void setbase_front(bool to_default);
extern bool getbase_front(); // returns TRUE if default front is the current front
extern void setbase_switchmode(bool automatic);
extern bool getbase_switchmode();
extern void setbase_travelmode(U8 mode);
extern U8 getbase_travelmode();
extern void setbase_autostop(bool enabled);
extern bool getbase_autostop();


// Bumper switches
// Note: Bumper switches are referenced from the ORIGINAL (PERMANENT) FRONT
#define RIGHT_FRONT_BUMPER_SWITCH 0x0100
#define LEFT_REAR_BUMPER_SWITCH 0x0200
#define RIGHT_SIDE_BUMPER_SWITCH 0x0400
#define RIGHT_REAR_BUMPER_SWITCH 0x0800
#define LEFT_FRONT_BUMPER_SWITCH 0x1000
#define LEFT_SIDE_BUMPER_SWITCH 0x2000

#define FRONT_BUMPER_SWITCHES (LEFT_FRONT_BUMPER_SWITCH | RIGHT_FRONT_BUMPER_SWITCH)
#define REAR_BUMPER_SWITCHES (LEFT_REAR_BUMPER_SWITCH | RIGHT_REAR_BUMPER_SWITCH)
#define SIDE_BUMPER_SWITCHES (LEFT_SIDE_BUMPER_SWITCH | RIGHT_SIDE_BUMPER_SWITCH)

#define LOWEST_BUMPER_SWITCH 0x0100
#define HIGHEST_BUMPER_SWITCH 0x2000


// Tilt switches
// Note: Tilt switches are referenced from the ORIGINAL (PERMANENT) FRONT
//	They are labelled by which one would activate if that part of the robot were to SINK DOWNWARDS
#define RIGHT_TILT_SWITCH 0x0001
#define BACK_TILT_SWITCH 0x0002
#define LEFT_TILT_SWITCH 0x0004
#define FRONT_TILT_SWITCH 0x0008

#define LOWEST_TILT_SWITCH 0x0001
#define HIGHEST_TILT_SWITCH 0x0008


// Switch states
#define SWITCH_DOWN 1
#define SWITCH_UP 2

extern bool isbase_moving();
/* Call with the name of the switches above. */
extern bool isbase_switchdown(U16 sw);

#endif
/*** endheader */

