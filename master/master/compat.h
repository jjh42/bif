/*** Beginheader */

/***************************************************************************
                          compat.h  -  description
                             -------------------
    begin                : Tue Aug 14 2001
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

/* This file is for "compatibility." It should be included first in every file. */

#ifndef _COMPAT_H
#define _COMPAT_H

#define INCLUDE_MATIGSALUG

#ifdef TARGET_RABBIT
#include "compat-rabbit.h"
#elif TARGET_POSIX
#include "compat-posix.h"
#elif TARGET_WIN32
#include "compat-win32.h"
#else
#error Unknown target
#endif

#ifndef bool
typedef unsigned char bool;
#endif

#ifndef BOOL
typedef bool BOOL;
#endif

#ifndef true
#define true  1
#endif

#ifndef false
#define false 0
#endif

#ifndef TRUE
#define TRUE  1
#endif

#ifndef FALSE
#define FALSE 0
#endif

#ifndef NULL
#define NULL ((void*)0)
#endif

typedef unsigned long TIME;

#ifdef REAL_COMPILER
/* This is the stuff common to ANSI C compilers. */

#define xmem
#define root
#define nodebug
#define useix
#define constparam const
#define nodebug
#define nonauto

/* Xmem stuff */
typedef void *xmem_ptr_t;
typedef const void *const_xmem_ptr_t;
typedef const char *const_char_xmem_ptr_t;
#define deref_xmem(type, p)        (*((type*)p))
#define deref_xmem_ptr(p)          deref_xmem(xmem_ptr_t, p)
#define xalloc  malloc
#define xmem2root memcpy
#define xmem2xmen memcpy
#define XSTRING(name)           const char *name[] =
#define XSTRING_DECL(name)      extern const char *name[];
typedef const_xmem_ptr_t xdata_entry_t;
#define XDATA(name)             const xdata_entry_t name[] =
#define XSINGLESTRING(name) const char name[] =
#define XACCESS(m, n)		deref_xmem_ptr((m) + (n))
#define XPTR_SIZE		sizeof(xmem_ptr_t)


#endif /* REAL_COMPILER */

#endif /* _COMPAT_H */
/*** endheader */

