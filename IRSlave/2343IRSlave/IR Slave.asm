;*****************************************************************************
;
;	IR Slave.asm	InfraRed Slave program for Robot
;
;	Written By:		Robert Hunt			November 2000
;
;	Modified By:	Robert Hunt
;	Mod. Number:	15
;	Mod. Date:		4 April 2001
;
;	Accepts the following messages (at 2400 baud):
;		I?			Poll for response (doesn't reply if nothing to send)
;		IV			Poll for version number
;		ILx			Set LED function to x
;						'0'	;Always off
;						'N'	;Flashes on when receiving
;						'I'	;Flashes off when receiving
;						'S'	;Slow flash
;						'F'	;Fast flash
;						'B'	;Baud rate diagnostic COMMENTED OUT
;						'T'	;Interrupt Time diagnostic COMMENTED OUT
;						'1'	;Always on
;		IXhh		Set SW UART TC reload to hh (hex) temporarily
;		IZhh		Set SW UART TC reload to hh (hex) permanently
;
;*****************************************************************************

; This program is written for an 2343 (8-pin) with a nominal 1MHz internal clock
;	on a custom made board

; This is version 1.0.0.5
.EQU	MajorVersion	= 1
.EQU	MinorVersion	= 0
.EQU	RevisionNumber	= 0
.EQU	FixNumber		= 5

;*****************************************************************************
;
;	Version History:
;
;	V1.0.0.5	4 April 2001	Adjusted timer reload factor
;								Removed some debugging code
;	V1.0.0.4	3 April 2001	Added temporary timer reload setting message
;								Put version number in beginning
;	V1.0.0.3	1 April 2001	Put the timer reload in EPROM and added a message
;								Added two new LED diagnostic modes
;	V1.0.0.2	21 March 2001	Added temporary diagnostic code for PE
;								Adjusted LED flash rates
;	V1.0.0.1	20 March 2001	Added LED message ILx where x=0/1/N/I/S/F
;									and FE diagnostic (temp)
;								Clear RxBufCnt when get a FE or PE
;	V1.0.0.0	13 March 2001	All works at 2400bps
;
;****************************************************************************

.nolist
.include	"C:\Program Files\AVRTOOLS\asmpack\appnotes\2343def.inc"
.list
.listmac


;*****************************************************************************
;
;	Global Parameters
;
;*****************************************************************************
;
.EQU	LF		= 0x0A
.EQU	CR		= 0x0D

.EQU	Num_IR_Bits = 32


;*****************************************************************************
;
;	Error Codes
;
;*****************************************************************************
;
.EQU	FlashAllocationErrorCode		= 1
.EQU	RAMAllocationErrorCode			= 2
.EQU	StackOverflowErrorCode			= 3
.EQU	UnusedInterruptErrorCode		= 4
.EQU	SUBufferFullErrorCode			= 5


;*****************************************************************************
;
;	Timer/Counter Assignments
;
;*****************************************************************************
;
; Timer/Counter 0 Prescaler Controls	 (See times below for 1MHz oscillator)
.EQU	TCStop			= 0b000									;8-bit	16-bit
.EQU	TCClkDiv1		= 0b001			; 1MHz			1us		256us	66ms
.EQU	TCClkDiv8		= 0b010			; 125KHz		8us		2ms		524ms
.EQU	TCClkDiv64		= 0b011			; 15.6KHz		64us	16ms	4.2s
.EQU	TCClkDiv256		= 0b100			; 3.91KHz		256us	66ms	17s
.EQU	TCClkDiv1024	= 0b101			; 977Hz			1ms		262ms	67s
.EQU	TCClkExtFall	= 0b110
.EQU	TCClkExtRise	= 0b111
;
;*****************************************************************************
;
; Timer/Counter-0 (8-bit)
;	Used for baud rate for software UART
;	Samples at 4 x baud rate, so 4 * 2400 = 9600
.EQU	SWUARTTCCR	= TCCR0
.EQU	SWUARTTC	= TCNT0
.EQU	SWUARTTCIE	= TOIE0
.EQU	SWUARTPS	= TCClkDiv1
; At 1MHz the reload should be 152 (256 - 152 = 104)
								;1000000 / 1 / 104 = 9615 Hz = 0.104ms
; But since the 1MHz is "nominal", the measured frequency was 5.5KHz
;  and it seems like the processor is running at 1.15MHz
;  so this reload value has been adjusted by hand
;.EQU	SWUARTTCReload = 136	;256 - 136 = 120
								;1150000 / 1 / 120 = 9583 Hz = 0.104ms
; But that still seemed too high so adjusted again by hand
;	It can also be adjusted now via the comms
.EQU	SWUARTTCReload = 134	;256 - 134 = 122
;

;*****************************************************************************
;
;	Watchdog Control Definitions
;
;*****************************************************************************
;
.EQU	WD16	= 0b000	;  16 cycles = 15 msec with Vcc = 5.0v
.EQU	WD32	= 0b001	;  32 cycles = 30 msec
.EQU	WD64	= 0b010	;  64 cycles = 60 msec
.EQU	WD128	= 0b011	; 128 cycles = 0.12 sec
.EQU	WD256	= 0b100	; 256 cycles = 0.24 sec
.EQU	WD512	= 0b101	; 512 cycles = 0.49 sec
.EQU	WD1024	= 0b110	;1024 cycles = 0.9 sec
.EQU	WD2048	= 0b111	;2048 cycles = 1.9 sec


;*****************************************************************************
;
;	Port/Pin Definitions
;
;*****************************************************************************
;
; Port-B:
;	PB0	(MOSI)		Pin-5	Out	LED
;	PB1	(MISO/INT0)	Pin-6	In	Rx
;	PB2	(SCK/T0)	Pin-7	Out	Tx (but only when transmitting)
;	PB3	(CLOCK)		Pin-2	In	IR Front
;	PB4				Pin-3	In	IR Rear
.EQU	LEDPin		= 0
.EQU	LEDPort	= PORTB
.EQU	SURx		= 1
.EQU	SUInput		= PINB
.EQU	SUTx		= 2
.EQU	SUPort		= PORTB
.EQU	IRFrontBit	= 3
.EQU	IRRearBit	= 4
.EQU	IRInput		= PINB


;*****************************************************************************
;
;	Register Assignments
;
;*****************************************************************************
;
;	R0		For general use (esp. with LPM instruction)
;	R1		Reserved for saving SREG in interrupt routines
;	R2		IR Front Byte
;	R3		IR Rear Byte
;	R4		IR Front Status
;	R5		IR Rear Status
;	R6		HaveComRxLine flag: 0=nothing, 1=line received
;	R7		TempLa: Temp 8-bit register for main program
;	R8		TempLb
;	R9		TempLc
;	R10		TempLd
;	R11		ISRTempL
;	R12		SWUART TC Reload value
;	R13		LED change time
;	R14		Software UART Rx Byte
;	R15		Software UART Tx Byte
.DEF	ISRSRegSav		= r1
.DEF	IRFrontByte		= r2
.DEF	IRRearByte		= r3
	.EQU	IRRepeatCode	= 0xFF
	.EQU	IRErrorCode		= 0xFE
.DEF	IRFrontStatus	= r4
.DEF	IRRearStatus	= r5
	.EQU	IR_Idle				= 0
	.EQU	GettingHeaderPulse	= 1
	.EQU	GettingHeaderSpace	= 2
	.EQU	GettingRepeatPulse	= 3
	.EQU	GettingPulse1		= 4	;These must be the final values
	.EQU	GettingSpace1		= 5	; because the other bits follow
	; Note: GettingPulse must be even, GettingSpace must be odd
	.EQU	GettingLastPulse	= (GettingPulse1 + (2 * (Num_IR_Bits)))

.DEF	HaveComRxLine	= r6
.DEF	TempLa			= r7
.DEF	TempLb			= r8
.DEF	TempLc			= r9
.DEF	TempLd			= r10
.DEF	ISRTempL		= r11
.DEF	SWUARTTCReloadR	= r12
.DEF	LEDTime			= r13	;SysTickh when LED changed
.DEF	SURxByte		= r14	;The byte being received
.DEF	SUTxByte		= r15	;The byte being transmitted
;
;*****************************************************************************
;
;	All of the following registers can be addressed by the LDI instruction:
;
;	R16		TempUa: Temp 8-bit register for main program
;	R17		TempUb: Temp 8-bit register for main program
;	R18		TempUc: Temp 8-bit register for main program
;	R19		Temp 8-bit register for interrupt service routines only
;	R20		LED Function
;	R21		Parameter 8-bit register
;	R22		Software UART Rx Status
;	R23		Software UART Tx Status
.DEF	TempUa			= r16
.DEF	TempUb			= r17
.DEF	TempUc			= r18
.DEF	ISRTempU		= r19
.DEF	LEDFn			= r20
	.EQU	LEDOff		= '0'	;Always off
	.EQU	LEDNormal	= 'N'	;Flashes on when receiving
	.EQU	LEDInverse	= 'I'	;Flashes off when receiving
	.EQU	LEDSlowFlash = 'S'	;Slow flash
	.EQU	LEDFastFlash = 'F'	;Fast flash
	.EQU	LEDOn		= '1'	;Always on
;	.EQU	LEDBaudDiag	= 'B'	;Baud rate diagnostic output
;	.EQU	LEDIntTime	= 'T'	;Interrupt time diagnostic output
.DEF	ParamReg		= r21
.DEF	SURxStatus		= r22
	.EQU	SURxIdle		= 39	;10 bits * 4 - 1
.DEF	SUTxStatus		= r23
	.EQU	SUTxIdle		= 0xFF	;Must be FF
;
;*****************************************************************************
;
;	All of the following registers can be addressed by the ADIW instruction:
;
;	R24		} SysTick variable
;	R25		}
;	R26	XL	Used for ISRs only
;	R27	XH	Used for ISRs only
;	R28	YL	}
;	R29	YH	} For general
;	R30	ZL	}	use
;	R31 ZH	}
.DEF	SysTick		= r24	;and r25 (MSB)
.DEF	SysTickL	= r24
.DEF	SysTickH	= r25


;*****************************************************************************
;
;	SRAM Variable Definitions
;
; Total RAM = 128 bytes starting at 0060 through to 00DF
;
; Note: On the 2343 the high address of RAM is always 00
;			(so nothing ever crosses a 256-byte boundary
;			 and the high byte of pointer registers is ignored)
;
;*****************************************************************************

	.DSEG

; Serial port buffers
.EQU	ComRxBufSiz		= 20	;Note: Maximum of 128 characters
								;Must be at least 32 bytes for DumpRegisters
ComRxBuf:		.byte	ComRxBufSiz
ComRxBufCnt:	.byte	1	;Number of characters in the buffer

.EQU	ComTxBufSiz		= 50	;Note: Maximum of 128 characters
ComTxBuf:		.byte	ComTxBufSiz
ComTxBufCnt:	.byte	1	;Number of characters in the buffer
ComTxBufO1:		.byte	1	;Offset to 1st character in buffer


; IR (InfraRed)
IRFrontTime:	.byte	1	;Time when bit last changed
IRRearTime:		.byte	1
IRFrontState:	.byte	1	;Last state of IR pin
IRRearState:	.byte	1
IRFrontBytes:	.byte	4	;32-bits of code
IRRearBytes:	.byte	4
	.EQU	IRByte1	= 0x38	;The first two bytes are fixed values
	.EQU	IRByte2 = 0xC7

; Miscellaneous variables
ConvString:		.byte	12	;Storage for null-terminated conversion string
							; (Sign plus five digits plus null)
							;But also used for forming comms messages
							; (BV0MMRF0CR plus null)

; Error Counters (All initialized to zero when RAM is cleared at RESET)
SUFramingErrorCount:			.byte	1
SUParityErrorCount:				.byte	1
SURxBufferOverflowErrorCount:	.byte	1
SULineOverflowErrorCount:		.byte	1
InvalidMessageErrorCount:		.byte	1
.EQU	SUFramingErrorCode			= 'F'	;46H
.EQU	SUParityErrorCode			= 'P'	;50H
.EQU	SURxBufferOverflowErrorCode	= 'B'	;42H
.EQU	SULineOverflowErrorCode		= 'L'	;4CH
.EQU	InvalidMessageErrorCode		= 'I'	;49H
;SUFEBC:	.byte	1	;Byte count when got FE for diagnostics
;SUFERx:	.byte	1;	;Rx char when got FE

; This next variable is here for error checking
;  (If it is not equal to RandomByteValue, then the stack has overflowed)
StackCheck:		.byte	1	;For error checking only -- contents should never change
	.EQU	RandomByteValue	= 0x96
Stack:			.byte	16	;Make sure that at least this many bytes are reserved for the stack
							; so that we get an assembler warning if we're low on RAM
NextSRAMAddress:	;Just to cause an error if there's no room for the stack
					; (NextSRAMAddress should be address E0H (RAMEND+1) or lower)


;*****************************************************************************
;
;	EEPROM Variable Definitions
;
; Total EEPROM = 128 bytes starting at 0000 through to 007F
;
;*****************************************************************************

	.ESEG

EEReload:	.db		SWUARTTCReload

NextEEPROMAddress:	;Just to cause an error if the EEPROM is overallocated
					; (NextEEPROMAddress should be address 80H (E2END+1) or lower)


;*****************************************************************************
;*****************************************************************************
;
;	MACROS
;
;*****************************************************************************
;*****************************************************************************

;*****************************************************************************
;
;	General Global Macros
;
;*****************************************************************************
;
.MACRO	clrw	;Clear Word
				; e.g. clrw		z
	clr		@0l
	clr		@0h
.ENDMACRO

.MACRO	mvw		;Move Word
				; e.g. mvw		z,y
	mov		@0l,@1l
	mov		@0h,@1h
.ENDMACRO

.MACRO	pushw	;Push Word
				; e.g. pushw	z
				;(Push LS byte first so easy to read stack dump)
	push	@0l
	push	@0h
.ENDMACRO

.MACRO	popw	;Pop Word
				; e.g. popw		z
	pop		@0h
	pop		@0l
.ENDMACRO

.MACRO	ldsa	;LoaD String Address into a register pair
				; e.g. ldsa	z,StringName
	ldi		@0l,low(@1<<1)
	ldi		@0h,high(@1<<1)
.ENDMACRO

.MACRO	ldiw	;LoaD Immediate Word into a register pair
				; e.g. ldiw	z,1000
	ldi		@0l,low(@1)
	ldi		@0h,high(@1)
.ENDMACRO

.MACRO	ldsw	;LoaD Sram Word into a register pair
				; e.g. ldsw	z,Value
	lds		@0l,@1
	lds		@0h,@1+1
.ENDMACRO

.MACRO	stsw	;STore register pair to a Sram Word
				; e.g. stsw	Value,z
				;(Save MS byte first so easy to read a RAM dump)
	sts		@0,@1l
	sts		@0+1,@1h
.ENDMACRO

.MACRO	addi	;Add Immediate
				; e.g. addi	R4,23
	subi	@0,-(@1)
.ENDMACRO

.MACRO	brze	;BRanch if ZEro
				; e.g. brze	Loop1
	breq	@0
.ENDMACRO

.MACRO	brnz	;BRanch if Not Zero
				; e.g. brnz	Loop2
	brne	@0
.ENDMACRO

.MACRO	 bris	;BRanch if I/O register Set
				; e.g. bris USR, FE, FramingError
	sbic	@0,@1
	rjmp	@2
.ENDMACRO

.MACRO	bric	;BRanch if I/O register Cleared
				; e.g. bric USR, FE, NoFramingError
	sbis	@0,@1
	rjmp	@2
.ENDMACRO

.MACRO	SaveSReg	;Save Status Register
	in  	ISRSRegSav,SREG	;Save the Status Register (in dedicated register)
.ENDMACRO

.MACRO	RestoreSRegReti	;Restore Status Register and Return from Interrupt
	out 	SREG,ISRSRegSav	;Restore SREG from temporary store
	reti					;return, and automatically reenable interrupts
.ENDMACRO


;*****************************************************************************
;
;	Specific Macros
;
;*****************************************************************************
;
.MACRO	LoadAndSendFString
				;	e.g. LoadAndSendFString	StringName
	; Uses z
	ldi		zl,low(@0<<1)
	ldi		zh,high(@0<<1)
	rcall	SendFString	;Uses: R0, y, z, TempUa, TempUb, TempUc, ParamReg
.ENDMACRO

; Check for operational errors
.MACRO	CheckError
	brcs	PC+12			;Skip this if already sent an error message
	lds		TempUa,@0ErrorCount
	tst		TempUa
	breq	PC+8
	; The error count is non-zero -- advise the user
	mov		ParamReg,TempUa		;Save the error count in ParamReg
	clr		zl
	sts		@0ErrorCount,zl		;Clear the error count in memory
	ldi		TempUa,@0ErrorCode
	rcall	SendErrorMessage
	sec							;Set carry flag to indicate we did something
	;Both branch instructions should reach here to the end
.ENDMACRO


;*****************************************************************************
;*****************************************************************************
;
;	Start of Actual Code
;
;	This chip has 1K 16-bit words (2K bytes) of flash memory
;	going from word addresses 000 to 3FF
;
;*****************************************************************************
;*****************************************************************************

	.CSEG


;*****************************************************************************
;
;	Interrupt Vector Table
;
;*****************************************************************************

 .ORG 	0x000
	rjmp	Reset
 .ORG 	INT0addr
	rjmp	UnusedInterruptError
 .ORG 	OVF0addr
	;rjmp	ISR_SU			;Software UART
 
;*****************************************************************************
;*****************************************************************************
;
;	Interrupt Service Routines
;
;*****************************************************************************
;*****************************************************************************

	
;*****************************************************************************
;
;	Software UART Timer Interrupt Service Routine
;
;	Services a timer interrupt at four times the desired baud rate
;		At 2400 baud this is 9600Hz or every 104usec
;
;	Sends the next bit or character if there is one, else disables itself
;
;*****************************************************************************

ISR_SU:
	; Reload the counter
	out		SWUARTTC,SWUARTTCReloadR

;*****************************************************************************

	SaveSReg			;Save the status register
	
;*****************************************************************************

;	cpi		LEDFn,LEDIntTime	;Interrupt Time diagnostic?
;	brne	ISRLEDDone1			;Do nothing here if not
;	cbi		LEDPort,LEDPin		;Turn it on (low)
;ISRLEDDone1:

;*****************************************************************************

; Increment SysTick 16-bit variable (which is kept in registers)
; 	SysTick increments every 104 usec
;		The LSB overflows every 27 msec
;		The MSB overflows every 6.8 seconds
	adiw	SysTick,1	;Increment it directly

;*****************************************************************************

;	tst		SysTickL
;	brnz	ISTDone
;	cpi		LEDFn,LEDBaudDiag	;Baud rate time diagnostic?
;	brne	ISTDone				;Do nothing here if not
;	in		ISRTempU,LEDPort
;	ldi		xl,1<<LEDPin
;	eor		ISRTempU,xl
;	out		LEDPort,ISRTempU
;ISTDone:
	
;*****************************************************************************

; Service the transmitter first
	cpi		SUTxStatus,SUTxIdle	;Is the TX status idle (FF)?
	breq	ISUTxFinished		;Yes, branch and check for characters in buffer
	
	; The transmitter is not idle
	mov		ISRTempU,SUTxStatus ;Copy the Tx status
	andi	ISRTempU,0x03	;Are the last two bits both zero?
	brne	ISUTxDone		;No, we don't have to do anything yet (except increment the status)
							; (The Tx only does something every fourth interrupt)
	; If you get here, SUTxStatus must be divisible by four

	; It's time to check for a new bit
	; Status	 0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 17 18 19
	;			 S  S  S  S  0  0  0  0  1  1  1  1  2  2  2  2  3  3  3  3
	;			20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40
	;			 4  4  4  4  5  5  5  5  6  6  6  6  7  7  7  7  S  S  S  S Done
	;			FF = Idle
	tst		SUTxStatus		;See if it's a start bit (Status = 0)
	brze	ISUTxZero		;Yes, branch and send it
	
	cpi		SUTxStatus,36	;Is it a stop bit?
	breq	ISUTxOne		;Yes, branch and send it

	cpi		SUTxStatus,40	;Have we finished sending the character
	breq	ISUTxFinished	;Yes, branch to see if there's any more to send

	; Send the next data bit (LS bit sent first)
	lsr		SUTxByte		;Get the next bit into carry
	brcc	ISUTxZero
ISUTxOne:
	sbi		SUPort,SUTx		;Send a one
	rjmp	ISUTxDone		; (either if the data bit is one or else for a stop bit)
ISUTxZero:
	cbi		SUPort,SUTx		;Send a zero
	rjmp	ISUTxDone		; (either if the data bit is zero or else for a start bit)
	
	; We've finished the stop bit -- see if there's any more characters to send
ISUTxFinished:
	; See if the count is non-zero
	lds		ISRTempU,ComTxBufCnt
	tst		ISRTempU
	brnz	ISUTxHaveSome
	
	; No characters in buffer
	cpi		SUTxStatus,SUTxIdle	;Were we already idle?
	breq	ISUTxEnd			;Yes, branch
	
	; We just finished transmitting the last character -- disable software transmitter
	ldi		SUTxStatus,SUTxIdle
	cbi		DDRB,SuTx			;Set Tx output into a high impedance input
	rjmp	ISUTxEnd			; (so can be used on multidrop comms)
	
ISUTxHaveSome:
	; Ensure that the Tx output is enabled
	sbi		DDRB,SuTx			;Set Tx into an output
	sbi		SUPort,SUTx			;Ensure Tx output is set high (idle)

	; Decrement the count and save it again
	dec		ISRTempU
	sts		ComTxBufCnt,ISRTempU
	
; Get the next character ready to send
	; Get the buffer address and add the offset to the first character
	lds		xl,ComTxBufO1	;Get the buffer offset
	addi	xl,ComTxBuf		;Add in the base address
	ld		SUTxByte,x+		;Get the character and increment the pointer
	
	; Now we have to see if the incremented pointer has gone past the end of the (circular) buffer
	subi	xl,ComTxBuf		;Convert the incremented address back to an offset
	cpi		xl,ComTxBufSiz
	brlo	ISUTxOk			;Ok if lower
	subi	xl,ComTxBufSiz	;Adjust if was higher
ISUTxOk:
	; Store the new offset to the first character in the buffer
	sts		ComTxBufO1,xl

	; Send the start bit
	cbi		SUPort,SUTx		;Set low for a start bit
	ldi		SUTxStatus,-1	;It will now get incremented to zero below
ISUTxDone:
	inc		SUTxStatus		;Increment the Tx status counter
ISUTxEnd:

;*****************************************************************************

; Service the receiver next
; The receiver receives a line terminated by a CR
	cpi		SURxStatus,SURxIdle
	brne	ISURxNotIdle
	
	; It's idle -- check for a start bit
	sbic	SUInput,SURx	;A start bit is low
	rjmp	ISURxIdle		;It's set so still idle
	
	; We've got the start of a start bit
	clr		SURxStatus	;So will sample at the right times later					
	rjmp	ISURxStarted; (We sample when it's divisible by 4)

	; We're in the middle of receiving a byte
ISURxNotIdle:
	mov		ISRTempU,SURxStatus ;Copy the Rx status
	andi	ISRTempU,0x03	;Are the last two bits both zero?
	brze	ISURxCheckIt	;Yes, we need to check it
	rjmp	ISURxDone		;No, we don't have to do anything yet
							; (The Rx only does something every fourth interrupt now)
ISURxCheckIt:
	tst		SURxStatus		;See if the status is zero
	brnz	ISURxNotStart	;If it's not zero we need to check further
	rjmp	ISURxDone		;If it's zero, we're still receiving the start bit
							; (We already know that so just wait until the next bit)
ISURxNotStart:
	; Check what we're up to now
	; Status	FF  0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 17 18
	;			 S  S  S  S  0  0  0  0  1  1  1  1  2  2  2  2  3  3  3  3
	;			19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39
	;			 4  4  4  4  5  5  5  5  6  6  6  6  7  7  7  7  S  S  S  S Done
	cpi		SURxStatus,36	;Waiting for stop bit?
	breq	ISURxStop		;Yes, branch
	
	; We're waiting for a data bit
	clc
	sbic	SUInput,SURx
	sec
	ror		SURxByte		;Put the carry bit into the byte
	rjmp	ISURxDone		; (Remember the LS bit is sent first)

	; We're waiting for a stop bit
ISURxStop:
	sbis	SUInput,SURx	;It should be high
	rjmp	ISUFramingError	;Branch if low
	; If we get here, we've sampled the stop bit. Action the character
	; even though the status counter will keep incrementing until the
	; full length of the stop bit is received

	; Check the parity of the received byte
	push	TempUa
	push	ParamReg
	mov		ParamReg,SURxByte	;Get the received byte
	rcall	GetEvenParity		;Gets the expected parity bit in T
	rol		ParamReg			;Get the received parity bit into C
	pop		ParamReg
	pop		TempUa

	; If C and T are the same, parity was correct
	brcc	ISUCC
	brts	ISUParOk		;Ok if both C and T are set
ISUParityError:
	lds		ISRTempU,SUParityErrorCount
	inc		ISRTempU
	sts		SUParityErrorCount,ISRTempU
;	rjmp	ISURxErrorDiag
	rjmp	ISURxErrorReset
ISUCC:
	brts	ISUParityError	;Error if C clear but T is set
ISUParOk:

	; Save the received byte in the buffer
	; See if we already have a line needing processing
	tst		HaveComRxLine
	brze	ISURNoDouble	;No, we're ok
	
	; Yes, we have doubled up somehow
	lds		ISRTempU,SULineOverflowErrorCount
	inc		ISRTempU		;Count the error and then ignore it
	sts		SULineOverflowErrorCount,ISRTempU
ISURNoDouble:

	; See if the RX buffer is already full
	lds		xl,ComRxBufCnt
	cpi		xl,ComRxBufSiz-1	;Leave room for the CR
	brlo	ISUROk					;Ok if lower

	; If this is not a CR, we have a buffer overflow
	mov		ISRTempU,SURxByte	;Get the character received
	cpi		ISRTempU,CR+0x80	;Was it a CR (with the parity bit set)?
	breq	ISRHaveFinalCR

	; We have a buffer overflow
	lds		ISRTempU,SURxBufferOverflowErrorCount
	inc		ISRTempU
	sts		SURxBufferOverflowErrorCount,ISRTempU
	ldi		ISRTempU,CR			;Let's make it a CR now anyway
	mov		SURxByte,ISRTempU
ISRHaveFinalCR:
ISUROK:

	; Increment the count and save it (so we can use xl for something else)
	inc		xl
	sts		ComRxBufCnt,xl
	
	; Calculate where to store the character in the buffer
	;  (xl contains the incremented ComRxBufCnt)
	addi	xl,ComRxBuf-1	;Add the buffer offset (less 1 for the increment of the count)

	; Get the character and save it in the buffer
	mov		ISRTempU,SURxByte
	andi	ISRTempU,0x7F	;Reduce to 7-bits (Ignore parity now -- it was checked above)
	st		x,ISRTempU
	
	; If it was a CR, set the EOL flag
	cpi		ISRTempU,CR
	brne	ISURxDone		;No, we're done

	; It was a CR so set the EOL flag
	com		HaveComRxLine	;Was zero -- now FF

ISURxDone:
	inc		SURxStatus
ISURxStarted:
ISURxIdle:
	rjmp	ISURxEnd

; This code is down here to allow a relative branch to reach
ISUFramingError:	; We have a framing error
	lds		ISRTempU,SUFramingErrorCount
	inc		ISRTempU
	sts		SUFramingErrorCount,ISRTempU
;ISURxErrorDiag:		; Save some diagnostic values (temp) xxxxxxxxxx
;	lds		ISRTempU,ComRxBufCnt
;	sts		SUFEBC,ISRTempU
;	sts		SUFERx,SURxByte
ISURxErrorReset:	;Toss out the characters already in the buffer
	clr		HaveComRxLine				;Clear the flag
	sts		ComRxBufCnt,HaveComRxLine	; and zeroize the count
ISURxReset:
	ldi		SURxStatus,SURxIdle
	rjmp	ISURxIdle
ISURxEnd:

;*****************************************************************************

;	cpi		LEDFn,LEDIntTime	;Interrupt Time diagnostic?
;	brne	ISRLEDDone2			;Do nothing here if not
;	sbi		LEDPort,LEDPin		;Turn it off (high)
;ISRLEDDone2:

;*****************************************************************************

	RestoreSREGReti	;Restore SREG, return, and automatically reenable interrupts


;*****************************************************************************
;*****************************************************************************
;
;	Version Number Strings
;
;	(Placed earlyish in the code so they're easy to find)
;
;*****************************************************************************
;*****************************************************************************

UnusedString:	.DB		"eVsroi n"	;Version!
	.DB	MajorVersion+'0','.',MinorVersion+'0','.',RevisionNumber+'0','.',FixNumber+'0','.'

;StartString:	.DB		CR,LF					;Must be an even number of characters
;				.DB		"Robot IR V"
;	.DB	MajorVersion+'0','.',MinorVersion+'0','.',RevisionNumber+'0','.',FixNumber+'0',CR,LF,0
;PORString:	.DB	"Power-On",0
;ExRString:	.DB	"External",0
;WDRString:	.DB	"Watchdog",0
;RString2:	.DB	" Reset",CR,LF,0


;*****************************************************************************
;
;	Unused Interrupt Error
;
;	Not really a big problem but we should know about it during development
;
;*****************************************************************************

UnusedInterruptError:
	SaveSReg
	push	ParamReg
	ldi		ParamReg,UnusedInterruptErrorCode
	rcall	ProgramError	;Display the error code
	pop		ParamReg
	RestoreSRegReti			;Then re-enable interrupts and carry on with the program


;*****************************************************************************
;*****************************************************************************
;
;	Start of Program Proper
;
;*****************************************************************************
;*****************************************************************************

Reset:
	cli			;Disable interrupts

	; Get reset flags
	in		xl,MCUSR		;Read the MCU Status Register and save in xl
	clr		xh
	out		MCUSR,xh		;and then reset the Reset Flags

	; Disable watchdog
	ldi 	TempUa,(1 << WDTOE) | (1 << WDE)
	out 	WDTCR,TempUa			;Set WDTOE while WDE is on also
	ldi 	TempUa,(1 << WDTOE)
	out 	WDTCR,TempUa			;Leave WDTOE but clear WDE

	; Ensure that all interrupt masks are initially cleared
	clr 	TempUa
	out 	GIMSK,TempUa
	out 	TIMSK,TempUa

	; Set the stack pointer to the top of the internal RAM
	ldi 	TempUa,RAMEND
	out 	SPL,TempUa

	; Initialise the MCU Control Register to default zero
	;	(Disables sleep, sets INT0 and INT1 to low level detection)
	clr 	TempUa
	out 	MCUCR,TempUa
	


;*****************************************************************************
;
; Setup IO Ports
;
;*****************************************************************************

; Port-B is all three inputs and two outputs
; However, don't enable the Tx output (PB2) until it's required
	ldi 	TempUa,0b00001	;All PB4,3,2,1 set as inputs, 0 as output
	out 	DDRB,TempUa

; Flash the LED to say that we are alive
	ldi		yl,8
LEDLoop:
	; Toggle the LED output
	in		TempUa,LEDPort
	ldi		TempUb,1<<LEDPin
	eor		TempUa,TempUb
	out		LEDPort,TempUa

	ldiw	z,30000
LEDDelay:
	sbiw	zl,1
	brnz	LEDDelay

	dec		yl
	brnz	LEDLoop
	
	sbi		LEDPort,LEDPin	;Leave it sitting high (off)


;*****************************************************************************
;
;	Check for program errors
;
;*****************************************************************************

; DebugOnly -- check for programming errors
; Check that the flash isn't over allocated (since the assembler only gives a warning)
;	ldiw	z,NextFlashAddress
;	ldi		TempUa,high(FLASHEND+2)	;For comparison later (there's no cpic instruction)
;	cpi		zl,low(FLASHEND+2)
;	cpc		zh,TempUa
;	brlo	FlashAllocationOk
;	ldi		ParamReg,FlashAllocationErrorCode
;	rcall	ProgramError
;	; Continue operation even though we will have some problems
;FlashAllocationOk:


; Check that the EEPROM isn't over allocated
;	ldiw	z,NextEEPROMAddress
;	ldi		TempUa,high(E2END+2)	;For comparison later (there's no cpic instruction)
;	cpi		zl,low(E2END+2)
;	cpc		zh,TempUa
;	brlo	EEPROMAllocationOk
;	ldi		ParamReg,EEPROMAllocationErrorCode
;	rcall	ProgramError
;	; Continue operation even though we will have some problems
;EEPROMAllocationOk:


; Check the RAM is not over allocated (since the assembler doesn't seem to check it)
	ldiw	z,NextSRAMAddress
	ldi		TempUa,high(RAMEND+2)	;For comparison later (there's no cpic instruction)
	cpi		zl,low(RAMEND+2)
	cpc		zh,TempUa
	brlo	RAMAllocationOk

RAMAllocationError:
	ldi		ParamReg,RAMAllocationErrorCode
	rcall	ProgramError
	; Continue operation even though we will have some problems
RAMAllocationOk:


;*****************************************************************************
;
;	Initialize Registers used to hold Variables
;
;*****************************************************************************

; Zeroize all of the registers
	push	xl		;Save MCUSR info
	clr		r0
	clrw	z		;Start at address 0000
ZRLoop:
	st		z+,r0	;Zeroize the register
	cpi		zl,30	;Stop after clearing the first 30 of 32 registers
	brne	ZRLoop
	clr		zl		;zl has to be cleared by hand (zh is already zero)
	pop		xl		;Restore MCUSR info

; Initialize other registers that need to be something other than zero
;	ldi		SURxStatus,SWUARTTCReload	;Use upper SURxStatus register temporarily
;	mov		SWUARTTCReloadR,SURxStatus	; to load lower register with immediate value

	ldi		SURxStatus,SURxIdle
	ldi		SUTxStatus,SUTxIdle

	ldi		LEDFn,LEDNormal


;*****************************************************************************
;
;	Initialize RAM Variables
;
;*****************************************************************************

; Zeroize all of the RAM (including the stack but doesn't matter yet because no calls)
	ldi		zl,0x60			;The 128 bytes RAM go from 0060 to 00DF
	clr		r0
ClearRamLoop:
	st		z+,r0
	cpi		zl,low(RAMEND+1)
	brne	ClearRamLoop

	
; Initialize other variables that are something other than zero
	ldi		TempUa,RandomByteValue
	sts		StackCheck,TempUa


;*****************************************************************************
;
;	Load variables from EEPROM
;
;*****************************************************************************

	ldi		zl,EEReload
	rcall	ReadEEPROMByte			;Get value into R0
	mov		SWUARTTCReloadR,R0


;*****************************************************************************
;
;	Setup Timer/Counter
;
;*****************************************************************************

; Set Software UART Timer/Counter which runs at 9600Hz -- four times the baud rate
	ldi 	TempUa,SWUARTPS		; Set the clock PreScaler
	out		SWUARTTCCR,TempUa
	
	out		SWUARTTC,SWUARTTCReloadR

; Enable interrupts for the timer
	in  	TempUa,TIMSK		;Clear the interrupt mask (Set the bit)
	ori 	TempUa,(1<< SWUARTTCIE)
	out 	TIMSK,TempUa		;This stays cleared all the time
	
	
;*****************************************************************************
;
;	Determine why we reset from MCUSR info saved in xl
;
; Note: We must do this before interrupts are enabled because they use xl
;		SendSUChar (called by SendFString) enables interrupts
;
; Note:	If we disable this code, we must enable interrupts explicitly
;
;*****************************************************************************

;	mov		xh,xl			;Save a copy of the reset flags
;	ldsa	z,PORString
;	andi	xl,(1<<PORF)	;Get Power-On Reset Flag
;	brnz	SendResetInfo
;	ldsa	z,ExRString
;	andi	xh,(1<<EXTRF)	;Get EXTernal Reset Flag
;	brnz	SendResetInfo
;	ldsa	z,WDRString		;Must have been the watchdog
;SendResetInfo:
;	rcall	SendFString		;Send first part of string
;	ldsa	z,RString2
;	rcall	SendFString		;Send second part of string


;*****************************************************************************
;
;	Finished the setup routine
;
;*****************************************************************************

	; Enable the Watchdog now
	wdr									;Kick it first so resets to zero
	ldi 	TempUa,(1 << WDE) | WD2048	;Enable a 1.9s time out
	out 	WDTCR,TempUa

	sei				;Enable interrupts now
	;rjmp	Main

;*****************************************************************************
;*****************************************************************************
;
;	Main Program
;
;*****************************************************************************
;*****************************************************************************

Main:

; Enable IDLE sleep mode so that we can sleep later
	in		TempUa,MCUCR		;Read the other register bits
	andi	TempUa,0x0F			;Preserve lower four bits (Interrupt sense control bits)
	ori		TempUa,(1 << SE)	;Enable sleep mode IDLE (SM1/SM0 = 00)
	out		MCUCR,TempUa


;*****************************************************************************
;*****************************************************************************
;
;	Main Loop
;
;*****************************************************************************
;*****************************************************************************
;
MainLoop:	

; Check that the stack hasn't overflowed
	lds		TempUa,StackCheck
	cpi		TempUa,RandomByteValue
	breq	StackOk
	ldi		ParamReg,StackOverflowErrorCode
	rcall	NonFatalProgramError	;Send the error code on the comms
									; and then enable interrupts, return, and try running again
	ldi		TempUa,RandomByteValue
	sts		StackCheck,TempUa		;Reset the stack check variable
StackOk:


;*****************************************************************************

;	Diagnostic test (temp) xxxxxxxxxxx
;	lds		TempUa,SUFramingErrorCount
;	tst		TempUa
;	brze	NoFEs
	; Have some framing errors
;	clr		TempUa			;Reset the count
;	sts		SUFRamingErrorCount,TempUa
;	cli						;Disable interrupts temporarily so sure to get matching pair of values
;	lds		zl,SUFEBC		;Put in zl, zh
;	lds		zh,SUFERx		; (because not affected by SendSUChar)
;	sei						;Enable interrupts again now
;	ldi		ParamReg,'F'
;	rcall	SendSUChar
;	ldi		ParamReg,'E'
;	rcall	SendSUChar
;	ldi		ParamReg,'0'
;	add		ParamReg,zl		;BC converted to ASCII
;	rcall	SendSUChar
;	mov		ParamReg,zh		;Get the character
;	swap	ParamReg			;Swap nibbles
;	andi	ParamReg,0x0F		;Get the four bits
;	addi	ParamReg,'0'		;ASCIIize it by adding '0'
;	cpi		ParamReg,':'		;Colon is one past '9'
;	brlo	FESB1OK				;Ok if it's a valid digit
;	addi	ParamReg,'a'-':'	;Convert to a-f
;FESB1OK:
;	rcall	SendSUChar
;	mov		ParamReg,zh			;Get the character again
;	andi	ParamReg,0x0F		;Get the four LS bits
;	addi	ParamReg,'0'		;ASCIIize it by adding '0'
;	cpi		ParamReg,':'		;Colon is one past '9'
;	brlo	FESB2OK				;Ok if it's a valid digit
;	addi	ParamReg,'a'-':'	;Convert to a-f
;FESB2OK:
;	rcall	SendSUChar
;	ldi		ParamReg,CR
;	rcall	SendSUChar
;NoFEs:

;	Diagnostic test (temp) xxxxxxxxxxx
;	lds		TempUa,SUParityErrorCount
;	tst		TempUa
;	brze	NoPEs
	; Have some parity errors
;	clr		TempUa			;Reset the count
;	sts		SUParityErrorCount,TempUa
;	cli						;Disable interrupts temporarily so sure to get matching pair of values
;	lds		zl,SUFEBC		;Put in zl, zh
;	lds		zh,SUFERx		; (because not affected by SendSUChar)
;	sei						;Enable interrupts again now
;	ldi		ParamReg,'P'
;	rcall	SendSUChar
;	ldi		ParamReg,'E'
;	rcall	SendSUChar
;	ldi		ParamReg,'0'
;	add		ParamReg,zl		;BC converted to ASCII
;	rcall	SendSUChar
;	mov		ParamReg,zh		;Get the character
;	swap	ParamReg			;Swap nibbles
;	andi	ParamReg,0x0F		;Get the four bits
;	addi	ParamReg,'0'		;ASCIIize it by adding '0'
;	cpi		ParamReg,':'		;Colon is one past '9'
;	brlo	PESB1OK				;Ok if it's a valid digit
;	addi	ParamReg,'a'-':'	;Convert to a-f
;PESB1OK:
;	rcall	SendSUChar
;	mov		ParamReg,zh			;Get the character again
;	andi	ParamReg,0x0F		;Get the four LS bits
;	addi	ParamReg,'0'		;ASCIIize it by adding '0'
;	cpi		ParamReg,':'		;Colon is one past '9'
;	brlo	PESB2OK				;Ok if it's a valid digit
;	addi	ParamReg,'a'-':'	;Convert to a-f
;PESB2OK:
;	rcall	SendSUChar
;	ldi		ParamReg,CR
;	rcall	SendSUChar
;NoPEs:

;*****************************************************************************

	tst		IRRearStatus
	brnz	CheckRear
	rcall	CheckFrontIR	;Only check front IR if rear is idle

	tst		IRFrontStatus
	brnz	DontCheckRear
CheckRear:
	rcall	CheckRearIR		;Only check rear IR if front is idle
DontCheckRear:

;*****************************************************************************


; Set LED indicator
;	cpi		LEDFn,LEDBaudDiag	;Baud rate diagnostic?
;	breq	LEDDone				;Yes, do nothing here
;	cpi		LEDFn,LEDIntTime	;Interrupt Time diagnostic?
;	breq	LEDDone				;Yes, do nothing here
	cpi		LEDFn,LEDOff
	breq	DoLEDOff		;Always off
	cpi		LEDFn,LEDOn
	breq	DoLEDOn			;Always on

	ldi		TempUa,30		;30 * 27ms = 800ms
	cpi		LEDFn,LEDSlowFlash
	breq	DoLEDFlash
	ldi		TempUa,10		;10 * 27ms = 270ms
	cpi		LEDFn,LEDFastFlash
	breq	DoLEDFlash
		
	mov		TempUa,IRFrontStatus
	or		TempUa,IRRearStatus
	brze	BothIdle
	
; One must be in action
	cpi		LEDFn,LEDInverse
	breq	DoLEDOff
	rjmp	DoLEDOn			;Assume it's normal then
	
BothIdle:
	cpi		LEDFn,LEDInverse
	breq	DoLEDOn
	rjmp	DoLEDOff		;Assume it's normal then

DoLEDFlash:	;TempUa has compare count
	mov		TempUb,SysTickH
	sub		TempUb,LEDTime	;Get number of SysTick increments since last change
	cp		TempUb,TempUa	;Is it time yet?
	brlo	LEDDone			;No change if still less
	mov		LEDTime,SysTickH ;Remember change time
;DoLEDInvert:
	in		TempUa,LEDPort
	ldi		TempUb,1<<LEDPin
	eor		TempUa,TempUb
	out		LEDPort,TempUa
	rjmp	LEDDone
DoLEDOn:
	cbi		LEDPort,LEDPin	;Turn it on (low)
	rjmp	LEDDone
DoLEDOff:
	sbi		LEDPort,LEDPin	;Turn it off (high)
LEDDone:


;*****************************************************************************

	rcall	CheckRx

;*****************************************************************************
;
; Enter sleep mode (as defined above in Main) until an interrupt occurs
;	Idle mode uses 1.9mA instead of 6.4mA on 8535 at 4MHz, 3V
;	Restart after IDLE is immediate
;
;*****************************************************************************

	wdr							;Kick the watchdog before we sleep

; Go to IDLE sleep until something else happens
	sleep

; We've woken up again after an interrupt
	rjmp	MainLoop


;*****************************************************************************
;
;	Strings
;
;*****************************************************************************

;SUFramingErrorString:			.DB		" Framing Err ",0
;SUParityErrorString:			.DB		" Parity Err ",0
;SURxBufferOverflowErrorString:	.DB		" Rx Buff Ovrflw ",0
;SULineOverflowErrorString:		.DB		" Line Ovrflw ",0


;*****************************************************************************
;*****************************************************************************
;
;	General Subroutines
;
;*****************************************************************************
;*****************************************************************************
;
;*****************************************************************************
;
;	ReadEEPROMByte		Read a byte from the EEPROM
;
; Expects:	zl = EEPROM address
;
; Waits in case a previous write operation is still in progress
;
; Returns:	R0 = value
;
; Doesn't change any other registers
;
;*****************************************************************************
;
ReadEEPROMByte:
	bris	EECR,EEWE,ReadEEPROMByte	;Loop if a write operation is still in progress

	out		EEARL,zl		;Output the 7-bit address

	sbi		EECR,EERE		;Do the read command (will halt CPU for 4 cycles)
	in		R0,EEDR			;Get the EEPROM value
	ret


;*****************************************************************************
;
;	WriteEEPROMByte		Writes a byte to the EEPROM
;
; Expects:	zl = EEPROM address
;			ParamReg = byte to write
;
; Waits in case a previous write operation is still in progress
;
; Doesn't change any registers
; Leaves interrupts enabled
;
;*****************************************************************************
;
WriteEEPROMByte:
	bris	EECR,EEWE,WriteEEPROMByte	;Loop if a write operation is still in progress

	out		EEDR,ParamReg	;Output the value

	out		EEARL,zl		;Output the 7-bit address

	cli						;Disable interrupts temporarily
	sbi		EECR,EEMWE		;Do the write enable command
	sbi		EECR,EEWE		;Do the write command (will halt CPU for 2 cycles)
	reti					;Reenable interrupts and then return


;*****************************************************************************
;
;	GetEvenParity		Calculates even parity
;
;	Expects:	ParamReg = 7-bit character to check
;
;	Changes:	TempUa to zero
;
;	Returns:	Even parity in T
;
;*****************************************************************************

GetEvenParity:
	ldi		TempUa,7	;Number of bits to check
	clt					;T-flag will hold parity
GP_Next:
	; Rotate off each bit starting with the LS bit and toggle parity if it is set.
	ror		ParamReg	;Get the next LS bit into carry
	brcc	GP_NoC		;If carry is clear, no change to parity bit

	; Carry is set so toggle parity bit in T
	brtc	GP_Set
	clt
	rjmp	GP_Clear
GP_Set:
	set
GP_Clear:

	; See if we have done all seven bits yet
GP_NoC:
	dec		TempUa
	brnz	GP_Next
	
	; Parity is in T-flag
	ror		ParamReg	;Restore ParamReg
	ror		ParamReg
	ret					;from GetEvenParity


;*****************************************************************************
;
;	ConvertUByte		Converts a unsigned byte to ASCII digits
;							and outputs it
;
; Expects:	T = 0 for zero suppression, non-zero for no zero suppression
;			ZL = byte to be converted
;
;*****************************************************************************
;
ConvertUByte:
	clr		zh
	;Fall through to ConvertUWord below
	
;*****************************************************************************
;
;	ConvertUWord		Converts an unsigned word to ASCII digits
;							and outputs it
;
; Expects:	T = 0 for zero suppression, non-zero for no zero suppression
;			Z = word to be converted
;
; Uses:		TempLa, TempLb, TempLc, TempLd, TempUa, Tempb, TempUc, y, t
;
;*****************************************************************************
;
ConvertUWord:
	;Point y to the start of the string storage area
	ldi		yl,ConvString
ConvertUWord1:	
	clr		TempLa
	clr		TempLb
	clr		TempLc
	clr		TempLd
	
	;Divide by 10,000 first
	ldi		TempUa,low(10000)
	ldi		TempUb,high(10000)
	rcall	CWCount

	;Divide by 1,000 next
	ldi		TempUa,low(1000)
	ldi		TempUb,high(1000)
	rcall	CWCount

	;Divide by 100 next
	ldi		TempUa,100
	clr		TempUb		;high(100) = 0
	rcall	CWCount

	;Divide by 10 next
	ldi		TempUa,10		;TempUb is still zero
	rcall	CWCount
	
	; The residual should be 0-9, convert to ASCII
	addi	zl,'0'		;Convert the last digit to ASCII
	st		y+,zl		;Append to string
ConvertFinish:
	st		y,TempUb	;Append the final null
	
	; Point z to ConvString
	ldi		zl,ConvString
	rjmp	SendSString	;Send string and then return


;*****************************************************************************
;
;	CWCount		Local routine used only by above Convert routines
;
;	Expects:	TempUa, TempUb is divisor
;				TempLa, TempLb, TempLc, TempLd
;				
;	Uses:	TempUc, y, t
;
;*****************************************************************************
;
CWCount:
	ldi		TempUc,'0'		;Initialize count to ASCII '0'
CWCountLoop:
	cp		zl,TempUa
	cpc		zh,TempUb
	cpc		TempLa,TempLc
	cpc		TempLb,TempLd
	brlo	CWDigit		;Yes, we are done
	sub		zl,TempUa		;No, ok to subtract it then
	sbc		zh,TempUb
	sbc		TempLa,TempLc
	sbc		TempLb,TempLd
	inc		TempUc			;Increment the ASCII digit
	brne	CWCountLoop	;Keep doing this until an underflow would occur
CWDigit:
	brts	CWPrintAll	;Must keep zeroes
	cpi		TempUc,'0'
	breq	CWSkipZero
	set					;Have a non-zero digit so must keep all following zeroes
CWPrintAll:
	;Need to add the character in TempUc to the string
	st		y+,TempUc
CWSkipZero:
	ret


;*****************************************************************************
;
;	ConvertHByte		Converts a hex byte to two ASCII digits
;							and outputs it
;
; Expects:	ZL = byte to be converted
;
; StoreHexByte uses TempUa and TempUc, updates y
;
;*****************************************************************************
;
ConvertHByte:
	ldi		yl,ConvString	;Point y to the start of the string storage area
	mov		TempUa,zl
	rcall	StoreHexByte
	clr		TempUb
	rjmp	ConvertFinish


;*****************************************************************************
;
;	ConvertHWord		Converts a hex word to four ASCII digits
;							and outputs it
;
; Expects:	ZL = byte to be converted
;			StringOut = destination
;
; StoreHexByte uses TempUa and TempUc, updates y
;
;*****************************************************************************
;
ConvertHWord:
	ldi		yl,ConvString	;Point y to the start of the string storage area
	mov		TempUa,zh
	rcall	StoreHexByte
	mov		TempUa,zl
	rcall	StoreHexByte
	clr		TempUb
	rjmp	ConvertFinish


;*****************************************************************************
;
;	ProcessFirstDigit		Check the first character of a digit string
;
; Expects:	ParamReg = ASCII hex digit (0-9, or A-F or a-f)
;
; Returns with: yl set to value
;				C = 0 for ok, 1 for error
;
;*****************************************************************************
;
ProcessFirstDigit:
; See if it's a valid hexadecimal digit (digit, A-F, a-f)
	cpi		ParamReg,'0' 	;If it's less than an ASCII zero it's always invalid
	brlo	PDError
	subi	ParamReg,'0' 	;De-ASCII it
	cpi		ParamReg,9+1
	brlo	PFDHexOk		;Branch if it was a valid digit
	cpi		ParamReg,'A'-'0'
	brlo	PDError
	subi	ParamReg,'A'-':'
	cpi		ParamReg,15+1
	brlo	PFDHexOk		;Branch if it was A-F
	subi	ParamReg,'a'-'A'
	cpi		ParamReg,15+1
	brsh	PDError

PFDHexOk:
; The number in ParamReg should be from 0-15
	mov		yl,ParamReg	;Remember it
	clc					;C = 0 for no error
	ret					;Done

PDError:
	sec					;C = 1 indicates error
	ret


;*****************************************************************************
;
;	ProcessNextDigit		Check the next character of a digit string
;
; Expects:	ParamReg = ASCII hex digit (0-9, or A-F)
;			yl = Total so far
;
; Uses:		TempLc, TempLd
;
; Returns with: yl = Accumulated total
;				C = 0 for ok, 1 for error
;
;*****************************************************************************
;
ProcessNextDigit:
; See if it's a valid hexadecimal digit (digit, A-F, a-f)
	cpi		ParamReg,'0' ;If it's less than an ASCII zero it's always invalid
	brlo	PDError
	subi	ParamReg,'0' 	;De-ASCII it
	cpi		ParamReg,9+1
	brlo	PNDHexOk		;Branch if it was a valid digit
	cpi		ParamReg,'A'-'0'
	brlo	PDError
	subi	ParamReg,'A'-':'
	cpi		ParamReg,15+1
	brlo	PNDHexOk		;Branch if it was A-F
	subi	ParamReg,'a'-'A'
	cpi		ParamReg,15+1
	brsh	PDError

; The number in ParamReg should be from 0-15
PNDHexOk:
; Multiply total value by 16 (ignoring overflow) and add new digit value
	lsl		yl			; * 2
	lsl		yl			; * 2 again = * 4
	lsl		yl			; * 2 again = * 8
	lsl		yl			; * 2 again = * 16
	add		yl,ParamReg	;Add in this new digit
;	clc					;C = 0 for no error
	ret					;Done (Carry should be clear from the add)


;*****************************************************************************
;
;	FormCommsHeader		Starts to form a message to the controller in ConvString
;
; Expects:	ParamReg = First character of message
;
; Uses:		TempUb
;
; Returns:	y pointing to next character position in the buffer
;			z pointing to start of buffer
;
;*****************************************************************************
;
FormCommsHeader:
	;Point y to the start of the string storage area
	ldi		yl,ConvString
	mov		zl,yl			;Keep a copy of the buffer address in z
	mov		zh,yh
	ldi		TempUb,'I'
	st		y+,TempUb
	st		y+,ParamReg
	ret


;*****************************************************************************
;
;	SendDebugMessage		Sends a debug message
;
;*****************************************************************************
;
;SendDebugMessage:
;	ldi		ParamReg,'D'
;	rcall	FormCommsHeader	;Returns with buffer address in y
;	pushw	z
;	ldiw	z,IRFrontBytes
;	ld		TempUa,z+
;	rcall	StoreHexByte
;	ld		TempUa,z+
;	rcall	StoreHexByte
;	ld		TempUa,z+
;	rcall	StoreHexByte
;	ld		TempUa,z
;	rcall	StoreHexByte
;	popw	z
;	mov		TempUa,IRFrontByte
;	rjmp	StoreHexByteThenSend


;*****************************************************************************
;
;	SendOverflowMessage		Sends an overflow message
;
;*****************************************************************************
;
;SendOverflowMessage:
;	ldi		ParamReg,'O'
;	rcall	FormCommsHeader	;Returns with buffer address in y
;	mov		TempUa,IRFrontByte
;	rjmp	StoreHexByteThenSend


;*****************************************************************************
;
;	SendFrontMessage		Sends a "Front" message
;
;*****************************************************************************
;
SendFrontMessage:
	ldi		ParamReg,'F'
	rcall	FormCommsHeader	;Returns with buffer address in y
	mov		TempUa,IRFrontByte
	rjmp	DecThenSend


;*****************************************************************************
;
;	SendRearMessage		Sends a "Rear" message
;
;*****************************************************************************
;
SendRearMessage:
	ldi		ParamReg,'R'
	rcall	FormCommsHeader	;Returns with buffer address in y
	mov		TempUa,IRRearByte
DecThenSend:
	cpi		TempUa,IRRepeatCode
	breq	StoreHexByteThenSend	;Don't decrement repeat code
	cpi		TempUa,IRErrorCode
	breq	StoreHexByteThenSend	;Don't decrement error code
	dec		TempUa
	rjmp	StoreHexByteThenSend	;But decrement all others (because previously incremented)


;*****************************************************************************
;
;	SendVersionMessage		Sends a version number message
;
;*****************************************************************************
;
SendVersionMessage:
	ldi		ParamReg,'V'
	rcall	FormCommsHeader	;Returns with buffer address in y
	ldi		TempUa,'0'
	st		y+,TempUa
	ldi		TempUa,MajorVersion+'0'
	st		y+,TempUa
	ldi		TempUa,MinorVersion+'0'
	st		y+,TempUa
	ldi		TempUa,RevisionNumber+'0'
	st		y+,TempUa
	ldi		TempUa,FixNumber+'0'
	st		y+,TempUa
	ldi		TempUa,'0'
	;rjmp	StoreCharThenSend

;*****************************************************************************
;
;	StoreCharThenSend	Stores the character and then sends the message
;
; Expects:	TempUa = character
;			y = buffer pointer
;
;*****************************************************************************
;
StoreCharThenSend:
	st		y+,TempUa
	rjmp	SendControlMessage


;*****************************************************************************
;
;	SendErrorMessage		Sends a error message
;
; Expects:	TempUa = Error character
;			ParamReg = Error count
;
;*****************************************************************************
;
SendErrorMessage:
	push	ParamReg
	ldi		ParamReg,'E'
	rcall	FormCommsHeader	;Returns with buffer address in y
	rcall	StoreHexByte	;Store the error character from TempUa
	clr		TempUa
	rcall	StoreHexByte	;Store a zero MS byte first
	pop		TempUa			;Pop the error count (from ParamReg) into TempUa
	;rjmp	StoreHexByteThenSend

;*****************************************************************************
;
;	StoreHexByteThenSend
;
;	Expects:	TempUa = Byte to store
;				y points to buffer
;
;*****************************************************************************
;
StoreHexByteThenSend:
	rcall	StoreHexByte
	;rjmp	SendControlMessage

;*****************************************************************************
;
;	SendControlMessage
;
;	Expects:	y points to place to put CR and null in buffer
;				z points to beginning of buffer
;
;	Uses:		TempUa, TempUc, y, z
;
;*****************************************************************************
;
SendControlMessage:
	ldi		TempUa,CR		;Append a trailing CR
	st		y+,TempUa
	clr		TempUa			;Append a trailing NULL
	st		y,TempUa
	;rjmp	SendSString		;Send the string and return

;*****************************************************************************
;
;	SendSString	Sends a null-terminated string from the STATIC RAM to the selected buffer
;
; Expects:	SRAM string pointer in Z
;
; Uses:		ParamReg, y, z, TempUa, TempUc
;
; Returns:	ParamReg = 0
;
;*****************************************************************************
;
SendSString:
	ld		ParamReg,z+		;Get byte pointed to by Z and then increment Z
	tst		ParamReg			;See if it's a null
	brze	Return2
	rcall	SendSUChar	;Send (buffer) the character in ParamReg
	rjmp	SendSString


;*****************************************************************************
;
;	StoreHexByte
;
;	Expects:	TempUa = byte to store
;				y points to buffer
;
;	Stores the byte as two hex digits
;	Saves the character(s) and increments the pointer (y)
;
;	Uses:	TempUa, TempUc
;			Increments y by 2
;
;*****************************************************************************
;
StoreHexByte:
	mov		TempUc,TempUa	;Copy the character
	swap	TempUc			;Swap nibbles
	andi	TempUc,0x0F		;Get the four bits
	addi	TempUc,'0'		;ASCIIize it by adding '0'
	cpi		TempUc,':'		;Colon is one past '9'
	brlo	SB1OK			;Ok if it's a valid digit
	addi	TempUc,'a'-':'	;Convert to a-f
SB1OK:
	st		y+,TempUc
	
	andi	TempUa,0x0F		;Get the four LS bits
	addi	TempUa,'0'		;ASCIIize it by adding '0'
	cpi		TempUa,':'		;Colon is one past '9'
	brlo	SB2OK			;Ok if it's a valid digit
	addi	TempUa,'a'-':'	;Convert to a-f
SB2OK:
	st		y+,TempUa
Return2:
	ret


;*****************************************************************************
;
;	SendSUChar	Calculates even parity and then sends
;					a character to the Software UART TX buffer
;				The interrupt routine then outputs the buffer automatically
;
; Expects:	(ASCII) Character in ParamReg
;
; Uses:	y, TempUa
;
; Must not change z, TempUc
;
;*****************************************************************************
;
SendSUChar:
	; Set the parity bit
	rcall	GetEvenParity	;Gets the result in T
	bld		ParamReg,7		;Set the parity into bit-7

	clrw	y		;Use y for a counter when the buffer is full

SendSUCharLoop:
	cli		; Disable interrupts temporarily
			;	so the SU interrupt can't change buffer control variables

	; See if there's room in the buffer
SSUCTxBusy:
	lds		TempUa,ComTxBufCnt
	cpi		TempUa,ComTxBufSiz
	brsh	SSUCBufferFull
	
	; Add the start offset and the length together
	lds		yl,ComTxBufO1	;Get the offset to the first character
	add		yl,TempUa	;Add the TxBufCnt (Note: Total must not exceed 256)
	
	; Now yl is sort of the the offset of the first empty space
	; We have to adjust it though, if it's past the end of the (circular) buffer
	cpi		yl,ComTxBufSiz
	brlo	SSUCBNFOk			;Ok if the calculated offset is already inside the buffer
	subi	yl,ComTxBufSiz		;Otherwise, adjust it down
SSUCBNFOk:
	
	; Now yl is the adjusted offset of the first empty space
	addi	yl,ComTxBuf			;Add the actual buffer address
	
	; Now yl is the address of the first empty space in the buffer
	st		y,ParamReg
	inc		TempUa			;Increment and save the count
	sts		ComTxBufCnt,TempUa

SSUCDone:	
	reti					;Enable interrupts and return

SSUCBufferFull:
	; If we get here the buffer must be full
	sei						;Enable interrupts again so transmitter can keep sending
	adiw	yl,1			;Increment the loop counter
	; Note: At 1,200bps, the UART should send a character about every 8.3 milliseconds
	; This buffer full loop has 8 instructions (10 cycles) and takes about 10 microseconds at 1MHz
	;  so y shouldn't count to more than about 830 before there's room for the next character
	cpi		yh,5			;Has y got to 5 * 256 = 1280?
	brlo	SendSUCharLoop	;No, keep waiting
	; What should we do here???
	ldi		ParamReg,SUBufferFullErrorCode
	;rjmp	NonFatalProgramError	;Display the error code on the LEDs
									; and then enable interrupts, return, and try running again

;*****************************************************************************
;
;	NonFatalProgramError	For non-fatal programming errors
;							(Not for expected operational errors)
;
;	Disables interrupts and then flashes all the LEDs five times
;	Then displays error code for a while before re-enabling interrupts and returning
;
;	Expects:	ParamReg = Error code
;
;	Changes no registers
;
;*****************************************************************************
;
NonFatalProgramError:
	rcall	ProgramError;Disable interrupts and then display the error code on the LEDs
	reti				;Re-enable interrupts again now and try to continue running the program


;*****************************************************************************
;
;	SendFString	Sends a null-terminated string from the FLASH to the selected buffer
;
; Expects:	z = Flash string pointer
;
; Uses:		R0, y, z, TempUa, TempUc, ParamReg
;
; Returns:	R0 = 0
;
;*****************************************************************************
;
SendFString:
	lpm					;Get byte pointed to by Z into R0
	tst		r0			;See if it's a null
	brnz	SFS2
	ret

SFS2:
	mov		ParamReg,r0	;Save byte ready to output
	adiw	zl,1		;Increment the 16-bit buffer pointer for next time

	rcall	SendSUChar	;Send (buffer) the character in ParamReg
	rjmp	SendFString


;*****************************************************************************
;
;	CheckIR
;
; Checks the front and rear IR inputs and decodes them
;
;	This code is for a SPACE coded (REC-80) IR control,
;		i.e., the width of the space determines the data bit
;
;	RC 669 32-bits Space-coded with header
;	+------------+      +--+  +--+    +--+    +--+  +--+
;	|            |      |  |  |  |    |  |    |  |  |  |
;	+            +------+  +--+  +----+  +----+  +--+  +--
;	      Header             0      1       1      0
;
; Header pulse = 9000usec
; Header space = 4500usec
; Pulse = 600usec
; 0 Space = 530usec
; 1 Space = 1600usec
; Has trailing pulse after last bit
; Always has 16 0-bits and 16 1-bits because
;  the second byte is the complement of the first byte and
;  the fourth byte is the complement of the third byte
;
; 	 31H=56   C7H=199
;	00011100 11100011 0-86 Complement-of-third-byte
;
; Repeat code
; Header pulse = 8800usec
; Header space = 2350usec
; Repeat pulse = 600usec
; Sent every 100msec
;
;*****************************************************************************
;
; SysTickL increments every 104usec so these are our timeouts
;
.EQU	IRHeaderPulseCount			= 76	;Must be at least 7.9 msec
.EQU	IRHeaderSpaceCount			= 38	;Must be at least 4.0 msec
.EQU	IRMinHeaderSpaceCount		= 18	;Must be at least 1.9 msec
.EQU	IRPulseCount				= 4		;Must be at least 417 usec
.EQU	IRSpaceCount				= 10	;0 < 1.0 msec, 1 > 1.0 msec
.EQU	IRRepeatHeaderSpaceCount	= 29	;Must be < 3.1 usec
.EQU	IRTimeoutCount				= 96	;10 msec
;
;
; SysTickL increments every 208usec so these are our timeouts
;
;.EQU	IRHeaderPulseCount			= 38	;Must be at least 7.9 msec
;.EQU	IRHeaderSpaceCount			= 19	;Must be at least 4.0 msec
;.EQU	IRMinHeaderSpaceCount		= 9		;Must be at least 1.9 msec
;.EQU	IRPulseCount				= 2		;Must be at least 417 usec
;.EQU	IRSpaceCount				= 5		;0 < 1.0 msec, 1 > 1.0 msec
;.EQU	IRRepeatHeaderSpaceCount	= 15	;Must be < 3.1 usec
;.EQU	IRTimeoutCount				= 48	;10 msec
;
;*****************************************************************************
;
CheckFrontIR:

	; Check for a change of state
	in		TempUa,IRInput
	andi	TempUa,(1<<IRFrontBit)
	lds		TempUb,IRFrontState
	cp		TempUa,TempUb
	brne	IRFHaveStateChange
	
	; We don't have a change of state but check for timeouts
	tst		IRFrontStatus
	brnz	IRFNotIdle
	ret						;Return if we're idle

IRFNotIdle:
	; We're not idle
	lds		TempUc,IRFrontTime
	mov		TempUb,SysTickL
	sub		TempUb,TempUc
	cpi		TempUb,IRTimeoutCount
	brlo	PC+2			;Return if haven't reached timeout count yet
	clr		IRFrontStatus	;Return to idle if timed out
	ret

;*****************************************************************************

IRFHaveStateChange:
	; TempUa contains the new state (remember that it's inverted)
	sts		IRFrontState,TempUa	;Save new state
	
	; Find out how long since last change, i.e., length of bit just received
	lds		TempUc,IRFrontTime
	mov		TempUb,SysTickL
	sub		TempUb,TempUc			;Get TempUb = CurrentTime - LastTime
	sts		IRFrontTime,SysTickL	;Update LastTime

	; TempUa contains the new state, TempUb contains length of last bit
	mov		TempUc,IRFrontStatus
	tst		TempUc
	brnz	IRFHSCNotIdle

	; We're idle -- look for the start of a possible header pulse
	; The signal is inverted so we need a low level to start
	tst		TempUa				;What is the new level?
	brnz	PC+2				;Wrong, just return
	inc		IRFrontStatus		;Right, advance status
	ret							; and return

;*****************************************************************************

IRFHSCNotIdle:
	; TempUa contains new state, TempUb is length of last bit, TempUc is status
	; Check for a pulse that's too short
	cpi		TempUb,IRPulseCount			;Every transition should be at least this long
	brsh	IRFHSCLongEnough			;Yes, branch if long enough
IRFResetStatus:
	clr		IRFrontStatus				;No, reset status
	ret
	
;*****************************************************************************

IRFHSCLongEnough:
	; We know that the pulse is at least the minimum length long
	; TempUa contains new state, TempUb is length of last bit, TempUc is status
	cpi		TempUc,GettingHeaderPulse
	brne	IRFHSC1
	; Clear the four byte buffer first
	ldi		zl,IRFrontBytes
	clr		TempUa
	st		z+,TempUa
	st		z+,TempUa
	st		z+,TempUa
	st		z,TempUa
	; We're should have the end of a long header pulse
	cpi		TempUb,IRHeaderPulseCount	;Must be at least this long
	brsh	IRFIncStatus				;Yes, branch
	clr		IRFrontStatus				;No, reset status
	ret
	
;*****************************************************************************

IRFHSC1:
	; TempUa contains new state, TempUb is length of last bit, TempUc is status
	cpi		TempUc,GettingHeaderSpace
	brne	IRFHSC2
	; We're should have the end of a normal header space or a repeat header space
	cpi		TempUb,IRMinHeaderSpaceCount	;Must be at least this long
	brlo	IRFResetStatus
	; Yes, it's longer than a standard space
	inc		IRFrontStatus				;Increment by default
	cpi		TempUb,IRHeaderSpaceCount	;Must be at least this long
	brsh	IRFIncStatus				;Yes, branch (increments twice)
	cpi		TempUb,IRRepeatHeaderSpaceCount ;Repeat must be shorter than this
	brsh	IRFResetStatus				;No, reset
	ret									;Yes, already incremented once

;*****************************************************************************

	; TempUa contains new state, TempUb is length of last bit, TempUc is status
IRFHSC2:
	cpi		TempUc,GettingRepeatPulse
	brne	IRFHSC3
	; Got a valid repeat code
	tst		IRFrontByte					;See if we already have something in the buffer
	brnz	IRFIgnoreRepeat				;Yes, ignore the repeat
	ldi		TempUa,IRRepeatCode			;No, do the repeat
	mov		IRFrontByte,TempUa
IRFIgnoreRepeat:
	clr		IRFrontStatus				;Finished
	ret

;*****************************************************************************

IRFHSC3:
	; TempUa contains new state, TempUb is length of last bit, TempUc is status
	cpi		TempUc,GettingLastPulse
	brne	IRFHSC4
	; Got a full code now -- process it
	ldi		zl,IRFrontBytes
	ld		TempUa,z+			;Get first byte
	cpi		TempUa,IRByte1		;Should always be this fixed value
	breq	IRFHSC3a				;Branch if ok
IRFHaveError:
	ldi		TempUa,IRErrorCode
	rjmp	IRFSave

IRFHSC3a:
	ld		TempUa,z+			;Get second byte
	cpi		TempUa,IRByte2		;Should always be this fixed value
	brne	IRFHaveError		;Branch if error
	ld		TempUa,z+			;Get third byte
	ld		TempUb,z			;Get fourth byte
	com		TempUb				;Complement it
	cp		TempUa,TempUb		;The third and fourth bytes should be the complement of each other
	brne	IRFHaveError			;Error if different
	
	; We have a valid keypress
	tst		IRFrontByte			;See if something already buffered
	brnz	IRFOverflow			;Yes, branch
IRFAccept:
	inc		TempUa				;All ok, increment value (from third byte) so cannot be zero
IRFSave:
	mov		IRFrontByte,TempUa
	clr		IRFrontStatus
	ret

IRFOverflow:
	; If the overflow is just a repeat code, overwrite it
	mov		TempUb,IRFrontByte
	cpi		TempUb,IRRepeatCode
	breq	IRFAccept
	; If the overflow is an error code, overwrite it
	cpi		TempUb,IRErrorCode
	breq	IRFAccept
	rjmp	IRFHaveError

;*****************************************************************************

IRFHSC4:
	; Must be getting one of the data bits (pulse or space)
	; TempUa contains new state, TempUb is length of last bit, TempUc is status
	andi	TempUc,1			;See if status is even or odd
	brnz	IRFHSC5				;Branch if odd -- expecting variable length space
	; Must be getting expecting a short pulse
	cpi		TempUb,IRSpaceCount	;It should be shorter than this
	brsh	IRFHaveError
IRFIncStatus:
	inc		IRFrontStatus
	ret

;*****************************************************************************

IRFHSC5:
	; Must be getting a space -- variable length data bit
	; TempUa contains new state, TempUb is length of last bit, TempUc is status
	clt							;Set T = 0
	cpi		TempUb,IRSpaceCount	;0 if shorter, 1 if longer
	brlo	PC+2				;Set T according to result
	set							;Set T = 1
	; Add bit in T to 32-bit buffer, LS-bit first, MS-byte first
	; i.e., move the bits in the bytes right to left
	;		and from the last byte to the first byte
	ldi		zl,IRFrontBytes+3
	ld		TempUa,z
	ror		TempUa				;Rotate right (Shifts C into MS bit)
	bld		TempUa,7			;Set MS bit according to T
	st		z,TempUa			;Save shifted byte
	ld		TempUa,-z
	ror		TempUa				;Shift carry into third byte
	st		z,TempUa
	ld		TempUa,-z
	ror		TempUa				;Shift carry into second byte
	st		z,TempUa
	ld		TempUa,-z
	ror		TempUa				;Shift carry into first byte
	st		z,TempUa
	inc		IRFrontStatus
	ret

;*****************************************************************************
;*****************************************************************************

CheckRearIR:

	; Check for a change of state
	in		TempUa,IRInput
	andi	TempUa,(1<<IRRearBit)
	lds		TempUb,IRRearState
	cp		TempUa,TempUb
	brne	IRRHaveStateChange
	
	; We don't have a change of state but check for timeouts
	tst		IRRearStatus
	brnz	IRRNotIdle
	ret						;Return if we're idle

IRRNotIdle:
	; We're not idle
	lds		TempUc,IRRearTime
	mov		TempUb,SysTickL
	sub		TempUb,TempUc
	cpi		TempUb,IRTimeoutCount
	brlo	PC+2			;Return if haven't reached timeout count yet
	clr		IRRearStatus	;Return to idle if timed out
	ret

;*****************************************************************************

IRRHaveStateChange:
	; TempUa contains the new state (remember that it's inverted)
	sts		IRRearState,TempUa	;Save new state
	
	; Find out how long since last change, i.e., length of bit just received
	lds		TempUc,IRRearTime
	mov		TempUb,SysTickL
	sub		TempUb,TempUc			;Get TempUb = CurrentTime - LastTime
	sts		IRRearTime,SysTickL	;Update LastTime

	; TempUa contains the new state, TempUb contains length of last bit
	mov		TempUc,IRRearStatus
	tst		TempUc
	brnz	IRRHSCNotIdle

	; We're idle -- look for the start of a possible header pulse
	; The signal is inverted so we need a low level to start
	tst		TempUa				;What is the new level?
	brnz	PC+2				;Wrong, just return
	inc		IRRearStatus		;Right, advance status
	ret							; and return

;*****************************************************************************

IRRHSCNotIdle:
	; TempUa contains new state, TempUb is length of last bit, TempUc is status
	; Check for a pulse that's too short
	cpi		TempUb,IRPulseCount			;Every transition should be at least this long
	brsh	IRRHSCLongEnough			;Yes, branch if long enough
IRRResetStatus:
	clr		IRRearStatus				;No, reset status
	ret
	
;*****************************************************************************

IRRHSCLongEnough:
	; We know that the pulse is at least the minimum length long
	; TempUa contains new state, TempUb is length of last bit, TempUc is status
	cpi		TempUc,GettingHeaderPulse
	brne	IRRHSC1
	; Clear the four byte buffer first
	ldi		zl,IRRearBytes
	clr		TempUa
	st		z+,TempUa
	st		z+,TempUa
	st		z+,TempUa
	st		z,TempUa
	; We're should have the end of a long header pulse
	cpi		TempUb,IRHeaderPulseCount	;Must be at least this long
	brsh	IRRIncStatus				;Yes, branch
	clr		IRRearStatus				;No, reset status
	ret
	
;*****************************************************************************

IRRHSC1:
	; TempUa contains new state, TempUb is length of last bit, TempUc is status
	cpi		TempUc,GettingHeaderSpace
	brne	IRRHSC2
	; We're should have the end of a normal header space or a repeat header space
	cpi		TempUb,IRMinHeaderSpaceCount	;Must be at least this long
	brlo	IRRResetStatus
	; Yes, it's longer than a standard space
	inc		IRRearStatus				;Increment by default
	cpi		TempUb,IRHeaderSpaceCount	;Must be at least this long
	brsh	IRRIncStatus				;Yes, branch (increments twice)
	cpi		TempUb,IRRepeatHeaderSpaceCount ;Repeat must be shorter than this
	brsh	IRRResetStatus				;No, reset
	ret									;Yes, already incremented once

;*****************************************************************************

	; TempUa contains new state, TempUb is length of last bit, TempUc is status
IRRHSC2:
	cpi		TempUc,GettingRepeatPulse
	brne	IRRHSC3
	; Got a valid repeat code
	tst		IRRearByte					;See if we already have something in the buffer
	brnz	IRRIgnoreRepeat				;Yes, ignore the repeat
	ldi		TempUa,IRRepeatCode			;No, do the repeat
	mov		IRRearByte,TempUa
IRRIgnoreRepeat:
	clr		IRRearStatus				;Finished
	ret

;*****************************************************************************

IRRHSC3:
	; TempUa contains new state, TempUb is length of last bit, TempUc is status
	cpi		TempUc,GettingLastPulse
	brne	IRRHSC4
	; Got a full code now -- process it
	ldi		zl,IRRearBytes
	ld		TempUa,z+			;Get first byte
	cpi		TempUa,IRByte1		;Should always be this fixed value
	breq	IRRHSC3a				;Branch if ok
IRRHaveError:
	ldi		TempUa,IRErrorCode
	rjmp	IRRSave

IRRHSC3a:
	ld		TempUa,z+			;Get second byte
	cpi		TempUa,IRByte2		;Should always be this fixed value
	brne	IRRHaveError		;Branch if error
	ld		TempUa,z+			;Get third byte
	ld		TempUb,z			;Get fourth byte
	com		TempUb				;Complement it
	cp		TempUa,TempUb		;The third and fourth bytes should be the complement of each other
	brne	IRRHaveError			;Error if different
	
	; We have a valid keypress
	tst		IRRearByte			;See if something already buffered
	brnz	IRROverflow			;Yes, branch
IRRAccept:
	inc		TempUa				;All ok, increment value (from third byte) so cannot be zero
IRRSave:
	mov		IRRearByte,TempUa
	clr		IRRearStatus
	ret

IRROverflow:
	; If the overflow is just a repeat code, overwrite it
	mov		TempUb,IRRearByte
	cpi		TempUb,IRRepeatCode
	breq	IRRAccept
	; If the overflow is an error code, overwrite it
	cpi		TempUb,IRErrorCode
	breq	IRRAccept
	rjmp	IRRHaveError

;*****************************************************************************

IRRHSC4:
	; Must be getting one of the data bits (pulse or space)
	; TempUa contains new state, TempUb is length of last bit, TempUc is status
	andi	TempUc,1			;See if status is even or odd
	brnz	IRRHSC5				;Branch if odd -- expecting variable length space
	; Must be getting expecting a short pulse
	cpi		TempUb,IRSpaceCount	;It should be shorter than this
	brsh	IRRHaveError
IRRIncStatus:
	inc		IRRearStatus
	ret

;*****************************************************************************

IRRHSC5:
	; Must be getting a space -- variable length data bit
	; TempUa contains new state, TempUb is length of last bit, TempUc is status
	clt							;Set T = 0
	cpi		TempUb,IRSpaceCount	;0 if shorter, 1 if longer
	brlo	PC+2				;Set T according to result
	set							;Set T = 1
	; Add bit in T to 32-bit buffer, LS-bit first, MS-byte first
	; i.e., move the bits in the bytes right to left
	;		and from the last byte to the first byte
	ldi		zl,IRRearBytes+3
	ld		TempUa,z
	ror		TempUa				;Rotate right (Shifts C into MS bit)
	bld		TempUa,7			;Set MS bit according to T
	st		z,TempUa			;Save shifted byte
	ld		TempUa,-z
	ror		TempUa				;Shift carry into third byte
	st		z,TempUa
	ld		TempUa,-z
	ror		TempUa				;Shift carry into second byte
	st		z,TempUa
	ld		TempUa,-z
	ror		TempUa				;Shift carry into first byte
	st		z,TempUa
	inc		IRRearStatus
	ret


;*****************************************************************************
;
;	CheckRx
;
;	Checks the communications from the controller
;
;	Called only from MainLoop so doesn't preserve any registers
;
;*****************************************************************************
;
CheckRx:
; See if anything has been received from the controller
	tst		HaveComRxLine
	brze	CheckRxReturn	;Return if no line yet

; We have a line in the Com Rx buffer -- process it
	ldi		zl,ComRxBuf		;Point z to the buffer	
	ld		TempUb,z+		;Get the first character
	cpi		TempUb,'I'		;Is it for me?
	breq	HaveRxLineForMe	;Yes, branch

; Clear the line by setting the count to zero
ClearComRxLine:
	clr		HaveComRxLine				;Clear the flag
	sts		ComRxBufCnt,HaveComRxLine	; and zeroize the count
CheckRxReturn:
	ret

;*****************************************************************************

; We have an I (InfraRed) message -- now which message is it (?, L, X, or V)?
HaveRxLineForMe:
	ld		TempUb,z+			;Get the character after the I

	cpi		TempUb,'?'
	breq	PC+2
	rjmp	NotComQu
	ld		TempUb,z			;Get the next character
	cpi		TempUb,CR			;Is it the final CR?
	breq	PC+2
	rjmp	RxInvalidMessage	;No, invalid message
	; We have an interrogation poll
	tst		IRFrontByte
	brze	ComQuTestRear
	mov		TempUa,IRFrontByte
	cpi		TempUa,IRRepeatCode
	brne	ComQuDoFront
	tst		IRRearByte			;If the front is a repeat, check in case the rear was the character
	brnz	ComQuDoRear
ComQuDoFront:
	rcall	SendFrontMessage
	clr		IRFrontByte
	rjmp	ClearComRxLine
ComQuTestRear:
	tst		IRRearByte
	brze	ComQuB
ComQuDoRear:	
	rcall	SendRearMessage
	clr		IRRearByte
	rjmp	ClearComRxLine
ComQuB:
	; No IR messages -- check for error messages
	clc						;Clear carry (error) flag
	CheckError	SULineOverflow		;Check least likely first
	CheckError	SURxBufferOverflow
	CheckError	InvalidMessage
	CheckError	SUParity
	CheckError	SUFraming
	rjmp	ClearComRxLine
NotComQu:

	cpi		TempUb,'L'
	brne	NotComL
	ld		yl,z+				;Get the function character into yl
	ld		ParamReg,z			;Get the next character
	cpi		ParamReg,CR			;Is it a CR ?
	brne	RxInvalidMessage	;No, error
	mov		LEDFn,yl			;Save the function byte
	mov		LEDTime,SysTickH	;Remember the time
	rjmp	ClearComRxLine		;We're done
NotComL:

	cpi		TempUb,'V'
	brne	NotComV
	ld		TempUb,z			;Get the next character
	cpi		TempUb,CR			;Is it the final CR?
	brne	RxInvalidMessage	;No, invalid message
	rcall	SendVersionMessage
	rjmp	ClearComRxLine
NotComV:

	cpi		TempUb,'X'
	brne	NotComX
	ld		ParamReg,z+			;Get the first hex character
	rcall	ProcessFirstDigit	;Keeps total in y
	brcs	RxInvalidMessage	;Check error flag (in carry)
	ld		ParamReg,z+			;Get the second hex character
	rcall	ProcessNextDigit	;Keeps total in y
	brcs	RxInvalidMessage	;Check error flag (in carry)
	ld		ParamReg,z			;Get the next character
	cpi		ParamReg,CR			;Is it a CR ?
	brne	RxInvalidMessage	;No, error
	mov		SWUARTTCReloadR,yl	;Save the temporary reload byte
	rjmp	ClearComRxLine		;We're done
NotComX:

	cpi		TempUb,'Z'
	brne	NotComZ
	ld		ParamReg,z+			;Get the first hex character
	rcall	ProcessFirstDigit	;Keeps total in y
	brcs	RxInvalidMessage	;Check error flag (in carry)
	ld		ParamReg,z+			;Get the second hex character
	rcall	ProcessNextDigit	;Keeps total in y
	brcs	RxInvalidMessage	;Check error flag (in carry)
	ld		ParamReg,z			;Get the next character
	cpi		ParamReg,CR			;Is it a CR ?
	brne	RxInvalidMessage	;No, error
	mov		SWUARTTCReloadR,yl	;Save the reload byte
	ldi		zl,EEReload
	mov		ParamReg,yl
	rcall	WriteEEPROMByte		;Save in EEPROM as well
	rjmp	ClearComRxLine		;We're done
NotComZ:

;*****************************************************************************

RxInvalidMessage:
	; We got an invalid message
	lds		TempUa,InvalidMessageErrorCount
	inc		TempUa
	sts		InvalidMessageErrorCount,TempUa
	rjmp	ClearComRxLine


;*****************************************************************************
;
;	ProgramError		For fatal programming errors
;							(Not for expected operational errors)
;
;	Expects:	ParamReg = Error code
;
;	Changes no registers
;
;*****************************************************************************
;
ProgramError:
	push	R0
	push	TempUb
	push	TempUc
	push	TempLa
	pushw	y
	pushw	z

	LoadAndSendFString	PEString1
	clt
	mov		zl,ParamReg
	rcall	ConvertUByte
	LoadAndSendFString	PEString2

; Do a delay and then try running again	
	ldi		TempUc,200
	mov		r0,TempUc
	clr		TempUc
	clr		TempLa
PEDelay:
	dec		TempUc
	brnz	PEDelay
	dec		TempLa
	brnz	PEDelay
	dec		r0
	brnz	PEDelay

	popw	z
	popw	y
	pop		TempLa
	pop		TempUc
	pop		TempUb
	pop		R0
	ret


PEString1:	.DB	CR,LF,"<<Error ",0
PEString2:	.DB	">>",CR,LF,0


;*****************************************************************************
;
; Must be at the end of the file
NextFlashAddress:	;Just to cause an error if the flash is overallocated
					; (NextFlashAddress should be address 400H (FLASHEND+1) or lower)
