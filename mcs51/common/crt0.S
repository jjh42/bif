/***************************************************************************
                          crt0.S  -  description
                             -------------------
    begin                : Thu Jul 26 2001
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

#include <config.h>

        .globl  __main
/* Startup code for the mcs51 */

/* Inderectly addressable data. */
.area ISEG  (DATA)

/* Bit addressable data. */
.area BSEG (BIT)

/* Data segment. */
.area DSEG (DATA)

#ifdef XMEM
.area XSEG (DATA)
#endif

/* Stack segment. */
.area SSEG (DATA)
stack:          .ds     STACK_SIZE
stackcheck:     .ds     1

.area ACSEG  (ABS, CON, CODE)
    .org   0x000 
    ljmp    _startup

.area CSEG  (CODE)
    .globl   _startup

/* The first startup code before _main C function is called. It sets all the ports
 * to 0xff and clears all the memory. Then it sets up the stack and calls _main.
 */

_startup:
; This is the first startup code.
        clr     EA      ; Disable interrupts
; Clear PSW
        mov     PSW, #0
; Setup ports
        mov     P1, #0xff
        mov     P2, #0xff
        mov     P3, #0xff
        mov     P4, #0xff
; Clear internal memory
        mov     r0, #0
s_MemLoop:
        mov     @r0, #0
        djnz   r0, s_MemLoop
#ifdef  XMEM
; Clear external memory
        mov     r0, #LOW(XMEM_SIZE)
        mov     r1, #HIGH(XMEM_SIZE)
        mov     DPTR, #XMEM_START
        clr     a
s_XMemL:
        movx    @dptr, a
        inc     DPTR
        clr     C
        mov     a, r0
        subb    a, #1
        mov     r0, a
        mov     a, r1
        subb    a, #0
        mov     r1, a
        jnz     s_XMemL
#endif
; Setup the stack check
        mov     stackcheck, STACK_CHECKBYTE
        mov     SP, #stack
        ljmp    __main    /* C code takes over. */

