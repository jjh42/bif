/***************************************************************************
                          main.c  -  description
                             -------------------
    begin                : Wed Jan 17 2001
    copyright            : (C) 2001 by Jonathan Hunt
    email                : jhuntnz@users.sourceforge.net
 ***************************************************************************/

/***************************************************************************
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 ***************************************************************************/

#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include <stdio.h>
#include <stdlib.h>
#include <getopt.h>

#include "main.h"
#include "results.h"

const char *usage =
"[switches] [filename]\n"
"Use --help to get more options\n";

const char *help =
"-c --comsonly use dump file\n"
"   --colour Colorize output\n"
"-d --debug Set debug level\n"
"-p --play item\n"
"   --stdio Send hbit to stdio\n"
"-P --parse Parse only\n"
"-H --help this menu\n"
"-n --nocoms print only to the dump file\n"
"-V --version print our version number\n";

#if !defined(HAVE_CONFIG_H)
#define VERSION		"Unknown"
#endif

#define ARG_STDIO	254
const char *opts = "VHp:ncP";
struct option lopts[] =
{
	{"version", no_argument, NULL, 'V'},
	{"help", no_argument, NULL, 'H'},
	{"nocoms", no_argument, NULL, 'n'},
	{"comsonly", no_argument, NULL, 'c'},
	{"colour", no_argument, NULL, 'C'},
	{"play", required_argument, NULL, 'p'},
        {"parse", no_argument, NULL, 'P'},
        {"debug", required_argument, NULL, 'd'},
	{"stdio", no_argument, NULL, ARG_STDIO },
	{NULL, no_argument, NULL, 0}
};

char *programname;
ProgramTask task = normal;
unsigned char *flash_buffer;
int debuglevel = 0;

int main(int argc, char *argv[])
{
	
  int c;
  int playitem;
  BOOL stdio = FALSE;
  /* First thing we check our command line. */
  /* Set our program name. */
  programname = argv[0];

  /* Read our arguments. */
  while((c = getopt_long(argc, argv, opts, lopts, NULL)) != EOF)
  	switch(c) {
  		case 'V':
  			printf("%s : %s\n", programname, VERSION);
  			return 0;
  		case 'H':
  			/* Print our help string. */
  			printf(help);
  			return 0;
  		case 'n':
  			if(task != normal)
				goto Usage;
			/* Set task */
			task = dumpOnly;
  			break;
  		case 'c':
  			if(task != normal)
  				goto Usage;
  			/* Set task */
  			task = comsOnly;
  			break;
                case 'P':
                        if(task != normal)
                                goto Usage;
                        task = parseOnly;
			break;
		case ARG_STDIO:
			stdio = TRUE;
			break;			
  		case 'C':
  			/* Set that we are doing our output in colour. */
  			colour = TRUE;
  			break;
		case 'p':
			/* Play the sound. */
			if(task != normal)
				goto Usage;
			task = play;;
			if(sscanf(optarg, "%i", &playitem) <= 0)
				goto Usage;
			break;
                case 'd':
                        /* Set debug level */
                        if(sscanf(optarg, "%i", &debuglevel) <= 0)
                                goto Usage;
                        printf("Debug level is %d\n", debuglevel);
                        break;
  		default:
Usage:;
  			/* This was an invalid option. */
  			printf("Usage %s %s", programname, usage);
  			return -1;
  	}
  	
  /* We now know what we should be doing. */
  switch (task)
  {
  case normal:
  	printf("Beginning normal run\n");
  	break;
  case dumpOnly:
  	printf("Beginning dump only run\n");
  	break;
  case comsOnly:
  	printf("Beginning coms only run\n");
  	break;
  case parseOnly:
        printf("Beginning parse only run\n");
        break;
  case play:
        if(!stdio)
    	    printf("Beginning play of item %d\n", playitem);
	if(!load_dump())
		goto ReturnError; 
	if(!play_item(playitem, stdio))
		goto ReturnError;
	goto ReturnSuccess;
	break;
  }

  flash_buffer = malloc(SIZE_OF_FLASH);
  /* If we are doing a coms only then we need to load the dump file. */
  if(task == comsOnly) {
	if(!load_dump()) /* Return if it fails */
			goto ReturnError;
	}
	else { /* This is either a normal run or a dumpOnly or a parseOnly. */
		if(!make_dump()) /* Return if it fails. */
			goto ReturnError;
	}
			
	/* We have successfully loaded or made the data to program now program
		it. */
	if(task != dumpOnly && task != parseOnly)
		if(!do_program())
			goto ReturnError;

ReturnSuccess:			
	if(stdio)
	    return EXIT_SUCCESS;
	/* If we got here we completed successfully. */
	if(!colour)
		printf("Completed task successfully\n");
	else
		printf(SETCOLOR_SUCCESS "Completed task successfully\n" SETCOLOR_NORMAL);
		
  return EXIT_SUCCESS;

  /* If we got here there was an error */
ReturnError:;
	if(!colour)
		printf( "Errors occured look at above messages\n");
	else
		printf( SETCOLOR_FAILURE "Errors occured look at above messages\n"
			SETCOLOR_NORMAL);
	return 1;
}
