;*****************************************************************************
;
;	IRTest.asm		Infrared test program
;
;	Written By:		Robert Hunt			September/October 2000
;
;	Modified By:	Robert Hunt
;	Mod. Number:	7
;	Mod. Date:		4 October 2000
;
;*****************************************************************************

; This program is written for an 8535 (40-pin analogue) with a 4MHz crystal
;	on the Atmel AVR-200 Starter Board

.nolist
.include	"C:\Program Files\AVRTOOLS\asmpack\appnotes\8535def.inc"
;.include	"C:\Program Files\AVRTools\appnotes\8535def.inc"
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
.EQU	MU		= 0xE6	;ASCII micro symbol


;*****************************************************************************
;
;	Error Codes
;
;*****************************************************************************
;
.EQU	FlashAllocationErrorCode		= 1
.EQU	RAMAllocationErrorCode			= 2
.EQU	EEPROMAllocationErrorCode		= 3
.EQU	StackOverflowErrorCode			= 4
.EQU	UnusedInterruptErrorCode		= 5
.EQU	TXBufferFullErrorCode			= 6


;*****************************************************************************
;
;	Timer/Counter Assignments
;
;*****************************************************************************
;
; Timer/Counter 0/1 Prescaler Controls	 (See times below for 4MHz crystal)
.EQU	TCStop			= 0b000									;8-bit	16-bit
.EQU	TCClkDiv1		= 0b001			; 4MHz			250ns	64us	16.4ms
.EQU	TCClkDiv8		= 0b010			; 500KHz		2us		512us	131+ms
.EQU	TC01ClkDiv64	= 0b011			; 62.5KHz		16us	4.1ms	1.05s
.EQU	TC01ClkDiv256	= 0b100			; 15.625KHz		64us	16.4ms	4.19s
.EQU	TC01ClkDiv1024	= 0b101			; 3906.25KHz	256us	65.5ms	16.8s
.EQU	TC01ClkExtFall	= 0b110
.EQU	TC01ClkExtRise	= 0b111
;
; Timer/Counter 2 Prescaler Controls
;  (The first three are the same as Timer/Counter 0/1 above)
.EQU	TC2ClkDiv32		= 0b011			; 125KHz		8us		2.05ms
.EQU	TC2ClkDiv64		= 0b100			; 62.5KHz		16us	4.1ms
.EQU	TC2ClkDiv128	= 0b101			; 31.25KHz		32us	8.2ms
.EQU	TC2ClkDiv256	= 0b110			; 15.625KHz		64us	16.4ms
.EQU	TC2ClkDiv1024	= 0b111			; 3906.25KHz	256us	65.5ms
;
;*****************************************************************************
;
; Timer/Counter-0 (8-bit)
;	Used for LCD output timer - reprogrammed as necessary
;
;*****************************************************************************
;
; Timer/Counter-1 (16-bit)
;
;*****************************************************************************
;
; Timer/Counter-2/RTC (8-bit)
;;	 Used for timing samples
.EQU	EventTCCR	= TCCR2
.EQU	EventTCNT	= TCNT2
.EQU	EventTCIE	= TOIE2


;*****************************************************************************
;
;	Port/Pin Definitions
;
;*****************************************************************************
;
; Port-A:
;	Pin-40	PA0 (ADC0)	In		Analog switches on remote control
;	Pin-39	PA1 (ADC1)	In		Battery Voltage
;	Pin-38	PA2 (ADC2)	In		Charging Voltage
;	Pin-37	PA3 (ADC3)	In		IR Input
;	Pin-36	PA4 (ADC4)	Unused
;	Pin-35	PA5 (ADC5)	Out		Remote LED
;	Pin-34	PA6 (ADC6)	Out		PowerControl
;	Pin-33	PA7 (ADC7)	Out 	Beeper
;
.EQU	SamplePort	= PINA
.EQU	SampleBit	= 3
.EQU	PowerPort	= PORTA
.EQU	PowerBit	= 6
;
;*****************************************************************************
;
; Port-B:
;	Pin-1	PB0	(T0)	Out	LED Also drives LED on remote control
;	Pin-2	PB1	(T1)	Out	LED
;	Pin-3	PB2	(AIN0)	Out	LED
;	Pin-4	PB3	(AIN1)	Out	LED
;	Pin-5	PB4	(/SS)	Out	LED
;	Pin-6	PB5	(MOSI)	Out	LED
;	Pin-7	PB6	(MISO)	Out	LED
;	Pin-8	PB7	(SCK)	Out	LED Indicates RUNNING (on) vs SLEEP (off)
;
.EQU	LEDPort		= PORTB
	.EQU	RunningLED		= 7
	.EQU	WaitingLED		= 6
	.EQU	SamplingLED		= 5
	.EQU	TransmittingLED = 4
	.EQU	AbortLED		= 3
;
;*****************************************************************************
;
; Port-C:
;	Pin-22	PC0			Out	DB4	}
;	Pin-23	PC1			Out DB5	}				for 4-bit HD44780 comms
;	Pin-24	PC2			Out	DB6	}	LCD			R/W is tied to GND and
;	Pin-25	PC3			Out DB7	}	Display		 so is always in WR mode
;	Pin-26	PC4			Out	EN	}
;	Pin-27	PC5			Out RS	}
;	Pin-28	PC6	(TOSC1)	In	RX	} to base board
;	Pin-29	PC7	(TOSC2)	Out	TX	} (software UART -- 1200bps)
;
;*****************************************************************************
;
; Port-D:
;	Pin-14	PD0	(RXD)	In	19,200bps RXD RS-232 from computer
;	Pin-15	PD1	(TXD)	Out	19,200bps TXD RS-232 to computer
;	Pin-16	PD2	(INT0)	InP	Switch 1: Toggle Power Off/Low/Normal
;	Pin-17	PD3	(INT1)	InP	Switch 2: Toggle Lights Off/Normal/Full
;	Pin-18	PD4	(OC1B)	InP	Switch 3: Toggle Stealth mode Off/On
;	Pin-19	PD5	(OC1A)	InP	Switch 4: Toggle AutoStop mode Off/On
;	Pin-20	PD6	(ICP)	InP	Switch 5: Toggle Turn-Straight/Circle Travel mode
;	Pin-21	PD7	(OC2)	InP	Switch 6: Toggle Diagnostics Off/On
;
;	Note: 		InP = Input with Pull-up resistor enabled
;
.EQU	SwitchPort = PIND
.EQU	SwitchBits = 0b11111100

;*****************************************************************************
;
;	Register Assignments
;
;*****************************************************************************
;
;	R0		For general use (esp. with LPM instruction)
;	R1		Reserved for saving SREG in interrupt routines
;	R2
;	R3
;	R4
;	R5
;	R6		HaveComRxLine flag: 0=nothing, 1=line received
;	R7		TempLa: Temp 8-bit register for main program
;	R8		TempLb
;	R9		TempLc
;	R10		TempLd
;	R11
;	R12
;	R13
;	R14
;	R15
.DEF	ISRSRegSav		= r1
.DEF	Min0			= r2
.DEF	Max0			= r3
.DEF	Min1			= r4
.DEF	Max1			= r5
.DEF	HaveComRxLine	= r6
.DEF	TempLa			= r7
.DEF	TempLb			= r8
.DEF	TempLc			= r9
.DEF	TempLd			= r10
.DEF	SampleDelay		= r11	;Sample delay for dedicated loop
.DEF	Divisor			= r12	;Timer/Counter divisor (3-bits)
.DEF	Char0			= r13	;Character to send for 0 bit
.DEF	Char1			= r14	;Character to send for 1 bit
.DEF	IgnoreLess		= r15	;Ignore less than this for timed waits
;
;*****************************************************************************
;
;	All of the following registers can be addressed by the LDI instruction:
;
;	R16		TempUa: Temp 8-bit register for main program
;	R17		TempUb: Temp 8-bit register for main program
;	R18		TempUc: Temp 8-bit register for main program
;	R19		Temp 8-bit register for interrupt service routines only
;	R20
;	R21		Parameter 8-bit register
;	R22
;	R23
.DEF	TempUa			= r16
.DEF	TempUb			= r17
.DEF	TempUc			= r18
.DEF	ISRTempUa		= r19
.DEF	ParamReg		= r21
.DEF	LastSampleType	= r22	;Stores type of last sample
	.EQU	LSTUnknown		= 0
	.EQU	LSTWait			= 1
	.EQU	LSTSample		= 2
	.EQU	LSTFastWait		= 3
	.EQU	LSTFastSample	= 4
	.EQU	LSTTimed		= 5
	.EQU	LSTFastTimed	= 6
.DEF	FirstState		= r23	;Stores state of first sample (0 or 255)
;
;*****************************************************************************
;
;	All of the following registers can be addressed by the ADIW instruction:
;
;	R24
;	R25
;	R26	XL	Used for ISRs only
;	R27	XH	Used for ISRs only
;	R28	YL	}
;	R29	YH	} For general
;	R30	ZL	}	use
;	R31 ZH	}
.DEF	TimerOverflowFlag = r24


;*****************************************************************************
;
;	SRAM Variable Definitions
;
; Total RAM = 512 bytes starting at 0060 through to 025F
;
;*****************************************************************************

	.DSEG

; Serial port buffers
.EQU	ComRxBufSiz		= 10	;Note: Maximum of 128 characters
ComRxBuf:		.byte	ComRxBufSiz	;MUST NOT CROSS 256 byte boundary
ComRxBufCnt:	.byte	1	;Number of characters in the buffer

.EQU	ComTxBufSiz		= 36	;Note: Maximum of 128 characters
ComTxBuf:		.byte	ComTxBufSiz	;MUST NOT CROSS 256 byte boundary
ComTxBufCnt:	.byte	1	;Number of characters in the buffer
ComTxBufO1:		.byte	1	;Offset to 1st character in buffer

ConvString:		.byte	10	;Storage for null-terminated conversion string
							; (Sign plus five digits plus null)
							;But also used for forming messages to base
							; (BGssaaddddCR plus null)
							;And to computer (STB: BGssaaddddCR plus null)

; Error Counters (All initialized to zero when RAM is cleared at RESET)
RxBufferOverflowErrorCount:		.byte	1
ComLineOverflowErrorCount:		.byte	1

.EQU	BBSize = 430
BitBuffer:			.byte	BBSize

; This next variable is here for error checking
;  (If it is not equal to RandomByteValue, then the stack has overflowed)
StackCheck:		.byte	1	;For error checking only -- contents should never change
	.EQU	RandomByteValue	= 0x96
Stack:			.byte	20	;Make sure that at least this many bytes are reserved for the stack
							; so that we get an assembler warning if we're low on RAM
NextSRAMAddress:	;Just to cause an error if there's no room for the stack
					; (NextSRAMAddress should be address 260H (RAMEND+1) or lower)


;*****************************************************************************
;
;	EEPROM Variable Definitions
;
; Total EEPROM = 512 bytes starting at 0000 through to 01FF
;
;*****************************************************************************

	.ESEG

NextEEPROMAddress:	;Just to cause an error if the EEPROM is overallocated
					; (NextEEPROMAddress should be address 200H (E2END+1) or lower)


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

.MACRO	pushw	;Push Word
				; e.g. pushw	z
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
	sts		@0,@1l
	sts		@0+1,@1h
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

.MACRO	incm	;INCrement to 255 Maximum
				; e.g. incm		R0
	inc		@0		;Increment it and set zero flag
	brne	PC+2	;Ok if it's not currently zero
	dec		@0		;If it was incremented to zero, decrement it back to 255 again
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
	lds		TempUa,@0ErrorCount
	tst		TempUa
	breq	PC+7
	; The error count is non-zero
	ldi		zl,low((@0ErrorString)<<1)
	ldi		zh,high((@0ErrorString)<<1)
	rcall	SendFString
	clr		TempUa
	sts		@0ErrorCount,TempUa
	;The breq instruction should reach here to the end
.ENDMACRO

.MACRO LEDOn
				; e.g. LEDOn	SamplingLED
	cbi		LEDPort,@0		;Low is on
.ENDMACRO

.MACRO LEDOff
				; e.g. LEDOf	AbortLED
	sbi		LEDPort,@0		;High is off
.ENDMACRO


;*****************************************************************************
;*****************************************************************************
;
;	Start of Actual Code
;
;	This chip has 4K 16-bit words (8K bytes) of flash memory
;	going from word addresses 000 to FFF
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
 .ORG 	INT1addr
	rjmp	UnusedInterruptError
 .ORG 	OC2addr
	rjmp	UnusedInterruptError
 .ORG 	OVF2addr
 	rjmp	ISR_T2Overflow			;Timer-2 overflow
 .ORG 	ICP1addr
	rjmp	UnusedInterruptError
 .ORG 	OC1Aaddr
	rjmp	UnusedInterruptError
 .ORG 	OC1Baddr
	rjmp	UnusedInterruptError
 .ORG 	OVF1addr
	rjmp	UnusedInterruptError
 .ORG 	OVF0addr
	rjmp	UnusedInterruptError
 .ORG 	SPIaddr
	rjmp	UnusedInterruptError
 .ORG 	URXCaddr
	rjmp	ISR_URXC	;RX Char
 .ORG 	UDREaddr
	rjmp	ISR_UDRE	;TX ready
 .ORG 	UTXCaddr
	rjmp	UnusedInterruptError
 .ORG 	ADCCaddr
	rjmp	UnusedInterruptError
 .ORG 	ERDYaddr
	rjmp	UnusedInterruptError
 .ORG 	ACIaddr
	;rjmp	UnusedInterruptError

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
	push	r0
	push	TempUb
	push	TempUc
	push	TempLa
	rcall	ProgramError	;Display the error code on the LEDs
	pop		TempLa
	pop		TempUc
	pop		TempUb
	pop		r0
	pop		ParamReg
	RestoreSRegReti			;Then carry on with the program


;*****************************************************************************
;*****************************************************************************
;
;	Version Number Strings
;
;	(Placed early in the code so they're easy to find)
;
;*****************************************************************************
;*****************************************************************************

StartString:	.DB		CR,LF					;Must be an even number of characters
HeaderString:	.DB		"IR Test Program V0.55",CR,LF,0


;*****************************************************************************
;*****************************************************************************
;
;	Start of Program Proper
;
;*****************************************************************************
;*****************************************************************************

Reset:
	cli			;Disable interrupts

	; Disable Watchdog
	ldi 	TempUa,(1 << WDDE) | (1 << WDE)
	out 	WDTCR,TempUa			;Set WDTOE while WDE is on also
	ldi 	TempUa,(1 << WDDE)
	out 	WDTCR,TempUa			;Leave WDTOE but clear WDE

	; Ensure that all interrupt masks are initially cleared
	clr 	TempUa
	out 	GIMSK,TempUa
	out 	TIMSK,TempUa

	; Set the stack pointer to the top of the internal RAM
	ldiw 	z,RAMEND
	out 	SPL,zl
	out 	SPH,zh

	; Initialise the MCU Control Register to default zero
	;	(Disables sleep, sets INT0 and INT1 to low level detection)
	clr 	TempUa
	out 	MCUCR,TempUa
	
	; Disable the Analog Comparator
	ldi 	TempUa,(1 << ADEN)	;Set the AC Disable bit
	out 	ACSR,TempUa


;*****************************************************************************
;
;	Setup Timer/Counters
;
;*****************************************************************************

; Enable overflow interrupt for event timer/counter
	in  	TempUa,TIMSK		;Clear the interrupt mask (Set the bit)
	ori 	TempUa,1<<EventTCIE
	out 	TIMSK,TempUa		;This stays cleared all the time
	
;*****************************************************************************
;
; Setup IO Ports
;
;*****************************************************************************

; Port-A is all inputs except bits 7=beeper output and 6=power output
	ldi		TempUa,0b11000000
	out		DDRA,TempUa
	ldi		TempUa,0b11000000	;Bits-7&6 should be high initially
	out		PORTA,TempUa

; Port-B is all outputs
	ser 	TempUa
	out 	DDRB,TempUa
	out		LEDPort,TempUa	;Set all bits high to turn LEDs off
	
; Port-C is all outputs except PC6 which is Software UART RX
	ldi		TempUa,0b10111111
	out 	DDRC,TempUa
	ldi		TempUa,0b11000000	;Set Rx bit high, LCD control & data bits low
	out		PORTC,TempUa		; Also turns on the internal pull-up for bit-6 (SU Rx)

; Port-D is all inputs (except PD1 which is set by the UART as TXD)
	clr		TempUa
	out		DDRD,TempUa

; Port-D needs pull-up resistors on the upper six bits used for switches
	ldi		TempUa,SwitchBits
	out		PORTD,TempUa


;*****************************************************************************
;
;	Setup the UART for 19,200 baud communications
;
;	UBRR = (CLK / 16 /Baud) - 1			4000000/16/19200 - 1 = 12
;
;	Baud = CLK / (16 * (UBRR + 1))		4000000/(16*(12+1)) = 19,231
;
;	Error = Actual - Desired / Desired	(19231 - 19200) / 19200 = 0.16%
;
;*****************************************************************************

	ldi		TempUa,12			;19,200 baud with 4MHz crystal
	out		UBRR,TempUa			;
	
	ldi		TempUa,0b10011000	;Enable the transmitter and receiver and RX Complete Interrupt
	out		UCR,TempUa

	
;*****************************************************************************
;
;	Check for program errors
;
;*****************************************************************************

; DebugOnly -- check for programming errors
; Check that the flash isn't over allocated (since the assembler only gives a warning)
	ldiw	z,NextFlashAddress
	ldi		TempUa,high(FLASHEND+2)	;For comparison later (there's no cpic instruction)
	cpi		zl,low(FLASHEND+2)
	cpc		zh,TempUa
	brlo	FlashAllocationOk
	ldi		ParamReg,FlashAllocationErrorCode
	rcall	ProgramError
	; Continue operation even though we will have some problems
FlashAllocationOk:


; Check that the EEPROM isn't over allocated
	ldiw	z,NextEEPROMAddress
	ldi		TempUa,high(E2END+2)	;For comparison later (there's no cpic instruction)
	cpi		zl,low(E2END+2)
	cpc		zh,TempUa
	brlo	EEPROMAllocationOk
	ldi		ParamReg,EEPROMAllocationErrorCode
	rcall	ProgramError
	; Continue operation even though we will have some problems
EEPROMAllocationOk:


; Check that circular queues don't cross a 256 byte boundary
	ldi		TempUa,high(ComTxBuf)
	cpi		TempUa,high(ComTxBufCnt)
	brne	RAMAllocationError
	ldi		TempUa,high(ComRxBuf)
	cpi		TempUa,high(ComRxBufCnt)
	brne	RAMAllocationError

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
	clr		r0
	clrw	z		;Start at address 0000
ZRLoop:
	st		z+,r0	;Zeroize the register
	cpi		zl,30	;Stop after clearing the first 30 of 32 registers
	brne	ZRLoop
	clr		zl		;zl has to be cleared by hand (zh is already zero)


; Initialize other registers that need to be something other than zero
	;none


;*****************************************************************************
;
;	Initialize RAM Variables
;
;*****************************************************************************

; Zeroize all of the RAM (including the stack but doesn't matter yet)
	ldi		zl,0x60			;The 512 bytes RAM go from 0060 to 025F
	clr		zh
	clr		r0
ClearRamLoop:
	st		z+,r0
	cpi		zl,low(RAMEND+1)
	brne	ClearRamLoop
	cpi		zh,high(RAMEND+1)
	brne	ClearRamLoop

	
; Initialize other variables that are something other than zero
	ldi		TempUa,RandomByteValue
	sts		StackCheck,TempUa
	ldi		TempUa,'-'
	mov		Char0,TempUa
	ldi		TempUa,'*'
	mov		Char1,TempUa
	ldi		TempUa,2
	mov		SampleDelay,TempUa
	ldi		TempUa,0b011		;Timer-2 div by 32
	mov		Divisor,TempUa


;*****************************************************************************
;
;	Finished the setup routine
;
;*****************************************************************************

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
	LEDOn	RunningLED ;Turn RUNNING LED on (indicates reached Main)

;*****************************************************************************

; Display the version number, etc.
	LoadAndSendFString		StartString

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
	rcall	ProgramError	;Disable interrupts and then display the error code on the LEDs
	sei						;Enable interrupts again and try to continue
	ldi		TempUa,RandomByteValue
	sts		StackCheck,TempUa
StackOk:

;*****************************************************************************

; Check for operational errors
	CheckError	RxBufferOverflow
	CheckError	ComLineOverflow

;*****************************************************************************

	rcall	CheckComms

;*****************************************************************************
;
; Enter sleep mode (as defined above in Main) until an interrupt occurs
;	Idle mode uses 1.9mA instead of 6.4mA on 8535 at 4MHz, 3V
;	Restart after IDLE is immediate
;
;*****************************************************************************

; Go to IDLE sleep until something else happens
	LEDOff	RunningLED 	;Turn RUNNING LED off
	sleep

; We've woken up again after an interrupt
	LEDOn	RunningLED 	;Turn RUNNING LED on
	rjmp	MainLoop


;*****************************************************************************
;
;	Strings
;
;*****************************************************************************

RxBufferOverflowErrorString:	.DB		" Rx Buffer Ovrflow ",0
ComLineOverflowErrorString:		.DB		" Com Line Ovrflow ",0


;*****************************************************************************
;*****************************************************************************
;
;	Interrupt Service Routines
;
;*****************************************************************************
;*****************************************************************************

	
;*****************************************************************************
;
;	Event Timer Interrupt Service Routine
;
; Sets the timer overflowflag
;
;*****************************************************************************
;
ISR_T2Overflow:
	; Note: We don't need to save the status register because not changing any flags
	ser		TimerOverflowFlag
	reti


;*****************************************************************************
;
;	TX Buffer Empty (UART Data Register Empty) Interrupt Service Routine
;
;	Sends the next character if there is one, else disables itself
;
;*****************************************************************************

ISR_UDRE:
	SaveSReg			;Save the status register

	; See if the count is non-zero
	lds		ISRTempUa,ComTxBufCnt
	tst		ISRTempUa
	brnz	IUHaveSome
	
	; No characters in buffer -- disable this interrupt
	cbi		UCR,UDRIE
	rjmp	IUExit
	
IUHaveSome:
	; Decrement the count and save it again
	dec		ISRTempUa
	sts		ComTxBufCnt,ISRTempUa
	
	; Get the next character and send it
	; Get the buffer address and add the offset to the first character
	ldiw	x,ComTxBuf
	lds		ISRTempUa,ComTxBufO1
	add		xl,ISRTempUa		;Note: Only works if buffer does not cross a 256-byte boundary
	
	; Send this character
	ld		ISRTempUa,x+		;Get the character and increment the pointer
	out		UDR,ISRTempUa	;Send the character
	
	; Now we have to see if the incremented pointer has gone past the end of the (circular) buffer
	subi	xl,low(ComTxBuf)	;Convert the incremented address back to an offset
	cpi		xl,ComTxBufSiz
	brlo	IUOk			;Ok if lower
	subi	xl,ComTxBufSiz	;Adjust if was higher
IUOk:
	; Store the new offset to the first character in the buffer
	sts		ComTxBufO1,xl
	
IUExit:
	RestoreSREGReti	;Restore SREG, return, and automatically reenable interrupts


;*****************************************************************************
;
;	RX Character Received Interrupt Service Routine
;
;	Stores the character in the buffer and sets flag when CR
;
;*****************************************************************************

ISR_URXC:
	SaveSReg			;Save the status register

	; See if we already have a line needing processing
	tst		HaveComRxLine
	brze	IURNoDouble		;No, we're ok
	
	; Yes, we have doubled up somehow
	lds		ISRTempUa,ComLineOverflowErrorCount
	inc		ISRTempUa
	sts		ComLineOverflowErrorCount,ISRTempUa
	; Ignore the error now
IURNoDouble:

	; See if the RX buffer is already full
	lds		ISRTempUa,ComRxBufCnt
	cpi		ISRTempUa,ComRxBufSiz-1	;Allow room for the trailing NULL
	brlo	IUROk					;Ok if lower
	
	; Have buffer overflow
	lds		ISRTempUa,RxBufferOverflowErrorCount
	inc		ISRTempUa
	sts		RxBufferOverflowErrorCount,ISRTempUa
	clr		ISRTempUa	;Clear the counter and continue (i.e., lose the beginning of the message)
IUROK:

	; Calculate where to store the character in the buffer
	;  (ISRTempUa still contains ComRxBufCnt)
	ldiw	x,ComRxBuf
	add		xl,ISRTempUa		;Note: Only works if buffer does not cross a 256-byte boundary

	; Increment the count and save it (so we can use ISRTempUa for something else)
	inc		ISRTempUa
	sts		ComRxBufCnt,ISRTempUa
	
	; Get the character and save it in the buffer
	in		ISRTempUa,UDR
	andi	ISRTempUa,0x7F	;Reduce to 7-bits (Ignore parity)
	st		x+,ISRTempUa
	
	; If it was a CR, set the EOL flag
	subi	ISRTempUa,CR
	brne	IURExit			;No, we're done

	; It was a CR so append a trailing NULL and set the EOL flag
	st		x,ISRTempUa		;(Set to zero by SUBI instruction)
	com		HaveComRxLine	;Was zero -- now FF

IURExit:
	RestoreSREGReti	;Restore SREG, return, and automatically reenable interrupts


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
;	SendCRLF	Sends a CRLF to the TX buffer
;				The interrupt routine then outputs the buffer automatically
;
; Uses:	y, TempUa, TempUb
;
;*****************************************************************************
;
SendCRLF:
	ldi		ParamReg,CR
	rcall	SendTxChar
	ldi		ParamReg,LF
	;rjmp	SendTxChar

;*****************************************************************************
;
;	SendTXChar	Sends a character to the TX buffer
;				The interrupt routine then outputs the buffer automatically
;
; Expects:	(ASCII) Character in ParamReg
;
; Uses:	y, TempUa, TempUb
;
; Must not change z, TempUc
;
;*****************************************************************************
;
SendTXChar:
	clrw	y	;Use y for a counter when the buffer is full
SendTxCharLoop:
	cli		; Disable interrupts temporarily
			;	so the TX interrupt can't change buffer control variables
	
	;See if there's room in the buffer
	lds		TempUa,ComTxBufCnt
	cpi		TempUa,ComTxBufSiz
	brlo	STCBufferNotFull
	
	; If we get here the buffer must be full (Should only occur on a HELP message or Memory Dump)
	sei						;Enable interrupts again so transmitter can keep sending
	adiw	yl,1			;Increment the loop counter
	; Note: At 19,200bps, the UART should send a character about every 521 microseconds
	; This buffer full loop has 8 instructions (10 cycles) and takes more than 2 microseconds at 4MHz
	;  so y shouldn't count to more than about 260 before there's room for the next character
	cpi		yh,2			;Has y got to 2 * 256 = 512?
	brlo	SendTxCharLoop	;No, keep waiting
	ldi		ParamReg,TXBufferFullErrorCode	;Yes, must be some major problem
	rcall	ProgramError	;Disable interrupts and then display the error code on the LEDs
	sei						;Enable interrupts again
	ret
	
STCBufferNotFull:
	; Add the start offset and the length together
	lds		TempUb,ComTxBufO1	;Get the offset to the first character
	add		TempUb,TempUa	;Add the TxBufCnt (Note: Total must not exceed 256)
	
	; Now TempUb is sort of the the offset of the first empty space
	; We have to adjust it though, if it's past the end of the (circular) buffer
	cpi		TempUb,ComTxBufSiz
	brlo	STCBNFOk			;Ok if the calculated offset is already inside the buffer
	subi	TempUb,ComTxBufSiz		;Otherwise, adjust it down
STCBNFOk:
	
	; Now TempUb is the adjusted offset of the first empty space
	; Add it to the buffer address
	ldiw	y,ComTxBuf
	add		yl,TempUb		;Note: Only works if buffer does not cross a 256-byte boundary
	
	; Now y is the address of the first empty space in the buffer
	st		y,ParamReg
	inc		TempUa			;Increment and save the count
	sts		ComTxBufCnt,TempUa
	
	; Enable TX ready (UDRE) interrupts (in case they weren't already enabled)
	sei						; Enable interrupts again now
	sbi		UCR,UDRIE
	ret


;*****************************************************************************
;
;	DumpRegisters	Sends a register dump to the TX buffer
;					The interrupt routine then outputs the buffer automatically
;
; Uses:	y, z, TempUa, ParamReg
; plus SendTXChar uses y, TempUa, TempUb
; plus ConvertUByte uses TempLa, TempLb, TempLc, TempLd, TempUa, TempUb, TempUc, y
;
;*****************************************************************************
;
DumpRegisters:

; First save most of the registers in SRAM temporarily
; We'll borrow the ComRxBuf since it's probably not being used
	; Save y and z by hand before we use them
	sts		ComRxBuf+28,yl	;yl = R28
	sts		ComRxBuf+29,yh	;yh = R29
	sts		ComRxBuf+30,zl	;zl = R30
	sts		ComRxBuf+31,zh	;zh = R31

	; Save the others
	ldiw	y,ComRxBuf
	clrw	z			;Start at address 00
DRSaveLoop:
	ld		R0,z+		;Get register
	st		y+,R0		;Save in buffer
	cpi		zl,32-4		;Don't include y or z as they're already saved
	brne	DRSaveLoop

; Now display the registers from the SRAM	
	clr		zl		;Start at register 00
	ldiw	y,ComRxBuf
DRLoop:
	push	zl
	pushw	y

	; Put an extra space before register numbers 0 to 9
	cpi		zl,10
	brsh	DROk			;Branch if register number is 10 or higher
	ldi		ParamReg,' '
	rcall	SendTXChar		;Doesn't change z
DROk:

	; Display the register number in decimal
	clt						;Zero suppress
	rcall	ConvertUByte	;Convert register number already in zl
	
	ldi		ParamReg,'='
	rcall	SendTXChar

	popw	y
	ld		zl,y+			;Get the register value from ComRxBuf
	pushw	y
	
	; Display the register value in hex
	rcall	ConvertHByte	;Convert it to a string

	ldi		ParamReg,' '
	rcall	SendTXChar

	popw	y		
	pop		zl
	inc		zl				;Increment register counter
	
; Send a CRLF after every eight registers
	mov		zh,zl
	andi	zh,0b00000111
	brnz	DRLoop
	rcall	SendCRLF		;Doesn't alter z
	
; Stop after displaying all 32 registers
	cpi		zl,32
	brne	DRLoop
	ret						;Finished all 32


;*****************************************************************************
;
;	DumpNamedRegisters	Sends a named register dump to the TX buffer
;						The interrupt routine then outputs the buffer automatically
;
; Uses:	z, TempUa, ParamReg
; plus SendTXChar uses y, TempUa, TempUb
; plus ConvertUByte uses TempLa, TempLb, TempLc, TempLd, TempUa, TempUb, TempUc, y
;
;*****************************************************************************
;
DumpNamedRegisters:
	ldi		zl,low(NRString<<1)
	ldi		zh,high(NRString<<1)
	clr		TempUa			;Counter
	push	TempUa			;Keep the counter on the stack
DNRLoop:
	; Display the register name
	ldi		TempUc,9		;Bytes per name
DNRLoop2:
	lpm						;Get character pointed to by Z into R0
	adiw	zl,1			;Increment the string pointer
	mov		ParamReg,r0
	cpi		ParamReg,255	;See if we're done
	breq	DNRDone
	rcall	SendTxChar		;Doesn't alter z or TempUc
	dec		TempUc
	brnz	DNRLoop2

	ldi		ParamReg,'='
	rcall	SendTXChar

	lpm						;Get register LSB address pointed to by Z into R0
	adiw	zl,1			;Increment the pointer
	mov		yl,R0			;Get register address into y
	clr		yh				; (Upper address byte must be zero)
	pushw	z				;Save the string address
	ld		zl,y+			;Get the register value
	
	; Display the register value in hex
	rcall	ConvertHByte	;Convert it to a string

	ldi		ParamReg,' '
	rcall	SendTXChar

	popw	z				;Get the string address back into z
	
; Send a CR after every four registers
	pop		TempUa			;Get number of registers displayed
	inc		TempUa			;Increment it
	push	TempUa			;Save the incremented value on the stack
	andi	TempUa,0b00000011
	brnz	DNRLoop

	rcall	SendCRLF		;Doesn't alter z
	rjmp	DNRLoop

DNRDone:
	pop		TempUa			;Clean up stack
	ret						;Finished all registers

NRString: ;Nine bytes per entry followed by register address
	;    123456789		123456789	   123456789	  123456789
	.DB	"       R0", 0,"R1/ISRRSv", 1,"  R2/Min0", 2,"  R3/Max0", 3
	.DB	"  R4/Min1", 4,"  R5/Max1", 5,"R6/HvComL", 6,"R7/TempLa", 7
	.DB	"R8/TempLb", 8,"R9/TempLc", 9,"R10/TmpLd",10,"R11/SaDly",11
	.DB	"R12/Divsr",12,"R13/Char0",13,"R14/Char1",14,"R15/IgLes",15
	.DB	"R16/TmpUa",16,"R17/TmpUb",17,"R18/TmpUc",18,"R19/ISRUa",19
	.DB	"      R20",20,"R21/ParRg",21,"R22/LSaTy",22,"R23/1Stat",23
	.DB "R24/TOvFl",24,"      R25",25,"R26/ISRXL",26,"R27/ISRXH",27
	.DB "   R28/YL",28,"   R29/YH",29,"   R30/ZL",30,"   R31/ZH",31
	.DB "     SREG",95,"     SP H",94,"     SP L",93,"   MCU SR",84
	.DB	"  GI MaSK",91,"    GI FR",90,"  TI MaSK",89,"    TI FR",88
	.DB "     PInA",57,"     PInB",54,"     PInC",51,"     PInD",48
	.DB	255


;*****************************************************************************
;
;	DumpSRam		Sends a static RAM dump to the TX buffer
;					The interrupt routine then outputs the buffer automatically
;
; Uses:	z, TempUa, ParamReg
; plus SendTXChar uses y, TempUa, TempUb
; plus ConvertUByte uses TempLa, TempLb, TempLc, TempLd, TempUa, TempUb, TempUc, y
;
;*****************************************************************************
;
DumpSRam:
	ldi		zl,0x60		;Start at address 0060
	clr		zh

DSRLoop1:
	; Display the next line of characters
	pushw	z			;Save the RAM address for this line

	; Display the SRAM address in hex
	rcall	ConvertHWord	;Convert RAM address already in z

	ldi		ParamReg,'='
	rcall	SendTXChar

	popw	z				;z contains the SRAM address
	pushw	z

; Display the 16 hex values
	ldi		TempUa,16		;Bytes per line
DSRLoop2:
	pushw	z				;Save the SRAM address for this byte

	push	TempUa
	ld		zl,z			;Get the SRAM value
	
	; Display the SRAM contents in hex
	rcall	ConvertHByte	;Convert it to a string

	ldi		ParamReg,' '
	rcall	SendTXChar
	pop		TempUa

	popw	z				;Get the SRAM address for this byte
	adiw	zl,1			;Increment SRAM pointer
	
	dec		TempUa			;Bytes left to print on this line
	brnz	DSRLoop2
	
; Display the 16 ASCII characters
	popw	z				;Get the SRAM starting address
	ldi		TempUa,16		;Bytes per line
DSRLoop3:
	push	TempUa			;Save the byte count
	ld		ParamReg,z+		;Get the SRAM value again
	pushw	z				;Save the incremented SRAM address
	
	; Display the SRAM contents in ASCII
	cpi		ParamReg,' '
	brlo	DSRDispDot		;Display a dot if it's less than ASCII space
	cpi		ParamReg,0x80
	brlo	DSRDispASC		;Display a dot if it's over 7F
DSRDispDot:
	ldi		ParamReg,'.'
DSRDispASC:
	rcall	SendTXChar
	popw	z				;Get the incremented SRAM address back again
	pop		TempUa			;Get the byte count back again

	dec		TempUa			;Bytes left to print on this line
	brnz	DSRLoop3
	
; Send a CR at the end of every line
	rcall	SendCRLF		;Doesn't alter z
	
; Stop after displaying all of the RAM
	cpi		zl,low(RAMEND+1)
	brne	DSRLoop1
	cpi		zh,high(RAMEND+1)
	brne	DSRLoop1
	ret						;Finished all 512 bytes


;*****************************************************************************
;
;	DumpEEPROM		Sends a static EEPOM dump to the TX buffer
;					The interrupt routine then outputs the buffer automatically
;
; Uses:	z, TempUc, ParamReg
; plus SendTXChar uses y, TempUa, TempUb
; plus ConvertUByte uses TempLa, TempLb, TempLc, TempLd, TempUa, TempUb, TempUc, y
;
;*****************************************************************************
;
DumpEEPROM:
	; Make sure that we're not writing to the EEPROM
DEEWait:
	bris	EECR,EEWE,DEEWait	;Loop if a write operation is still in progress

	clrw	z		;Start at address 0000

DEELoop1:
	; Display the next line of characters
	pushw	z			;Save the EEPROM address for this line

	; Display the EEPROM address in hex
	rcall	ConvertHWord	;Convert EEPROM address already in z

	ldi		ParamReg,'='
	rcall	SendTXChar

	popw	z				;z contains the EEPROM address
	pushw	z

; Display the 16 hex values
	ldi		TempUa,16		;Bytes per line
DEELoop2:
	pushw	z				;Save the EEPROM address for this byte

	push	TempUa
	
	; Read the byte from the EEPROM into zl
	out		EEARH,zh		;Output the 9-bit address
	out		EEARL,zl
	sbi		EECR,EERE		;Do the read command (will halt CPU for 4 cycles)
	in		zl,EEDR			;Get the EEPROM value
	
	; Display the SRAM contents in hex
	rcall	ConvertHByte	;Convert it to a string

	ldi		ParamReg,' '
	rcall	SendTXChar
	pop		TempUa

	popw	z				;Get the EEPROM address for this byte
	adiw	zl,1			;Increment EERPOM pointer
	
	dec		TempUa			;Bytes left to print on this line
	brnz	DEELoop2
	
; Display the 16 ASCII characters
	popw	z				;Get the EEPROM starting address
	ldi		TempUa,16		;Bytes per line
DEELoop3:
	push	TempUa			;Save the byte count

	; Read the byte from the EEPROM into ParamReg
	out		EEARH,zh		;Output the 9-bit address
	out		EEARL,zl
	sbi		EECR,EERE		;Do the read command (will halt CPU for 4 cycles)
	in		ParamReg,EEDR	;Get the EEPROM value
	
	adiw	zl,1			;Increment the address counter
	pushw	z				;Save the incremented EEPROM address
	
	; Display the EEPROM contents in ASCII
	cpi		ParamReg,' '
	brlo	DEEDispDot		;Display a dot if it's less than ASCII space
	cpi		ParamReg,0x80
	brlo	DEEDispASC		;Display a dot if it's over 7F
DEEDispDot:
	ldi		ParamReg,'.'
DEEDispASC:
	rcall	SendTXChar
	popw	z				;Get the incremented EEPROM address back again
	pop		TempUa			;Get the byte count back again

	dec		TempUa			;Bytes left to print on this line
	brnz	DEELoop3
	
; Send a CR at the end of every line
	rcall	SendCRLF		;Doesn't alter z
	
; Stop after displaying all of the EEPROM
	cpi		zl,low(E2END+1)
	brne	DEELoop1
	cpi		zh,high(E2END+1)
	brne	DEELoop1
	ret						;Finished all 512 bytes


;*****************************************************************************
;
;	SendFString	Sends a null-terminated string from the FLASH to the selected buffer
;
; Expects:	z = Flash string pointer
;
; Uses:		R0, y, z, TempUa, TempUb, TempUc, ParamReg
;
; Returns:	R0 = 0
;
;*****************************************************************************
;
SendFString:
	lpm					;Get byte pointed to by Z into R0
	tst		r0			;See if it's a null
	brze	Return

	mov		ParamReg,r0	;Save byte ready to output
	adiw	zl,1		;Increment the 16-bit buffer pointer for next time

	rcall	SendTXChar	;Send (buffer) the character in ParamReg
	rjmp	SendFString


;*****************************************************************************
;
;	GetEvenParity		Calculates even parity
;
;	Expects:	TempUa = 7-bit character to check
;
;	Changes:	TempUa
;				TempUb to zero
;
;	Returns:	Even parity in T
;
;*****************************************************************************

GetEvenParity:
	ldi		TempUb,7	;Number of bits to check
	clt					;T-flag will hold parity
GP_Next:
	; Rotate off each bit starting with the LS bit and toggle parity if it is set.
	ror		TempUa		;Get the next LS bit into carry
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
	dec		TempUb
	brnz	GP_Next
	
	; Parity is in T-flag
Return:
	ret		;from GetEvenParity


;*****************************************************************************
;
;	ConvertUByte		Converts a unsigned byte to ASCII digits
;
; Expects:	T = 0 for zero suppression, non-zero for no zero suppression
;			ZL = byte to be converted
;			Saves the null-terminated string in ConvString
;
; Returns with Z pointing to ConvString
;
;*****************************************************************************
;
ConvertUByte:
	clr		zh
	;Fall through to ConvertUWord below
	
;*****************************************************************************
;
;	ConvertUWord		Converts an unsigned word to ASCII digits
;
; Expects:	T = 0 for zero suppression, non-zero for no zero suppression
;			Z = word to be converted
;			Saves the null-terminated string in ConvString
;
; Returns with Z pointing to ConvString
;
; Uses:		TempLa, TempLb, TempLc, TempLd, TempUa, Tempb, TempUc, y
;
;*****************************************************************************
;
ConvertUWord:
	;Point y to the start of the string storage area
	ldiw	y,ConvString
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
	subi	zl,-'0'		;Convert the last digit to ASCII
	st		y+,zl		;Append to string
ConvertFinish:
	st		y,TempUb	;Append the final null
	
	; Point z to ConvString
	ldiw	z,ConvString
	;rjmp	SendString

;*****************************************************************************
;
;	SendSString	Sends a null-terminated string from the STATIC RAM to the selected buffer
;
; Expects:	SRAM string pointer in Z
;
; Uses:		ParamReg, y, z, TempUa, TempUb, TempUc
;
; Returns:	ParamReg = 0
;
;*****************************************************************************
;
SendSString:
	ld		ParamReg,z+		;Get byte pointed to by Z and then increment Z
	tst		ParamReg			;See if it's a null
	brze	Return2

	rcall	SendTXChar	;Send (buffer) the character in ParamReg
	rjmp	SendSString


;*****************************************************************************
;
;	CWCount		Local routine used only by above Convert routines
;
;	Expects:	TempUa, TempUb is divisor
;				TempLa, TempLb, TempLc, TempLd
;				
;	Uses:	TempUc, y
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
Return2:
	ret


;*****************************************************************************
;
;	ConvertHByte		Converts a hex byte to two ASCII digits
;
; Expects:	zl = byte to be converted
;			Saves the null-terminated string in ConvString
;
; StoreHexByte uses TempUa and TempUc, updates y
;
; Returns with z pointing to ConvString
;
;*****************************************************************************
;
ConvertHByte:
	ldiw	y,ConvString	;Point y to the start of the string storage area
	mov		TempUa,zl
	rcall	StoreHexByte
	clr		TempUb
	rjmp	ConvertFinish


;*****************************************************************************
;
;	ConvertHWord		Converts a hex word to four ASCII digits
;
; Expects:	z = word to be converted
;			Saves the null-terminated string in ConvString
;
; StoreHexByte uses TempUa and TempUc, updates y
;
; Returns with z pointing to ConvString
;
;*****************************************************************************
;
ConvertHWord:
	ldiw	y,ConvString	;Point y to the start of the string storage area
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
; Expects:	ParamReg = ASCII digit (0-9, or H for hex)
;
; Returns with: y set to value
;				TempUa = Number of digits processed
;							(Normally 1 but 0 for H)
;				TempLa = 0 for decimal mode, non-zero for hex mode
;				C = 0 for ok, 1 for error
;
;*****************************************************************************
;
ProcessFirstDigit:
	clrw	y			;Clear TOTAL register
	clr		TempUa		;Number of processed digits = 0
	clr		TempLa		;Default mode = decimal

	cpi		ParamReg,'H'
	breq	PFDH
	cpi		ParamReg,'h'
	brne	PFDNotH
PFDH:
	inc		TempLa		;0 to non-zero (1) indicates hex mode
	clc					;C = 0 for no error
	ret					;Done

PFDNotH:
	;Should be a decimal digit
	cpi		ParamReg,'0'
	brlo	PDError
	cpi		ParamReg,'9'+1
	brsh	PDError
	subi	ParamReg,'0';It's a valid digit -- remove ASCII part
	mov		yl,ParamReg	;Save it
	inc		TempUa		;Number of digits processed goes from 0 to 1
	clc					;C = 0 for no error
	ret					;Done

PDError:
	sec					;C = 1 indicates error
	ret


;*****************************************************************************
;
;	ProcessNextDigit		Check the next character of a digit string
;
; Expects:	ParamReg = ASCII digit (0-9, or A-F if in hex mode)
;			y = Total so far
;			TempUa = Number of digits already processed
;			TempLa = 0 for decimal mode, non-zero for hex mode
;
; Uses:		TempLc, TempLd
;
; Returns with: y = Accumulated total
;				TempUa = Number of digits processed
;				TempLa = 0 for decimal mode, non-zero for hex mode
;				C = 0 for ok, 1 for error
;
;*****************************************************************************
;
ProcessNextDigit:
;Do the common test
	cpi		ParamReg,'0' ;If it's less than an ASCII zero it's always invalid
	brlo	PDError

	tst		TempLa		;Now see if we are in decimal or hex mode
	brnz	PNDHex		;Branch if hex mode

; See if it's a decimal digit
	cpi		ParamReg,'9'+1
	brsh	PDError

	subi	ParamReg,'0';It's a valid digit -- remove ASCII part
	inc		TempUa		;Count this digit

; Multiply word value by 10 (ignoring overflow) and add new digit value
	mov		TempLc,yl	;Save current total
	mov		TempLd,yh
	lsl		yl			; * 2
	rol		yh
	lsl		yl			; * 2 again = * 4
	rol		yh
	add		yl,TempLc	; add original = * 5
	adc		yh,TempLd
	lsl		yl			; * 2 again = * 10
	rol		yh
	clr		TempLc
	add		yl,ParamReg	;Add in this new digit
	adc		yh,TempLc	; (add zero with carry)
	clc					;C = 0 for no error
	ret					;Done

PNDHex:
; See if it's a valid hexadecimal digit (digit, A-F, a-f)
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
	inc		TempUa		;Count this digit

; Multiply word value by 16 (ignoring overflow) and add new digit value
	lsl		yl			; * 2
	rol		yh
	lsl		yl			; * 2 again = * 4
	rol		yh
	lsl		yl			; * 2 again = * 8
	rol		yh
	lsl		yl			; * 2 again = * 16
	rol		yh
	clr		TempLc
	add		yl,ParamReg	;Add in this new digit
	adc		yh,TempLc	; (add zero with carry)
	clc					;C = 0 for no error
	ret					;Done


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
;
;*****************************************************************************
;
StoreHexByte:
	mov		TempUc,TempUa	;Copy the character
	swap	TempUc			;Swap nibbles
	andi	TempUc,0x0F		;Get the four bits
	subi	TempUc,-'0'		;ASCIIize it by adding '0'
	cpi		TempUc,':'		;Colon is one past '9'
	brlo	SB1OK			;Ok if it's a valid digit
	subi	TempUc,':'-'a'	;Convert to A-F
SB1OK:
	st		y+,TempUc
	
	andi	TempUa,0x0F		;Get the four LS bits
	subi	TempUa,-'0'		;ASCIIize it by adding '0'
	cpi		TempUa,':'		;Colon is one past '9'
	brlo	SB2OK			;Ok if it's a valid digit
	subi	TempUa,':'-'a'	;Convert to A-F
SB2OK:
	st		y+,TempUa
	ret


;*****************************************************************************
;
;	CheckComms
;
;	Checks the computer communications
;
;	Accepts case-insensitive commands from the computer:
;
;	Numbers can be entered in decimal or hex (PRECEDED by H)
;
;	Called only from MainLoop so doesn't preserve any registers
;
;*****************************************************************************
;
;*****************************************************************************
;
CheckComms:
; See if anything has been received from the computer
	tst		HaveComRxLine
	brnz	HaveComRxLineNow
	ret						;Return if nothing yet

; We have a line in the Com Rx buffer -- process it
HaveComRxLineNow:
	rcall	SendCRLF		;Do a CRLF
	ldiw	z,ComRxBuf		;Point z to the buffer	
	ld		TempUb,z+		;Get the first character
	cpi		TempUb,'a'
	brlo	FirstCharOk
	subi	TempUb,'a'-'A'	;Convert lower case to upper case
FirstCharOk:

	lds		TempUa,ComRxBufCnt ;See how many characters there are
	cpi		TempUa,2+1
	brlo	ComHaveOneChar		;Branch if have 1 or 2 characters (counting the CR)
	rjmp	ComMoreThan2		;Branch if have 3 or more characters (including CR)

;*****************************************************************************

; Have a one character message (plus the CR)
ComHaveOneChar:
	cpi		TempUb,'?'
	brne	NotComQu
	LoadAndSendFString	HeaderString
	LoadAndSendFString	HelpString
	rjmp	ClearComRxLine
NotComQu:

	cpi		TempUb,'`'
	brne	NotComBQ
	cbi		PowerPort,PowerBit
	rjmp	ClearComRxLine
NotComBQ:

	cpi		TempUb,'A'
	brne	NotComA
	rcall	AIDecode
	rjmp	ClearComRxLine
NotComA:

	cpi		TempUb,'E'
	brne	NotComE
	rcall	DumpEEPROM
	rjmp	ClearComRxLine
NotComE:

	cpi		TempUb,'F'
	brne	NotComF
	rcall	CalculateFrequency
	rjmp	ClearComRxLine
NotComF:

	cpi		TempUb,'I'
	brne	NotComI
	rcall	SendInformation
	rjmp	ClearComRxLine
NotComI:

	cpi		TempUb,'M'
	brne	NotComM
	rcall	SendMinMax
	rjmp	ClearComRxLine
NotComM:

	cpi		TempUb,'N'
	brne	NotComN
	rcall	DumpNamedRegisters
	rjmp	ClearComRxLine
NotComN:

	cpi		TempUb,'R'
	brne	NotComR
	; Resend buffer
	rcall	SendAll
	rjmp	ClearComRxLine
NotComR:

	cpi		TempUb,'S'
	brne	NotComS
	; Sample now
	rcall	SampleNow
	rcall	SendAll
	rjmp	ClearComRxLine
NotComS:

	cpi		TempUb,'T'
	brne	NotComT
	; Timed sample
	tst		Divisor
	brnz	TDivisorOk
	rjmp	CInvalidParameter
TDivisorOk:
	rcall	TimedSample
	rcall	SendAll
	rjmp	ClearComRxLine
NotComT:

	cpi		TempUb,'V'
	brne	NotComV
	; Display this version number
	LoadAndSendFString	StartString
	rjmp	ClearComRxLine
NotComV:

	cpi		TempUb,'W'
	brne	NotComW
	; Sample after waiting for transition
	rcall	SampleWait
	rcall	SendAll
	rjmp	ClearComRxLine
NotComW:

	cpi		TempUb,'X'
	brne	NotComX
	rcall	DumpRegisters
	rjmp	ClearComRxLine
NotComX:

	cpi		TempUb,'Z'
	brne	NotComY
	rcall	DumpSRam
	rjmp	ClearComRxLine
NotComY:

; We got an invalid message so beep
	rjmp	CInvalidMessage

;*****************************************************************************

; We have a message longer than one character (plus CR)
ComMoreThan2:
	cpi		TempUb,'0'
	brne	NotCom0
Com00:
	; Check that there is an equals sign
	ld		ParamReg,z+		;Get the next character after the 0
	cpi		ParamReg,' '
	breq	Com00			;Ignore spaces
	cpi		ParamReg,'='
	breq	PC+2
	rjmp	CInvalidMessage
	; Ignore any spaces after the equals
Com01:
	ld		ParamReg,z+		;Get the next character (space or digit)
	cpi		ParamReg,' '
	breq	Com01			;Ignore spaces
	;Get the digits
	rcall	ProcessFirstDigit
	brcc	Com0DigitLoop
	rjmp	CInvalidMessage	;Error if no first digit
Com0DigitLoop:
	ld		ParamReg,z+		;Get the next character
	cpi		ParamReg,CR
	breq	Com0Done		;Finished when hit CR
	rcall	ProcessNextDigit
	brcc	Com0DigitLoop
	rjmp	CInvalidMessage	;Branch if error
Com0Done:
	mov		Char0,yl	;Save the delay
	rjmp	ClearComRxLine
NotCom0:

	cpi		TempUb,'1'
	brne	NotCom1
Com10:
	; Check that there is an equals sign
	ld		ParamReg,z+		;Get the next character after the 1
	cpi		ParamReg,' '
	breq	Com01			;Ignore spaces
	cpi		ParamReg,'='
	breq	PC+2
	rjmp	CInvalidMessage
	; Ignore any spaces after the equals
Com11:
	ld		ParamReg,z+		;Get the next character (space or digit)
	cpi		ParamReg,' '
	breq	Com11			;Ignore spaces
	;Get the digits
	rcall	ProcessFirstDigit
	brcc	Com1DigitLoop
	rjmp	CInvalidMessage	;Error if no first digit
Com1DigitLoop:
	ld		ParamReg,z+		;Get the next character
	cpi		ParamReg,CR
	breq	Com1Done		;Finished when hit CR
	rcall	ProcessNextDigit
	brcc	Com1DigitLoop
	rjmp	CInvalidMessage	;Branch if error
Com1Done:
	mov		Char1,yl	;Save the delay
	rjmp	ClearComRxLine
NotCom1:

	cpi		TempUb,'C'
	brne	NotComC
ComC:
	; Check that there is an equals sign
	ld		ParamReg,z+		;Get the next character after the C
	cpi		ParamReg,' '
	breq	ComC			;Ignore spaces
	cpi		ParamReg,'='
	breq	PC+2
	rjmp	CInvalidMessage
	; Ignore any spaces after the equals
ComC1:
	ld		ParamReg,z+		;Get the next character (space or digit)
	cpi		ParamReg,' '
	breq	ComC1			;Ignore spaces
	;Get the digit
	rcall	ProcessFirstDigit
	brcc	ComCDone
CInvalid:
	rjmp	CInvalidMessage	;Error if no first digit
ComCDone:
	; Must be a number between 1 and 7
	tst		yl
	brze	CInvalid
	cpi		yl,7+1
	brsh	CInvalid
	mov		Divisor,yl	;Save the divisor
	rjmp	ClearComRxLine
NotComC:

	cpi		TempUb,'D'
	brne	NotComD
ComD:
	; Check that there is an equals sign
	ld		ParamReg,z+		;Get the next character after the D
	cpi		ParamReg,' '
	breq	ComD			;Ignore spaces
	cpi		ParamReg,'='
	breq	PC+2
	rjmp	CInvalidMessage
	; Ignore any spaces after the equals
ComD1:
	ld		ParamReg,z+		;Get the next character (space or digit)
	cpi		ParamReg,' '
	breq	ComD1			;Ignore spaces
	;Get the digits
	rcall	ProcessFirstDigit
	brcc	ComDDigitLoop
	rjmp	CInvalidMessage	;Error if no first digit
ComDDigitLoop:
	ld		ParamReg,z+		;Get the next character
	cpi		ParamReg,CR
	breq	ComDDone		;Finished when hit CR
	rcall	ProcessNextDigit
	brcc	ComDDigitLoop
	rjmp	CInvalidMessage	;Branch if error
ComDDone:
	mov		SampleDelay,yl	;Save the delay
	rjmp	ClearComRxLine
NotComD:

	cpi		TempUb,'E'
	breq	ComEE
	rjmp	NotComEE
ComEE:
	ld		ParamReg,z+		;Get the next character (space or digit)
	cpi		ParamReg,' '
	breq	ComEE			;Ignore spaces
	;Get the digits
	rcall	ProcessFirstDigit
	brcc	ComEEAddressLoop
	rjmp	CInvalidMessage	;Error if no first digit
ComEEAddressLoop:
	ld		ParamReg,z+		;Get the next character
	cpi		ParamReg,'='
	breq	ComEEAddDone		;Finished set address when hit equals sign
	cpi		ParamReg,CR
	breq	ComEEAddDisplay	;Finished display address when hit CR
	rcall	ProcessNextDigit
	brcc	ComEEAddressLoop
	rjmp	CInvalidMessage	;Branch if error
ComEEAddDisplay:
	;Display the value from the address in y
	pushw	y
	ldi		ParamReg,' '
	rcall	SendTxChar		;Indent by one space
	popw	y
ComEEWait1:
	bris	EECR,EEWE,ComEEWait1	;Loop if a write operation is still in progress
	out		EEARH,yh		;Output the 9-bit address
	out		EEARL,yl
	sbi		EECR,EERE		;Do the read command (will halt CPU for 4 cycles)
	in		zl,EEDR			;Get the EEPROM value
	rcall	ConvertHByte	;Convert it to a string
	rcall	SendCRLF		;Doesn't alter z
	rjmp	ClearComRxLine
ComEEAddDone:				;Now the address is in y
	ld		ParamReg,z+		;Get the next character (space or digit)
	cpi		ParamReg,' '
	breq	ComEEAddDone	;Ignore spaces
	;Get the value digits
	pushw	y				;Save the address
	rcall	ProcessFirstDigit
	brcc	ComEEValueLoop
	popw	y				;Clean up the stack if had error
	rjmp	CInvalidMessage	;Error if no first digit
ComEEValueLoop:
	ld		ParamReg,z+		;Get the next character
	cpi		ParamReg,','
	breq	ComEEDone		;Finished when hit comma
	cpi		ParamReg,CR
	breq	ComEEDone		;Finished when hit CR
	rcall	ProcessNextDigit
	brcc	ComEEValueLoop
	popw	y				;Clean up the stack if had error
	rjmp	CInvalidMessage	;Branch if error
ComEEDone:
	bris	EECR,EEWE,ComEEDone	;Loop if a write operation is still in progress
	; We have the address on the stack and the value in yl
	out		EEDR,yl			;Output the value
	popw	y				;Get the address back into y
	out		EEARH,yh		;Output the 9-bit address
	out		EEARL,yl
	cli						;Disable interrupts temporarily
	sbi		EECR,EEMWE		;Do the write enable command
	sbi		EECR,EEWE		;Do the write command (will halt CPU for 2 cycles)
	sei						;Can reenable interrupts again now
	cpi		ParamReg,','	;Was the terminator a comma?
	breq	ComEEAddDone	;Yes, get next value
	rjmp	ClearComRxLine
NotComEE:

	cpi		TempUb,'L'
	brne	NotComL
ComL:
	; Check that there is an equals sign
	ld		ParamReg,z+		;Get the next character after the L
	cpi		ParamReg,' '
	breq	ComL			;Ignore spaces
	cpi		ParamReg,'='
	breq	PC+2
	rjmp	CInvalidMessage
	; Ignore any spaces after the equals
ComL1:
	ld		ParamReg,z+		;Get the next character (space or digit)
	cpi		ParamReg,' '
	breq	ComL1			;Ignore spaces
	;Get the digit
	rcall	ProcessFirstDigit
	brcc	ComLDone
	rjmp	CInvalidMessage	;Error if no first digit
ComLDone:
	mov		IgnoreLess,yl	;Save the value
	rjmp	ClearComRxLine
NotComL:

	cpi		TempUb,'Z'
	brne	NotComZ
ComZ:
	ld		ParamReg,z+		;Get the next character (space or digit)
	cpi		ParamReg,' '
	breq	ComZ			;Ignore spaces
	;Get the digits
	rcall	ProcessFirstDigit
	brcc	ComZAddressLoop
	rjmp	CInvalidMessage	;Error if no first digit
ComZAddressLoop:
	ld		ParamReg,z+		;Get the next character
	cpi		ParamReg,'='
	breq	ComZAddDone		;Finished set address when hit equals sign
	cpi		ParamReg,CR
	breq	ComZAddDisplay	;Finished display address when hit CR
	rcall	ProcessNextDigit
	brcc	ComZAddressLoop
	rjmp	CInvalidMessage	;Branch if error
ComZAddDisplay:
	;Display the value from the address in y
	pushw	y
	ldi		ParamReg,' '
	rcall	SendTxChar		;Indent by one space
	popw	y
	ld		zl,y			;Get the memory value
	rcall	ConvertHByte	;Convert it to a string
	rcall	SendCRLF		;Doesn't alter z
	rjmp	ClearComRxLine
ComZAddDone:				;Now the address is in y
	ld		ParamReg,z+		;Get the next character (space or digit)
	cpi		ParamReg,' '
	breq	ComZAddDone		;Ignore spaces
	;Get the value digits
	pushw	y				;Save the address
	rcall	ProcessFirstDigit
	brcc	ComZValueLoop
	popw	y				;Clean up the stack if had error
	rjmp	CInvalidMessage	;Error if no first digit
ComZValueLoop:
	ld		ParamReg,z+		;Get the next character
	cpi		ParamReg,','
	breq	ComZDone		;Finished when hit comma
	cpi		ParamReg,CR
	breq	ComZDone		;Finished when hit CR
	rcall	ProcessNextDigit
	brcc	ComZValueLoop
	popw	y				;Clean up the stack if had error
	rjmp	CInvalidMessage	;Branch if error
ComZDone:
	; We have the address on the stack and the value in yl
	mov		R0,yl			;Get the value into R0
	popw	y				;Get the address back into y
	st		y+,R0			;Write the entered value to the SRAM
	cpi		ParamReg,','	;Was the terminator a comma?
	breq	ComZAddDone		;Yes, get next value
	rjmp	ClearComRxLine
NotComZ:

;*****************************************************************************

CInvalidMessage:
	; We got an invalid message
	; Send them a message telling them what we think
	LoadAndSendFString	BadMessage
	rjmp	ClearComRxLine

CInvalidParameter:
	; We got an invalid parameter
	; Send them a message telling them what we think
	LoadAndSendFString	BadParameter
	rcall	SendInformation

; Clear the line by setting the count to zero
ClearComRxLine:
	clr		TempUa
	sts		ComRxBufCnt,TempUa	;Zeroize the count
	clr		HaveComRxLine		; and clear the flag
	ret


;*****************************************************************************
;
;	ProgramError		For fatal programming errors
;							(Not for expected operational errors)
;
;	Disables interrupts and then flashes all the LEDs five times
;	Then displays error code for a while before returning
;
;	Expects:	ParamReg = Error code
;
;	Uses:		R0, TempUb, TempUc, TempLa
;
;	Doesn't use the stack except for the return
;	Leaves interrupts disabled
;
;*****************************************************************************
;
ProgramError:
	cli			;Disable interrupts so nothing else can happen

	ldi		TempUb,12	;Number of times to flash all LEDs

	clr		r0			;Start by turning LEDs on
PEFlashLoop:
	out		LEDPort,r0	;Turn on/off all the LEDs

	clr		TempUc
	clr		TempLa	
PEDelay1:
	dec		TempUc
	brnz	PEDelay1
PEDelay1a:
	dec		TempUc
	brnz	PEDelay1a
	dec		TempLa
	brnz	PEDelay1
	
	com		r0		;Change LED output
	dec		TempUb
	brnz	PEFlashLoop
	
	com		ParamReg		;0 is on so complement the error code
	out		LEDPort,ParamReg	;Display error code
	com		ParamReg		;Restore it again

; Do another delay and then try running again	
	ldi		TempUc,30
	mov		r0,TempUc
	clr		TempUc
	clr		TempLa
PEDelay2:
	dec		TempUc
	brnz	PEDelay2
	dec		TempLa
	brnz	PEDelay2
	dec		r0
	brnz	PEDelay2
	
	ret					;Return leaving interrupts disabled

;*****************************************************************************
;
;	ProgramErrorDump	For fatal programming errors
;							(Not for expected operational errors)
;
;	Disables interrupts and then flashes all the LEDs five times
;	Then displays error code for a while and renables interrupts
;	Then dump registers and SRAM to TX
;	After that, return and try to continue operation
;
;	Expects:	ParamReg = Error code
;
;	Uses:		R0, TempUb, TempUc, TempLa, etc...
;
;*****************************************************************************
;
ProgramErrorDump:
	rcall	ProgramError
	sei				;Reenable interrupts so can try to continue

	pushw	z
	push	TempUc	
	rcall	DumpRegisters
	rcall	DumpSRam
	pop		TempUc
	popw	z
	ret


;*****************************************************************************
;
;	SampleWait	Samples the pin until the buffer is full
;
;	Returns:	C if aborted
;
;*****************************************************************************
;
SampleWait:
	tst		SampleDelay
	brnz	SWDelayOk
	rjmp	FastSampleWait
SWDelayOk:

	LEDOff	AbortLED ;Turn ABORT LED off

	ldi		LastSampleType,LSTWait

	LEDOn	WaitingLED ;Turn WAITING LED on

	in		TempUa,SamplePort	;Get the current reading
	andi	TempUa,1<<SampleBit

SWLoop:
	; Allow a switch press to abort
	in		TempUc,SwitchPort
	andi	TempUc,SwitchBits	;Get switches PD7-PD2 only
	cpi		TempUc,SwitchBits	;All off?
	breq	SWTest				;Yes, continue
	LEDOn	AbortLED			;No, Turn ABORT LED on
	LEDOff	WaitingLED 			;Turn WAITING LED off
	sec							;Set carry flag
	ret							; and exit

SWTest:
	in		TempUb,SamplePort	;Get a new reading
	andi	TempUb,1<<SampleBit
	cp		TempUb,TempUa
	breq	SWLoop				;Loop while they're the same

	LEDOff	WaitingLED			;Turn WAITING LED off
	rjmp	SNCont


;*****************************************************************************
;
;	SampleNow	Samples the pin until the buffer is full
;
; At 4MHz each processor cycle takes 250 nanoseconds or 0.25 microseconds
; At 40Kz each IR cycle takes 25 microseconds

; Each sample takes 3.75 microseconds plus 0.75 microseconds * SampleDelay
;	 1 =  4.50 microseconds
;	 2 =  5.25 microseconds
;	 3 =  6.00 microseconds
;	 4 =  6.75 microseconds
;	 5 =  7.50 microseconds
;	 6 =  8.25 microseconds
;	 7 =  9.00 microseconds
;	 8 =  9.75 microseconds
;	 9 = 10.50 microseconds
;
; If we sample every 6 microseconds, then each eight samples takes 48 microseconds
;	so each 100 bytes of buffer saves 4.8 milliseconds
; If we sample every 10.5 microseconds, then each eight samples takes 84 microseconds
;	so each 100 bytes of buffer saves 8.4 milliseconds
;
;	Returns:	C = 0
;
;*****************************************************************************
;
SampleNow:
	tst		SampleDelay
	brnz	SNDelayOk
	rjmp	FastSampleNow
SNDelayOk:

	LEDOff	AbortLED			;Turn ABORT LED off

	ldi		LastSampleType,LSTSample

SNCont:
	cli							;Disable interrupts
	LEDOn	SamplingLED 		;Turn SAMPLING LED on

; Sample the bit and fill the RAM
	ldiw	y,BBSize
	ldiw	z,BitBuffer

SampleLoop1:
	ldi		TempUc,0b10000000	;Initial mask for each byte							1
	clr		R0					;Initial value for each byte						1

SampleLoop2:

; This delay loop takes 3 * SampleDelay cycles or 0.75 * SampleDelay microseconds
	mov		TempLa,SampleDelay	;1
SampleLoop3:
	dec		TempLa				;1
	brnz	SampleLoop3			;2/1

; Takes minimum of 15 cycles per loop (irrespective of path) = 3.75 microseconds
	mov		TempUb,TempUc		;Get a copy of the mask						1
	sbis	SamplePort,SampleBit;Check the bit								1 or 2
	clr		TempUb				;Bit is not set so clear copy of mask		1 or 0
	or		R0,TempUb			;Mask bit into byte							1
	lsr		TempUc				;Shift mask									1
	brcs	SampleByteFull		;Loop if byte is full already				1 or	2
	nop							;											1
	nop							;											1
	nop							;These NOPs compensate for					1
	nop							; the time taken to handle					1
	nop							; loop counters, etc.						1
	nop							;											1
	nop							;											1
	rjmp	SampleLoop2			;Go and get the next bit					2

SampleByteFull:
	st		z+,R0				;Save the 8 bits & increment RAM pointer			2
	sbiw	yl,1				;Decrement counter									2
	brnz	SampleLoop1			;Branch if RAM not full yet					(1 or)	2

	LEDOff	SamplingLED			;Turn SAMPLING LED off
	sei							;Enable interrupts again
	clc							;Clear error flag
	ret							; and return

	
;*****************************************************************************
;
;	FastSampleWait	Samples the pin until the buffer is full
;
;	Returns:	C if aborted
;
;*****************************************************************************
;
FastSampleWait:
	LEDOff	AbortLED ;Turn ABORT LED off

	ldi		LastSampleType,LSTFastWait

	LEDOn	WaitingLED ;Turn WAITING LED on

	in		TempUa,SamplePort	;Get the current reading
	andi	TempUa,1<<SampleBit

FSWLoop:
	; Allow a switch press to abort
	in		TempUc,SwitchPort
	andi	TempUc,SwitchBits	;Get switches PD7-PD2 only
	cpi		TempUc,SwitchBits	;All off?
	breq	FSWTest				;Yes, continue
	LEDOn	AbortLED			;No, Turn ABORT LED on
	LEDOff	WaitingLED 			;Turn WAITING LED off
	sec							;Set carry flag
	ret							; and exit

FSWTest:
	in		TempUb,SamplePort	;Get a new reading
	andi	TempUb,1<<SampleBit
	cp		TempUb,TempUa
	breq	FSWLoop				;Loop while they're the same

	LEDOff	WaitingLED			;Turn WAITING LED off
	rjmp	FSNCont


;*****************************************************************************
;
;	FastSampleNow	Samples the pin until the buffer is full
;
; At 4MHz each processor cycle takes 250 nanoseconds or 0.25 microseconds
; At 40Kz each IR cycle takes 25 microseconds

; Each sample takes 3.75 microseconds
;
;	Returns:	C = 0
;
;*****************************************************************************
;
FastSampleNow:
	LEDOff	AbortLED			;Turn ABORT LED off

	ldi		LastSampleType,LSTFastSample

FSNCont:
	cli							;Disable interrupts
	LEDOn	SamplingLED 		;Turn SAMPLING LED on

; Sample the bit and fill the RAM
	ldiw	y,BBSize
	ldiw	z,BitBuffer

FSampleLoop1:
	ldi		TempUc,0b10000000	;Initial mask for each byte							1
	clr		R0					;Initial value for each byte						1

FSampleLoop2:
; Takes minimum of 15 cycles per loop (irrespective of path) = 3.75 microseconds
	mov		TempUb,TempUc		;Get a copy of the mask						1
	sbis	SamplePort,SampleBit;Check the bit								1 or 2
	clr		TempUb				;Bit is not set so clear copy of mask		1 or 0
	or		R0,TempUb			;Mask bit into byte							1
	lsr		TempUc				;Shift mask									1
	brcs	FSampleByteFull		;Loop if byte is full already				1 or	2
	nop							;											1
	nop							;											1
	nop							;These NOPs compensate for					1
	nop							; the time taken to handle					1
	nop							; loop counters, etc.						1
	nop							;											1
	nop							;											1
	rjmp	FSampleLoop2		;Go and get the next bit					2

FSampleByteFull:
	st		z+,R0				;Save the 8 bits & increment RAM pointer			2
	sbiw	yl,1				;Decrement counter									2
	brnz	FSampleLoop1		;Branch if RAM not full yet					(1 or)	2

	LEDOff	SamplingLED			;Turn SAMPLING LED off
	sei							;Enable interrupts again
	clc							;Clear error flag
	ret							; and return

	
;*****************************************************************************
;
;	TimedSample		Samples the pin until the buffer is full
;
;	Returns:	C if aborted
;
;*****************************************************************************
;
TimedSample:
	mov		TempUa,Divisor
	cpi		TempUa,3
	brsh	TSDelayOk
	rjmp	FastTimedSample	;Use Fast routine (no abort) for Divisor=1,2
TSDelayOk:

	LEDOff	AbortLED			;Turn ABORT LED off

	ldi		LastSampleType,LSTTimed

	; Zeroize the buffer first
	ldiw	y,BBSize
	ldiw	z,BitBuffer
	clr		TempUa
TSZ:
	st		z+,TempUa
	sbiw	yl,1
	brnz	TSZ

	;Set the timer up for the right speed
	mov		TempUc,Divisor
	andi	TempUc,0b111		;Make sure it's only three bits
	out		EventTCCR,TempUc

	ldiw	y,BBSize
	ldiw	z,BitBuffer
	clr		TempLa				;Keep this register at zero

; Wait for a transition
	LEDOn	WaitingLED 			;Turn WAITING LED on

	in		TempUa,SamplePort	;Get the current reading
	andi	TempUa,1<<SampleBit

TSWLoop:
	; Allow a switch press to abort
	in		TempUc,SwitchPort
	andi	TempUc,SwitchBits	;Get switches PD7-PD2 only
	cpi		TempUc,SwitchBits	;All off?
	breq	TSWTest				;Yes, continue
	LEDOff	WaitingLED 			;No, turn WAITING LED off
	rjmp	TSErrorExit

TSWTest:
	in		TempUb,SamplePort	;Get a new reading
	andi	TempUb,1<<SampleBit
	cp		TempUb,TempUa
	breq	TSWLoop				;Loop while they're the same

	LEDOff	WaitingLED			;Turn WAITING LED off
	LEDOn	SamplingLED			;Turn SAMPLING LED on

; Now ready to go
	mov		TempUa,TempUb		;Save a copy of the first reading in TempUa
	clr		FirstState			;Default to zero
	tst		TempUb				;Was the zero default correct?
	brze	PC+2				;Yes, branch
	ser		FirstState			;No, set to 255

; This is the main sampling loop
TSLoop1:
	; Set the timer/counter to zero (It counts up from there)
	out		EventTCNT,TempLa
	clr		TimerOverflowFlag	;(Must do this after zeroizing the counter)

TSLoop2:
	; Wait for a transition
	in		TempUb,SamplePort	;Get a new reading
	andi	TempUb,1<<SampleBit
	cp		TempUb,TempUa		;Same as last time?
	brne	TSTransition		;No, exit loop

	; Allow a switch press to abort
	in		TempUc,SwitchPort
	andi	TempUc,SwitchBits	;Get switches PD7-PD2 only
	cpi		TempUc,SwitchBits	;All off?
	breq	TSLoop2				;Yes, loop
TSErrorExit:
	LEDOn	AbortLED			;No, Turn ABORT LED on
	sec							;Set error flag
	rjmp	TSExit				; and exit

TSTransition:
	; Record the time
	in		TempUc,EventTCNT
	tst		TimerOverflowFlag
	brze	PC+2				;No overflow so use timer value
	ser		TempUc				;Overflow so use 255
	st		z+,TempUc			;Save in memory
	sbiw	yl,1				;Decrement count
	brnz	TSLoop1				;Loop until buffer full

	clc							;Clear error flag
TSExit:
	LEDOff	SamplingLED			;Turn SAMPLING LED off
	ldi		TempUc,TCStop
	out		EventTCCR,TempUc	;Stop the timer/counter
	ret


;*****************************************************************************
;
;	FastTimedSample		Samples the pin until the buffer is full
;
;	Returns:	C if aborted but doesn't check for abort after first transition
;
;*****************************************************************************
;
FastTimedSample:
	LEDOff	AbortLED			;Turn ABORT LED off

	ldi		LastSampleType,LSTFastTimed

	; Zeroize the buffer first
	ldiw	y,BBSize
	ldiw	z,BitBuffer
	clr		TempUa
FTSZ:
	st		z+,TempUa
	sbiw	yl,1
	brnz	FTSZ

	;Set the timer up for the right speed
	mov		TempUc,Divisor
	andi	TempUc,0b111		;Make sure it's only three bits
	out		EventTCCR,TempUc

	ldiw	y,BBSize
	ldiw	z,BitBuffer
	clr		TempLa				;Keep this register at zero

; Wait for a transition
	LEDOn	WaitingLED 			;Turn WAITING LED on

	in		TempUa,SamplePort	;Get the current reading
	andi	TempUa,1<<SampleBit

FTSWLoop:
	; Allow a switch press to abort
	in		TempUc,SwitchPort
	andi	TempUc,SwitchBits	;Get switches PD7-PD2 only
	cpi		TempUc,SwitchBits	;All off?
	breq	FTSWTest			;Yes, continue
	LEDOff	WaitingLED 			;No, turn WAITING LED off
	LEDOn	AbortLED			;Turn ABORT LED on
	sec							;Set error flag
	rjmp	FTSExit				; and exit

FTSWTest:
	in		TempUb,SamplePort	;Get a new reading
	andi	TempUb,1<<SampleBit
	cp		TempUb,TempUa
	breq	FTSWLoop				;Loop while they're the same

	LEDOff	WaitingLED			;Turn WAITING LED off
	LEDOn	SamplingLED			;Turn SAMPLING LED on

; Now ready to go
	mov		TempUa,TempUb		;Save a copy of the first reading in TempUa
	clr		FirstState			;Default to zero
	tst		TempUb				;Was the zero default correct?
	brze	PC+2				;Yes, branch
	ser		FirstState			;No, set to 255

; This is the main sampling loop
FTSLoop1:
	; Set the timer/counter to zero (It counts up from there)
	out		EventTCNT,TempLa
	clr		TimerOverflowFlag	;(Must do this after zeroizing the counter)

FTSLoop2:
	; Wait for a transition
	in		TempUb,SamplePort	;Get a new reading
	andi	TempUb,1<<SampleBit
	cp		TempUb,TempUa		;Same as last time?
	breq	FTSLoop2			;Yes, keep waiting

	; Record the time
	in		TempUc,EventTCNT
	tst		TimerOverflowFlag
	brze	PC+2				;No overflow so use timer value
	ser		TempUc				;Overflow so use 255
	st		z+,TempUc			;Save in memory
	sbiw	yl,1				;Decrement count
	brnz	FTSLoop1			;Loop until buffer full

	clc							;Clear error flag
FTSExit:
	LEDOff	SamplingLED			;Turn SAMPLING LED off
	ldi		TempUc,TCStop
	out		EventTCCR,TempUc	;Stop the timer/counter
	ret


;*****************************************************************************
;
;	SendInformation		Sends the static information to the Tx
;
;	Alters:		TempUa, TempUb
;
;*****************************************************************************
;
SendInformation:
	LEDOff	AbortLED ;Turn ABORT LED off

	; Display version number
	LoadAndSendFString	StartString

	; Display buffer size
	LoadAndSendFString	BuffSizeString
	ldiw	z,BBSize
	clt						;Zero suppress
	rcall	ConvertUWord	;Convert number in z
	LoadAndSendFString	BuffSizeString2
	ldiw	z,BBSize*8
	clt						;Zero suppress
	rcall	ConvertUWord	;Convert number in z
	LoadAndSendFString	BuffSizeString3	;Includes CRLF
	
	; Display sample delay
	LoadAndSendFString	DelayString
	mov		zl,SampleDelay
	clt						;Zero suppress
	rcall	ConvertUByte	;Convert number in zl
	LoadAndSendFString	DelayString2	;Includes CRLF
	
	; Display TC divisor
	LoadAndSendFString	DivisorString
	mov		zl,Divisor
	clt						;Zero suppress
	rcall	ConvertUByte	;Convert number in zl
	LoadAndSendFString	DivisorString2	;Includes CRLF
	
	; Display TC divisor
	LoadAndSendFString	IgnoreLessString
	mov		zl,IgnoreLess
	clt						;Zero suppress
	rcall	ConvertUByte	;Convert number in zl
	rcall	SendCRLF
	
	; Send characters
	LoadAndSendFString	Char0String
	mov		ParamReg,Char0
	rcall	SendTxChar
	LoadAndSendFString	CharString
	mov		zl,Char0
	clt						;Zero suppress
	rcall	ConvertUByte	;Convert number in zl
	LoadAndSendFString	CharString2	;Includes CRLF

	LoadAndSendFString	Char1String
	mov		ParamReg,Char1
	rcall	SendTxChar
	LoadAndSendFString	CharString
	mov		zl,Char1
	clt						;Zero suppress
	rcall	ConvertUByte	;Convert number in zl
	LoadAndSendFString	CharString2	;Includes CRLF
	ret


;*****************************************************************************
;
;	SendAll		Sends the buffer to the Tx and calculates Min/Max values
;
;	Returns:	C if aborted
;
;*****************************************************************************
;
SendAll:
	LEDOff	AbortLED ;Turn ABORT LED off

	ser		TempUa
	mov		Min0,TempUa
	mov		Min1,TempUa
	clr		Max0
	clr		Max1

	cpi		LastSampleType,LSTSample
	breq	SendSample
	cpi		LastSampleType,LSTWait
	breq	SendSample
	cpi		LastSampleType,LSTFastSample
	breq	SendSample
	cpi		LastSampleType,LSTFastWait
	breq	SendSample
	cpi		LastSampleType,LSTTimed
	breq	SATimed
	cpi		LastSampleType,LSTFastTimed
	brne	SAInvalidParameter
SATimed:
	rjmp	SendTimed
SAInvalidParameter:
	rjmp	CInvalidParameter

SendSample:
	ldiw	y,BBSize
	ldiw	z,BitBuffer

	; Set R0 to first state and TempLd to contiguous count
	ld		TempUa,z	;Get the first byte
	andi	TempUa,0x80	;Get the first bit
	mov		R0,TempUa	;Zero or non-zero
	clr		TempLd		;Zeroize count of contiguous readings

	LEDOn	TransmittingLED ;Turn TRANSMITTING LED on
SendLoop1:
	; Allow a switch press to abort
	in		TempUa,SwitchPort
	andi	TempUa,SwitchBits	;Get switches PD7-PD2 only
	cpi		TempUa,SwitchBits	;All off?
	breq	SendLoop1Cont		;Yes, loop
	LEDOn	AbortLED		 	;No, turn ABORT LED on
	rcall	SendCRLF
	sec							;Set error flag
	rjmp	SLExit				; then exit

SendLoop1Cont:	
	ld		TempUa,z+			;Get the byte
	ldi		TempUc,0b10000000	;Initial mask for each byte							1
SendLoop2:
	mov		TempUb,TempUa		;Get a copy of the byte
	and		TempUb,TempUc		;Get the desired bit

	; Count contiguous bits for Min/Max calculations
	brze	SLNowZero
	; It's a one
	tst		R0			;What was the last one?
	brze	SL0To1
	; It's a one and the last one was a one
SLIncCount:
	incm	TempLd		;Increment contiguous count but not past 255
	rjmp	SLMinMaxDone
	; It's a one and the last one was a zero
SL0To1:
	cp		TempLd,Min0
	brsh	PC+2
	mov		Min0,TempLd
	cp		TempLd,Max0
	brlo	PC+2
	mov		Max0,TempLd
	rjmp	SLMinMaxTidyUp
SLNowZero:
	; It's a zero
	tst		R0			;What was the last one?
	brze	SLIncCount	;A zero also? Yes, increment contiguous count
	; It's a zero and the last one was a one
	cp		TempLd,Min1
	brsh	PC+2
	mov		Min1,TempLd
	cp		TempLd,Max1
	brlo	PC+2
	mov		Max1,TempLd
SLMinMaxTidyUp:
	mov		R0,TempUb	;Remember this bit
	clr		TempLd
SLMinMaxDone:

	; Output the appropriate character
	pushw	z
	pushw	y
	push	TempUa
	mov		ParamReg,Char0		;For 0 bit
	tst		TempUb
	brze	SLChar
	mov		ParamReg,Char1		;For 1 bit
SLChar:
	rcall	SendTxChar
	pop		TempUa
	popw	y
	popw	z

	lsr		TempUc				;Shift mask
	brcc	SendLoop2			;Branch if still have more bits
	sbiw	yl,1				;Decrement counter
	brnz	SendLoop1			;Branch if RAM not all done yet
	clc							;Clear error flag
SLExit:
	LEDOff	TransmittingLED		;Turn TRANSMITTING LED off
	ret

;*****************************************************************************

SendTimed:
	LEDOn	TransmittingLED ;Turn TRANSMITTING LED on
	
	; Send initial state
;	LoadAndSendFString	InitStateString
;	tst		FirstState
;	brze	FSZero
;	ldsa	z,State1
;	rjmp	FSDisplay
;FSZero:
;	ldsa	z,State0
;FSDisplay:
;	rcall	SendFString
	
	; Initialize variables
	mov		TempLa,FirstState	;Save working copy 
	clr		TempLb				;Clear "Num Ignored" count

	ldiw	y,BBSize
	ldiw	z,BitBuffer

STLoop:
	; Allow a switch press to abort
	in		TempUa,SwitchPort
	andi	TempUa,SwitchBits	;Get switches PD7-PD2 only
	cpi		TempUa,SwitchBits	;All off?
	breq	STLoop1Cont			;Yes, loop
	LEDOn	AbortLED		 	;No, turn ABORT LED on
	rcall	SendCRLF
	sec							;Set error flag
	rjmp	STExit				; then exit

STLoop1Cont:
	; Set min/max values
	ld		TempUb,z		;Get the count
	tst		TempLa			;Test this state
	brze	TSMMZero
	cp		TempUb,Min1
	brsh	PC+2
	mov		Min1,TempUb
	cp		TempUb,Max1
	brlo	PC+2
	mov		Max1,TempUb
	rjmp	TSMMDone
TSMMZero:
	cp		TempUb,Min0
	brsh	PC+2
	mov		Min0,TempUb
	cp		TempUb,Max0
	brlo	PC+2
	mov		Max0,TempUb
TSMMDone:

	pushw	y
	pushw	z

	; Test ignore less (The current count is still in TempUb)
	cp		TempUb,IgnoreLess
	brsh	TSDontIgnore
	
	; We should ignore this one -- just count it for now
	incm	TempLb		;Increment it but not past 255
	rjmp	STCont

TSDontIgnore:
	;Note: The "Num Ignored" (TempLb) is cleared further down
	;		 (so it doesn't have to be saved on the stack)
	; We may need to print the ignore count
	tst		TempLb			;Have we ignored any?
	brze	TSNoIgnorePrint	;No, forget this
	LoadAndSendFString	IgnoreString1
	mov		zl,TempLb
	cpi		zl,1
	breq	TSIgnoreOne		;Don't print number
	ldi		ParamReg,'('
	rcall	SendTxChar
	clt						;Zero suppress
	push	TempLa			;Save current state
	rcall	ConvertUByte	;Convert register number already in zl
	pop		TempLa			;Restore current state
	ldi		ParamReg,')'
	rcall	SendTxChar
TSIgnoreOne:
	LoadAndSendFString	IgnoreString2	;includes a trailing space
TSNoIgnorePrint:

	; Output the state and count
	tst		TempLa			;Test this state
	brze	TSZero
	ldi		ParamReg,'1'	;It's a one
	rjmp	TSDisplay
TSZero:
	ldi		ParamReg,'0'	;It's a zero
TSDisplay:
	rcall	SendTxChar		;Send this state

	ldi		ParamReg,'='	;Send an equals sign
	rcall	SendTxChar
	popw	z

	; Display the timing number in decimal
	ld		TempUb,z		;Get the count again
	pushw	z
	push	TempLa			;Save current state
	mov		zl,TempUb
	clt						;Zero suppress
	rcall	ConvertUByte	;Convert register number already in zl
	pop		TempLa

	ldi		ParamReg,' '	;Send a space
	rcall	SendTxChar

	clr		TempLb			;Clear "Num Ignored" count

STCont:
	popw	z
	popw	y
	com		TempLa			;Complement the state
	adiw	zl,1			;Step pointer
	sbiw	yl,1			;Decrement counter
	brze	PC+2
	rjmp	STLoop			;Branch if RAM not all done yet
	rcall	SendCRLF
	clc						;Clear error flag
STExit:
	LEDOff	TransmittingLED	;Turn TRANSMITTING LED off
	ret

IgnoreString1:	.DB	"--",0
IgnoreString2:	.DB	"-- ",0


;*****************************************************************************
;
;	SendMinMax		Sends the Min and Max values
;
;*****************************************************************************
;
; Output the minimum and maximum values
.MACRO	SendX
	ldi		zl,low(@0String<<1)
	ldi		zh,high(@0String<<1)
	rcall	SendFString	;Uses: R0, y, z, TempUa, TempUb, TempUc, ParamReg
	mov		zl,@0
	clt						;Zero suppress
	rcall	ConvertUByte	;Convert register number already in zl
.ENDMACRO

SendMinMax:
	tst		Max0
	brnz	Have0		;Don't send if still set to defaults
	mov		zl,Min0
	cpi		zl,255
	breq	No0
Have0:
	SendX	Min0
	SendX	Max0
	rcall	SendCRLF
No0:
	tst		Max1
	brnz	Have1		;Don't send if still set to defaults
	mov		zl,Min1
	cpi		zl,255
	breq	No1
Have1:
	SendX	Min1
	SendX	Max1
	rcall	SendCRLF
No1:
	ret

Min0String:	.DB	"Minimum zero count = ",0
Max0String:	.DB	", Maximum zero count = ",0
Min1String:	.DB	"Minimum one count = ",0
Max1String:	.DB	", Maximum one count = ",0


;*****************************************************************************
;
;	CalculateFrequency		Calculate the modulation frequency
;
; The 38KHz cycle time is 26.3us which is a transition every 13.2us
; The 40KHz cycle time is 25.0us which is a transition every 12.5us
;
;*****************************************************************************
;
CalculateFrequency:

; Do a fast timed sample
	LoadAndSendFString	CFIntroString
	push	Divisor
	ldi		TempUa,TCClkDiv1	;4MHz = 250ns up to 64us
	mov		Divisor,TempUa
	rcall	TimedSample
	pop		Divisor
	brcc	PC+2
	rjmp	CFError			;Error if carry set

; Now try to calculate the modulation frequency
	rcall	SendAll			;Display the information and give them a chance to abort it
	brcc	PC+2
	rjmp	CFError			;Error if carry set

; Now check the minimum values
	rcall	SendMinMax		;Let the user see what we're getting

; Now count the transitions in 1000 counts
	ldiw	y,1000
	ldiw	z,BitBuffer
	clr		TempUa			;TransitionCount
	clr		TempLa			;Always zero
FSLoop:
	ld		TempUb,z+		;Get the count
	cpi		TempUb,80		;Shouldn't ever exceed about 80
	brlo	FSOk
	inc		TempUc			;Ignore this one
	rjmp	FSLoop
FSOk:
	incm	TempUa			;TransitionCount += 1 (but not over 255)
	sub		yl,TempUb		;y = y - count
	sbc		yh,TempLa
	brcc	FSLoop
	
; Now we have to double the result and should get the frequency
	lsl		TempUa			;TransitionCount *= 2
	push	TempUc			;Save ignore count
	push	TempUa			;Save Frequency
	LoadAndSendFString	FreqString1
	pop		zl				;zl = Frequency
push zl
	rcall	ConvertUByte	;Convert number in zl
	LoadAndSendFString	FreqString2	;Includes CRLF
pop TempUa
	pop		TempUc			;Restore ignore count
	tst		TempUc
	brze	FSNoIgnore
	push	TempUc			;Save ignore count again
	LoadAndSendFString	CFIgnoreString1
	pop		zl				;zl = Ignore count
	rcall	ConvertUByte	;Convert number in zl
	LoadAndSendFString	CFIgnoreString2	;Includes CRLF
FSNoIgnore:

	cpi		TempUa,60
	brsh	CFError			;Shouldn't ever exceed 60
	cpi		TempUa,30
	brlo	CFError			;Shouldn't be lower than 30

; Now count the transitions in 2000 counts
	ldiw	y,2000
	ldiw	z,BitBuffer
	clr		TempUa			;TransitionCount
	clr		TempLa			;Always zero
FSLoop2:
	ld		TempUb,z+		;Get the count
	cpi		TempUb,80		;Shouldn't ever exceed about 80
	brlo	FSOk2
	inc		TempUc			;Ignore this one
	rjmp	FSLoop2
FSOk2:
	incm	TempUa			;TransitionCount += 1 (but not over 255)
	sub		yl,TempUb		;y = y - count
	sbc		yh,TempLa
	brcc	FSLoop2
	
; Now TempUa should contain the frequency
	push	TempUc			;Save ignore count
	push	TempUa			;Save Frequency
	LoadAndSendFString	FreqString1
	pop		zl				;zl = Frequency
push zl
	rcall	ConvertUByte	;Convert number in zl
	LoadAndSendFString	FreqString2	;Includes CRLF
pop	TempUa
	pop		TempUc			;Restore ignore count
	tst		TempUc
	brze	FSNoIgnore2
	push	TempUc			;Save ignore count again
	LoadAndSendFString	CFIgnoreString1
	pop		zl				;zl = Ignore count
	rcall	ConvertUByte	;Convert number in zl
	LoadAndSendFString	CFIgnoreString2	;Includes CRLF
FSNoIgnore2:

	cpi		TempUa,60
	brsh	CFError			;Shouldn't ever exceed 60
	cpi		TempUa,30
	brlo	CFError			;Shouldn't be lower than 30

;	cpi		TempUa,30		;Shouldn't ever exceed 30
; The 38KHz cycle time is 26.3us which is a transition every 13.2us so count = 52(.63) @ 250ns
; The 40KHz cycle time is 25.0us which is a transition every 12.5us so count = 50 @ 250ns
;	mov		TempUa,Min0		;Calculate the average minimum of 0s and 1s
;	add		TempUa,Min1
;	lsr		TempUa			; / 2
;	cpi		TempUa,51
;	breq	CFError
;	brlo	CFIs40
;	LoadAndSendFString	Freq38String
;	ret
;CFIs40:
;	LoadAndSendFString	Freq40String
	ret

CFError:
	LoadAndSendFString	FreqErrorString
	ret

CFIntroString:		.DB	"Doing a fast sample with 4MHz (250nsec) timer (C=0)",CR,LF,0
CFIgnoreString1:	.DB	"  Ignored ",0
CFIgnoreString2:	.DB	" counts over 80 (20usec)",CR,LF,0
FreqErrorString:	.DB	"Cannot calculate modulation frequency",CR,LF,0
FreqString1:		.DB	"Modulation frequency is ",0
FreqString2:		.DB	"KHz",CR,LF,0


;*****************************************************************************
;
;	AI Decode		AI decode signal
;
;*****************************************************************************
;
AIDecode:

; Do a slow timed sample
	LoadAndSendFString	AIIntroString
	push	Divisor
;	ldi		TempUa,TC2ClkDiv128	;31.25KHz = 32us up to 8.2ms
	ldi		TempUa,TC2ClkDiv256	;15.625KHz = 64us up to 16ms
	mov		Divisor,TempUa
	rcall	TimedSample
	pop		Divisor
	brcs	AIError			;Error if carry set

	LoadAndSendFString	AIILString
	push	IgnoreLess
;	ldi		TempUa,10
	ldi		TempUa,5
	mov		IgnoreLess,TempUa
	rcall	SendAll			;Display the information and give them a chance to abort it
	pop		IgnoreLess
	brcs	AIError			;Error if carry set
	
	LoadAndSendFString	AIString
	ret

AIError:
	LoadAndSendFString	AIErrorString
	ret

;AIIntroString:	.DB	"Doing a slow sample with 31.25KHz (32usec) timer (C=5) which can time to 8.2ms",CR,LF,0
AIIntroString:	.DB	"Doing a slow sample with 15.625KHz (64usec) timer (C=6) which can time to 16ms",CR,LF,0
AIILString:		.DB	"Ignore counts less than 5 (320 usec)",CR,LF,0
AIErrorString:	.DB	"Cannot decode signal",CR,LF,0
AIString:		.DB	"If you think I can decode this by myself, you're pretty hopeful!!! :)",CR,LF,0


;*****************************************************************************

; Note: All lines not ending with a null (0) must have an even number of characters
BuffSizeString:	.DB	"Buffer size = ",0
BuffSizeString2:.DB	" bytes (for T command) = ",0
BuffSizeString3:.DB	" bits (for S/W commands)",CR,LF,0

DelayString:	.DB "Delay factor for high speed sample = ",0
					;12345678901234567890123456789012345678901234567890
DelayString2:	.DB	" (for S & W commands -- use D to change)",CR,LF
				.DB	"  Sample delay = 3.75 microseconds + 0.75 * above ",CR,LF
				.DB "    0 =  3.75 microseconds",CR,LF
				.DB	"    1 =  4.50 microseconds",CR,LF
;				.DB	"    2 =  5.25 microseconds",CR,LF
				.DB	"    3 =  6.00 microseconds",CR,LF
;				.DB	"    4 =  6.75 microseconds",CR,LF
;				.DB	"    5 =  7.50 microseconds",CR,LF
;				.DB	"    6 =  8.25 microseconds",CR,LF
				.DB	"    7 =  9.00 microseconds",CR,LF
;				.DB	"    8 =  9.75 microseconds",CR,LF
;				.DB	"    9 = 10.50 microseconds",CR,LF
				.DB	"   11 = 12.00 microseconds",CR,LF
				.DB	"   15 = 15.00 microseconds",CR,LF
				.DB	"   19 = 18.00 microseconds",CR,LF
;				.DB	"   23 = 21.00 microseconds",CR,LF
				.DB	"   27 = 24.00 microseconds",CR,LF
				.DB	"   31 = 27.00 microseconds",CR,LF
				.DB	"   35 = 30.00 microseconds",CR,LF
;				.DB	"   39 = 33.00 microseconds",CR,LF
				.DB	"   43 = 36.00 microseconds",CR,LF,0

DivisorString:	.DB	"Divisor for counter (for T command) = ",0
					;12345678901234567890123456789012345678
DivisorString2:	.DB	" (Use C to change)",CR,LF
				.DB	"  1 = Div    1 = 250ns ( 64us max)",CR,LF
				.DB	"  2 = Div    8 =   2us (512us max)",CR,LF
				.DB	"  3 = Div   32 =   8us (2.1ms max)",CR,LF
				.DB	"  4 = Div   64 =  16us (4.1ms max)",CR,LF
				.DB	"  5 = Div  128 =  32us (8.2ms max)",CR,LF
				.DB	"  6 = Div  250 =  64us ( 16ms max)",CR,LF
				.DB	"  7 = Div 1024 = 256us ( 65ms max)",CR,LF,0

IgnoreLessString: .DB "Ignore delays less than ",0

Char0String:	.DB	"Zero Character = '",0
Char1String:	.DB	"One Character = '",0
CharString:		.DB	"' (",0
CharString2:	.DB	")",CR,LF,0

;InitStateString:	.DB		"Initial state was ",0
;State0:				.DB		"Zero",CR,LF,0
;State1:				.DB		"One",CR,LF,0

HelpString:	; NOTE: Each line must have an even number of characters
			;		so that an extra NULL doesn't get inserted
			;12345678901234567890123456789012345678901234567890123456789012345678901234567890
	.DB		"HELP",CR,LF
	.DB		" `          Power off ",CR,LF
	.DB		" 0=ddd      Set 0 character (for S/W commands)",CR,LF
	.DB		" 1=ddd      Set 1 character (for S/W commands)",CR,LF
	.DB		" A          AI decode signal",CR,LF
			;12345678901234567890123456789012345678901234567890123456789012345678901234567890
	.DB		" C=c        Set counter divisor (1-7) (for T command) ",CR,LF
	.DB		" D=dd       Set sample delay = 3.75 microseconds + 0.75 * dd (for S/W commands) ",CR,LF
	.DB		" E          Display all EEPROM memory ",CR,LF
	.DB		" Eaaa(=vv)  Display/Set specified EEPROM memory address ",CR,LF
	.DB		"             (Can have multiple values separated by commas) ",CR,LF
;			;12345678901234567890123456789012345678901234567890123456789012345678901234567890
	.DB		" F          Calculate modulation frequency",CR,LF
	.DB		" I          Display Information ",CR,LF
	.DB		" L          Ignore less than",CR,LF
;			;12345678901234567890123456789012345678901234567890123456789012345678901234567890
	.DB		" M          SendMin/Max values",CR,LF
	.DB		" N          Display Named registers ",CR,LF
;			;12345678901234567890123456789012345678901234567890123456789012345678901234567890
	.DB		" R          Resend sample ",CR,LF
	.DB		" S          Sample now",CR,LF
	.DB		" T          Timed sample",CR,LF
	.DB		" V          Display Version numbers ",CR,LF
	.DB		" W          Wait for a transition and then sample ",CR,LF
;			;12345678901234567890123456789012345678901234567890123456789012345678901234567890
	.DB		" X          eXamine registers ",CR,LF
	.DB		" Zaaaa(=vv) Display/Set specified memory (or register or IO port) address ",CR,LF
	.DB		"             (Can have multiple values separated by commas) ",CR,LF
			;12345678901234567890123456789012345678901234567890123456789012345678901234567890
	.DB		"Numbers can be entered in decimal or in hexadecimal (PRECEDED by H) ",CR,LF
	.DB		CR,LF,0

BadMessage:		.DB		"Invalid command (Press ? for help)",CR,LF,0
BadParameter:	.DB		"Command has invalid parameter",CR,LF,0


; Must be at the end of the file
NextFlashAddress:	;Just to cause an error if the flash is overallocated
					; (NextFlashAddress should be address 1000H (FLASHEND+1) or lower)
