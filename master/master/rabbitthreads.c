/***************************************************************************
                          rabbitthreads.c  -  description
                             -------------------
    begin                : Mon Sep 10 2001
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

/* This is the version of threading for the rabbit. Not threading on the rabbit
 * is cooperative, not preemptive. Mutex's are unneeded as so the mutex routines
 * in here are empty.
 */
#ifndef TARGET_RABBIT
#error This file should only be included when compiling for the rabbit
#endif

/* Dummy headers for Dynamic C */
/*** Beginheader rabbitthreads_c */
#ifdef TARGET_RABBIT
void rabbitthreads_c();

#asm
XXXrabbitthreads_c:	equ	rabbitthreads_c
#endasm

#endif /* TARGET_RABBIT */
/*** endheader */

//#define NEW_THREADS

#ifdef TARGET_RABBIT
void rabbitthreads_c () { }
#endif /* TARGET_RABBIT */


/* This file does the rabbit thread. Rabbit threading is a bit complicated since
 * I don't use Dynamic C's partial thread support since it can't do what I want.
 */

#define FLAG_HASRUN     0x01
#define FLAG_PAUSED      0x02
typedef struct {
        long stack;
        long pc;
        char flags;
        } thread_table_t;

thread_table_t thread_table[MAX_THREADS];
U8 numthreads;
U8 running_thread;

extern long __initial_stack;
extern long init_threads_exit;

void init_threads()
{
        // Clear the thread table
        memset(thread_table, 0, sizeof(thread_table));

        // Setup first entry in table to initial thread
        thread_table[0].stack = __initial_stack;
        thread_table[0].pc = 0; // Pc will get set when it yields
        numthreads = 1;
        running_thread = 0;
}

thread_handle_t thread_begin(thread_start_t start, unsigned int stacksize)
{
        assert(numthreads < MAX_THREADS);

        thread_table[numthreads].stack = Alloc_Stack(stacksize);
        thread_table[numthreads].pc = (long)start;
        assert(thread_table[numthreads].stack != 0);

        numthreads++;
        return numthreads;
}

void thread_pause(thread_handle_t handle)
{
        assert(handle);
        thread_table[handle - 1].flags |= FLAG_PAUSED;
        thread_yield();
        while(thread_table[handle -1].flags & FLAG_PAUSED);
}

void thread_resume(thread_handle_t handle)
{
        assert(handle);
        thread_table[handle - 1].flags &= ~(FLAG_PAUSED);
}

void SwitchStack(long newstack);

/* Switch stack to the newstack. Subtract 4 from the value of the new stack
 * because when it returns the C compiler will add 4 to the stack.
 */
#asm root
SwitchStack::
	pop iy 				; remove return address from stack
	pop hl 				; new sp value
	pop bc 				; get the new STACKSEG value from c
	ld  a, c
	ld sp,hl
	ioi ld (STACKSEG), a
	push iy		; Subtract 4 from stack so it won't be damaged
	push iy		; when the compiler adds 4 to stack
	jp (iy)		; restore return address to program stack
	ret
#endasm


xmem useix void thread_yield()
{
	static long __pc;
	unsigned int __sp;
	// Get the calling threads stack pointer and PC
#asm
	; Set __pc
	ld A, (ix + 4) ; xpc
	ld (__pc + 2), A
	ld HL, (ix + 2) 
	ld (__pc), HL
	; Set __sp to stackpointer now + 7
        ; The Plus 7 is so the stack will be returned to what it was before
        ; we were called.
	ld hl, 7
	add hl, sp
	ld (ix + __sp), hl
#endasm

	thread_table[running_thread].pc = __pc;
	thread_table[running_thread].stack = thread_table[running_thread].stack & 0xffff0000;
	thread_table[running_thread].stack |= __sp;
	
	// Go to the next thread
	// Look for an unrun thread
	thread_table[running_thread].flags |= FLAG_HASRUN; // Mark as having run	
	running_thread++;
	if(running_thread >= numthreads) {
		// If at end of the list clear the HASRUN flag
		for(running_thread = 0; running_thread < numthreads; running_thread++) {
			thread_table[running_thread].flags &= ~FLAG_HASRUN;
		}
		running_thread = 0;
	}

	// Find a thread to run
	for(; running_thread < numthreads; running_thread++) {
		if(!(thread_table[running_thread].flags & (FLAG_HASRUN | FLAG_PAUSED))) {
			// This thread hasn't run yet and isn't paused so run it
			__pc = thread_table[running_thread].pc;			
			SwitchStack(thread_table[running_thread].stack);
#asm					
			; Begin executing the code in that routine
			ld	ix, (__pc + 1)
			push	ix
			; XPC only takes 1 byte on stack
			add	sp, 1
			ld	ix, (__pc)
			push	ix
		
			lret
#endasm		
		}
	}

	assert(0); // Deadlock
}


#if 0
// Yield execution
#asm root
        call    next_thread
#endasm

#asm root
        ; This is the periodic interrupt that changes what is running.
::thread_isr
        push    IX
        push    a
        ; Save this thread, then we can play with the registers
        ld      ix, (running_thread)
        ; Since each entry in the table is
::next_thread   ; Go to the next thread
        ld      A, (running_thread)     ; Load the current thread in A
        inc     A                       ; Go to the next thread
        ld      HL, numthreads
        cp      (HL)                    ; Compare HL to A
        jr      NC, overflow            ; If A >= (HL)
nooverflow:
save_entryix:
        ; Save the running thread in entry at (IX)
        ld      (IX), SP
        ioi ld  a, STACKSEG
        ld      (IX + 2), a
        ld      (IX + 4), PC
        ld      (IX + 6), XPC
        ld      (IX + 8), A
        ld      (IX + 9), F
        ld      (IX + 10), HL
        ld      (IX + 12), DE
        ld      (IX + 14), BC
restore_entryix:
        ld      SP, (IX)
        ld      a, (IX + 2)
        ioi ld  STACKSEG, a
        ld      PC, (IX + 4)
        ld      XPC, (IX + 6)
        ld      A, (IX + 8)
        ld      (IX + 6), XPC
        ld      (IX + 8), A
        ld      (IX + 9), F
        ld      (IX + 10), HL
        ld      (IX + 12), DE
        ld      (IX + 14), BC


overflow:
        ld      A, 0                    ; Clear A
        jr      nooverflow
#endasm

#asm
        // Setup Timer B to give a periodic interupt every 1/64th of a second

        ; Setup vector
	ld		a,iir	                ; get the offset of interrupt table
	ld		h,a
        ld		l,0xb                   ; Timer B offset
	ld		iy,hl
	ld		(iy),0c3h		; jp instruction entry
	inc	        iy
        ld		hl,thread_isr           ; set service routine
	ld		(iy),hl

        ; Setup timer B
        ; 13000
        ioi ld  (TBM1R),53
        ioi ld  (TBL1R),0x00
        ioi ld  (TBCR), 0x81            ; Enable perclk/2/8
        ioi ld	(TBCSR),0x01            ; Enable Timer B clock

#endasm

#endif


#asm root
mutex_init::
mutex_unlock::
        ; Mutex_init and unlock actually both do the same thing
        ; Clear the mutex
        ld      (HL), 0
        ret
#endasm

#asm root
mutex_lock::
        ; Hl is already loaded with the pointer to mut.
        bit     0, (HL)     ; Test bit at HL
        set     0, (HL)     ; Make sure bit is set
        ; If 0 flag set then mutex belongs to us. Otherwise it belongs to
        ; someone else.
        jp      Z, m_exit
        ; Yield control
        call thread_yield
        ; Try again
        jp      mutex_lock
m_exit:
        ret        
#endasm




