/***************************************************************************
                          main.c  -  description
                             -------------------
    begin                : Thu Jun 28 2001
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

#include <at89S8252.h>
#include <ser_ir.h>
#include <stdio.h>
#include <stdlib.h> 
#include <assert.h>
#include <stdarg.h>

/*-------------------------------------------------------------------------
  ser_ir.c - source file for serial routines 
  
  Written By - Josef Wolf <jw@raven.inka.de> (1999) 
  
	 This program is free software; you can redistribute it and/or modify it
	 under the terms of the GNU General Public License as published by the
	 Free Software Foundation; either version 2, or (at your option) any
	 later version.
	 
	 This program is distributed in the hope that it will be useful,
	 but WITHOUT ANY WARRANTY; without even the implied warranty of
	 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	 GNU General Public License for more details.
	 
	 You should have received a copy of the GNU General Public License
	 along with this program; if not, write to the Free Software
	 Foundation, 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
	 
	 In other words, you are welcome to use, share and improve this program.
	 You are forbidden to forbid anyone else to use, share and improve
	 what you give them.   Help stamp out software-hoarding!

-------------------------------------------------------------------------*/
/* #include "ser_ir.h" */

/* This file implements a serial interrupt handler and its supporting
* routines. Compared with the existing serial.c and _ser.c it has
* following advantages:
* - You can specify arbitrary buffer sizes (umm, up to 255 bytes),
*   so it can run on devices with _little_ memory like at89cx051.
* - It won't overwrite characters which already are stored in the
*   receive-/transmit-buffer.
* - It checks receiver first to minimize probability for overruns
*   in the serial receiver.
*/

/* BUG: those definitions (and the #include) should be set dynamically
* (while linking or at runtime) to make this file a _real_ library.
*/
/* #include <at89x2051.h> */
#define XBUFLEN 10
#define RBUFLEN 10

static unsigned char rbuf[RBUFLEN], xbuf[XBUFLEN];
static unsigned char rcnt, xcnt, rpos, xpos;
static unsigned char busy;

void ser_init (void)
{
   ES = 0;
   rcnt = xcnt = rpos = xpos = 0;  /* init buffers */
   busy = 0;
   SCON = 0x50;
   PCON |= 0x80;                   /* SMOD = 1; */
   TMOD &= 0x0f;                   /* use timer 1 */
   TMOD |= 0x20;
   TL1 = -3; TH1 = -3; TR1 = 1;    /* 19200bps with 11.059MHz crystal */
   ES = 1;
}

void ser_handler (void) interrupt 4
{
   if (RI) {
	   RI = 0;
	   /* don't overwrite chars already in buffer */
	   if (rcnt < RBUFLEN)
		   rbuf [(rpos+rcnt++) % RBUFLEN] = SBUF;
   }
   if (TI) {
	   TI = 0;
	   if (busy = xcnt) {   /* Assignment, _not_ comparison! */
		   xcnt--;
		   SBUF = xbuf [xpos++];
		   if (xpos >= XBUFLEN)
			   xpos = 0;
	   }
   }
}

void ser_putc (unsigned char c)
{
   while (xcnt >= XBUFLEN) /* wait for room in buffer */
	   ;
   ES = 0;
   if (busy) {
	   xbuf[(xpos+xcnt++) % XBUFLEN] = c;
   } else {
	   SBUF = c;
	   busy = 1;
   }
   ES = 1;
}

unsigned char ser_getc (void)
{
   unsigned char c;
   while (!rcnt)   /* wait for character */
	   ;
   ES = 0;
   rcnt--;
   c = rbuf [rpos++];
   if (rpos >= RBUFLEN)
	   rpos = 0;
   ES = 1;
   return (c);
}
#pragma SAVE
#pragma NOINDUCTION
void ser_puts (unsigned char *s)
{
   unsigned char c;
   while (c=*s++) {
	   if (c == '\n') ser_putc ('\r');
	   ser_putc (c);
   }
}
#pragma RESTORE
void ser_gets (unsigned char *s, unsigned char len)
{
   unsigned char pos, c;

   pos = 0;
   while (pos <= len) {
	   c = ser_getc ();
	   if (c == '\r') continue;        /* discard CR's */
	   s[pos++] = c;
	   if (c == '\n') break;           /* NL terminates */
   }
   s[pos] = '\0';
}

unsigned char ser_can_xmt (void)
{
   return XBUFLEN - xcnt;
}

unsigned char ser_can_rcv (void)
{
   return rcnt;
}


//#define LED_PIN P2_4
//#define WATCHDOG_PIN	P3_4
#define RX_MODE_PIN     P3_4

#define low(n)      \
    (n & 0xff)

#define high(n)     \
    ((n >> 8) & 0xff)

#define CRYSTAL_SPEED   12000000

/* Analogue bits */
#define ANA_SEL P1_2
#define ANA_A0	P1_3
#define ANA_A1  P1_4
#define ANA_DEV0 P1_5
#define ANA_DEV1 P1_6
#define ANA_CLK P1_7
#define ANA_DATA P1_0

#define nop	\
    _asm nop _endasm

/* Stuff for using a servo. */
#define SERVO_PORT P2_5 /* TMP */

unsigned int servopos = 1500; /* 1000 - 2000 */
#define DEGREES_TO_SERVPOS(d) \
	(d * 360 / 2000)


/* ISR */

void servo_init()
{
    /* Setup the timer to do a pulse in 20 ms */
    RCAP2H = ~(high(20000));
    RCAP2L = ~(low(20000));
    TR2 = 1;
    ET2 = 1;
    SERVO_PORT = 0;
}

void timer2_handler () interrupt TF2_VECTOR
{
    static char dopulse = 0;
    TF2 = 0;
    if(dopulse) {
        /* Setup the timer to do a pulse based on servopos. */
        dopulse = 0;
        RCAP2H = ~(high(servopos));
        RCAP2L = ~(low(servopos));
        SERVO_PORT = 1;
    }
    else {
        /* Setup the timer to wait 20 ms */
        dopulse = 1;
        RCAP2H = ~(high(20000));
        RCAP2L = ~(low(20000));
        SERVO_PORT = 0;
    }
}

const char sel[] = 
{
    /* 0b10000111 */ 0x87,
    /* 0b10001111 */ 0x8f,
    /* 0b10010111 */ 0x97,
    /* 0b10011111 */ 0x9f,
    /* 0b10101111 */ 0xaf,
    /* 0b10110111 */ 0xb7,
    /* 0b10111111 */ 0xbf,
    /* 0b11000111 */ 0xc7,
    /* 0b11001111 */ 0xcf,
    /* 0b11010111 */ 0xd7,
    /* 0b11011111 */ 0xdf,
    /* 0b10100111 */ 0xa7,
};

#define ANASELECT	0xfd /* 0b11111101 */

unsigned int getanalogue(unsigned char channel) 
{
    unsigned char i;
    unsigned int d = 0;
    
    /* I'm not sure if this is righta about selecting the channel */
    /* Select the right channel */
   // assert(channel < 12);
    /* First select the right multiplexer */
    
    EA = 0; /* Disable interupts. */
    
    P1 = sel[channel];	 /* Select the channel */
    
    ANA_CLK = 0;
    ANA_SEL = 0;
    nop;
    nop;
    
    ANA_CLK = 1;
    nop;
    nop;
    
    ANA_CLK = 0;
    nop;
    nop;
    
    ANA_CLK = 1;
    nop;
    nop;
    
    ANA_CLK = 0;
    nop;
    nop;
    ANA_CLK = 1;
    nop;
    nop;
    ANA_CLK = 0;
    
    /* Read in the data */
    for(i = 0; i < 12; i++ ) {
	ANA_CLK = 1;
	/* ANA_DATA contains a bit */
	d <<= 1;
	if(ANA_DATA)
	    d ++;
	ANA_CLK = 0;
    }
    
    ANA_SEL = 1;
    ANA_CLK = 1;
    
    EA = 1;
    return d;
}

void putchar(char c)
{
    ser_putc(c);
} 

void pause()
{
    unsigned int p = 10000;
    while(p) p--;
}

#include <itoa.c>

void mainloop()
{
    unsigned char i;    
    char temp[20];

    for(;;) {
//	LED_PIN = 0; 
	ser_puts("Looping\n");
    	/* Read in the analogue and output it */
	i = 0;
	while(i < 12) {
	    ser_puts("A input ");
	    pause();
	    itoa(i, temp, 10);
	    ser_puts(temp);
	    pause();
	    ser_puts(" is ");
	    pause();
	    itoa(getanalogue(i), temp, 10);
	    ser_puts(temp);
	    pause();
	    ser_puts("\n");
	    pause();
	    i++;
	}
        /* Set servopos based on a0 */
/*        servopos = (unsigned int) (((unsigned long )getanalogue(0)) * 2000 / 4096); */
//	LED_PIN = 1;
	pause();
    }
}

void sendbyte(char b)
{
    // Setup direction to output
    RX_MODE_PIN = 0;
    SBUF = b; // Send it
    // Wait until its done
    while(! TI);
        TI = 0;				
    // Setup direction to input
    RX_MODE_PIN = 1;

}

void main()
{	
    char byte;
    
        EA = 1;

   ES = 0;
   rcnt = xcnt = rpos = xpos = 0;  /* init buffers */
   busy = 0;
   SCON = 0x50;
   PCON |= 0x80;                   /* SMOD = 1; */
   TMOD &= 0x0f;                   /* use timer 1 */
   TMOD |= 0x20;
   TL1 = -3; TH1 = -3; TR1 = 1;    /* 19200bps with 11.059MHz crystal */
//   ES = 1; // Never enable the interrupt
   
/*   RX_MODE_PIN = 0;
   ser_puts("Ladies and Gentlemen I present the fish\r");
    while((xcnt) || (! TI));
    TI = 0;
    RX_MODE_PIN = 1;     */
//    sendbyte('T' | 0x80);
        // Turn on the led
        for(;;) {
//                WATCHDOG_PIN = 0;
        		
		while(! RI);// WATCHDOG_PIN = ! WATCHDOG_PIN;
		byte = SBUF;
		RI = 0;
		
		byte &= 0x7f;	// Clear parity bit
		
		switch(byte)
		{
		case 'v':
		    sendbyte('w');
		    break;
		case '<':
		    sendbyte('p' | 0x80);		
		    break;
		}
		
//		WATCHDOG_PIN = 1;
        }
}

