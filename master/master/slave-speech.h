/*** Beginheader */

/***************************************************************************
                          slave-speech.h  -  description
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

#ifndef _SLAVE_SPEECH_H
#define _SLAVE_SPEECH_H

// Beep times in msec
#define Beep0s1 100
#define Beep0s2 200

// Beep frequencies in Hz
#define Beep160Hz 160
#define Beep200Hz 200
#define Beep240Hz 240
#define Beep300Hz 300
#define Beep400Hz 400
#define Beep480Hz 480
#define Beep600Hz 600
#define Beep800Hz 800
#define Beep1200Hz 1200
#define Beep2400Hz 2400

#define BEEP_SILENT 0 // for waveform for a pause (freq is ignored)
#define SQUARE_WAVE 1 // for waveform
#define TRIANGLE_WAVE 2
#define SINE_WAVE 3
extern void beep(U8 waveform, U16 freq, U16 time);
extern void errorbeep ();

extern void speech_init();

extern void saysounds(constparam U8 *items);
extern void saysound(U8 item);
#define SAY_FIFO_SIZE           1024

#define SPEECH_NODEBUG          0x00
#define SPEECH_DEBUG            0x01
#define SPEECH_DEBUG_MASK       0x01
extern void speech_flagmsg(U8 flags);
extern void speech_tonemsg(U8 tone);

#endif /* _SLAVE_SPEECH_H */

/*** endheader */

