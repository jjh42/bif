/***************************************************************************
                          posixmain.c  -  description
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

/* This file is the start part for a POSIX version of the robot master. This
 * is used for simulation etc.
 */

#ifndef TARGET_POSIX
#error This file is for POSIX only
#endif

#include <stdio.h>
#include <stdlib.h>
#include <getopt.h>
#include <unistd.h>

#include "compat.h"
#include "master.h"
#include "slavecomms.h"
#include "posix.h"

const char *usage =
"[switches]\n"
"Use --help to get more options\n";

const char *help =
"   --hookup                Pause of startup to wait for debugger hookup\n"
"-H --help                  Show this menu\n"
"-V --version               Show version\n"
"   --slave-add-cr          Add CR to slave messages\n"
"   --slave-debug level     Set slave comms debug level\n"
;

#define HOOKUP          256
#define SLAVE_DEBUG     257
#define SLAVE_ADD_CR    258

const char *opts = "VH";
struct option lopts[] =
{
        {"hookup", no_argument, NULL, HOOKUP },
	{"help", no_argument, NULL, 'H'},
	{"version", no_argument, NULL, 'V'},
        {"slave-debug", required_argument, NULL, SLAVE_DEBUG},
        {"slave-add-cr", no_argument, NULL, SLAVE_ADD_CR},
	{NULL, no_argument, NULL, 0}
};

const char *programname;
char *execpath;

int main(int argc, char *argv[])
{
	
  int c;
  /* First thing we check our command line. */
  /* Set our program name. */
  programname = argv[0];

  /* Set our path. */
  execpath = strdup(argv[0]);
  *(strrchr(execpath, '/')) = 0;

  /* Read our arguments. */
  while((c = getopt_long(argc, argv, opts, lopts, NULL)) != EOF)
  	switch(c) {
  		case 'V':
  			printf("%s : Master Version %s\n"
                               "     Robot Version  %s\n",
                                programname, MASTER_VERSION_STRING,
                                ROBOT_VERSION_STRING);
  			return 0;
  		case 'H':
  			/* Print our help string. */
  			printf(help);
  			return 0;
                case SLAVE_DEBUG: {
                        int level;
                        /* Set debug level */
                        if(sscanf(optarg, "%i", &level) <= 0)
                                goto Usage;
                        set_slave_debuglevel(level);
                        break;
                }
                case SLAVE_ADD_CR:
                        addslavecr = true;
                        break;
                case HOOKUP: {
                        int hwait = 1;

                        printf("Waiting for debugger hookup\n");
                        while(hwait) sleep(1);

                        break;
                }
  		default:
Usage:;
  			/* This was an invalid option. */
  			printf("Usage %s %s", programname, usage);
  			return -1;
  	}
  	

        /* Have parsed options - now begin the actual program. */
        mastermain();

        printf("Master exited\n");

        return 0;
}

int VdGetFreeWd(char count)
{
        return 1;
}

int VdHitWd(int ndog)
{
        return 0;
}
