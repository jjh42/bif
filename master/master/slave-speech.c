

/* Dummy headers for Dynamic C */
/*** Beginheader slave_speech_c */
#ifdef TARGET_RABBIT
void slave_speech_c();

#asm
xxxslave_speech_c: equ slave_speech_c
#endasm
#endif /* TARGET_RABBIT */
/*** endheader */

#ifdef TARGET_RABBIT
void slave_speech_c () { }
#endif /* TARGET_RABBIT */


/***************************************************************************
                          slave-speech.c  -  description
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

#ifdef TARGET_POSIX
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <threads.h>
#include <unistd.h>
#include <errno.h>
#include <sys/wait.h>

#include "posix.h"
#endif

#include "compat.h"
#include "slavecomms.h"
#include "slave-speech.h"
#include "commonsubs.h"
#include "alloc.h"
#include "threads.h"

/* Explanation of how the speech queuing is handled:

 *
 * Every time the higher level wants to say a sound it calls say(const char *)
 * (or saychar which ends up calling say). Say puts the string in a buffer and
 * calls speech_sendsay(). Speech_sendsay checks freeslotsonslave. It sends
 * a message a maximum of 16 sounds long. This maximum is reduced if there is
 * not 16 sounds in the queue. Ff freeslotsonslave is less than 16 then it doesn't
 * both sending a message.
 *
 * On a F reply from the speech freeslotsonslave is updated and speech_sendsay
 * is called.
 *
 * POSIX version has a thread which calls playsound to play items out of the queue.
 */

#define MAX_SOUNDS_SEND_AT_ONCE         16

int speech_handler_free(char *d);
void speech_sendsay();
#ifdef TARGET_POSIX
void say_thread();
void posix_say(U8 item);
int my_system (const char *command);
#endif

const slaveresponse_handlertable_t speech_handler_table[] =
{
        { 'D', CR_MSG, generic_handler_dump },
        { 'E', 6, generic_handler_error  },
        { SFREE_REPLY, 2, speech_handler_free },
        { 'V', 4, generic_handler_version },
        { 0, 0, NULL }
};

/* To Say fifo */
static char sayfifo[SAY_FIFO_SIZE];
char *sayhead;
char *saytail;
int numtosay;
static S16 freeslotsonslave ;
static mutex_t say_mutex;

void speech_init()
{
        mutex_init(&say_mutex);
        /* Initialize say queue. */
        sayhead= saytail = sayfifo;
        numtosay = 0;
#ifdef TARGET_POSIX
        freeslotsonslave = 0;
        /* Because the saythread is taking care of everything we don't
         * want the comms handler emptying our Say buffer so set freeslotsonslave
         * to 0.
         */
#else
        freeslotsonslave = MAX_SOUNDS_SEND_AT_ONCE;
#endif
        speech_flagmsg(SPEECH_NODEBUG);

#ifdef TARGET_POSIX
        thread_begin(say_thread, STACK_512);
#endif
}

void saysounds(constparam U8 *items)
{
        int len;

        int i;

        len = strlen(items);
        /* Add item to fifo. */
        if(numtosay >= SAY_FIFO_SIZE - len) {
                printf("Say fifo full discarding sound\n");
                return;
        }

        mutex_lock(&say_mutex);
        /* Add all of these to the fifo. */
        for(i = 0; i < len; i++) {
                if(*items == 0xff) {
                        /* An 0xff means the say queue should be emptied. */
                        sayhead= saytail = sayfifo;
                        numtosay = 0;
#ifndef TARGET_POSIX			
                        freeslotsonslave = MAX_SOUNDS_SEND_AT_ONCE;
#endif			
                }

                *saytail = *items;
                numtosay++;
                saytail++;
                items++;

                /* Check for rap around. */
                if(saytail >= sayfifo + sizeof(sayfifo) / sizeof(sayfifo[0]))
                        saytail = sayfifo;
        }

        mutex_unlock(&say_mutex);

        speech_sendsay();
}

void saysound(U8 item)
{
        char items[2];
        items[0] = item;
        items[1] = 0;
        saysounds(items);
}

int speech_handler_free(char *d)
{
        int free;

        free = gethexbyte(d);
        if(free < 0)
                return -1;

        freeslotsonslave = free;

        /* There is free number of free sound spaces on the speech slave. */
        speech_sendsay();

        return 0;
}

/* Remove up to 16 bytes from the sayfifo and send it. */
void speech_sendsay()
{
        char *d;
        char *upto;
        int i;
        int numgoingtosay;
        char c;

	if(numtosay == 0)	// Nothing left to say
		return;
	assert(sayhead != saytail);
        numgoingtosay = numtosay;	

        /* Only ever say 16 sounds in one go. */
        if(numgoingtosay > MAX_SOUNDS_SEND_AT_ONCE)
                numgoingtosay = MAX_SOUNDS_SEND_AT_ONCE;
        if(numgoingtosay > freeslotsonslave) {
                numgoingtosay = freeslotsonslave;
                if(numgoingtosay < MAX_SOUNDS_SEND_AT_ONCE)
                        /* Wait until there are at least 16 slots free on the slave */
                        return;
        }

        /* Decrement the number of free slots. */
        freeslotsonslave -= numgoingtosay;
        if(freeslotsonslave < 0)
                freeslotsonslave = 0;

        d = ialloc(numgoingtosay * 2 + 3 /* 1 for NULL, 1 for message
                1  for CR */);

        d[0] = SSAY_MSG;

        mutex_lock(&say_mutex);

        upto = d + 1;
        for(i = 0; i < numgoingtosay; i++) {
                /* Remove a byte from the fifo. */
                numtosay --;
                c = *sayhead;
                sayhead++;
                printhexbyte(upto, c);
                upto += 2;
        }

        mutex_unlock(&say_mutex);

        /* Add the CR and null. */
        upto[0] = CR;
        upto[1] = 0;

        add_slave_msg(SPSYNTH_ID, PRIORITY_NORMAL_MSG, d, SM_FREEDATA);
}

void speech_flagmsg(U8 flags)
{
        char *d;

        d = ialloc(4);

        assert((flags & (~SPEECH_DEBUG_MASK)) == 0);

        *d = SFLAG_MSG;
        printhexbyte(d + 1, flags);

        add_slave_msg(SPSYNTH_ID, PRIORITY_NORMAL_MSG, d, SM_FREEDATA);
}

void speech_tonemsg(U8 tone)
{
        char *d;

        d = ialloc(4);

        *d = STONE_MSG;
        printhexbyte(d + 1, tone);

        add_slave_msg(SPSYNTH_ID, PRIORITY_NORMAL_MSG, d, SM_FREEDATA);
}

void beep(U8 waveform, U16 freq, U16 time)
{
#ifdef TARGET_RABBIT
	Buzz (30); // 30 msec ........ temp xxxxxxxxxxx
#else
        printf(" Beeping %u at %u for %u\n", waveform, freq, time);
#endif
}


nodebug void errorbeep ()
{
beep (SQUARE_WAVE, Beep800Hz, Beep0s2);
beep (SQUARE_WAVE, Beep1200Hz, Beep0s2);
}


#ifdef TARGET_POSIX
void say_thread()
{
        char buffer[256];
        sprintf(buffer, "%s/initplay", execpath);
        my_system(buffer);

        for(;;) {
                U8 tosay;
                /* Wait until there is something to say */
                while(numtosay == 0)
                        thread_yield();

              	assert(sayhead != saytail);

                mutex_lock(&say_mutex);
                /* Get the item to say */
                numtosay --;
                tosay = *sayhead;
                sayhead++;

                mutex_unlock(&say_mutex);
//                printf("POSIX saying %x\n", (int) tosay);
                /* Ignore 0xff bytes. The buffer will have already been emptied. */
                if(tosay == 0xff)
                        continue;

                posix_say(tosay);
        }
}

/* Say item is POSIX by calling playsound. */
void posix_say(U8 item)
{
        char buffer[256];
        sprintf(buffer, "%s/playsound %d", execpath, (int) item);
        my_system(buffer);
}

/* Interruptible version of system. */
int my_system (const char *command) {
           int pid, status;

           if (command == 0)
               return 1;
           pid = fork();
           if (pid == -1)
               return -1;
           if (pid == 0) {
               char *argv[4];
               argv[0] = "sh";
               argv[1] = "-c";
               argv[2] = (char *)command;
               argv[3] = 0;
               execve("/bin/sh", argv, 0);
               exit(127);
           }

           do {
               if (waitpid(pid, &status, 0) == -1) {
                   if (errno != EINTR)
                       return -1;
               } else
                   return status;
           } while(1);
}
#endif /* TARGET_POSIX */


