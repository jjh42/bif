/*** Beginheader */

/***************************************************************************
                          compat-rabbit.h  -  description
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

#ifndef _COMPAT_RABBIT_H
#define _COMPAT_RABBIT_H

#define constparam
#define signed

#undef true
#undef false
#undef TRUE
#undef FALSE
#define true 1
#define false 0
#define TRUE 1
#define FALSE 0

#ifndef NULL
#define NULL (void*)0
#endif

#define nonauto static

typedef unsigned char U8;
typedef signed char S8;
typedef unsigned int U16;
typedef signed int S16;
typedef signed long S32;
typedef unsigned long U32;

#define assert(x) assert_handler(x);
extern void assert_handler(bool val);

#define strncasecmp	strncmpi
#define strcasecmp	strcmpi

typedef long xmem_ptr_t;
typedef long const_xmem_ptr_t;
typedef long const_char_xmem_ptr_t;
// Note: Can't handle anything larger than long (sizeof(xmem_ptr_t) == sizeof(long))
extern long __deref_xmem(const_xmem_ptr_t ptr);
#define deref_xmem(type, p)        (type) __deref_xmem(p)
#define deref_xmem_ptr(p)          deref_xmem(xmem_ptr_t, p)
#define XSTRING(name)		xstring name
#define XSTRING_DECL(name)
#define XSINGLESTRING(name)	xdata name
#define XDATA(name)		xdata name
#define XACCESS(m, n)		deref_xmem_ptr((m + (sizeof(long)*n)))
#define XPTR_SIZE		sizeof(long)

#endif /* _COMPAT_RABBIT_H */

/*** endheader */

