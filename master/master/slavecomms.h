/*** Beginheader */

/***************************************************************************
                          llslavecomms.h  -  description
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

/* There are two tables of slave definitions. One is the data table for changing
 * data and the constant table for constant date. Both are defined in slavecomms.c
 * There is also a message table for each slave defined in the file
*/

#ifndef _SLAVECOMMS_H
#define _SLAVECOMMS_H

#include <comms.h>

#define NUM_SLAVES              5
#define MAX_MSG_LEN             64

/* Priorities */
#define PRIORITY_LOW_MSG        1
#define PRIORITY_SPEECH_POLL    2
#define PRIORITY_IO_SUPERVISOR_POLL 5
#define PRIORITY_IO_SLAVE_POLL  5
#define PRIORITY_BASE_POLL      8
#define PRIORITY_NORMAL_MSG     10
#define PRIORITY_IR_POLL        12
#define PRIORITY_URGENT_MSG     15


/* Handlers return a value less than zero is message was invalid.
 * 0 is message was okay and greater than zero is another message
 * is expected.
 */
typedef int (*slave_response_handler_t)
#ifdef TARGET_RABBIT
	();
#else
	(char *data);
#endif
typedef void (*slave_init_t) ();

typedef struct {
                char msg;
                U8 msglen; /* Set to CR_MSG for a message terminated by a CR. */
                slave_response_handler_t handler;
        }
        slaveresponse_handlertable_t;

typedef struct {
                char id;
                U8 priority;
                constparam char *name;
                constparam slaveresponse_handlertable_t *handlertable;
                slave_init_t init;
        }
        slaveconst_t;

typedef struct {
//                time_t lastresponse;
                U16 version;
        }

        slavedynamic_t;


extern void init_slavecomms(); /* Splits off a seperate thread. */
/* Set the debug level. May be called before init_llslavecomms. */
void set_slave_debuglevel(int level);

/* Tables defined in slavecomms.c */
extern const slaveconst_t slaveconst_table[NUM_SLAVES];

extern slavedynamic_t slavedynamic_table[NUM_SLAVES];

/* Flags for slavemsgentry_t. */
/* Flags accepted by add_slave_msg */
#define SM_NODISCARD            0x01
#define SM_EXPECTRESPONSE       0x02
#define SM_FREEDATA             0x04
void add_slave_msg(char id, U8 priority, constparam char *data, U8 flags);

#ifdef TARGET_POSIX
/* Set to true to make the slave comms add CRs */
extern bool addslavecr;
#endif

/* Generic slave messages */
extern void sendslave_versionmsg(char id);
extern void sendslave_setmsg(char id, U16 address, U8 data);
extern void sendslave_dumpmsg(char id, char area);

/* Generic message handlers. */
extern int generic_handler_error(char *d);
extern int generic_handler_version(char *d);
extern int generic_handler_dump(char *d);

/* Variables set before a message handler is called. */
extern int from_slaveindex;
extern char response_msg;

// Do raw slave comms
extern void rawslavecomms(bool echo);

#ifdef TARGET_RABBIT
void slavecomms_thread();
#endif

#endif /* _SLAVECOMMS_H */

/*** endheader */

