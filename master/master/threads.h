/*** Beginheader */

/***************************************************************************
                          threads.h  -  description
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

#ifndef _THREADS_H
#define _THREADS_H
/* Compatibility layer for threading */
#ifdef TARGET_POSIX
#include <pthread.h>
#endif

typedef void (*thread_start_t)();

#ifdef TARGET_RABBIT
typedef int thread_handle_t;
#endif
#ifdef TARGET_POSIX
typedef pthread_t * thread_handle_t;
#endif
#ifdef TARGET_WIN32
typedef void *thread_handle_t; // Doesn't matter if this doesn't work here
#endif

extern void init_threads();
/* Begin a thread with the start in this file. Pass 0 for a default stack size.
 * Returns the handle or 0 on error. */
#define STACK_128       128
#define STACK_256       256
#define STACK_512       512
#define STACK_1024      1024
#define STACK_2048      2048
#define STACK_4096      4096
#define STACK_8192      8192
extern thread_handle_t thread_begin(thread_start_t start, unsigned int stacksize);
extern void thread_pause(thread_handle_t handle);
extern void thread_resume(thread_handle_t handle);

// Yield execution
extern void thread_yield();

// Maximum number of threads
#define MAX_THREADS     3

/* Mutexes */
#ifdef TARGET_RABBIT
        /* Empty */
typedef char mutex_t;
#elif TARGET_WIN32
typedef char mutex_t;
#elif TARGET_POSIX
typedef pthread_mutex_t mutex_t;
#endif


extern void mutex_init(mutex_t *mutex);
extern void mutex_lock(mutex_t *mutex);
extern void mutex_unlock(mutex_t *mutex);

#endif /* THREADS_H */

/*** endheader */

