/* Dummy headers for Dynamic C */
/*** Beginheader slavecomms_c */
#ifdef TARGET_RABBIT
void slavecomms_c();

#asm
xxxslavecomms_c: equ slavecomms_c
#endasm

#define DINBUFSIZE	31
#define DOUTBUFSIZE	31

#endif /* TARGET_RABBIT */
/*** endheader */

#ifdef TARGET_RABBIT
void slavecomms_c () { }
#endif /* TARGET_RABBIT */


/***************************************************************************
                          slavecomms.c  -  description
                             -------------------
    begin                : Wed Aug 8 2001
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

/* This file is meant to handle the low level part of slave communication. It handles
 * sending queued messages, polling at checking message length etc. It calls functions
 * in hlslavecomms when it receives a message and is called by hlslavecomms to queue
 * messages. It handles checking message integrity and timeouts etc. Hlslavecomms
 * handles the already checked messages etc.
 *
 *      [ High level slave comms ]
 *              /|\              |
 *               |              \|/
 *          Received messages.  Messages to be sent.
 *      [ Low level slave comms (slavecomms.c) ]
 *              /|\              |
 *               |              \|/
 *          Responses           Polls & Messages
 *      [               slaves                   ]
 *
 */

#ifdef TARGET_POSIX
#include <unistd.h>
#include <string.h>
#include <fcntl.h>
#include <pthread.h>
#include <stdio.h>
#include <ctype.h>

#include "posix.h"

#endif

#include "compat.h"
#include "slavecomms.h"
#include "commonsubs.h"
#include "alloc.h"
#include "io.h"
#include "computercontrol.h"
#include "mytime.h"

typedef struct {
                listentry_t l;
                char id;
                U8 priority;
                U8 originalpriority;
                U8 flags;
                constparam char *data;

        } slavemsgentry_t;


// Timeout before it considers a no-reply.
#define MILLISECOND_TIMEOUT     3

/* Subroutines local to this file */
void slavecomms_thread();
void putslavedata(constparam void *data, U16 len);
void putslavestring(constparam char *str);
int getslavechar(BOOL GetEchoFlag);
#define GET_ECHO TRUE
#define GET_REAL_CHAR FALSE
void emptyslavebuffer();
void putslavechar(char c);
void send_msg(slavemsgentry_t *msg);
void handle_response(constparam slavemsgentry_t *msg);
int slaveidtoindex(char id);
bool haveslavechar();
void commsecho(char c);

static int sldebug
#ifdef TARGET_POSIX
        = 0
#endif
        ;
#ifdef TARGET_POSIX
bool addslavecr = false;
#endif
static list_t msglist;

int from_slaveindex;
char response_msg;
thread_handle_t scthread;

extern const slaveresponse_handlertable_t infrared_handler_table[];
extern const slaveresponse_handlertable_t base_handler_table[];
extern const slaveresponse_handlertable_t speech_handler_table[];
extern const slaveresponse_handlertable_t io_supervisor_handler_table[];
extern const slaveresponse_handlertable_t io_slave_handler_table[];

extern void ir_init();
extern void base_init();
extern void speech_init();
extern void io_supervisor_init();
extern void io_slave_init();
/* Constant slave table
 * Note: When adding a slave don't forget to change NUM_SLAVES in slavecomms.h
 */
const slaveconst_t slaveconst_table[NUM_SLAVES] =
{
	/* Alphabetically sorted */
	{'I', PRIORITY_IR_POLL,            "Infrared",          infrared_handler_table, ir_init       },
	{'M', PRIORITY_BASE_POLL,          "Base",              base_handler_table,     base_init     },
	{'P', PRIORITY_IO_SUPERVISOR_POLL, "IO Supervisor",     io_supervisor_handler_table, io_supervisor_init },
	{'S', PRIORITY_SPEECH_POLL,        "Speech",            speech_handler_table,   speech_init   },
	{'V', PRIORITY_IO_SLAVE_POLL,      "IO Slave",          io_slave_handler_table, io_slave_init },        	
};

slavedynamic_t slavedynamic_table[NUM_SLAVES];

xmem void set_slave_debuglevel(int level)
{
        printf("Setting llslave debug level %d\n", level);
        sldebug = level;
}

/* Return -1 if id doesn't exist. */
int slaveidtoindex(char id)
{
        int i;

        id = toupper(id);

        for(i = 0; i < NUM_SLAVES; i++) {
                if(slaveconst_table[i].id == id)
                        return i;
        }

        return -1;
}

xmem void init_slavecomms()
{
        int i;

#ifdef TARGET_RABBIT
        sldebug = 0;
#endif

        if(sldebug > 0)
                printf("Init low-level slv comms\n");

        list_init(&msglist);

        for(i = 0; i < NUM_SLAVES; i++) {
#if 0        
                clear_time(&slavedynamic_table[i].lastresponse);
#endif
                slavedynamic_table[i].version = 0;

                /* Add this slave to the list */
                add_slave_msg(tolower(slaveconst_table[i].id),
                        slaveconst_table[i].priority, NULL, SM_NODISCARD |
                                        SM_EXPECTRESPONSE);

                /* Also add a message to get the slave version. */
                sendslave_versionmsg(slaveconst_table[i].id);

                /* Call their init routine. */
                (*slaveconst_table[i].init)();
        }


#ifdef TARGET_POSIX
        /* First set both files to O_SYNC */
        fcntl(SLAVE_COMMS_READ_FILE, F_SETFL, O_SYNC);
        fcntl(SLAVE_COMMS_WRITE_FILE, F_SETFL, O_SYNC);
#else /* TARGET_RABBIT */
	Jr485Init();
	Jr485Rx(); /* Go to receive mode. */
	serDopen(19200);
	serDparity(PARAM_EPARITY);
	serDdatabits(PARAM_7BIT);
#endif

        scthread = thread_begin(slavecomms_thread, STACK_2048);
}

/* The main thread for the llslavecomms. */
void slavecomms_thread()
{
        slavemsgentry_t *cur;
        slavemsgentry_t *highest;
        U8 bestpriority;

        if(sldebug > 0)
                printf("Beginning llslavecomms thrd\n");

        for(;;) {

                /* Go through the slave list looking for the lowest priority message */
                cur = highest = (slavemsgentry_t *)msglist.firstentry;
                bestpriority = 0;

                while(cur) {

                        if(cur->priority > bestpriority) {
                                highest = cur;
                                bestpriority = cur->priority;
                        }
                        /* Increment priority */
                        cur->priority ++;

                        cur = (slavemsgentry_t *) cur->l.next;
                }

                /* Highest now holds the highest priority entry */
                send_msg(highest);

                if(highest->flags & SM_EXPECTRESPONSE)
                        handle_response(highest);

                if(highest->flags & SM_NODISCARD) {
                        /* This message stays around */
                        highest->priority = highest->originalpriority;
                }
                else {
                        /* Kill this entry */
                        if(highest->flags & SM_FREEDATA)
                                ifree((void*)highest->data);

                        list_remove(&msglist, (listentry_t*)highest);
                        ifree(highest);
                }

                thread_yield();
        }
}

void send_msg(slavemsgentry_t *msg)
{
	if(sldebug >= 1 && isupper(msg->id)) {
		// Print this message to stdio
		printf("Sndng msg: %c%s\n", (char)msg->id,
			msg->data);
	}
#ifdef TARGET_RABBIT
        LEDOff (SlaveLED0 + slaveidtoindex(msg->id));
#endif
        putslavechar(msg->id);
        if(msg->data)
                putslavestring(msg->data);
#ifdef TARGET_POSIX
        if(addslavecr)
                putslavechar('\n');
#endif
}

// Echo character to STDOUT
void commsecho(char c)
{
        switch(c) {
        case '\r':
                c = '\n';
                break;
        }

        putchar(c);
}

void rawslavecomms(bool echo)
{
        int c;

        thread_pause(scthread);
			printf ("Raw slave comms mode -- press ESC to exit\n");
        for(;;) {
            	/* Send characters. */
#ifdef TARGET_RABBIT
    	        if(kbhit()) {
#else
                {
#endif
    		        c = getcomputerchar();
                        if(c == 0x1b) // Esc
                                break;

                        putslavechar(c);
                        if(echo)
                                commsecho(c);
                }

                if(haveslavechar()) {
                        c = getslavechar(GET_REAL_CHAR);
                        if(c != -1)
                                commsecho(c);
                }
    	}

        thread_resume(scthread);
}

/* This is called only when expecting a response from slave id. */
xmem void handle_response(constparam slavemsgentry_t *msg)
{
        int c;
        int index;
        char *d;
        int len;
        char msgdata[MAX_MSG_LEN + 1];
        int result;
        const slaveresponse_handlertable_t *t;

Start:
        c = getslavechar(GET_REAL_CHAR);

        if(c < 0) {
                if(sldebug > 0)
                        printf("No rply frm slv %c ", msg->id);
                return;
        }

        /* Lowercase responses are incremented by 1 from the slave id. */
        if(islower(c))
        	c--;

        if(toupper(c) != toupper(msg->id)) {
                if(sldebug > 0)
                        printf("Rspnse frm slv %c when expected frm %c\n",
                                (char) c, msg->id);
        }

        /* Have now received a response from a slave check that this slave exists. */
        index = slaveidtoindex(c);

        if(index == -1) {
                if(sldebug > 0)
                        printf("Slv %c doesn't exist\n", (char) c);
                        return;
        }
#ifdef TARGET_RABBIT
        LEDOn (SlaveLED0 + index);
#endif

        if(!islower(c)) { /* Ignore lowercase messages. */
                /* This is an actual message */
                c = getslavechar(GET_REAL_CHAR);
                if(c < 0) {
                        if(sldebug > 0)
                                printf("Empty msg frm slv %c\n", (char) c);
                        return;
                }
                response_msg = c;

                /* Lookup this message in the slave message table. */
                t = slaveconst_table[index].handlertable;

                while(t->msg) {
                        if(t->msg == c || t->msg > c)
                                break;
                        t++;
                }

                if(t->msg != c) {
                        /* This message isn't in the table */
                        if(sldebug > 0)
                                printf("Inv msg %c frm slv %s\n", (char) c,
                                        slaveconst_table[index].name);
                        return;
                }

                /* Message has been found and is in the table. */
                len = t->msglen;
                d = msgdata;

                while(len) {
                        c = getslavechar(GET_REAL_CHAR);
                        if(c < 0) {
                                if(sldebug > 0)
                                printf("Error gettin msg\n");
                                return;
                        }

                        if(d >= msgdata + sizeof(msgdata) * sizeof(msgdata[0])) {
                                if(sldebug > 0)
                                        printf("Ovrflw in msg data\n");
                                return;
                        }

                        if(len != CR_MSG)
                                len --;
                        else if(c == CR
#ifdef TARGET_POSIX
                        || c == '\n'
#endif
                          )
                                break;

                        *d = c;
                        d++;
                }

                *d = 0;
                /* We have receive the right amount of data and it is in
                 * msgdata. Call the handler. */
                 // First print the message to STDIO
                if(sldebug >= 2)
                	printf("Msg from %s: %c%c%s\n", slaveconst_table[index].name,
                		(char) slaveconst_table[index].id, (char) response_msg,
                		msgdata);
                		
                from_slaveindex = index;
                result = (*t->handler)(msgdata);
                if(result == 0)
                        return;
                else if(result < 0) {
                        if(sldebug > 0)
                                printf("Inv msg contents\n");
                        return;
                }
                else if(result > 0) {
                        goto Start; /* Expect another message. */
                }
        }

#if 0
        /* Update lastresponse for the slave. */
        get_time(&slavedynamic_table[index].lastresponse);
#endif
}

xmem void add_slave_msg(char id, U8 priority, constparam char *data, U8 flags)
{
        slavemsgentry_t *entry;

        entry = (slavemsgentry_t*)ialloc(sizeof(slavemsgentry_t));
        entry->id = id;
        entry->priority = priority;
        entry->data = data;
        entry->originalpriority = priority;
        entry->flags = flags;


        list_add(&msglist, (listentry_t*)entry);
}

xmem void putslavestring(constparam char *str)
{
        putslavedata((void *) str, strlen(str));
}

xmem void putslavechar(char c)
{
        putslavedata(&c, sizeof(c));
}

#ifdef TARGET_POSIX

// Return true when there is a character available
bool haveslavechar()
{
        return true;
}
/* Get a char for the slave or return -1 if no available or timeout. */
int getslavechar(BOOL GetEchoFlag)
{
        char c;
        if(read(SLAVE_COMMS_READ_FILE, &c, sizeof(c)) != sizeof(char)) {
                return -1;
        }

        return c;
}

xmem void emptyslavebuffer()
{
        fdatasync(SLAVE_COMMS_READ_FILE);
}

/* Write to the slave comms */
void putslavedata(constparam void *data, U16 len)
{
        write(SLAVE_COMMS_WRITE_FILE, data, (unsigned int) len);
}

#else

bool haveslavechar()
{
        return serDrdFree() != DINBUFSIZE;
}
/* Get a char for the slave or return -1 if no available or timeout. */
int getslavechar(BOOL GetEchoFlag)
{
	int retval;
	unsigned long timeout;

        timeout = getmsectimer();

	while((retval = serDgetc()) == -1) {		
		if(getmsectimer() > timeout + MILLISECOND_TIMEOUT) {
			if (sldebug>=1) {
				printf("Timeout ");
				if (GetEchoFlag) printf("waiting for echo ");
				}
			return -1;
		}
		thread_yield();		
	}
	if(sldebug >= 4 && retval != -1) {
		if (!GetEchoFlag)
			printf("Rcvd a %c ", (char) retval);
		else if (sldebug >= 6)
			printf("Rcvd echo %c ", (char) retval);
		}
		
	return retval;
}

void emptyslavebuffer()
{
        serDwrFlush();
        serDrdFlush();
        if(sldebug >= 4)
        	printf("Emptying slv buff\n");
}

/* Write to the slave comms */
void putslavedata(constparam void *data, U16 len)
{
char ThisChar;

        Jr485Tx(); /* Go to transmit mode. */
		if(sldebug >= 4)
			printf("\nSending ");
        
        while(len) {  	        

		ThisChar = *((constparam char *)data);
		serDputc(ThisChar);
		if(sldebug >= 4)
			printf("%c ", ThisChar);

                // Wait for echo from RS485 comms
                if (getslavechar(GET_ECHO) != ThisChar)
                	break; // no point in continuing
                	
                ((constparam char *)data) ++;
                len--;
        }

        Jr485Rx();
}

#endif

static const char vmsg[] =  { VERSION_MSG, 0 };
xmem void sendslave_versionmsg(char id)
{
        add_slave_msg(id, PRIORITY_LOW_MSG, vmsg, SM_EXPECTRESPONSE);
}

xmem void sendslave_dumpmsg(char id, char area)
{
        char *d;

        d = ialloc(3);

        assert(area == DUMP_EEPROM || area == DUMP_FLASH || area == DUMP_REGISTERS
               || area == DUMP_SRAM);

        d[0] = DUMP_MSG;
        d[1] = area;
        d[2] = 0;

        add_slave_msg(id, PRIORITY_URGENT_MSG, d, SM_EXPECTRESPONSE | SM_FREEDATA);
}

xmem void sendslave_setmsg(char id, U16 address, U8 data)
{
        char *d;

        d = ialloc(8);

        *d = SET_MSG;
        printhexword(d + 1, address);
        printhexbyte(d + 5, data);

        add_slave_msg(id, PRIORITY_URGENT_MSG, d, SM_FREEDATA);
}

/* Generic message handlers. */
xmem int generic_handler_error(char *d)
{
        LEDOff (SlaveLED0 + from_slaveindex);
        printf("Error frm slv %s with data of %s\n",
                slaveconst_table[from_slaveindex].name, d);
        return  0;
}

xmem int generic_handler_version(char *d)
{
        S32 version;

        if((version = gethexword(d)) < 0)
                return -1;

        slavedynamic_table[from_slaveindex].version = (U16)version;

        if(sldebug)
        	printf("Slave version %04x\n", (unsigned int)version);

        return 0;
}

xmem int generic_handler_dump(char *d)
{
        S32 address;
        U8 data[16];
        int index;
        int i;
        char c;
        constparam char *type;
        S16 tmp;

        index = 0;

        if(*d == 0) {
                /* This was the last byte of dump. */
                return 0;
        }

        /* This won't be able to handle an even length dump so check that first.
         * ( The dump is odd length because off the even length data plus the
         * type of dump at the begining (eg F for flash).
         */
        if((strlen(d) % 2) != 1)
                return -1;

        c = *d;
        if((address = gethexword(d + 1)) < 0)
                return -1;

        switch(c) {
        case DUMP_EEPROM:
                type = "eeprom";
                break;
        case DUMP_SRAM:
                type = "sram";
                break;
        case DUMP_REGISTERS:
                type = "registers";
                break;
        case DUMP_FLASH:
                type = "flash";
                break;
        default:
                /* Invalid type of dump. */
                return -1;
        }

        d += 5;

        while(*d) {
                if((tmp = gethexbyte(d)) < 0)
                        return -1;

                data[index] = tmp;
                index++;
                d += 2;
        }

        /* Data is now full dump it. */
        printf("%s %s dump: %04x =  ", slaveconst_table[from_slaveindex].name, type,
                address);

        for(i = 0; i < index; i++) {
                printf(" %02x", (int) data[i]);

                if(i == 7)
                        printf(" ");
        }

        printf("   ");

        for(i = 0; i < index; i++) {
                if(isalnum((char)data[i]))
                        printf("%c", (char) data[i]);
                else
                        printf(".");
        }


        printf("\n");

        return 1;
}

