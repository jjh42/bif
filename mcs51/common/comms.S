/***************************************************************************
                          comms.S  -  description
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
#include "mcscomms.h"

        .globl  _setup_comms

        .area   DSEG(DATA)
_commsstatus:     .ds     1
_commsbuflen:     .ds     1

#ifdef XMEM
        .area   XSEG(DATA)
#else
        .area   ISEG(DATA)
#endif
_commsbuf:  .ds     COMMSBUFSIZE


        .area   CSEG(CODE)



_setup_comms:
        /* Use Timer 1 to generate the baud rate. */
        mov     TMOD, #0x20     ; set Timer 1 for auto reload - Mode 2
        mov     TCON, #0x41     ; run Timer 1 and set edge triggered interrupts
        mov     TH1, #CLOCK_SPEED / 4800       ; setup baud rate
        mov     SCON, #0x50     ; set Mode 1 and 8 bits data

        mov     _commsstatus, #COMMS_IDLE

        ret



_emptycomms:
        mov     _commsstatus, #COMMS_IDLE
        mov     _commsbuflen, #0
        ret


        .area ACSEG  (ABS, CON, CODE)
        .org    UART_VECT
        ljmp    comms_isr


        .area   CSEG(CODE)



cisr_lookup:
        sjmp    cisr_reset

comms_isr:
        push    PSW
        push    acc
        push    AR1

        ; Check if it was receiving or sending.
        jnb     TI, cisr_receiving
        clr     TI
        ; We are sending
        mov     a, _commsbuflen
        cjne    a, #0, cisr_okay
        ; If buffer is empty just exit (will happen for the last
        ; instruction)
        sjmp    cisr_exit

cisr_okay:
        add     a, #LOW(_commsbuf)
        mov     r0, a
#ifdef  XMEM
        ; Have to add high byte
        mov     a, #0
        addc    a, #HIGH(_commsbuf)
        mov     P2,a    ; Output high byte to address lines
        ; Get and send data
        movx    a, @r0
        mov     SBUF, a
#else
        mov     SBUF, @r0
#endif
        dec     _commsbuflen

cisr_exit:
        pop     AR0
        pop     acc
        pop     PSW
        reti

cisr_receiving:

        sjmp    cisr_exit