/***************************************************************************
                          posixthreads.c  -  description
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

/* POSIX threads */

#ifndef TARGET_POSIX
#error This file is for POSIX only
#endif

#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include "compat.h"
#include "threads.h"

// Does nothing in POSIX
void init_threads()
{
}

/* This first subroutine called at the start of a new thread */
void *new_thread(void *arg)
{
        thread_start_t start = (thread_start_t)arg;
        /* Call their routine. */
        (*start)();

        printf("Thread ended\n");
        return 0;
}

/* Begin a new thread */
thread_handle_t thread_begin(thread_start_t start, unsigned int stacksize)
{
        pthread_t *thread_handle = malloc(sizeof(thread_handle));

        if(pthread_create(thread_handle, NULL, new_thread, start) != 0) {
                printf("Failed to create thread\n");
                return 0;
        }

        return thread_handle;
}


void thread_pause(thread_handle_t handle)
{
        assert(handle);
        // TODO

}

void thread_resume(thread_handle_t handle)
{
        assert(handle);
        // TODO
}

void thread_yield()
{
        usleep(1);
}

void mutex_init(mutex_t *mutex)
{
        pthread_mutex_init(mutex, 0);
}

void mutex_lock(mutex_t *mutex)
{
        if(pthread_mutex_lock(mutex) != 0)
                printf("Warning failed to lock mutex\n");
}

void mutex_unlock(mutex_t *mutex)
{
        if(pthread_mutex_unlock(mutex) != 0)
                printf("Warning failed to unlock mutex\n");
}

