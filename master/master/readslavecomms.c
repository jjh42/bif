/***************************************************************************
                          readslavecomms.c  -  description
                             -------------------
    begin                : Wed Aug 29 2001
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


/* This is a simple helper program that simply reads STDIN (2) and pipes it to 3
 * and reads 4 and pipes it STDOUT (1). */
#include <pthread.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdio.h>
#include <termios.h>

#define STDIN_FILE 0
#define STDOUT_FILE 1
#define STDERR_FILE 2
#define IN_FILE 3
#define OUT_FILE 4

static struct termios originalterm;

void init_tty();
void restore_tty();

/* Read STDIN and pipe it to 3 */
void read_stdin()
{
        char c;

        for(;;) {
                if(read(STDIN_FILE, &c, sizeof(char)) == 1)
                        write(OUT_FILE, &c, sizeof(char));
        }
}

/* Read from IN_FILE and pipe it to STDOUT */
void *read_in(void *ignore)
{
        char c;

        for(;;) {
                if(read(IN_FILE, &c, sizeof(char)) == 1)
                        write(STDOUT_FILE, &c, sizeof(char));
        }

        return 0;
}


/* Setup the tty to get one character at a time. */
void init_tty()
{
        struct termios newterm;

        tcgetattr(STDIN_FILE, &originalterm);
        newterm = originalterm;

        /* Set up the new terminal. */
        newterm.c_lflag &= ~(ECHOCTL | ICANON);

        tcsetattr(STDIN_FILE, TCSANOW, &newterm);
}

void restore_tty()
{
        tcsetattr(STDIN_FILE, TCSANOW, &originalterm);
}

int main(int argv, char *argc[])
{
        pthread_t rthread;

        init_tty();

        if(pthread_create(&rthread, NULL, read_in, 0) != 0) {
                printf("Failed to create read thread\n");
                return -1;
        }
        /* First set both files to O_SYNC */
        fcntl(IN_FILE, F_SETFL, O_SYNC);
        fcntl(OUT_FILE, F_SETFL, O_SYNC);

        /* Read from STDIN and pipe it to 4. */
        read_stdin();

        restore_tty();

        return 0;
}
