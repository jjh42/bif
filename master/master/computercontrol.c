

/* Dummy headers for Dynamic C */
/*** Beginheader computercontrol_c */
#ifdef TARGET_RABBIT
void computercontrol_c();

#asm
XXXcomputercontrol_c:	equ	computercontrol_c
#endasm

#endif /* TARGET_RABBIT */
/*** endheader */

#ifdef TARGET_RABBIT
void computercontrol_c () { }
#endif /* TARGET_RABBIT */


/***************************************************************************
                          computercontrol.c  -  description
                             -------------------
    begin                : Wed Sep 5 2001
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

/* This is the code to take care of input from the user via the computer.
 * It cannot control all parts of the robot but is only for testing.
 * It operates on its own thread that waits for input.
 */

/* ABBREVIATIONS        MEANING
 * b                    Bool value. Accepts t, f, 1, 0 or o, f.
 * n                    Signed integer.
 *
 * COMMANDS             DESCRIPTIONS
 * irmode               Go to irmode. This means it uses keys to
 *                      emulate the IR remote. ESC exits from this
 *                      mode.
 * slcr b               Set slcr on or off.
 * sldebug n            Set sldebug (slave comms debug) to n.
 */

/* How it works:
 *
 * Basically it waits for a string from the user (until the user pushs enter).
 * It thens looks up the first part of this string in the command
 * table. It then uses the entrie's 2nd item (the parameter list)
 * to compile a list of parameters in a int array and then calls
 * the handler. They return true if everything was okay and false
 * if something was wrong.
 */

#ifdef TARGET_POSIX
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#endif

#include "compat.h"
#include "computercontrol.h"
#include "threads.h"
#include "slavecomms.h"
#include "IRControl.h"
#include "speak.h"

#define MAX_PARAMS              5
#define MAX_COMMAND_LENGTH      256

typedef void (*command_handler_t)
#ifndef TARGET_RABBIT
	(int *params);
#else
	();
#endif		

typedef struct  {
        constparam char *command;
        constparam char *args;
        command_handler_t handler;
        }
        command_entry_t;

/* Local functions. */
void handle_irmode(int *params);
void handle_slcr(int *params);
void handle_sldebug(int *params);
void handle_help(int *params);
void handle_rawslavecomms(int *params);
void handle_testenglish(int *params);

void computercontrol_thread();
void process_command(char *command);
bool getbool_arg(char *arg, int *result);
bool getint_arg(char *arg, int *result);
constparam command_entry_t *lookup_command(char *command);
int getcomputerstring(char *buf, int maxlen);


/* This table must be alphabectically sorted. */
static const command_entry_t command_table[] =
{
        {"help",        "",     handle_help     },
        {"irmode",      "",     handle_irmode   },
        {"rawslavecomms", "b",   handle_rawslavecomms },
#ifdef TARGET_POSIX
        {"slcr",        "b",    handle_slcr      },
#endif
        {"sldebug",     "n",    handle_sldebug  },
        {"testenglish", "",     handle_testenglish },
        {NULL, NULL}
};

/* Handlers. */
xmem void handle_help(int *params)
{
#if 0 // to make some room in memory
        printf(
        "Help for master input\n" \
        "help           View this message\n" \
        "irmode         Enter ir mode\n" \
        "rawslavecomms b Enter raw slave comms mode. b control echo\n" \
#ifdef TARGET_POSIX
        "slcr  b        Set slave comms cr on or off\n" \
#endif
        "sldebug n      Set slave comms debug level\n" \
        "testenglish    Go into test english mode\n" \
        "\n"
        );
#endif
}

xmem void handle_irmode(int *params)
{
        printf("Entering ir mode\n");
        irmode();
        printf("Exiting ir mode\n");
}

// Enter raw mode, transmit everything to the slave and comms
void handle_rawslavecomms(int *params)
{
        rawslavecomms(*params != 0);
}

#ifdef TARGET_POSIX
void handle_slcr(int *params)
{
        if(params[0])
                printf("Enabling slcr\n");
        else
                printf("Disable slcr\n");

        addslavecr = params[0] != 0 ? true : false;
}
#endif

xmem void handle_sldebug(int *params)
{
        printf("Setting sldebug to %d\n", params[0]);

        set_slave_debuglevel(params[0]);
}

xmem void handle_testenglish(int *params)
{
        char buf[1024];

        printf("Type text to say, type exit to exit this mode\n");
        for(;;) {
                getcomputerstring(buf, sizeof(buf));
                if(strcmp(buf, "exit") == 0)
                        return;
                printf("Saying %s\n", buf);
                SayEnglishText(TRUE, buf);
        }
}
/* Initialize computer control and branch seperate thread. */
xmem void init_computercontrol()
{
        thread_begin(computercontrol_thread, STACK_512);
}

/* Takes a NULL terminated string a looks for it in the command_table.
 * If it exists it returns a pointer to the entry otherwise it returns 0
 */
xmem constparam command_entry_t *lookup_command(char *command)
{
        constparam command_entry_t *cur;
        int retval;

	cur  = command_table;
        
        while(cur->command != 0) {
                retval = strcmp(cur->command, command);
                if(retval == 0)
                        return cur;
                else if(retval > 0)
                        return NULL;

                cur++;
        }

        return NULL;
}

/* Set *result to the 1 if arg is true or 0 if arg is false.
 * Return true if sucessful.
 */
xmem bool getbool_arg(char *arg, int *result)
{
        int len;

        len  = strlen(arg);

        if(strncasecmp(arg, "true", len) == 0 ||
                strcmp(arg, "1") == 0 ||
                strcasecmp(arg, "on") == 0) {
                /* Successful match for true */
                *result = 1;
                return true;
        }
        else if(strncasecmp(arg, "false", len) == 0 ||
                strcmp(arg, "0") == 0 ||
                strcasecmp(arg, "off") == 0) {
                /* Successful match for false. */
                *result = 0;
                return true;
        }

        return false;
}

/* Set *result to the signed integer or arg. Return true if
 * sucessful.
 */
xmem bool getint_arg(char *arg, int *result)
{
        long val;
        char *end;

        val = strtol(arg, &end, 0);

        if(*end != 0)
                return false;

        *result = (int) val;

        return true;
}

/* Takes a pointer to the string the user types in a breaks it down
 * into tokens and gets the arguments and then calls the handler.
 */
xmem void process_command(char *command)
{
        constparam command_entry_t *entry;
        constparam char *argstr;
        int paramarray[MAX_PARAMS];
        int numparams;

        numparams = 0;

        command = strtok(command, " \t");
        if(!command)
                /* An empty line */
                return;

        entry = lookup_command(command);
        if(!entry) {
                printf("Invalid command\n");
                return;
        }

        /* Now get each argument. */
        argstr = entry->args;
        while(*argstr != 0) {
                /* Check we haven't gone over the maximum number of parameters. */
                assert(numparams < MAX_PARAMS);
                command = strtok(NULL, " \t");
                if(command == 0) {
                        printf("Argument %d missing\n", numparams + 1);
                        return;
                }

                switch(*argstr) {
                case 'b':
                        if(!getbool_arg(command, &paramarray[numparams])) {
                                printf("Argument %d invalid\n", numparams + 1);
                                return;
                        }
                        break;
                case 'n':
                        if(!getint_arg(command, &paramarray[numparams])) {
                                printf("Argument %d invalid\n", numparams + 1);
                                return;
                        }
                        break;
                default:
                        /* Invalid type of argument expected. */
                        assert(0);
                }
                argstr ++;
                numparams ++;
        }

        command = strtok(NULL, " \t");
        if(command != 0) {
                printf("Junk at the end on the line\n");
                return;
        }

        entry->handler(paramarray);
}

xmem void computercontrol_thread()
{
        char command[MAX_COMMAND_LENGTH];

        for(;;) {
                if(getcomputerstring(command, sizeof(command)) != 0)
                        return;
                process_command(command);
        }
}

int getcomputerstring(char *buf, int maxlen)
{
        int c;
        char *upto;

        upto = buf;

        for(;;) {
                c = getcomputerchar();
                if(c < 0) {
                        printf("Computer control died\n");
                        return -1;
                }
                else if(c == 0x7f) {
                        /* Backspace */
                        if(upto != buf) {
                                printf("\b \b");
                                upto--;
                        }
                }
                else if(upto >= buf + maxlen) {
                        printf("You typed too many characters\n");
                        upto = buf;
                }
                else if(c ==
#ifndef TARGET_RABBIT
	                '\n'
#else
			'\r' // Rabbit STDIO sends CR
#endif /* TARGET_RABBIT */
		) {
			printf("\n");
                        *upto = 0;
                        return 0;
                }
                else {
#ifdef TARGET_RABBIT
                	putchar(c);
#endif                	
                        *upto = c;
                        upto ++;
                }
        }

}

int getcomputerchar()
{
#ifdef TARGET_POSIX
        return getchar();
#else
        while(!kbhit())
                thread_yield();
        return getchar();
#endif
}