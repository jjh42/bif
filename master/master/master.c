/***************************************************************************
                          master.c  -  description
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

#ifndef TARGET_POSIX
#define TARGET_RABBIT
#endif

#ifdef TARGET_POSIX
#include <stdio.h>
#include <unistd.h>
#include <termios.h>
#endif // TARGET_POSIX

#ifdef TARGET_RABBIT
// Variables inside a function default to being declared on the stack (not static)
#class auto
// Default storage class is xmem. Use root to put a function in root memory
#memmap xmem

#ifndef NDEBUG
#debug
#else
#nodebug
#endif


#use version.h
#use comms.h

#use compat.h
#use compat-rabbit.h

#use io.h
#use LCD.h
#use mytime.h
#use threads.h
#use alloc.h
#use soundcontrol.h
#use sounds.h
#use speak.h
#use Brain.h
#use IR.h
#use IRControl.h
#use commonsubs.h
#use computercontrol.h
#use control.h
#use master.h
#use slavecomms.h
#use slave-base.h
#use slave-ir.h
#use slave-io.h
#use slave-speech.h

// Time critical modules should be listed first to ensure a higher chance of being put in the root code space
#use io.c
#use lcd.c
#use mytime.c
#use rabbitthreads.c
#use alloc.c
#use slavecomms.c
#use commonsubs.c
#use control.c
#use slave-base.c
#use slave-io.c
#use slave-ir.c
#use slave-speech.c
#use speak.c
#use ircontrol.c
#use brain.c
#use computercontrol.c
#use tell.c
#use help.c
#use english.c
#use matigsalug.c
#use sounds_P.c
#use sounds_S.c
#use sounds_M.c
#use sounds_E.c

#else // not TARGET_RABBIT

// The following includes are ignored anyway by the Dynamic-C (Rabbit) compiler
#include "compat.h"
#include "master.h"
#include "io.h"
#include "LCD.h"
#include "slavecomms.h"
#include "threads.h"
#include "IRControl.h"
#include "control.h"
#include "Brain.h"
#include "speak.h"
#include "computercontrol.h"
#include "alloc.h"
#include "threads.h"

#ifdef TARGET_POSIX
#include "posix.h"
void init_tty();
void restore_tty();

static struct termios originalterm;
#endif

#endif

/* This is the start of the architecture independant program. */
#ifdef TARGET_RABBIT
void main ()	/* This is the main routine on the rabbit. */
#else // not TARGET_RABBIT
void mastermain () /* Called from Posix main */
#endif
{
        // Do initializations
#ifdef TARGET_POSIX
        printf("Robot Master is starting\n");
        init_tty();
#endif
        init_dynamic_memory();
        init_threads();
        InitIO();
        InitLCD();
        init_slavecomms();
        InitSpeak();
        InitControls();
        init_computercontrol();
        InitIRControl();
        InitBrain();

        /* The main loop for the main thread. */
        for(;;) {
                UpdateIRControl();
                UpdateControls();
                UpdateBrain();
                UpdateIO();
                UpdateLCD();
                thread_yield();
        }

#ifdef TARGET_POSIX
        restore_tty();
#endif // TARGET_POSIX
}


#ifdef TARGET_POSIX
/* Setup the tty to get one character at a time. */
void init_tty()
{
        struct termios newterm;

        tcgetattr(STDIO_IN, &originalterm);
        newterm = originalterm;

        /* Set up the new terminal. */
        newterm.c_lflag &= ~(ECHOCTL | ICANON);

        tcsetattr(STDIO_IN, TCSANOW, &newterm);
}

void restore_tty()
{
        tcsetattr(STDIO_IN, TCSANOW, &originalterm);
}
#endif // TARGET_POSIX


#ifdef TARGET_RABBIT
nodebug root void assert(bool val)
{
	if(!val)
		printf("Assertion failure\n");
}

root long __deref_xmem(const_xmem_ptr_t ptr)
{
	long temp;
	xmem2root(&temp, ptr, sizeof(temp));
	return temp;
}
#endif // TARGET_RABBIT

