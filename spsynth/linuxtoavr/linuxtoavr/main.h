/***************************************************************************
                          main.h  -  description
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
 #include "bool.h"

typedef enum tagProgramTask
{
	normal,
	dumpOnly,
	comsOnly,
        parseOnly,
	play,
} ProgramTask;

extern ProgramTask task;


#define MAX_SOUNDS 	256

/* Define all the subroutines. */
BOOL load_dump();
BOOL make_dump();
BOOL do_program();
BOOL play_item(int item, BOOL tostdio);

#define SIZE_OF_FLASH		540672
extern unsigned char *flash_buffer;

extern int debuglevel;

/* File name of the file used for a dump file. */
#define DUMP_FILE_NAME				"./dump"
#define INPUT_FILE_NAME				"./input.conf"
#define HEADER_FILE_NAME			"./sounds.h"
#define INCLUDE_FILE_NAME			"./sounds.inc"
#define	TTY_FILE_NAME					"./ttydevice"

/* Maximum length of a name in the input file */
#define MAX_NAME_LEN				1024