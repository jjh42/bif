;*****************************************************************************
;
;	Master.asm		Temporary 8535 master program for Robot
;
;	Communicates with at 2400 baud with three slaves: base, IR, and Speech
;
;	Written By:		Robert Hunt			February 2001
;
;	Modified By:	Robert Hunt
;	Mod. Number:	18
;	Mod. Date:		12 July 2001
;
;*****************************************************************************

; This program is written for an 8535 (40-pin analogue) with a 4MHz crystal
;	on Lincoln's little board

; This is version 0.0.1.5
.EQU	MajorVersion	= 0
.EQU	MinorVersion	= 0
.EQU	RevisionNumber	= 1
.EQU	FixNumber		= 5
;NOTE:	Must also change speech string at SPVersion

;*****************************************************************************
;
;	To Do
;		Add more demo modes
;		Add speed override
;		Further decode individual bumper/tilt switches
;		Not go forward if forward bumper switches already pressed
;		Make program error indicate error number somehow (computer comms???)
;		Clean up LCD display handling
;
;	Possible
;		Clean up LCD display handling for computer comms commands
;
;*****************************************************************************
;
;	Version History:
;
;	V0.0.1.5	xx July 2001	Fixed a couple of minor speaking errors
;
;	V0.0.1.4	12 July 2001	Tidied up some string handling to save code space
;								Moved speech strings to EEPROM, fixed intensity setting bug
;								Added second DEMO "speak" mode, announce which bumper/tilt switch is activated
;	V0.0.1.3	29 June 2001	Lengthened LCD reset time, fixed intensity setting
;								Fixed tilt switch detection, fixed UI bugs
;								Corrected timeout for SU buffer overflow in SendSUChar
;								Made PollTick a register variable, increased SlaveTxBuffer size
;	V0.0.1.2	26 June 2001	Added IR features, fixed bugs
;	V0.0.1.1	24 June 2001	Added IR features
;	V0.0.1.0	23 June 2001	Rewrote UI
;	V0.0.0.7	22 June 2001	Fixed bug with "lights" display on LCD
;	V0.0.0.6	22 June 2001	Fixed buffer overflow and other minor bugs
;	V0.0.0.5	18 June 2001	Added speech stuff
;	V0.0.0.4	1 April 2001	Added polling display switch
;	V0.0.0.3	31 March 2001	Some improvements in IR distance settings
;	V0.0.0.2	16 March 2001	Next try -- fixed bug in decoding IR replies
;	V0.0.0.1	16 March 2001	First try -- echoes all version request messages
;									No code for speech slave yet other than basic polling
;									Some diagnostic/dump routines can be still deleted for more code space
;
;*****************************************************************************
;
; Handles the following key sequences:
;	<Clear> (At any time independent of entry state)
;	<Halt> (At any time independent of entry state)
;
;	<Forward> (Optional ddddd) <Enter>
;	<Reverse> (Optional ddddd) <Enter>
;	<Straight> (Sets angle to zero)
;	<Angle> aaa <Enter> or <Angle><Query>
;	<Speed> sss <Enter> (Sets speed variable)
;xx	<Speed> <Speed> sss <Enter> (Overrides speed)
;	<Stealth> <Off>/<On>/<Query>
;	<Lights> <Off>/<On>/<Auto>/<Manual>/<Demo>/<0>=All off/<Query>
;	<Intensity> iii <Enter> or <Intensity><Demo>/<Query>>
;	<Query> <Lights>/<Power>/<Stealth>/<Forward>/<Speed>/<Intensity>/<Angle> or vv
;
;	<Diag> PIN <Enter> (Press <Diag> again to leave diagnostic mode)
;		<AS> <Off>/<On> (Autostop)
;		<TM> <Straight>=Turn&Straight/<Angle>=Circle/<2>=Extreme
;		<FB> <Forward>/<Reverse>/<Auto>
;		<Power> <1>=Low
;		<Power> Software reset
;xx		<Demo> Comms Diagnostic mode
;
;
;	<Help> NOT DONE YET
;
;	<Demo> (There are some duplicates here)
;		<Forward> Forward 10m
;		<Reverse> Reverse 10m
;		<Speed> Forward 500mm changing speeds
;		<0> = Forward/Reverse 500mm
;		<1> = Left 45 100mm
;xx		<2> = Forward 500mm changing speeds
;		<3> = Right 45 100mm
;		<4> = Left 90 100mm
;		<5> = 200mm right rectangle
;		<6> = Right 90 100mm
;		<7> = Left 135 100mm
;xx		<8> = Reverse 500mm changing speeds
;		<9> = Right 135 100mm
;		<Lights> or <Intensity> = Lights test mode
;		<+/-> = Switch front/back
;		<Left> = Turn left on spot
;		<Right> = Turn right on spot
;	The unlabelled buttons also do demo actions
;xx		(1) Turn left on spot
;xx		(2) Turn right on spot
;xx		(3) Zigzag
;
;	<Power> <Off>/<On>/<Auto>/<Manual>/<Query>
;
; The only keys which auto repeat are:
;xx	<Left>, <Right>, <Up>, <Down>
;
;*****************************************************************************

.nolist
.include	"C:\Program Files\Atmel\AVR Studio\appnotes\8535def.inc"
.include	"IR.inc"
.include	"sounds.inc"
.list
.listmac


;*****************************************************************************
;
;	Global Parameters
;
;*****************************************************************************
;
;.EQU	BS		= 0x08
.EQU	HT		= 0x09
.EQU	LF		= 0x0A
.EQU	CR		= 0x0D
.EQU	ESC		= 0x1B
;.EQU	DEL		= 0xFF

.EQU	SP_OVERRIDE	= 0xFF

.EQU	DegreeSymbol	= 0xDF	;For Hitachi LCD chip

; Battery voltage:	The indicator voltage is the battery voltage / 3.24
;					The 8-bit count is the battery voltage * 15.8
.EQU	BVLowThreshold		= 180	;Battery voltage low threshold 11.4V
.EQU	BVFullThreshold		= 196	;Battery voltage normal threshold 12.4V

; Charging Voltage: Normally zero -- anything over 120 should be charging
.EQU	ChargingThreshold	= 150	;Charging voltage threshold

.EQU	BaudRate = 2400


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
.EQU	SUBufferFullErrorCode			= 6
.EQU	TXBufferFullErrorCode			= 7
.EQU	LCDBufferFullErrorCode			= 8
.EQU	SWCaseErrorCode					= 9
.EQU	DMCaseErrorCode					= 10
.EQU	AssemblerErrorCode				= 11
;.EQU	RxBufferFullErrorCode			= 
;.EQU	SURxBufferFullErrorCode			= 
;.EQU	SURxFramingErrorCode			= 
;.EQU	InvalidFlashAddressErrorCode	= 
;.EQU	InvalidRAMAddressErrorCode		= 
;.EQU	ComRxLineOverflowErrorCode		= 
;.EQU	SlaveRxLineOverflowErrorCode		= 
;.EQU	SUTxBufferErrorCode				= 


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

.EQU	LCDTCCR		= TCCR0
.EQU	LCDTC		= TCNT0
.EQU	LCDTCIE		= TOIE0

.EQU	LCD40usPS		= TCClkDiv8		;For fast timeout < 512us in 2us steps
.EQU	LCD40usReload	= 236	;256 - 236 = 20
								;4000000 / 8 / 20 = 25,000 Hz = 40us

.EQU	LCDCharPS		= LCD40usPS		;Delay after sending a character
.EQU	LCDCharReload	= LCD40usReload

.EQU	LCD100usPS		= TCClkDiv8		;For fast timeout < 512us in 2us steps
.EQU	LCD100usReload = 206	;256 - 206 = 50
								;4000000 / 8 / 50 = 10,000 Hz = 100us

.EQU	LCD4ms1PS		= TC01ClkDiv256	;For slow timeout < 16ms in 64us steps
.EQU	LCD4ms1Reload 	= 192	;256 - 192 = 64
								;4000000 / 256 / 64 = 244.1 Hz = 4.1ms
;
;*****************************************************************************
;
; Timer/Counter-1 (16-bit)
;	Used for general system timer (1 ms)
.EQU	SYSTCCR		= TCCR1B
.EQU	SYSTCOCH	= OCR1AH
.EQU	SYSTCOCL	= OCR1AL
.EQU	SYSTCPS		= TCClkDiv1
.EQU	SYSTCCompare = 4000		;4000000 / 1 / 4000 = 1000 Hz = 1msec
.EQU	SYSTCIE		= OCIE1A
;
; Note that the beeper timer is first divided by 8 so it counts down every 8msec
.EQU	Beep0s1		= 12	;12 * 8msecs = 96msec
.EQU	Beep0s2		= 25	;25 * 8msecs = 200msec
.EQU	Beep0s3		= 37	;37 * 8msecs = 296msec
.EQU	Beep0s4		= 50	;50 * 8msecs = 400msec
.EQU	Beep0s5		= 62	;62 * 8msecs = 496msec
.EQU	Beep0s6		= 75	;75 * 8msecs = 600msec
.EQU	Beep1s		= 125	;125 * 8msecs = 1 second
.EQU	Beep2s		= 250	;250 * 8msecs = 2 seconds
;
;*****************************************************************************
;
; Timer/Counter-2/RTC (8-bit)
;	Used for baud rate for software UART and for beeper
;	Samples at 4 x baud rate, so 4 * 2400 = 9600
.EQU	SWUARTTCCR	= TCCR2
.EQU	SWUARTTCOC	= OCR2
.EQU	SWUARTPS	= TCClkDiv8
.EQU	SWUARTTCCompare = 52	;4000000 / 8 / 52 = 9615 Hz = 0.104ms
.EQU	SWUARTTCIE	= OCIE2
; This should be set the time it takes (in milliseconds) to send one char of software UART
; rounded up to the nearest millisecond.
.EQU	MSecPerSlaveChar	= 5	;4.1ms @ 2400 baud
;
; Note that the beeper pin can be toggled every interrupt (9600Hz)
; so the maximum frequency is the interrupt frequency divided by two = 4800Hz
.EQU	BeepSilent	= 255	;for the frequency count

.EQU	Beep160Hz	= 30	;4800 / 30 = 160
.EQU	Beep200Hz	= 24	;4800 / 24 = 200
.EQU	Beep240Hz	= 20	;4800 / 20 = 240
.EQU	Beep300Hz	= 16	;4800 / 16 = 300
.EQU	Beep400Hz	= 12	;4800 / 12 = 400
.EQU	Beep480Hz	= 10	;4800 / 10 = 480
.EQU	Beep600Hz	=  8	;4800 /  8 = 600
.EQU	Beep800Hz	=  6	;4800 /  6 = 800
.EQU	Beep960Hz	=  5	;4800 /  5 = 960
.EQU	Beep1200Hz	=  4	;4800 /  4 = 1200
.EQU	Beep1600Hz	=  3	;4800 /  3 = 1600
.EQU	Beep2400Hz	=  2	;4800 /  2 = 2400


;*****************************************************************************
;
;	A-to-D Convertor Control Definitions
;
;*****************************************************************************
;
; ADC Prescaler Selections		Frequency at 4MHz (Should be in range 50-200KHz)
.EQU	ADCPSDiv2	= 0b001		2MHz		500ns	;Too fast
.EQU	ADCPSDiv4	= 0b010		1MHz		1us		;Too fast
.EQU	ADCPSDiv8	= 0b011		500KHz		2us		;Too fast
.EQU	ADCPSDiv16	= 0b100		250KHz		4us		;Too fast
.EQU	ADCPSDiv32	= 0b101		125KHz		8us		; * 13 cycles = 104us
													; * 14 cycles = 112us
.EQU	ADCPSDiv64	= 0b110		62.5KHz		16us	; * 13 cycles = 208us
													; * 14 cycles = 224us
.EQU	ADCPSDiv128	= 0b111		31.25KHz	32us	;Too slow


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
; Port-A:
;	Pin-40	PA0 (ADC0)	AIn		Analog switches on remote control -- IGNORED
;	Pin-39	PA1 (ADC1)	AIn		Battery voltage
;	Pin-38	PA2 (ADC2)	AIn		Charge voltage
;	Pin-37	PA3 (ADC3)	Unused

;	Pin-36	PA4 (ADC4)	Unused
;	Pin-35	PA5 (ADC5)	Unused
;	Pin-34	PA6 (ADC6)	Out		PowerControl
;	Pin-33	PA7 (ADC7)	Out 	Beeper
;
.EQU	PortASetup	= 0b11000000

.EQU	AISwitch	= 0
.EQU	AIBattery	= 1
.EQU	AICharge	= 2
;
.EQU	PowerPort	= PORTA
.EQU	PowerPin	= 6
.EQU	BeepPort	= PORTA
.EQU	BeepPin		= 7
;
;*****************************************************************************
;
; Port-B:
;	Pin-1	PB0	(T0)	Out	LED
;	Pin-2	PB1	(T1)	Out	LED
;	Pin-3	PB2	(AIN0)	Out	LED
;	Pin-4	PB3	(AIN1)	Out	LED
;	Pin-5	PB4	(/SS)	Out	LED
;	Pin-6	PB5	(MOSI)	Out	LED
;	Pin-7	PB6	(MISO)	Out	LED
;	Pin-8	PB7	(SCK)	Out	LED Indicates RUNNING (on) vs SLEEP (off)
;
.EQU	PortBSetup	= 0b11111111

.EQU	RunningLED	= 7
.EQU	LEDPort		= PORTB
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
;	Pin-29	PC7	(TOSC2)	Out	TX	} (software UART -- 2400bps)
;
.EQU	PortCSetup = 0b10111111
;
.EQU	LCDPort = PORTC
.EQU	LCDEN   = 4		;PC4: Falling edge sensitive
.EQU	LCDRS   = 5		;PC5: 0=Commands, 1=Data
;
.EQU	SUPort	= PORTC
.EQU	SUInput	= PINC
.EQU	SURX	= 6		;PC6
.EQU	SUTX	= 7		;PC7
;
;*****************************************************************************
;
; Port-D:
;	Pin-14	PD0	(RXD)	In	19,200bps RXD RS-232 from computer
;	Pin-15	PD1	(TXD)	Out	19,200bps TXD RS-232 to computer
;	Pin-16	PD2	(INT0)	InP	Switch 1: Toggle Power Off/Low/Normal
;	Pin-17	PD3	(INT1)	InP	Switch 2: Toggle Lights Off/Normal/Full/Test
;	Pin-18	PD4	(OC1B)	InP	Switch 3: Toggle Stealth mode Off/On
;	Pin-19	PD5	(OC1A)	InP	Switch 4: Toggle AutoStop mode Off/On
;	Pin-20	PD6	(ICP)	InP	Switch 5: Toggle Turn-Straight/Circle Travel mode
;	Pin-21	PD7	(OC2)	InP	Switch 6: Toggle Diagnostics Off/On
;
;	Note: 		InP = Input with Pull-up resistor enabled
;
.EQU	PortDSetup = 0b00000000

.EQU	SwitchPort	= PIND
.EQU	SwitchBits	= 0b11111100


;*****************************************************************************
;
;	Register Assignments
;
;*****************************************************************************
;
;	R0		For general use (esp. with LPM instruction)
;	R1		Reserved for saving SREG in interrupt routines
;	R2		AI Done flag
;	R3		Store current digital switch reading  (Bits 7-2 are the six switches PD7-PD2)
;	R4		Store previous digital switch reading (Bits 7-2 are the six switches PD7-PD2)
;	R5		HaveComRxLine flag: 0=nothing, 1=line received
;	R6		HaveSlaveRxLine flag: 0=nothing, 1=line received
;	R7		TempLa: Temp 8-bit register for main program
;	R8		TempLb
;	R9		TempLc
;	R10		TempLd
;	R11		LCDUseTime (Remembers the seconds when the LCD was last used)
;	R12		LCDStatus
;	R13		StringOutControl
;	R14		Software UART Rx Byte
;	R15		Software UART Tx Byte
.DEF	ISRSRegSav		= r1
.DEF	AIDone			= r2
.DEF	ThisSwitches	= r3
.DEF	LastSwitches	= r4
.DEF	HaveComRxLine	= r5
.DEF	HaveSlaveRxLine	= r6
.DEF	TempLa			= r7
.DEF	TempLb			= r8
.DEF	TempLc			= r9
.DEF	TempLd			= r10
.DEF	LCDUseTime		= r11
.DEF	LCDStatus		= r12
		.EQU	LCDStartInit	= 2	;When it decrements to zero it is initialized
.DEF	StringOutControl = r13
		.EQU	OutToLCD	= 1
		.EQU	OutToTx		= 2
		.EQU	OutToSlaves	= 4
		.EQU	OutToBoth	= OutToTx + OutToSlaves
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
;	R20		Reserved for generating the beep frequency
;	R21		Parameter 8-bit register
;	R22		Software UART Rx Status
;	R23		Software UART Tx Status
.DEF	TempUa			= r16
.DEF	TempUb			= r17
.DEF	TempUc			= r18
.DEF	ISRTempU		= r19
.DEF	BeepFreqCounter	= r20
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
;	R24		Display polling flag
;	R25		Poll tick counter
;	R26	XL	Used for ISRs only
;	R27	XH	Used for ISRs only
;	R28	YL	}
;	R29	YH	} For general
;	R30	ZL	}	use
;	R31 ZH	}
.DEF	DisplayPolling	= r24
.DEF	PollTick		= r25	;Set to zero when poll sent (Counts up every millisecond)
	.equ	WFSRIdle = 0	;Must be 0
	.equ	WFSRWaitingForStart = 1
	.equ	WFSRWaitingForEnd = 2


;*****************************************************************************
;
;	SRAM Variable Definitions
;
; Total RAM = 512 bytes starting at 0060 through to 025F
;
;*****************************************************************************

	.DSEG

; Serial port buffers
.EQU	ComRxBufSiz		= 48	;Note: Maximum of 128 characters
								;Must be at least 32 bytes for DumpRegisters
ComRxBuf:		.byte	ComRxBufSiz	;MUST NOT CROSS 256 byte boundary
ComRxBufCnt:	.byte	1	;Number of characters in the buffer

.EQU	ComTxBufSiz		= 110	;Note: Maximum of 128 characters
ComTxBuf:		.byte	ComTxBufSiz	;MUST NOT CROSS 256 byte boundary
ComTxBufCnt:	.byte	1	;Number of characters in the buffer
ComTxBufO1:		.byte	1	;Offset to 1st character in buffer

.EQU	SlaveRxBufSiz	= 80	;Note: Maximum of 128 characters
SlaveRxBuf:		.byte	SlaveRxBufSiz	;MUST NOT CROSS 256 byte boundary
SlaveRxBufCnt:	.byte	1	;Number of characters in the buffer

.EQU	SlaveTxBufSiz	= 82	;Note: Maximum of 128 characters
SlaveTxBuf:		.byte	SlaveTxBufSiz	;MUST NOT CROSS 256 byte boundary
SlaveTxBufCnt:	.byte	1	;Number of characters in the buffer
SlaveTxBufO1:	.byte	1	;Offset to 1st character in buffer


; LCD
.EQU	LCDOutBufSiz	= 64	;Note: Maximum of 128 characters
						; 2 lines of 16 characters plus extra for two-byte commands
LCDOutBuf:		.byte	LCDOutBufSiz	;MUST NOT CROSS 256 byte boundary
LCDPastBuf:					;Must immediately follow buffer
LCDOutBufCnt:	.byte	1	;Number of characters in the buffer
LCDOutBufO1:	.byte	1	;Offset to 1st character in buffer
.EQU	LCDCommand	= 0xFF	;Indicates that the next char in LCDOutBuf is a command
	; Useful LCD Commands
	.EQU	LCDInit			= 0x28	;Initialize in 4-bit mode with 2 display lines
	.EQU	LCDIncrement	= 0x06	;Increment cursor position after writing a character
	.EQU	LCDCls			= 0x01	;Clear Screen
	.EQU	LCDHome1		= 0x02	;Home Cursor - 1st Line
	.EQU	LCDHome2		= 0xC0	;Home Cursor - 2nd line
	.EQU	LCDDisplayOff	= 0x08	;Display off, cursor off, blinking off
	.EQU	LCDCursorOn		= 0x0e	;Display on, cursor on, blinking off
	.EQU	LCDCursorOff	= 0x0c	;Display on, cursor off, blinking off
	.EQU	LCDShiftLeft	= 0x18	;Shift display left


; Beeper
.EQU	BeepBufSiz		= 8		;Note: Maximum of 64 2-byte units or 128 bytes
.EQU	BeepEntryLength	= 2		;Each entry is two bytes long
BeepBuf:				.byte	BeepBufSiz*BeepEntryLength	;MUST NOT CROSS 256 byte boundary
	;NOTE:	Each entry is two bytes long
	;			The first byte is the frequency count
	;			The second byte is the time count
BeepBufCnt:				.byte	1	;Number of two-byte ENTRIES in the buffer
BeepBufO1:				.byte	1	;Offset to 1st entry in buffer
BeepTimeRemaining:		.byte	1	;Time remaining before we need to turn off current beep
BeepFrequencyReload:	.byte	1


; Timers and Counters
SysTick:				.byte	2	;Counts up to 1000 milliseconds
	.EQU	SysTickl	= SysTick
;	.EQU	SysTickh	= SysTick+1
Seconds:				.byte	2	;Counts up to 65535 seconds (1092 minutes = 18.2 hours)
	.EQU	SecondsLSB = Seconds

; Slave pointers
SlavePollP:		.byte	2
	
; Slave timers
WaitingForSlaveReply:	.byte	1	;Yes/No flag

.equ	NumSlaves	= 3 ; Must be set to the number of slaves
GotSlaveVersionTimes:
; Must be in alphabetical order
; Must not go over 256 byte boundary
GotBaseVersionTime:		.byte	1	;Seconds counter for when last received version number from base slave
GotIRVersionTime:		.byte	1	;Seconds counter for when last received version number from IR slave
GotSpeechVersionTime:	.byte	1	;Seconds counter for when last received version number from speech slave

; Must not go over 256 byte boundary
; Slave dead flags
SlaveDeadFlags:
	.EQU	SDFUnknown	= 0		;(Default at power-up)
	.EQU	SDFAlive	= 1
	.EQU	SDFDead		= 2
; Must be in alphabetical order
BaseDeadFlag:	.byte	1	;Keeps track of whether the base slave is dead or alive
IRDeadFlag:		.byte	1	;Keeps track of whether the IR slave is dead or alive
SpeechDeadFlag:	.byte	1	;Keeps track of whether the speech slave is dead or alive

; AI variables
ThisAISwReading:		.byte	1	;MS 8-bits of the current switch A/D input
BattVoltageReading:		.byte	1	;MS 8-bits of last battery voltage reading
ChargeVoltageReading:	.byte	1	;MS 8-bits of last charging voltage reading
BVLowCount:				.byte	1	;Number of consecutive times for battery low

; Base slave control variables
PowerManual:	.byte	1	;Yes/no
LightsManual:	.byte	1	;Yes/no
PowerByte:		.byte	1	;Bits-7,6 = Unused
							;Bit-5 = Diagnostics: 0=Off, 1=On
							;Bit-4 = Stealth: 0=Off, 1=On
							;Bits-3,2 = Lights: 00=Off, 01=Normal, 10=Full, 11=Test
							;Bits-1,0 = Power: 00=Off, 01=Low, 10=Normal
	.EQU	DiagnosticBit	 = 0b00100000
	.EQU	NotDiagnosticBit = 0b11011111
		.EQU	DiagnosticsOff	= 0b00000000
		.EQU	DiagnosticsOn	= 0b00100000
	.EQU	StealthBit		= 0b00010000
	.EQU	NotStealthBit	= 0b11101111
		.EQU	StealthOff		= 0b00000000
		.EQU	StealthOn		= 0b00010000
	.EQU	LightBits		= 0b00001100
	.EQU	NotLightBits	= 0b11110011
	.EQU	LightBitsIncr	= 0b00000100
	.EQU	LightBitsOver	= 0b00010000
		.EQU	LightsOff		= 0b00000000
		.EQU	LightsNormal	= 0b00000100
		.EQU	LightsFull		= 0b00001000
		.EQU	LightsTest		= 0b00001100
	.EQU	PowerBits		= 0b00000011
	.EQU	NotPowerBits	= 0b11111100
	.EQU	PowerBitsIncr	= 0b00000001
	.EQU	PowerBitsOver	= 0b00000011		;(Since 11 is not used)
		.EQU	PowerOff		= 0b00000000
		.EQU	PowerLow		= 0b00000001
		.EQU	PowerNormal		= 0b00000010	;Note: 11 is not used

TravelByte:		.byte	1	;Bits-7,6,5 = Unused
							;Bit-4 = AutoStop: 0=Off, 1=On
							;Bits-3,2 = TravelMode 00=Turn&Straight, 01=Circle, 10=extreme
							;Bit-1 = FrontSwitchMode: 0=Manual, 1=Automatic
							;Bit-0 = Front: 0=Default, 1=Reverse
	.EQU	AutoStopBit			= 0b00010000
	.EQU	NotAutoStopBit		= 0b11101111
		.EQU	AutoStopOff			= 0b00000000
		.EQU	AutoStopOn			= 0b00010000
	.EQU	TravelModeBits		= 0b00001100
	.EQU	NotTravelModeBits 	= 0b11110011
	.EQU	TravelModeBitsIncr	= 0b00000100
	.EQU	TravelModeBitsOver	= 0b00001100		;(Since 11 is not used)
		.EQU	TravelModeTS		= 0b00000000
		.EQU	TravelModeC			= 0b00000100
		.EQU	TravelModeX			= 0b00001000	;Note: 11 is not used
	.EQU	FrontSwitchModeBit	= 0b00000010
	.EQU	NotFrontSwitchModeBit = 0b11111101
		.EQU	FrontSwitchMan		= 0b00000000
		.EQU	FrontSwitchAuto 	= 0b00000010
	.EQU	FrontBit			= 0b00000001
	.EQU	NotFrontBit			= 0b11111110
		.EQU	FrontDefault		= 0b00000000
		.EQU	FrontReverse		= 0b00000001
	.EQU	FrontSwitchModeBits    = 0b00000011		;(Combined)
	.EQU	NotFrontSwitchModeBits = 0b11111100


Speed:				.byte	1	;0-255
Angle:				.byte	2	;0-360 degrees
	.EQU	AngleLSB = Angle
	.EQU	AngleMSB = Angle+1
Distance:			.byte	2	;0-65535 mm
	.EQU	DistanceLSB = Distance
	.EQU	DistanceMSB = Distance+1
HeadlightIntensity:	.byte	1	;0-255
LeftMotorSpeed:		.byte	2	;-255...0...+255
	.EQU	LeftMotorSpeedLSB = LeftMotorSpeed
	.EQU	LeftMotorSpeedMSB = LeftMotorSpeed+1
RightMotorSpeed:	.byte	2	;-255...0...+255
	.EQU	RightMotorSpeedLSB = RightMotorSpeed
	.EQU	RightMotorSpeedMSB = RightMotorSpeed+1

DisplayMode:	.byte	1
	.EQU	DMIdle		= 0	;Must be zero
	.EQU	DMForward	= 1
	.EQU	DMReverse	= 2
	.EQU	DMAngle		= 3
	.EQU	DMSpeed		= 4
	.EQU	DMStealth	= 5
	.EQU	DMLights	= 6
	.EQU	DMIntensity	= 7
	.EQU	DMDiagnostics = 8
	.EQU	DMAutoStop	= 9
	.EQU	DMTravelMode = 10
	.EQU	DMFrontBackMode = 11
	.EQU	DMHelp		= 12
	.EQU	DMDemo		= 13
	.EQU	DMPower		= 14
	.EQU	DMQuery		= 15
	.EQU	DMSpeakW	= 16
	.EQU	DMSpeakS	= 17
;DisplayValue:	.byte	2	;To remember our current setting
;	.EQU	DisplayValueLSB = DisplayValue
;	.EQU	DisplayValueMSB = DisplayValue+1
; When display is a signed 8-bit value or angle the high byte is set to 1 if
; the value is negative or 0 is the value is positive. For motor speed
; negative means backwards and for angle negative means to the left.
;	.EQU	DMFBAuto	= 2
;	.EQU	DMFBBack	= 1
;	.EQU	DMFBFront	= 0 
;	.EQU	DMFBInvalid	= 3	; Must be the last value
EntryStatus:			.byte	1
	.EQU	ESIdle		= 0
	.EQU	ESDecimal	= 1
	.EQU	ESPIN		= 2
	.EQU	ESDone		=0xFF
MinEntryCharacters:	.byte	1
MaxEntryCharacters:	.byte	1
MinValue:			.byte	2
MaxValue:			.byte	2
NumEnteredCharacters:	.byte	1
EntryBuffer:		.byte	10		;Must not cross a 256-byte boundary
EnteredSign:		.byte	1	;0=plus, non-zero=minus
EnteredValue:		.byte	2
	.EQU	EnteredValueLSB = EnteredValue
	.EQU	EnteredValueMSB = EnteredValue+1


; IR slave control variables
HaveIR:	.byte	1	;Boolean: 0=false or non-zero=true
IRByte:	.byte	1	;See IR.inc for possible values
	

; Error Counters (All initialized to zero when RAM is cleared at RESET)
RxBufferOverflowErrorCount:		.byte	1
ComLineOverflowErrorCount:		.byte	1
SUFramingErrorCount:			.byte	1
SUParityErrorCount:				.byte	1
SURxBufferOverflowErrorCount:	.byte	1
SULineOverflowErrorCount:		.byte	1
SlaveCommsErrorCount:			.byte	1
.EQU	RxBufferOverflowErrorCode	= 'b'
.EQU	ComLineOverflowErrorCode	= 'l'
.EQU	SUFramingErrorCode			= 'F'
.EQU	SUParityErrorCode			= 'P'
.EQU	SURxBufferOverflowErrorCode	= 'B'
.EQU	SULineOverflowErrorCode		= 'L'
.EQU	SlaveCommsErrorCode			= 'S'

; Miscellaneous variables
StickyDemo:	.byte	1	;True/False
ConvString:	.byte	6	;Storage for null-terminated conversion string
							; (Sign plus five digits plus null)

; This next variable is here for error checking
;  (If it is not equal to RandomByteValue, then the stack has overflowed)
StackCheck:		.byte	1	;For error checking only -- contents should never change
	.EQU	RandomByteValue	= 0x96
Stack:			.byte	24	;Make sure that at least this many bytes are reserved for the stack
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

LCDSetupString:	.DB		LCDCommand,LCDIncrement	;"Increment" entry mode
				.DB		LCDCommand,LCDCursorOff
LCDHeaderString:.DB		LCDCommand,LCDCls
				.DB		" Robot Master "			;Must be an even number of characters
				.DB		LCDCommand,LCDHome2,"   V"	;Must be an even number of characters
	.DB	MajorVersion+'0','.',MinorVersion+'0','.',RevisionNumber+'0','.',FixNumber+'0',0

BatteryLowLCDString:		.DB		LCDCommand,LCDHome2
BLLCDString:				.DB		LCDCommand,0x80+0x40+14,"L",0
BCLCDString:				.DB		LCDCommand,0x80+0x40+15,"C",0
DLCDString:					.DB		LCDCommand,0x80+0x40+13,"D",0

LCDLightString:					.DB		LCDCommand,LCDCls,"Lights",LCDCommand,LCDHome2,0
LCDPowerString:					.DB		LCDCommand,LCDCls,"Power",LCDCommand,LCDHome2,0
LCDDemoString:					.DB		LCDCommand,LCDCls,"Demo",LCDCommand,LCDHome2,0
LCDStealthString:				.DB		LCDCommand,LCDCls,"Stealth",LCDCommand,LCDHome2,0
LCDIntensityString:				.DB		LCDCommand,LCDCls,"Intensity",LCDCommand,LCDHome2,0
LCDSpeedString:					.DB		LCDCommand,LCDCls,"Speed",LCDCommand,LCDHome2,0
LCDDiagnosticString:			.DB		LCDCommand,LCDCls,"Diag.",LCDCommand,LCDHome2,0
LCDAutoStopString:				.DB		LCDCommand,LCDCls,"AutoStop",LCDCommand,LCDHome2,0
LCDTravelModeString:			.DB		LCDCommand,LCDCls,"Travel",LCDCommand,LCDHome2,0
;LCDLeftMotorSpeedModeString:	.DB		LCDCommand,LCDCls,"Left Speed",LCDCommand,LCDHome2,0
;LCDRightMotorSpeedModeString:	.DB		LCDCommand,LCDCls,"Right Speed",LCDCommand,LCDHome2,0
;LCDSpeedModeString:			.DB		LCDCommand,LCDCls,"Speed",LCDCommand,LCDHome2,0
;LCDDistanceModeString:			.DB		LCDCommand,LCDCls,"Distance",LCDCommand,LCDHome2,0
;LCDAngleModeString:			.DB		LCDCommand,LCDCls,"Angle",LCDCommand,LCDHome2,0
LCDFBSwitchModeString:			.DB		LCDCommand,LCDCls,"F/B sw",LCDCommand,LCDHome2,0
;LCDIntensityModeString:		.DB		LCDCommand,LCDCls,"Intensity",LCDCommand,LCDHome2,0

ForwardString:			.DB		"Forward ",0
BackwardString:			.DB		"Backward ",0


;*****************************************************************************
;
;	Speech Strings
;
;*****************************************************************************

SPVersion:		.DB	SP_robot,WordPause,SP_version,WordPause	;Each line here must contain an
				.DB	SP_zero,WordPause,SP_point,WordPause	; even number of bytes
				.DB	SP_zero,WordPause,SP_point,WordPause
				.DB	SP_one,WordPause,SP_point,WordPause
				.DB	SP_five,SentencePause,0
SPGreeting:		.DB	SP_hello,WordPause,PH_AY,WordPause,SP_am,WordPause,SP_robot,WordPause,0

SPTellLights:	.DB	SP_the,WordPause,SP_light,PH_s,WordPause,SP_are,WordPause,0
SPTellLightsPower: .DB	SP_but,WordPause,SP_the,WordPause,SP_power,WordPause,SP_is,WordPause,SP_low,0
SPTellPower1:	.DB	SP_the,WordPause,SP_power,WordPause,SP_is,WordPause,0
SPTellPower2:	.DB	SentencePause,SP_battery,WordPause,SP_level,WordPause,SP_is,WordPause,0
SPTellPower3:	.DB	WordPause,SP_and,WordPause,SP_charging,WordPause,SP_at,WordPause,0

SPDistance:		.DB	SP_distance,WordPause,SP_is,WordPause,0
SPZeroDistance:	.DB	SP_error,WordPause,SP_distance,WordPause,SP_is,WordPause,SP_zero,0
SPmm:			.DB	SP_millimetre,PH_z,0

SPTooSmall:		.DB	SP_error,WordPause,SP_number,WordPause,SP_is,WordPause,SP_two,SP_small,0
SPTooBig:		.DB	SP_error,WordPause,SP_number,WordPause,SP_is,WordPause,SP_two,SP_big,0

SPSticky:		.DB	PH_s,PH_t,PH_IH,PH_k,PH_IY,0

SPOn:			.DB	SP_on,SentencePause,0
SPOff:			.DB	SP_off,SentencePause,0

SPLow:			.DB SP_low,SentencePause,0

SPNormal:		.DB	SP_normal,SentencePause,0
SPFull:			.DB	SP_full,SentencePause,0
SPTest:			.DB SP_test,SentencePause,0

SPInvalid:		.DB	SP_in,SP_valid,0

SPBattery:		.DB	SP_battery,WordPause,0

SPPower:		.DB	SP_OVERRIDE,SP_power,WordPause,0
SPLights:		.DB	SP_OVERRIDE,SP_light,PH_s,WordPause,0
;SPIntensity:	.DB	SP_intensity,0
SPStealth:		.DB	SP_OVERRIDE,SP_stealth,WordPause,SP_mode,WordPause,0
SPAutoStop:		.DB	SP_automatic,WordPause,SP_stop,WordPause,0
SPTravelMode:	.DB	SP_travel,SP_mode,WordPause,0
	SPTMTS:			.DB	SP_turn,WordPause,SP_and,WordPause,SP_straight,0
	;SPTMC:			.DB	SP_circle,0
	;SPTMX:			.DB	SP_extreme,0
SPFBSwitchMode:	.DB	SP_front,SP_back,SP_switch,SP_mode,WordPause,0
SPDemo:			.DB	SP_demo,WordPause,0
SPDiagnostics:	.DB	SP_diagnostic,PH_s,0
SPQuery:		.DB	SP_query,WordPause,0
SPHelp:			.DB	SP_sorry,SentencePause,SP_no,WordPause,SP_help,WordPause,SP_yet,SentencePause,0

SPSpeak:		.DB	WordPause,SP_speak		;} (Must be even)
SPWPMode:		.DB	WordPause,SP_mode,0		;}

SPBumperSwitch:	.DB SP_OVERRIDE,SP_ouch,SentencePause,SP_bumper,WordPause,SP_switch,0
SPTiltSwitch:	.DB SP_OVERRIDE,SP_help,WordPause,SP_help,SentencePause,SP_tilt,WordPause,SP_switch,0


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

.MACRO	clrsw	;Clear SRAM Word (using TempUa)
				; e.g. clrsw	temp
	clr		TempUa
	sts		@0,TempUa
	sts		@0+1,TempUa
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

.MACRO	ldfp	;LoaD Flash Pointer into a register pair
				; e.g. ldfp	z,StringName

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

.MACRO	LoadAndSendTxFString
				;	e.g. LoadAndSendTxFString	StringName
	; Uses z
	ldi		zl,low(@0<<1)
	ldi		zh,high(@0<<1)
	rcall	SendTxFString	;Uses: R0, y, z, TempUa, TempUb, TempUc, ParamReg
.ENDMACRO

;.MACRO	LoadAndSendLCDFString
;				;	e.g. LoadAndSendLCDFString	StringName
;	; Uses z
;	ldi		zl,OutToLCD
;	mov		StringOutControl,zl
;	ldi		zl,low(@0<<1)
;	ldi		zh,high(@0<<1)
;	rcall	SendFString	;Uses: R0, y, z, TempUa, TempUb, TempUc, ParamReg
;.ENDMACRO

.MACRO	LoadAndSendLCDEString
				;	e.g. LoadAndSendLCDEString	StringName
	; Uses z
	ldi		zl,low(@0)
	ldi		zh,high(@0)
	rcall	SendLCDEString	;Uses: R0, y, z, TempUa, TempUb, TempUc, ParamReg
.ENDMACRO

.MACRO	LoadAndSendLCDTxFString
				;	e.g. LoadAndSendLCDTxFString	StringName
	; Uses z
	ldi		zl,low(@0<<1)
	ldi		zh,high(@0<<1)
	rcall	SendLCDTxFString	;Uses: R0, y, z, TempUa, TempUb, TempUc, ParamReg
.ENDMACRO

;.MACRO	LoadAndSpeakFString
;				;	e.g. LoadAndSpeakFString	StringName
;	; Uses z
;	ldi		zl,low(@0<<1)
;	ldi		zh,high(@0<<1)
;	rcall	SpeakFString
;.ENDMACRO

.MACRO	LoadAndSpeakEString
				;	e.g. LoadAndSpeakEString	StringName
	; Uses z
	ldi		zl,low(@0)
	ldi		zh,high(@0)
	rcall	SpeakEString
.ENDMACRO

.MACRO	SayWord
				;	e.g. SayWord	SP_off
	; Uses ParamReg
	ldi		ParamReg,@0
	rcall	SpeakWord
.ENDMACRO

.MACRO	DoBeep
				;	e.g. DoBeep	Beep1200Hz,Beep0s2
	; Uses ParamReg, TempUa, TempUb, TempUc, y
	ldi		ParamReg,@0
	ldi		TempUa,@1
	rcall	Beep		;Changes: TempUb, TempUc, y
.ENDMACRO

; Check for operational errors
.MACRO	CheckError
	lds		TempUa,@0ErrorCount
	tst		TempUa
	breq	PC+7
	; The error count is non-zero -- advise the user
	ldi		zl,low((@0ErrorString)<<1)
	ldi		zh,high((@0ErrorString)<<1)
	rcall	SendTxFString
	clr		TempUa
	sts		@0ErrorCount,TempUa
	;The breq instruction should reach here to the end
.ENDMACRO

; Set DisplayMode
.MACRO	SetDM
	ldi		TempUa,@0
	sts		DisplayMode,TempUa
.ENDMACRO

; Set EntryStatus
.MACRO	SetES
	ldi		TempUa,@0
	sts		EntryStatus,TempUa
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
 Reset:
 	rjmp	ResetCont
 .ORG 	INT0addr
	reti
 .ORG 	INT1addr
	reti
 .ORG 	OC2addr
	rjmp	ISR_SU			;Software UART
 .ORG 	OVF2addr
	reti
 .ORG 	ICP1addr
	reti
 .ORG 	OC1Aaddr
	rjmp	ISR_ST			;System Timer
 .ORG 	OC1Baddr
	reti
 .ORG 	OVF1addr
	reti
 .ORG 	OVF0addr
	rjmp	ISR_LCDT		;LCD Timer
 .ORG 	SPIaddr
	reti
 .ORG 	URXCaddr
	rjmp	ISR_URXC		;RX Char
 .ORG 	UDREaddr
	rjmp	ISR_UDRE		;TX ready
 .ORG 	UTXCaddr
	reti
 .ORG 	ADCCaddr
	rjmp	ISR_ADCC		;A/D Complete

;*****************************************************************************
;*****************************************************************************
;
;	Version Number Strings
;
;	(Placed early in the code so they're easy to find)
;
;*****************************************************************************
;*****************************************************************************

DiagString:		.DB		CR,LF,"DIAGNOSTIC MODE ";Must be an even number of characters
												; (so it's not padded with a null)
StartString:	.DB		CR,LF					;Must be an even number of characters
HeaderString:	.DB		"Robot Master V"		;Must be an even number of characters
	.DB	MajorVersion+'0','.',MinorVersion+'0','.',RevisionNumber+'0','.',FixNumber+'0',CR,LF,0


;*****************************************************************************
;*****************************************************************************
;
;	Start of Program Proper
;
;*****************************************************************************
;*****************************************************************************

ResetCont:
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
; Setup IO Ports
;
;*****************************************************************************

; Port-A is all inputs except bits 7=beeper output, 6=power output, and 5=remote LED output
	ldi		TempUa,PortASetup
	out		DDRA,TempUa
	ldi		TempUa,0b11000000	;Bits-7&6 should be high initially
	out		PORTA,TempUa

; Port-B is all outputs
	ldi		TempUa,PortBSetup
	out 	DDRB,TempUa
;	out		LEDPort,TempUa	;Set all bits high to turn LEDs off
	
; Port-C is all outputs except PC6 which is Software UART RX
	ldi		TempUa,PortCSetup
	out 	DDRC,TempUa
	ldi		TempUa,0b11000000	;Set Tx bit high, LCD control & data bits low
	out		PORTC,TempUa		; Also turns on the internal pull-up for bit-6 (SU Rx)

; Port-D is all inputs (except PD1 which is set by the UART as TXD)
	ldi		TempUa,PortDSetup
	out		DDRD,TempUa

; Port-D needs pull-up resistors on the upper six bits used for switches
;	ldi		TempUa,SwitchBits
;	out		PORTD,TempUa


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


; Check that the assembler has its labels right
	ldfp	z,AssemblerErrorCheck
	lpm
	mov		TempUa,r0
	cpi		TempUa,123
	breq	AssemblerOk
	ldi		ParamReg,AssemblerErrorCode
	rcall	ProgramError
	; Continue operation even though we will have some problems
AssemblerOk:


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
	ldi		TempUa,high(SlaveTxBuf)
	cpi		TempUa,high(SlaveTxBufCnt)
	brne	RAMAllocationError
	ldi		TempUa,high(SlaveRxBuf)
	cpi		TempUa,high(SlaveRxBufCnt)
	brne	RAMAllocationError
	ldi		TempUa,high(LCDOutBuf)
	cpi		TempUa,high(LCDOutBufCnt)
	brne	RAMAllocationError
	ldi		TempUa,high(BeepBuf)
	cpi		TempUa,high(BeepBufCnt)
	brne	RAMAllocationError
	ldi		TempUa,high(GotBaseVersionTime)
	cpi		TempUa,high(GotSpeechVersionTime)
	brne	RAMAllocationError
	ldi		TempUa,high(BaseDeadFlag)
	cpi		TempUa,high(SpeechDeadFlag)
	brne	RAMAllocationError
	ldi		TempUa,high(EntryBuffer)
	cpi		TempUa,high(EnteredSign)
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
	ldi		SURxStatus,SURxIdle
	ldi		SUTxStatus,SUTxIdle


;*****************************************************************************
;
;	Initialize RAM Variables
;
;*****************************************************************************

; Zeroize all of the RAM (including the stack but doesn't matter yet)
	ldiw	z,0x60			;The 512 bytes RAM go from 0060 to 025F
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

	; Initialize the two base control bytes
	ldi		TempUa,0b000110	;Diagnostics 0=Off, Stealth 0=Off, Lights 01=Normal, Power 10=Normal
	sts		PowerByte,TempUa
	ldi		TempUa,0b10000	;AutoStop 1=On, TravelMode 00, FrontSwitch 0=Manual, Front 0=Default
	sts		TravelByte,TempUa

	; Initialize the other base control parameters
	ldiw	z,500
	stsw	Distance,z					;Default distance of 500mm = 0.5m = 0x01F4
	ldi		TempUa,255
	sts		Speed,TempUa				;Default speed of 255 (100%) = 0xFF
	sts		HeadlightIntensity,TempUa	;Default headlight intensity of 255 (full brightness)

	; Initialize slave control pointer
	ldfp	z, SlavePollList
	stsw	SlavePollP, z


;*****************************************************************************
;
;	Setup Timer/Counters
;
;*****************************************************************************

; Set System Timer/Counter which runs all the time
	ldi 	TempUa,SYSTCPS | (1<<CTC1)		; Set the clock PreScaler and CounTer Compare
	out 	SYSTCCR,TempUa

	ldiw 	z,SYSTCCompare
	out 	SYSTCOCH,zh 	;The high byte must be written first
	out 	SYSTCOCL,zl

; Set Software UART Timer/Counter which runs at four times the baud rate
	ldi 	TempUa,SWUARTPS | (1<<CTC2)		; Set the clock PreScaler and CounTer Compare
	out		SWUARTTCCR,TempUa
	
	ldi		TempUa,SWUARTTCCompare
	out		SWUARTTCOC,TempUa

; Enable interrupts for these timers	
	in  	TempUa,TIMSK		;Clear the interrupt mask (Set the bit)
	ori 	TempUa,(1 << SYSTCIE) | (1<< SWUARTTCIE)
	out 	TIMSK,TempUa		;These stay cleared all the time
	
	
;*****************************************************************************
;
;	Setup the LCD
;
;	Starts the initialization sequence by sending the first initialization
;		code and starting the LCD timer to interrupt after 4.1msec.
;
;*****************************************************************************

; Send the first initialization command
	ldi		ParamReg,LCDInit	;Function set command
	rcall	LCDCommandByteOut	;Send it

; Now we need to schedule a 4.1 msec delay
	ldi		TempUa,LCD4ms1PS
	out 	LCDTCCR,TempUa		;Set the clock PreScaler
	ldi		TempUa,LCD4ms1Reload
	out 	LCDTC,TempUa		;Load the value
	
	ldi		TempUa,LCDStartInit	;Remember what we're doing
	mov		LCDStatus,TempUa

	in  	TempUa,TIMSK		;Clear the interrupt mask (Set the bit)
	ori 	TempUa,(1 << LCDTCIE)
	out 	TIMSK,TempUa		;This stays cleared all the time


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
;	Setup the A-to-D convertor
;
;	The first conversion takes longer than successive ones
;
;*****************************************************************************

	; Enable the ADC and start a conversion to give an interrupt when finished
	clr		TempUa				;Start with channel zero
	out		ADMUX,TempUa
	ldi		TempUa,(1<<ADEN)+(1<<ADSC)+(1<<ADIE)+ADCPSDiv64
	out		ADCSR,TempUa		;Set ADC Control and Status Register

	
;*****************************************************************************
;
;	Finished the setup routine
;
;*****************************************************************************

;	sei				;Enable interrupts now
	;rjmp	Main

;*****************************************************************************
;*****************************************************************************
;
;	Main Program
;
;*****************************************************************************
;*****************************************************************************

;Main:
;	cbi		LEDPort,RunningLED ;Turn RUNNING LED on (indicates reached Main)

; Send a CR to the slaves to make sure their buffers are cleared
	ldi		ParamReg,CR
	rcall	SendSUChar	;Will enable interrupts

;*****************************************************************************

; Check for special diagnostic mode
;	in		TempUa,SwitchPort
;	andi	TempUa,0b10000000	;Get switch PD7 only
;	brze	MainDiag			;Diagnostic mode if it's on (pulled low)
	rjmp	MainNormal			;Normal mode if it's off

; We're in the special diagnostic mode
MainDiag:

; Wait until all the switches are off again
;MainDiagWait1:
;	in		TempUa,SwitchPort
;	andi	TempUa,SwitchBits	;Get switches PD7-PD2 only
;	cpi		TempUa,SwitchBits	;See if they're all off
;	brne	MainDiagWait1

; Play a little tune again
	DoBeep	Beep1200Hz,Beep0s2
	DoBeep	Beep600Hz,Beep0s2
	DoBeep	Beep480Hz,Beep0s2
	DoBeep	Beep800Hz,Beep0s2
	DoBeep	Beep600Hz,Beep0s3

; Display the version number, etc.
	LoadAndSendTxFString	DiagString
	LoadAndSendLCDEString	LCDSetupString

;*****************************************************************************

MainDiagLoop:
; Check for operational errors if the Tx buffer is empty
	lds		TempUa,ComTxBufCnt
	tst		TempUa
	brnz	NoDiagCheck
	CheckError	RxBufferOverflow
	CheckError	ComLineOverflow
	CheckError	SUFraming
	CheckError	SUParity
	CheckError	SURxBufferOverflow
	CheckError	SULineOverflow
NoDiagCheck:

; Send stuff back and forward from the two comms
	lds		TempUa,ComRxBufCnt ;See how many characters there are
	tst		TempUa
	brze	NoComRx
	lds		ParamReg,ComRxBuf	;Get the first character from comms
	cpi		ParamReg,ESC		;Is it ESC?
	breq	MainNormal			;Yes, ESC from diagnostic mode
	cpi		ParamReg,'@'		;Is it @?
	brne	NotDiagAt			;No, branch
	rjmp	Reset				;Yes, reset
NotDiagAt:
	cpi		ParamReg,'`'		;Is it this?
	brne	NotPD
	rcall	DoPowerDownSeq		;Yes, do power down sequence
	rjmp	DontSend
NotPD:
	rcall	SendSUChar			;Calculate parity and send it to the base
DontSend:
	clr		HaveComRxLine
	sts		ComRxBufCnt,HaveComRxLine
NoComRx:

	lds		TempUa,SlaveRxBufCnt ;See how many characters there are
	tst		TempUa
	brze	NoBaseRx
	lds		ParamReg,SlaveRxBuf	;Get the first character from the base
	rcall	SendTxChar			;Send it to the comms
	clr		HaveSlaveRxLine
	sts		SlaveRxBufCnt,HaveSlaveRxLine
NoBaseRx:

; Check for power-off command
;	in		TempUa,SwitchPort
;	cpi		TempUa,0b00110000	;Switches 7,6,3,2 on
;	brne	NotDiagPowerDown	;No, continue as usual
;	rcall	DoPowerDownSeq		;Yes, do power down sequence
;NotDiagPowerDown:

; Check for command to return to normal mode
;	in		TempUa,SwitchPort
;	andi	TempUa,0b01000000	;Get switch PD6 only
;	brze	MainDiagWait2		;Branch if it's on
	rjmp	MainDiagLoop		;Stay in diagnostics if it's off

; Wait until all the switches are off again
;MainDiagWait2:
;	in		TempUa,SwitchPort
;	andi	TempUa,SwitchBits	;Get switches PD7-PD2 only
;	cpi		TempUa,SwitchBits	;See if they're all off
;	brne	MainDiagWait2

;*****************************************************************************

; We're in normal master running mode
MainNormal:

; Play a little tune
	DoBeep	Beep480Hz,Beep0s3
	DoBeep	Beep600Hz,Beep0s3
	DoBeep	BeepSilent,Beep0s3
	DoBeep	Beep800Hz,Beep0s3
	DoBeep	Beep1200Hz,Beep0s3
	DoBeep	BeepSilent,Beep0s3
	DoBeep	Beep480Hz,Beep0s6
	DoBeep	BeepSilent,Beep1s

; Display the version number, etc.
	LoadAndSendTxFString	StartString
	LoadAndSendLCDEString	LCDSetupString

; Initialize slave modules
; Note: These are also automatically initialized when start responding
;		but initialize now anyway (in case they can't transmit for some reason)
	rcall	InitializeBase
	;rcall	InitializeIR
	rcall	InitializeSpeech	

	LoadAndSpeakEString	SPGreeting			;Say the greeting


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
	rcall	NonFatalProgramError	;Display the error code on the LEDs
									; and then enable interrupts, return, and try running again
	ldi		TempUa,RandomByteValue
	sts		StackCheck,TempUa		;Reset the stack check variable
StackOk:


;*****************************************************************************
;
;	Check the LCD Use Timer
;
;*****************************************************************************

	lds		TempUa,SecondsLSB
	sub		TempUa,LCDUseTime
	cpi		TempUa,12
	brlo	LCDOk
	lds		TempUa,DisplayMode
	cpi		TempUa,DMIdle
	breq	LCDCont
	;LoadAndSpeakEString	SPReset	;Say "reset" if clearing a non-idle mode
	SayWord	SP_reset	;Say "reset" if clearing a non-idle mode
LCDCont:	
	rcall	LCDReset	;Also resets LCDUseTime
LCDOk:

;*****************************************************************************

; Check for operational errors if the Tx buffer is empty
	lds		TempUa,ComTxBufCnt
	tst		TempUa
	brze	Check
Check:
	rjmp	NoCheck
	CheckError	RxBufferOverflow
	CheckError	ComLineOverflow
	CheckError	SUFraming
	CheckError	SUParity
	CheckError	SURxBufferOverflow
	CheckError	SULineOverflow
	CheckError	SlaveComms
NoCheck:

;*****************************************************************************

	rcall	CheckInputs
	rcall	CheckAllComms

;*****************************************************************************

; Check if the slave comms is idle
	lds		TempUa,WaitingForSlaveReply
	cpi		TempUa, WFSRWaitingForStart
	brne	NotWaitingForStart

; We are waiting for a reply
	cpi		PollTick,(MSecPerSlaveChar * 20)	;Has it been 4 (3 for sending plus 1 for receiving) (+1 for the asynchrounous timer) chars of time
	brsh	SC_Idle2
	rjmp 	SlaveCommsNotIdle	;No, keep waiting
SC_Idle2:

; We have timed out waiting for a poll or version reply
	ldi		TempUa, WFSRIdle
	sts		WaitingForSlaveReply,TempUa

NotWaitingForStart:
	; Check if we are waiting for the end of a byte
	; There is a small gap between WaitingForSlaveReply
	; being set to 2 and the finished byte being received
	cpi		TempUa, WFSRWaitingForEnd	; TempUa was loaded above
	breq	PCheckForTimeout

	lds		TempUa,SlaveRxBufCnt
	lds		TempUb,SlaveTxBufCnt
	or		TempUb,TempUa		;Don't send one yet if we've got other traffic
	brze	IsIdle
	; The comms are not idle so check if it is the Rx that is holding us up (ie we are waiting for the end of a message)
	tst		TempUa
	brze	SC_NotIdle
	; It is holding us up - check for a timeout
PCheckForTimeout: ; Comes here when WaitForSlaveReply is set to WSFRWaitingForEnd
	cpi		PollTick,(MSecPerSlaveChar * 40) ; Maximum message length is more or less 20
	brlo	SC_NotIdle
	; We have timed out waiting for the end of a message
	; Clear the buffer
	clr		HaveSlaveRxLine					;Clear the flag
	sts		SlaveRxBufCnt,HaveSlaveRxLine	; and zeroize the count
	rjmp	IsIdle
SC_NotIdle:	
	rjmp	SlaveCommsNotIdle
IsIdle:	

	; Now is the right time to send either a version or a poll message
	; Send a version request to the slaves every now and then if they have not responded for awhile

	ldsw	Z, SlavePollP	; Load the pointer to the table in the flash

	; Read the data for this entry
	lpm		; Load to r0
	mov		ParamReg, r0	; Load the slave letter (eg 'B' )
	sbr		ZL, 1	; Set bit 0 (to go to the next byte)
	lpm
	mov		TempUb, r0	; Load the slave index
		
	adiw	zl, 1
	lpm
	tst		r0
	brnz	SP_NotZ
	ldfp	Z, SlavePollList
SP_NotZ:
	stsw	SlavePollP, Z

	; Now for the slave we just loaded
	ldiw	Y, GotSlaveVersionTimes	; Load the useful data using the index
	add		YL, TempUb
	ldiw	Z, SlaveDeadFlags
	add		zl, TempUb

;	ldi		TempUb, OutToSlaves
;	mov		StringOutControl, TempUb

	ld		TempUb, Z	; Get the status
	cpi		TempUb, SDFAlive
	breq	SP_Alive
	; This slave is either unknown or dead so send a version request message
DoVersionRequest:
	tst		DisplayPolling
	brze	DVR1
	rcall	SendVersionRequestMessages	;(Echo on comms)
	rjmp	SlaveCommsNotIdle	
DVR1:
	rcall	SendVersionRequestMessage	;(Doesn't echo on comms)
	rjmp	SlaveCommsNotIdle	
	
SP_Alive:
	; The slave is alive
    ld		TempUc, Y	; Load the timeout
	lds		TempUb, SecondsLSB
	sub		TempUb, TempUc
	; First check if the slave should be marked as dead (has not responded for more then 60 seconds)
	cpi		TempUb, 60
	brlo	SP_NotDead
	; This slave should be marked as dead
	ldi		TempUb, SDFDead
	st		Z, TempUb
;	ser 	TempUa
;	out		LEDPort,TempUa	;Set all bits high to turn all LEDs off
	push	ParamReg ; This contains the slave's ID
	DoBeep	Beep300Hz,Beep0s2
	DoBeep	Beep240Hz,Beep0s3
	; Send the computer a CR and LF
	ldi		ParamReg, CR
	rcall	SendTxChar
	ldi		ParamReg, LF
	rcall	SendTxChar
	; Send the slave ID
	pop		ParamReg
	push	ParamReg	; Save ParamReg again
	rcall	SendTxChar
	pop		ParamReg
	; Send the rest of the dead string
	LoadAndSendTxFString	DeadString
	rjmp	DoVersionRequest
SP_NotDead:
	cpi		TempUb, 27		;Only request it every 27 seconds	
	brsh	DoVersionRequest		

	; Send a poll message instead since there is no need for a version message
	; ParamReg still has the slave ID
	rcall	PollSlave
	
SlaveCommsNotIdle:
	rjmp	MainLoop


;*****************************************************************************
;*****************************************************************************
;
;	Interrupt Service Routines
;
;*****************************************************************************
;*****************************************************************************

	
;*****************************************************************************
;
;	System Timer Interrupt Service Routine
;
; Services a timer interrupt every one millisecond
;
;*****************************************************************************

ISR_ST:
	SaveSReg			;Save the status register

	; Increment PollTick 8-bit variable
	inc		PollTick
	
	; Increment SysTick 16-bit variable
	ldsw	x,SysTick
	adiw	xl,1
	stsw	SysTick,x

	; See if the lowest 5-bits are zero (Every 32 interrupts or msec)
	; Note: Since SysTick gets reset to zero when it reaches 1000 (3E8),
	;			this timing is not perfect but it's good enough
	andi	xl,0b00011111
	brnz	ISTNotZero

	; Only read the keyboard switches if it's zero, i.e., every 32 interrupts or msec
	in		ISRTempU,SwitchPort
	andi	ISRTempU,SwitchBits	;Get switches PD7-PD2 only
	mov		ThisSwitches,ISRTempU

	clr		ISRTempU
	out		ADMUX,ISRTempU	;Make that the channel number
	sbi		ADCSR,ADSC		;Start the conversion
	sbi		ADCSR,ADIE		;Enable the completion interrupt
ISTNotZero:

; Handle the beeper beep length
; Note that the faster software UART interrupt handles the beeper frequency
	; See if the beeper is going
	tst		BeepFreqCounter
	brnz	ISTHaveBeep

	; See if the buffer count is non-zero
	lds		ISRTempU,BeepBufCnt
	tst		ISRTempU
	brze	ISTNoBeeper
	
	; Decrement the count and save it again
	dec		ISRTempU			;Decrement the number of ENTRIES (each entry is two bytes)
	sts		BeepBufCnt,ISRTempU
	
; Get the next beep parameters ready to action
	; Get the buffer address and add the offset to the first entry
	ldiw	x,BeepBuf
	lds		ISRTempU,BeepBufO1
	add		xl,ISRTempU		;Note: Only works if buffer does not cross a 256-byte boundary
	ld		BeepFreqCounter,x+	;Get the frequency value and increment the pointer
	ld		ISRTempU,x+		;Get the time value and increment the pointer
	sts		BeepFrequencyReload,BeepFreqCounter
	sts		BeepTimeRemaining,ISRTempU
	
	; Now we have to see if the twice incremented pointer has gone past the end of the (circular) buffer
	subi	xl,low(BeepBuf)	;Convert the incremented address back to an offset
	cpi		xl,BeepBufSiz*BeepEntryLength
	brlo	ISTBeepOk			;Ok if lower
	subi	xl,BeepBufSiz*BeepEntryLength	;Adjust if was higher
ISTBeepOk:
	; Store the new offset to the first character in the buffer
	sts		BeepBufO1,xl

	; See if the sys tick is divisible by 8
ISTHaveBeep:
	lds		ISRTempU,SysTickl
	andi	ISRTempU,0b00000111
	brnz	ISTBeepNot8

	; Its time to decrement the count
	lds		ISRTempU,BeepTimeRemaining
	dec		ISRTempU
	sts		BeepTimeRemaining,ISRTempU	;(Doesn't change flags)
	brnz	ISTBeepNotDone

	; We're done with the beeper
	sbi		BeepPort,BeepPin	;Leave the pin high when idle
	clr		BeepFreqCounter		;Clear the beep frequency register
ISTBeepNotDone:
ISTBeepNot8:
ISTNoBeeper:

	; See if SysTick's got to 1000 msecs yet?
	ldi		ISRTempU,high(1000)	;For comparison later (there's no cpic instruction)
	ldsw	x,SysTick
	cpi		xl,low(1000)
	cpc		xh,ISRTempU
	brne	ISTNotASecond
	
	; Yes, reset it to zero
	clrw	x				;Clears it from 1000 (3E8) to 0
	stsw	SysTick,x

	; Increment the seconds counter	
	ldsw 	x,Seconds		;Load it into x
	adiw	xl,1			;Increment the 16-bit register x
	stsw 	Seconds,x		;Save it again in memory
	
ISTNotASecond:

	RestoreSREGReti	;Restore SREG, return, and automatically reenable interrupts


;*****************************************************************************
;
;	A/D Conversion Complete Interrupt Service Routine
;
; Note:	ADIF is cleared automatically by hardware when executing this interrupt
;
;	Uses: ISRSRegSav, x
;
;*****************************************************************************

ISR_ADCC:
	SaveSReg			;Save the status register

	; Read the 10-bit conversion result into x
	in		xl,ADCL		;Must read ADCL first
	in		xh,ADCH

	; Get only the eight MS bits into xl
	lsr		xh			;Get Bit-9 into carry
	ror		xl			;Get Bit-9 into MS bit and discard LS bit
	lsr		xh			;Get Bit-10 into carry
	ror		xl			;Get Bit-10 into MS bit and discard LS bit
	
	; Save the eight-bit result in the proper place
	in		xh,ADMUX	;What reading was this
	tst		xh			;Was it zero (switches)?
	brnz	IADCNotZero	;No, branch
	
	; Save the switch reading
	sts		ThisAISwReading,xl	;Save the eight MS bits only
	ser		xl			;Set xl to FF
	mov		AIDone,xl	;Note that we've done it

	; Start the next A-to-D conversion
	ldi		xh,AIBattery	;Select the battery input
IADCStartNext:
	out		ADMUX,xh
	sbi		ADCSR,ADSC	;Start the battery conversion
	RestoreSREGReti	;Restore SREG, return, and automatically reenable interrupts

IADCNotZero:
	cpi		xh,AIBattery
	brne	IADCNotBatt
	sts		BattVoltageReading,xl
	ldi		xh,AICharge		;Select the charge input
	rjmp	IADCStartNext

IADCNotBatt:
	; Assume it must be the charge reading
	sts		ChargeVoltageReading,xl

ADCDone:
	; We've finished all three readings so disable the interrupt now
	cbi		ADCSR,ADIE	;(so that it won't start another conversion when we enter sleep mode)
	RestoreSREGReti	;Restore SREG, return, and automatically reenable interrupts


;*****************************************************************************
;
;	LCD Timer Interrupt Service Routine
;
;	The RESET code sets the status to 2 and sends the first initialization byte
;		After 4.1msec the initialization byte is resent.
;		After 100usec the initialization byte is sent a third time.
;		After 40usec we can begin sending data.
;
;	If the buffer contains a LCDCommand character (FF),
;		that means that the following character must go to the control register
;		not the data register, and may require a different delay.
;
;*****************************************************************************

ISR_LCDT:
	SaveSReg			;Save the status register

	tst		LCDStatus			;Is the status zero?
	brze	ILCheckForData		;Yes, check for data
	
; The status is not zero -- must be still initializing
; We need to do the second or third initialization byte
; Send the value
	ldi		ISRTempU,LCDInit
	rcall	LCDCommandByteOut	;Send the command byte

; Adjust the status
	dec		LCDStatus			;Decrement it
	brze	ILInitLast

; This must be the second initialization byte -- presumably LCDStatus is now decremented to one
	; Reload the 8-bit timer
	ldi 	ISRTempU,LCD100usPS		;Set the clock PreScaler
	out 	LCDTCCR,ISRTempU
	ldi		ISRTempU,LCD100usReload	;Load the value
	rjmp	ILInitExit

; This is the last initialization byte -- LCDStatus is now zero
ILInitLast:
	; Reload the 8-bit timer -- the clock prescaler is the same as last time
	ldi		ISRTempU,LCD40usReload		;Load the value
ILInitExit:
	out 	LCDTC,ISRTempU
	rjmp	ILExit


; See if we have any data to output from the buffer
ILCheckForData:
	; See if the count is non-zero
	lds		ISRTempU,LCDOutBufCnt
	tst		ISRTempU
	brnz	ILHaveSome
	
	; No characters in buffer -- disable this timer
	ldi 	ISRTempU,TCStop
	out 	LCDTCCR,ISRTempU
	rjmp	ILExit
	
ILHaveSome:
	; Decrement the count and save it again
	dec		ISRTempU
	sts		LCDOutBufCnt,ISRTempU
	
; Get the next character and send it
	; Get the buffer address and add the offset to the first character
	ldiw	x,LCDOutBuf
	lds		ISRTempU,LCDOutBufO1
	add		xl,ISRTempU		;Note: Only works if buffer does not cross a 256-byte boundary
	
	; Send this character
	ld		ISRTempU,x+		;Get the character and increment the pointer
	cpi		ISRTempU,LCDCommand	;Is it a command character?
	breq	ILCommand			;Yes, branch

;It's a data character in ISRTempUb
	rcall	LCDDataByteOut			;Send the data byte

; Set up the standard data delay
ILStandardDelay:
	ldi 	ISRTempU,LCDCharPS		;Set the clock PreScaler
	out 	LCDTCCR,ISRTempU
	ldi		ISRTempU,LCDCharReload	;Load the value
	out 	LCDTC,ISRTempU
	rjmp	ILNext

; It's a command character next in the buffer -- we need to get it out
ILCommand:
	; Decrement the count a second time and save it again
	lds		ISRTempU,LCDOutBufCnt
	dec		ISRTempU
	sts		LCDOutBufCnt,ISRTempU
	
	; Check for circular buffer wrap around
	cpi		xl,low(LCDPastBuf)	;Are we pointing to the next byte past the end of the buffer?
	brne	ILNotPast			;No, branch
	ldi		xl,low(LCDOutBuf)	;Point to the beginning if had gone past
ILNotPast:
	ld		ISRTempU,x+		;Get the actual command character and increment the pointer

; It's a command character in ISRTempU -- we might need a longer delay after it
	push	ISRTempU
	rcall	LCDCommandByteOut	;Send the command byte
	pop		ISRTempU

; The command character is still in ISRTempU -- see what it was
;	cpi		ISRTempU,LCDHome2
;	breq	ILLongerDelay		;Try a longer delay for home 2
	cpi		ISRTempU,3
	brsh	ILStandardDelay		;Commands 3 or over use the standard delay
								; 1 = Cls, 2 = Home1

; We need a longer delay (for slower commands)
;ILLongerDelay:
	ldi		ISRTempU,LCD4ms1PS
	out 	LCDTCCR,ISRTempU	;Set the clock PreScaler
	ldi		ISRTempU,LCD4ms1Reload
	out 	LCDTC,ISRTempU		;Load the value

; Now we have to see if the incremented pointer has gone past the end of the (circular) buffer
ILNext:
	subi	xl,low(LCDOutBuf)	;Convert the incremented address back to an offset
	cpi		xl,LCDOutBufSiz
	brlo	ILOk			;Ok if lower
	subi	xl,LCDOutBufSiz	;Adjust if was higher
ILOk:
	; Store the new offset to the first character in the buffer
	sts		LCDOutBufO1,xl

ILExit:
	RestoreSREGReti	;Restore SREG, return, and automatically reenable interrupts



;*****************************************************************************
;
;	LCDCommandByteOut		Sends a command byte to the LCD
;
;	Expects:	ISRTempU = byte to send
;
;	Changes:	ISRTempU, xh (in LCDByteOut)
;
;*****************************************************************************
;
LCDCommandByteOut:
	cbi		LCDPort,LCDRS	;Set into command mode
	rjmp	LCDByteOut		;Output it and then return


;*****************************************************************************
;
;	LCDDataByteOut			Sends a data byte to the LCD
;
;	Expects:	ISRTempU = byte to send
;
;	Changes:	ISRTempU, xh (in LCDByteOut)
;
;*****************************************************************************
;
LCDDataByteOut:
	sbi		LCDPort,LCDRS	;Set into data mode
	;rjmp	LCDByteOut		;Output it and then return

;*****************************************************************************
;
;	LCDByteOut	Sends two nibbles to the LCD
;
;	Expects:	ISRTempU = byte to send
;
;	Changes:	ISRTempUb, xh (in LCDNibbleOut)
;
;*****************************************************************************
;
LCDByteOut:
	push	ISRTempU		;Save the data byte
	swap	ISRTempU		;Swap nibbles
	rcall	LCDNibbleOut	;Output the MS nibble
	pop		ISRTempU		;Get the data byte back again
	;rjmp	LCDNibbleOut	;Output the LS nibble and return

;*****************************************************************************
;
;	LCDNibbleOut	Sends a nibble to the LCD
;
;	Expects:	ISRTempU Bits 0-3 = nibble to send
;
;	Changes:	ISRTempU, xh
;
;*****************************************************************************
;
LCDNibbleOut:
	in		xh,LCDPort
	andi	xh,0xF0			;Just get the upper four bits
	andi	ISRTempU,0x0F	;Get the nibble
	or		xh,ISRTempU 	;Combine the two
	out		LCDPort,xh		;Output the nibble on DB4-7
	;Must wait 250nsec after outputting data before the enable
	;Since this is only one instruction at 4 Mhz (250nsec cycle), we don't need any NOPs here.
	sbi		LCDPort,LCDEN	;Turn the enable on
	nop						;Need a 450nsec delay
							;One NOP is actually enough at 4Mhz (250nsec cycle)
	cbi		LCDPort,LCDEN	;Turn the enable off to latch the data
	ret						;The data stays stable as we return


;*****************************************************************************
;
;	Software UART Timer Interrupt Service Routine
;
;	Services a timer interrupt at four times the desired baud rate
;		At 2400 baud this is 9600Hz or every 104usec
;
;	Sends the next bit or character if there is one, else disables itself
;
;	Also handles the beeper frequency since this is our highest speed interrupt
;
;*****************************************************************************

ISR_SU:
	SaveSReg			;Save the status register
	
;*****************************************************************************

; This also doubles as the beeper generator to generate the frequency
; Note that the system timer interrupt controls the length of the beep
	tst		BeepFreqCounter	;Check the frequency control byte
	brze	ISUNoBeeper
	cpi		BeepFreqCounter,BeepSilent
	breq	ISUNoBeeper

	; The beeper is going
	dec		BeepFreqCounter
	brnz	ISUNotTimeYet

	; Reload the counter if it reached zero
	lds		BeepFreqCounter,BeepFrequencyReload

	; Its time to toggle the bit
	sbis	BeepPort,BeepPin
	rjmp	ISUSetBeeper
	cbi		BeepPort,BeepPin	;The beeper was set so clear it
	rjmp	PC+2
ISUSetBeeper:
	sbi		BeepPort,BeepPin	
ISUNotTimeYet:
ISUNoBeeper:
	
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
	lds		ISRTempU,SlaveTxBufCnt
	tst		ISRTempU
	brnz	ISUTxHaveSome
	
	; No characters in buffer
	cpi		SUTxStatus,SUTxIdle	;Were we already idle?
	breq	ISUTxEnd			;Yes, branch
	
	; We just finished transmitting the last character
	rjmp	ISUTxEnd
	
ISUTxHaveSome:
	; Decrement the count and save it again
	dec		ISRTempU
	sts		SlaveTxBufCnt,ISRTempU
	
; Get the next character ready to send
	; Get the buffer address and add the offset to the first character
	ldiw	x,SlaveTxBuf
	lds		ISRTempU,SlaveTxBufO1
	add		xl,ISRTempU		;Note: Only works if buffer does not cross a 256-byte boundary
	ld		SUTxByte,x+		;Get the character and increment the pointer
	
	; Now we have to see if the incremented pointer has gone past the end of the (circular) buffer
	subi	xl,low(SlaveTxBuf)	;Convert the incremented address back to an offset
	cpi		xl,SlaveTxBufSiz
	brlo	ISUTxOk			;Ok if lower
	subi	xl,SlaveTxBufSiz	;Adjust if was higher
ISUTxOk:
	; Store the new offset to the first character in the buffer
	sts		SlaveTxBufO1,xl

	; Send the start bit
	cbi		SUPort,SUTx		;Set low for a start bit
	ldi		SUTxStatus,-1	;It will now get incremented to zero below
ISUTxDone:
	inc		SUTxStatus		;Increment the Tx status counter
ISUTxEnd:

;*****************************************************************************

; Service the receiver next
	cpi		SURxStatus,SURxIdle
	brne	ISURxNotIdle
	
	; It's idle -- check for a start bit
	sbic	SUInput,SURx	;A start bit is low
	rjmp	ISURxIdle		;It's set so still idle
	
	; We've got the start of a start bit
	clr		SURxStatus	;So will sample at the right times later					
	ldi		ISRTempU, WFSRWaitingForEnd
	sts		WaitingForSlaveReply, ISRTempU ; We have received a start bit
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
	; We have got to the end so set WaitingForSlaveReply back to idle
	ldi		ISRTempU, WFSRIdle
	sts		WaitingForSlaveReply, ISRTempU ; We have received a start bit

	sbis	SUInput,SURx	;It should be high
	rjmp	ISUFramingError	;Branch if low
	; If we get here, we've sampled the stop bit. Action the character
	; even though the status counter will keep incrementing until the
	; full length of the stop bit is received

;	; Display the received byte on the LEDs
;	mov		xl,SURxByte
;	com		xl
;	out		LEDPort,xl		;(Messes up the main loop indicator temporarily)

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
	rjmp	ISURxReset
ISUCC:
	brts	ISUParityError	;Error if C clear but T is set
ISUParOk:

	; Save the received byte in the buffer
	; See if we already have a line needing processing
	tst		HaveSlaveRxLine

	brze	ISURNoDouble	;No, we're ok
	
	; Yes, we have doubled up somehow
	lds		ISRTempU,SULineOverflowErrorCount
	inc		ISRTempU		;Count the error and then ignore it
	sts		SULineOverflowErrorCount,ISRTempU
ISURNoDouble:

	; See if the RX buffer is already full
	lds		ISRTempU,SlaveRxBufCnt
	cpi		ISRTempU,SlaveRxBufSiz-2	;Leave room for the CR and trailing null as well
	brlo	ISUROk					;Ok if lower

	; If this is not a CR, we have a buffer overflow
	push	ISRTempU
	mov		ISRTempU,SURxByte	;Get the character received
	cpi		ISRTempU,CR+0x80	;Was it a CR (with the parity bit set)?
	breq	ISRHaveFinalCR

	; We have a buffer overflow
	lds		ISRTempU,SURxBufferOverflowErrorCount
	inc		ISRTempU
	sts		SURxBufferOverflowErrorCount,ISRTempU
	ldi		ISRTempU,CR		;Let's make it a CR now anyway
	mov		SURxByte,ISRTempU
ISRHaveFinalCR:
	pop		ISRTempU		;Restore ISRTempU = SlaveRxBufCnt and just continue
ISUROK:

	; Calculate where to store the character in the buffer
	;  (ISRTempU still contains SlaveRxBufCnt)
	ldiw	x,SlaveRxBuf
	add		xl,ISRTempU		;Note: Only works if buffer does not cross a 256-byte boundary

	; Increment the count and save it (so we can use ISRTempU for something else)
	inc		ISRTempU
	sts		SlaveRxBufCnt,ISRTempU
	
	; Get the character and save it in the buffer
	mov		ISRTempU,SURxByte
	andi	ISRTempU,0x7F	;Reduce to 7-bits (Ignore parity now -- it was checked above)
	st		x+,ISRTempU
	
	; If it was a CR, set the EOL flag
	subi	ISRTempU,CR
	brne	ISURxDone		;No, we're done

	; It was a CR so append a trailing NULL and set the EOL flag
	st		x,ISRTempU		;(Set to zero by SUBI instruction)
	com		HaveSlaveRxLine	;Was zero -- now FF

ISURxDone:
	inc		SURxStatus
ISURxStarted:
ISURxIdle:
	RestoreSREGReti	;Restore SREG, return, and automatically reenable interrupts

; This code is down here to allow a relative branch to reach
	; We have a framing error
ISUFramingError:
	lds		ISRTempU,SUFramingErrorCount
	inc		ISRTempU
	sts		SUFramingErrorCount,ISRTempU
ISURxReset:
	ldi		SURxStatus,SURxIdle
	rjmp	ISURxIdle


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
	lds		ISRTempU,ComTxBufCnt
	tst		ISRTempU
	brnz	IUHaveSome
	
	; No characters in buffer -- disable this interrupt
	cbi		UCR,UDRIE
	rjmp	IUExit
	
IUHaveSome:
	; Decrement the count and save it again
	dec		ISRTempU
	sts		ComTxBufCnt,ISRTempU
	
	; Get the next character and send it
	; Get the buffer address and add the offset to the first character
	ldiw	x,ComTxBuf
	lds		ISRTempU,ComTxBufO1
	add		xl,ISRTempU		;Note: Only works if buffer does not cross a 256-byte boundary
	
	; Send this character
	ld		ISRTempU,x+		;Get the character and increment the pointer
	out		UDR,ISRTempU	;Send the character
	
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
	lds		ISRTempU,ComLineOverflowErrorCount
	inc		ISRTempU		;Count the error and then ignore it
	sts		ComLineOverflowErrorCount,ISRTempU
IURNoDouble:

	; See if the RX buffer is already full
	lds		ISRTempU,ComRxBufCnt
	cpi		ISRTempU,ComRxBufSiz-1	;Allow room for the trailing NULL
	brlo	IUROk					;Ok if lower
	
	; Have buffer overflow
	lds		ISRTempU,RxBufferOverflowErrorCount
	inc		ISRTempU
	sts		RxBufferOverflowErrorCount,ISRTempU
	clr		ISRTempU	;Clear the counter and continue (i.e., lose the beginning of the message)
IUROK:

	; Calculate where to store the character in the buffer
	;  (ISRTempU still contains ComRxBufCnt)
	ldiw	x,ComRxBuf
	add		xl,ISRTempU		;Note: Only works if buffer does not cross a 256-byte boundary

	; Increment the count and save it (so we can use ISRTempU for something else)
	inc		ISRTempU
	sts		ComRxBufCnt,ISRTempU
	
	; Get the character and save it in the buffer
	in		ISRTempU,UDR
	andi	ISRTempU,0x7F	;Reduce to 7-bits (Ignore parity)
	st		x+,ISRTempU
	
	; If it was a CR, set the EOL flag
	subi	ISRTempU,CR
	brne	IURExit			;No, we're done

	; It was a CR so append a trailing NULL and set the EOL flag
	st		x,ISRTempU		;(Set to zero by SUBI instruction)
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
;	SendTxPollChar	Sends a character to the Tx buffer if DisplayPolling is set
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
SendTxPollChar:
	tst		DisplayPolling
	brnz	SendTxChar		;Send if set
	ret						;Else just return

	
;*****************************************************************************
;
;	SendTxChar	Sends a character to the Tx buffer
;				The interrupt routine then outputs the buffer automatically
;
; Expects:	(ASCII) Character in ParamReg
;
; Uses:	y, TempUa
;
; Must not change ParamReg, z, TempUc
;
;*****************************************************************************
;
SendTxChar:
	clrw	y	;Use y for a counter when the buffer is full
SendTxCharLoop:
	cli		; Disable interrupts temporarily
			;	so the TX interrupt can't change buffer control variables

	;See if there's room in the buffer
	lds		TempUa,ComTxBufCnt
	cpi		TempUa,ComTxBufSiz
	brsh	STCBufferFull
	
	; Add the start offset and the length together
	lds		yl,ComTxBufO1	;Get the offset to the first character
	add		yl,TempUa		;Add the TxBufCnt (Note: Total must not exceed 256)
	
	; Now yl is sort of the the offset of the first empty space
	; We have to adjust it though, if it's past the end of the (circular) buffer
	cpi		yl,ComTxBufSiz
	brlo	STCBNFOk			;Ok if the calculated offset is already inside the buffer
	subi	yl,ComTxBufSiz		;Otherwise, adjust it down
STCBNFOk:
	
	; Now yl is the adjusted offset of the first empty space
	addi	yl,low(ComTxBuf)	;Add the actual buffer address
	ldi		yh,high(ComTxBuf)	;Note: Only works if buffer does not cross a 256-byte boundary

	; Now y is the address of the first empty space in the buffer
	st		y,ParamReg
	inc		TempUa			;Increment and save the count
	sts		ComTxBufCnt,TempUa

	; Enable TX ready (UDRE) interrupts (in case they weren't already enabled)
;	sei						; Enable interrupts again now
	sbi		UCR,UDRIE
	reti					;Return and re-enable interrupts now

STCBufferFull:
	; If we get here the buffer must be full (Should only occur on a HELP message or Memory Dump)
	sei						;Enable interrupts again so transmitter can keep sending
	adiw	yl,1			;Increment the loop counter
	; Note: At 19,200bps, the UART should send a character about every 521 microseconds
	; This buffer full loop has 8 instructions (10 cycles) and takes more than 2 microseconds at 4MHz
	;  so y shouldn't count to more than about 260 before there's room for the next character
	cpi		yh,2			;Has y got to 2 * 256 = 512?
	brlo	SendTxCharLoop	;No, keep waiting
	ldi		ParamReg,TXBufferFullErrorCode	;Yes, must be some major problem
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
	; Save y and z and xh by hand before we use them
	sts		ComRxBuf+00,R0	;R0
	sts		ComRxBuf+28,yl	;yl = R28
	sts		ComRxBuf+29,yh	;yh = R29
	sts		ComRxBuf+30,zl	;zl = R30
	sts		ComRxBuf+31,zh	;zh = R31

	; Save the other registers (1..27) in ComRxBuf
	ldiw	y,ComRxBuf
	clr		zh			;Start at address 01 to miss R0
	ldi		zl,1
DRSaveLoop:
	ld		R0,z+		;Get register
	st		y+,R0		;Save in buffer
	cpi		zl,32-4		;Don't include y or z (28...) as they're already saved
	brne	DRSaveLoop

; Now display the registers from the SRAM buffer (ComRxBuf)
	ldi		TempUa,OutToTX
	mov		StringOutControl,TempUa

	clr		zl			;Start at register 00
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
	rcall	SendCString		;Send the decimal digit string from ConvString
	
	ldi		ParamReg,'='
	rcall	SendTXChar

	popw	y

	ld		zl,y+			;Get the register value from ComRxBuf
	pushw	y
	
	; Display the register value in hex
	rcall	ConvertHexByte	;Convert it to a string
	rcall	SendCString		;Send the hex digit string from ConvString

	ldi		ParamReg,' '
	rcall	SendTXChar

	popw	y		
	pop		zl
	inc		zl				;Increment register counter
	
; Send a CR after every eight registers
	mov		zh,zl
	andi	zh,0b00000111
	brnz	DRLoop
	ldi		ParamReg,CR
	rcall	SendTXChar		;Doesn't alter z
	
; Stop after displaying all 32 registers
	cpi		zl,32
	brne	DRLoop
	ret						;Finished all 32


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
	ldi		TempUa,OutToTX
	mov		StringOutControl,TempUa

	ldi		zl,0x60		;Start at address 0060
	clr		zh

DSRLoop1:
	; Display the next line of characters
	pushw	z			;Save the RAM address for this line

	; Display the SRAM address in hex
	rcall	ConvertHWord	;Convert RAM address already in z
	rcall	SendCString		;Send the hex digit string from ConvString

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
	rcall	ConvertHexByte	;Convert it to a string
	rcall	SendCString		;Send the hex digit string from ConvString

	ldi		ParamReg,' '
	rcall	SendTXChar
	pop		TempUa

	; Insert an extra space after every eight bytes (i.e., in the middle and at the end)
	push	TempUa
	andi	TempUa,0b111
	cpi		TempUa,1
	brne	DSRNot8a
	ldi		ParamReg,' '
	rcall	SendTXChar
DSRNot8a:
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

	; Insert an extra space after eight bytes
	cpi		TempUa,8+1
	brne	DSRNot8b
	push	TempUa
	ldi		ParamReg,' '
	rcall	SendTXChar
	pop		TempUa
DSRNot8b:

	dec		TempUa			;Bytes left to print on this line
	brnz	DSRLoop3
	
; Send a CR at the end of every line
	ldi		ParamReg,CR
	rcall	SendTXChar		;Doesn't alter z
	
; Stop after displaying all of the RAM
	cpi		zl,low(RAMEND+1)
	brne	DSRLoop1
	cpi		zh,high(RAMEND+1)
	brne	DSRLoop1
	ret						;Finished all 512 bytes


;*****************************************************************************
;
;	SendLCDChar	Sends a character to the LCD buffer
;				The interrupt routine then outputs the buffer automatically
;
; Expects:	(ASCII) Character in ParamReg
;
; Note: This routine leaves interrupts DISABLED when it receives an LCDCommand character
;		(LCDCommand characters should always be followed by the actual command character)
;		Interrupts will automatically be enabled again when the actual command character is sent to the buffer
;
; Uses:	y, TempUa
;
; Must not change z, TempUc
;
;*****************************************************************************
;
SendLCDChar:
	; Remember when we last updated the LCD
	lds		LCDUseTime,SecondsLSB

	cli		; Disable interrupts temporarily
			;	so the LCD timer interrupt can't change buffer control variables
	
	;See if there's room in the buffer
	lds		TempUa,LCDOutBufCnt
	cpi		TempUa,LCDOutBufSiz
	brsh	SLCBufferFull
	
	; Add the start offset and the length together
	lds		yl,LCDOutBufO1	;Get the offset to the first character
	add		yl,TempUa		;Add the TxBufCnt (Note: Total must not exceed 256)
	
	; Now yl is sort of the the offset of the first empty space
	; We have to adjust it though, if it's past the end of the (circular) buffer
	cpi		yl,LCDOutBufSiz
	brlo	SLCBNFOk			;Ok if the calculated offset is already inside the buffer
	subi	yl,LCDOutBufSiz		;Otherwise, adjust it down
SLCBNFOk:
	
	; Now yl is the adjusted offset of the first empty space
	addi	yl,low(LCDOutBuf)	;Add the actual buffer address
	ldi		yh,high(LCDOutBuf)	;Note: Only works if buffer does not cross a 256-byte boundary
	
	; Now y is the address of the first empty space in the buffer
	st		y,ParamReg
	inc		TempUa			;Increment and save the count
	sts		LCDOutBufCnt,TempUa

	; If it's a Command character (the first in a two-byte sequence), don't reenable interrupts yet
	cpi		ParamReg,LCDCommand
	breq	SLCDone			;Just return if it's a command character

	; Restart LCD timer if necessary
	in		TempUa,LCDTCCR
	andi	TempUa,0b00000111	;Get the Prescaler bits
	brne	SLCGoing		;000 is stopped (for any timer count)
	ldi 	TempUa,TCClkDiv8		;Set the clock PreScaler
	out 	LCDTCCR,TempUa
	ldi		TempUa,250		;Load the value 250 so will overflow shortly
	out 	LCDTC,TempUa
SLCGoing:	
	reti					;Reenable interrupts and then return
SLCDone:
	ret

SLCBufferFull:
	; If we get here the buffer must be full
	; What should we do here???
	push	ParamReg
	ldi		ParamReg,LCDBufferFullErrorCode
	;rjmp	ProgramErrorDump	;Disable interrupts and then display the error code on the LEDs
							; Then reenable interrupts and dump internal information to TX
							; and then return and try to continue operation

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
;				Former value of ParamReg is pushed on stack
;
;	Uses:		R0, TempUb, TempUc, TempLa, etc...
;
;*****************************************************************************
;
ProgramErrorDump:
	rcall	ProgramError
	sei				;Reenable interrupts so can try to continue
	pop		ParamReg

	pushw	z
	push	TempUc	
	rcall	DumpRegisters
	rcall	DumpSRam
	pop		TempUc
	popw	z
	ret


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
;							and stores it in ConvString with a final null
;
; Expects:	T = 0 for zero suppression, non-zero for no zero suppression
;			ZL = byte to be converted
;
; Returns:	y pointing to the final null in ConvString
;
;*****************************************************************************
;
ConvertUByte:
	clr		zh
	;Fall through to ConvertUWord below
	
;*****************************************************************************
;
;	ConvertUWord		Converts an unsigned word to ASCII digits
;							and stores it in ConvString with a final null
;
; Expects:	T = 0 for zero suppression, non-zero for no zero suppression
;			ZL = byte to be converted
;
; Uses:		TempLa, TempLb, TempLc, TempLd, TempUa, Tempb, TempUc, y, t
;
; Returns:	y pointing to the final null in ConvString
;
;*****************************************************************************
;
ConvertUWord:
	ldiw	y,ConvString	;Point y to the start of the string storage area

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
	ret
		

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
;	ConvertHexByte		Converts a (binary) byte to two ASCII hex digits
;							and stores it in ConvString with a final null
;
; Expects:	zl = byte to be converted
;
; SendHexByte uses TempUa and TempUc, updates y
;
; Returns:	y pointing to the final null in ConvString
;
;*****************************************************************************
;
ConvertHexByte:
	ldiw	y,ConvString	;Point y to the start of the string storage area
ConvertHexByteCont:
	mov		ParamReg,zl		;Copy the character
	swap	ParamReg			;Swap nibbles
	andi	ParamReg,0x0F		;Get the four bits
	addi	ParamReg,'0'		;ASCIIize it by adding '0'
	cpi		ParamReg,':'		;Colon is one past '9'
	brlo	CHB1OK				;Ok if it's a valid digit
	addi	ParamReg,'a'-':'	;Convert to a-f
CHB1OK:
	st		y+,ParamReg
	
	andi	zl,0x0F			;Get the four LS bits
	addi	zl,'0'		;ASCIIize it by adding '0'
	cpi		zl,':'		;Colon is one past '9'
	brlo	CHB2OK			;Ok if it's a valid digit
	addi	zl,'a'-':'	;Convert to a-f
CHB2OK:
	st		y+,ParamReg
	clr		TempUb
	rjmp	ConvertFinish


;*****************************************************************************
;
;	ConvertHWord		Converts a (binary) word to four ASCII hex digits
;							and stores it in ConvString with a final null
;
; Expects:	z = word to be converted
;
; SendHexByte uses TempUa and TempUc, updates y
;
; Returns:	y pointing to the final null in ConvString
;
;*****************************************************************************
;
ConvertHWord:
	push	zl
	mov		zl,zh
	rcall	ConvertHexByte	;Do MS byte first
	pop		zl
	rjmp	ConvertHexByteCont


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
	;clc					;C = 0 for no error
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
	;clc					;C = 0 for no error
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
	;clc					;C = 0 for no error
	ret					;Done


;*****************************************************************************
;
;	FormBaseCopyHeader		Starts to form a message to the base in ConvString
;
; Places a "STB: " (for Sent to Base) in the Tx buffer
;
; Sets StringOutControl to OutToBoth
; Places a 'B' (for Base) in the Tx buffers
;
;*****************************************************************************
;
FormBaseCopyHeader:
	ldi		ParamReg,'B'
	;rjmp	FormSlaveCopyHeader

;*****************************************************************************
;
;	FormSlaveCopyHeader		Starts to form a message to the slave in ConvString
;
; Expects:	ParamReg = SlaveID char (B/I/S)
;
; Places a "STx: " (for Sent to Slave x) in the Tx buffer
;
; Sets StringOutControl to OutToBoth
; Places the slave ID character in the Tx buffers
;
; Uses:		TempUa
;
;*****************************************************************************
;
FormSlaveCopyHeader:
	push	ParamReg
	ldi		ParamReg,'S'
	rcall	SendTxChar
	ldi		ParamReg,'t'
	rcall	SendTxChar
	pop		ParamReg
	push	ParamReg
	rcall	SendTxChar
	ldi		ParamReg,':'
	rcall	SendTxChar
	ldi		ParamReg,' '
	rcall	SendTxChar

	ldi		TempUa,OutToBoth
	mov		StringOutControl,TempUa
	pop		ParamReg
	rjmp	SendChar	;and return


;*****************************************************************************
;
;	FormBaseHeader		Starts to form a message to the base in ConvString
;
; Places the B character in the buffer
;
; Returns:	y pointing to next character position in the buffer
;			z pointing to start of buffer
;
;*****************************************************************************
;
;FormBaseHeader:
	ldi		ParamReg,'B'
	;rjmp	FormSlaveHeader

;*****************************************************************************
;
;	FormSlaveHeader		Starts to form a message to a slave in ConvString
;
; Expects:	ParamReg = character for slave (B/I/S)
;
; Sets StringOutControl = OutToSlaves
; Places the character in the buffer
;
; Returns:	y pointing to next character position in the buffer
;			z pointing to start of buffer
;
;*****************************************************************************
;
;FormSlaveHeader:
	ldi		yl,OutToSlaves
	mov		StringOutControl,yl

	;Point y to the start of the string storage area
	ldiw	y,ConvString
;	mov		zl,yl			;Keep a copy of the buffer address in z
;	mov		zh,yh

FormSlaveHeaderCont:
	st		y+,ParamReg		;Store the slave ID character in the buffer
InitializeIR:
	ret


;*****************************************************************************
;
;	SendPowerMessages		Sends a "Power" message to the com and slaves
;
;*****************************************************************************
;
SendPowerMessages:
	rcall	FormBaseCopyHeader
	ldi		ParamReg,'P'
	rcall	SendChar
	lds		TempUa,PowerByte
	rjmp	SendHexByteThenDone


;*****************************************************************************
;
;	SendTravelMessages		Sends a "Travel" message to the com and slaves
;
;*****************************************************************************
;
SendTravelMessages:
	rcall	FormBaseCopyHeader
	ldi		ParamReg,'T'
	rcall	SendChar
	lds		TempUa,TravelByte
	rjmp	SendHexByteThenDone


;*****************************************************************************
;
;	InitializeSpeech		Sends Sf00 initialization message to the speech slave
;
;*****************************************************************************
;
InitializeSpeech:
	ldi		ParamReg,'S'
	rcall	FormSlaveCopyHeader
	ldi		ParamReg,'f'
	rcall	SendChar
	clr		TempUa				;00
	rjmp	SendHexByteThenDone


;*****************************************************************************
;
;	InitializeIR			Sends initialization messages to the IR slave
;
;*****************************************************************************
;
;InitializeIR:
;	ret


;*****************************************************************************
;
;	InitializeBase			Sends initialization messages to the base slave
;
;*****************************************************************************
;
InitializeBase:
	rcall	SendHaltMessages		;In case it's already moving
	rcall	SendPowerMessages
	rcall	SendTravelMessages
	;rjmp	SendIntensityMessages	;and return

;*****************************************************************************
;
;	SendIntensityMessages	Sends a "Intensity" message to the com and slaves
;
;*****************************************************************************
;
SendIntensityMessages:
	rcall	FormBaseCopyHeader
	ldi		ParamReg,'I'
	rcall	SendChar
	lds		TempUa,HeadlightIntensity
	rjmp	SendHexByteThenDone


;*****************************************************************************
;
;	SendSpeedMessages		Sends a "Speed" message to the com and slaves
;
;*****************************************************************************
;
SendSpeedMessages:
	rcall	FormBaseCopyHeader
	ldi		ParamReg,'S'
	rcall	SendChar
	lds		TempUa,Speed
	rjmp	SendHexByteThenDone


;*****************************************************************************
;
;	SendVersionRequestMessages			Sends a version number request message
;										 to the com and selected slave
;
; Expects:	ParamReg = Slave ID character (B/I/S)
;
;*****************************************************************************
;
SendVersionRequestMessages:
	rcall	FormSlaveCopyHeader
	rjmp	SendVersionRequestMessageCont


;*****************************************************************************
;
;	SendVersionRequestMessage to slave comms
;
; Expects:	ParamReg = Slave ID character (B/I/S)
;
;*****************************************************************************
;
SendVersionRequestMessage:
	rcall	SendSUChar					;Send slave ID from ParamReg
	ldi		TempUa,OutToSlaves
	mov		StringOutControl,TempUa
SendVersionRequestMessageCont:
	; Now setup the timeouts
	clr		PollTick
	ldi		ParamReg,WFSRWaitingForStart	;We are now waiting for a response
	sts		WaitingForSlaveReply,ParamReg
	ldi		ParamReg,'V'
	rjmp	SendCharThenDone


;*****************************************************************************
;
;	SendHaltMessages		Sends a "Halt" message to the com and slaves
;
;*****************************************************************************
;
SendHaltMessages:
	rcall	FormBaseCopyHeader
	ldi		ParamReg,'H'
	;rjmp	SendCharThenDone	; and then return

;*****************************************************************************
;
;	SendCharThenDone	Send the character and then completes the message
;
; Expects:	ParamReg = character
;			StringOutControl is set
;
;*****************************************************************************
;
SendCharThenDone:
	rcall	SendChar
	rjmp	SendControlMessage	; and then return


;*****************************************************************************
;
;	SendManualMotorMessages		Sends left and right motor messages to the com and slaves
;
; Uses LeftMotorSpeed and RightMotorSpeed variables
;
;*****************************************************************************
;
SendManualMotorMessages:
; Send left motor messages
	rcall	FormBaseCopyHeader
	lds		TempUa,LeftMotorSpeedMSB
	ldi		ParamReg,'l'		;Reversing
	tst		TempUa
	brze	SLMMNext
	ldi		ParamReg,'L'
SLMMNext:
	rcall	SendChar
	lds		TempUa,LeftMotorSpeedLSB
	rcall	SendHexByteThenDone

; Send right motor messages
	rcall	FormBaseCopyHeader
	lds		TempUa,RightMotorSpeedMSB
	ldi		ParamReg,'r'		;Reversing
	tst		TempUa
	brze	SRMMNext
	ldi		ParamReg,'R'
SRMMNext:
	rcall	SendChar
	lds		TempUa,RightMotorSpeedLSB
	rjmp	SendHexByteThenDone		;and return


;*****************************************************************************
;
;	SendGoMessages		Sends a "Go" message to the com and slaves
;
; Uses Angle, Speed, and Distance variables
;
;*****************************************************************************
;
SendGoMessages:
	rcall	FormBaseCopyHeader

	lds		TempUa,AngleLSB
	lds		TempUb,AngleMSB
	
	tst		TempUb	; If set then we're going left
	brnz	STMLeft
	cpi		TempUa,180
	brsh	STMLeft
	
	ldi		ParamReg,'G'			;Go right
	rjmp	STMNext
STMLeft:
	ldi		ParamReg,'g'			;Go left
	; We are turning left so subtract it from 360
	subi	TempUa,low(360)
	neg		TempUa
	
STMNext:
	push	TempUa			;Save the adjusted angle info
	rcall	SendChar		;Send the correct G/g character
	lds		TempUa,Speed
	rcall	SendHexByte		;Send the speed
	pop		TempUa
SendGoCont:	
	rcall	SendHexByte		;Send the angle which is in TempUa
	lds		TempUa,DistanceMSB	;Send MS byte of distance first
	rcall	SendHexByte
	lds		TempUa,DistanceLSB
	rjmp	SendHexByteThenDone


;*****************************************************************************
;
;	SendReverseMessages		Sends a "Reverse" message to the com and slaves
;
;*****************************************************************************
;
SendReverseMessages:
	rcall	FormBaseCopyHeader
	ldi		ParamReg,'b'		;Go backwards
	rcall	SendChar
	lds		TempUa,Speed
	rjmp	SendGoCont


;*****************************************************************************
;
;	SpeakEString		Sends a "Speak" message to the com and speech slave
;
;	Expects:	z = Address of speech string in EEPOM
;
;	Uses:	TempUa,TempUc,ParamReg
;
;*****************************************************************************
;
SpeakEString:
	lds		TempUa,PowerByte
	andi	TempUa,StealthBit
	brze	SESCont				;Don't speak if in stealth mode
	ret
SESCont:

	ldi		ParamReg,'S'
	rcall	FormSlaveCopyHeader
	ldi		ParamReg,'s'		;Say command
	rcall	SendChar
	
; Send in speech control string from EEPROM preserving z
SESMWait:
; Only need the next line if use EEPROM also for writing
;	bris	EECR,EEWE,SendESMWait	;Loop if a write operation is still in progress
SESMLoop:
	; Read the byte from the EEPROM into TempUa
	out		EEARH,zh		;Output the 9-bit address
	out		EEARL,zl
	sbi		EECR,EERE		;Do the read command (will halt CPU for 4 cycles)
	in		TempUa,EEDR	;Get the EEPROM value

	tst		TempUa			;See if it's a null
	brze	SendControlMessage
	rcall	SendHexByte	;Not a null so send it in hex
	adiw	zl,1		;Increment the 16-bit buffer pointer for next time
	rjmp	SESMLoop


;*****************************************************************************
;
;	SpeakFString		Sends a "Speak" message to the com and speech slave
;
;	Expects:	z = Address of speech string in flash
;
;*****************************************************************************
;
;SpeakFString:
;	lds		TempUa,PowerByte
;	andi	TempUa,StealthBit
;	brze	SFSCont				;Don't speak if in stealth mode
;	ret
;SFSCont:

;	ldi		ParamReg,'S'
;	rcall	FormSlaveCopyHeader
;	ldi		ParamReg,'s'		;Say command
;	rcall	SendChar
	
; Send in speech control string from flash preserving z
;SFSMLoop:
;	lpm					;Get byte pointed to by Z into R0
;	tst		r0			;See if it's a null
;	brze	SendControlMessage
;	mov		TempUa,R0	;Get it into the correct register
;	rcall	SendHexByte
;	adiw	zl,1		;Increment the 16-bit buffer pointer for next time
;	rjmp	SFSMLoop


;*****************************************************************************
;
;	SpeakWord		Sends a "Speak" message to the com and speech slave
;
;	Expects:	ParamReg = Speech utterance number
;
;*****************************************************************************
;
SpeakWord:
	lds		TempUa,PowerByte
	andi	TempUa,StealthBit
	brze	SWCont				;Don't speak if in stealth mode
	ret
SWCont:

	push	ParamReg
	ldi		ParamReg,'S'
	rcall	FormSlaveCopyHeader
	ldi		ParamReg,'s'		;Say command
	rcall	SendChar
	pop		TempUa
	;rjmp	SendHexByteThenDone

;*****************************************************************************
;
;	SendHexByteThenDone
;
;	Expects:	TempUa = Byte to store
;
;*****************************************************************************
;
SendHexByteThenDone:
	rcall	SendHexByte
	;rjmp	SendControlMessage

;*****************************************************************************
;
;	SendControlMessage		Sends final CR
;
;	Expects:	StringOutControl is set
;
;	Uses:		TempUa, TempUc, y, z
;
;*****************************************************************************
;
SendControlMessage:
	ldi		ParamReg,CR		;Trailing CR
	rjmp	SendChar		;Send it and then return


;*****************************************************************************
;
;	SendCString	Sends the null-terminated string from ConvString to the selected buffer
;
; Expects:	StringOutControl is set
;
; Uses:		ParamReg, y, z, TempUa, TempUc
;
; Returns:	ParamReg = 0
;
;*****************************************************************************
;
SendCString:
	ldiw	z,ConvString
	;rjmp	SendSString		;and return

;*****************************************************************************
;
;	SendSString	Sends a null-terminated string from the STATIC RAM to the selected buffer
;
; Expects:	SRAM string pointer in z
;			StringOutControl is set
;
; Uses:		ParamReg, y, z, TempUa, TempUc
;
; Returns:	ParamReg = 0
;
;*****************************************************************************
;
SendSString:
	ld		ParamReg,z+		;Get byte pointed to by Z and then increment Z
	tst		ParamReg		;See if it's a null
	brze	Return2			;Yes, done
	rcall	SendChar		;No, send it
	rjmp	SendSString


;*****************************************************************************
;
;	SendLCDEString	Sends a null-terminated string from the EEPROM to the LCD
;
; Expects:	EEPROM string pointer in Z
;
; Uses:		ParamReg, y, z, TempUa, TempUc
;
; Returns:	ParamReg = 0
;
;*****************************************************************************
;
SendLCDEString:
	ldi		ParamReg,OutToLCD
	mov		StringOutControl,ParamReg
	;rjmp	SendEString			;and return

;*****************************************************************************
;
;	SendEString	Sends a null-terminated string from the EEPROM to the selected buffer
;
; Expects:	EEPROM string pointer in Z
;			StringOutControl is set
;
; Uses:				ParamReg, z
; SendChar uses:	y, TempUa, TempUc
;
; Returns:	ParamReg = 0
;
;*****************************************************************************
;
SendEString:
; Only need the next line if use EEPROM also for writing
;	bris	EECR,EEWE,SendEString	;Loop if a write operation is still in progress
SendEStringCont:
	; Read the byte from the EEPROM into ParamReg
	out		EEARH,zh		;Output the 9-bit address
	out		EEARL,zl
	sbi		EECR,EERE		;Do the read command (will halt CPU for 4 cycles)
	in		ParamReg,EEDR	;Get the EEPROM value

	tst		ParamReg		;See if it's a null
	brze	Return2			;Yes, done

	rcall	SendChar		;No, send it (doesn't change z)
	adiw	zl,1			;Increment the address
	rjmp	SendEStringCont


;*****************************************************************************
;
;	SendHexByte
;
;	Expects:	TempUa = byte to store
;				StringOutControl is set
;
;	Sends the byte as two hex digits
;
;	Uses:	TempUa, ParamReg
;
;*****************************************************************************
;
SendHexByte:
	mov		ParamReg,TempUa	;Copy the character
	swap	ParamReg			;Swap nibbles
	andi	ParamReg,0x0F		;Get the four bits
	addi	ParamReg,'0'		;ASCIIize it by adding '0'
	cpi		ParamReg,':'		;Colon is one past '9'
	brlo	SHB1OK				;Ok if it's a valid digit
	addi	ParamReg,'a'-':'	;Convert to a-f
SHB1OK:
	push	TempUa
	rcall	SendChar
	pop		ParamReg
	
	andi	ParamReg,0x0F		;Get the four LS bits
	addi	ParamReg,'0'		;ASCIIize it by adding '0'
	cpi		ParamReg,':'		;Colon is one past '9'
	brlo	SHB2OK			;Ok if it's a valid digit
	addi	ParamReg,'a'-':'	;Convert to a-f
SHB2OK:
	;rjmp	SendChar

;*****************************************************************************
;
;	SendChar	Sends a character to the selected buffer(s)
;
; Expects:	ParamReg = character
;			StringOutControl is set
;
; Uses:		y, TempUa, TempUc
;
; Must not change ParamReg, z
;
;*****************************************************************************
;
SendChar:
	mov		TempUc,StringOutControl	;Ready for ANDI instruction
	andi	TempUc,OutToLCD
	brze	PC+2
	rcall	SendLCDChar	;Send (buffer) the character in ParamReg
	mov		TempUc,StringOutControl	;Ready for ANDI instruction
	andi	TempUc,OutToTx
	brze	PC+2
	rcall	SendTXChar	;Send (buffer) the character in ParamReg
	mov		TempUc,StringOutControl	;Ready for ANDI instruction
	andi	TempUc,OutToSlaves
	brze	PC+2
	rcall	SendSUChar	;Send (buffer) the character in ParamReg
Return2:	
	ret


;*****************************************************************************
;
;	PollSlave			Sends a poll message to the selected slave
;
;	Expects:	ParamReg = Slave ID character (B/I/S)
;
;	SendSUChar also uses y, TempUa, TempUb
;
;*****************************************************************************
;
PollSlave:
	rcall	SendTxPollChar	;Echo poll char to computer comms if requested
	rcall	SendSUChar		;Send the ID char from ParamReg
	ldi		ParamReg,'?'
	rcall	SendTxPollChar	;Echo poll char to computer comms if requested
	rcall	SendSUChar

	clr		PollTick
	ldi		ParamReg, WFSRWaitingForEnd                     ; We are now waiting for a response
	sts		WaitingForSlaveReply, ParamReg

	ldi		ParamReg,CR
	rcall	SendTxPollChar	;Echo poll char to computer comms if requested
	;rcall	SendSUChar		;Send CR and return

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
; Must not change ParamReg, z, TempUc
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
	lds		TempUa,SlaveTxBufCnt
	cpi		TempUa,SlaveTxBufSiz
	brsh	SSUCBufferFull
	
	; Add the start offset and the length together
	lds		yl,SlaveTxBufO1	;Get the offset to the first character
	add		yl,TempUa	;Add the TxBufCnt (Note: Total must not exceed 256)
	
	; Now yl is sort of the the offset of the first empty space
	; We have to adjust it though, if it's past the end of the (circular) buffer
	cpi		yl,SlaveTxBufSiz
	brlo	SSUCBNFOk			;Ok if the calculated offset is already inside the buffer
	subi	yl,SlaveTxBufSiz		;Otherwise, adjust it down
SSUCBNFOk:
	
	; Now yl is the adjusted offset of the first empty space
	addi	yl,low(SlaveTxBuf)	;Add the actual buffer address
	ldi		yh,high(SlaveTxBuf)	;Note: Only works if buffer does not cross a 256-byte boundary
	
	; Now y is the address of the first empty space in the buffer
	st		y,ParamReg
	inc		TempUa			;Increment and save the count
	sts		SlaveTxBufCnt,TempUa

SSUCDone:	
	reti					;Reenable interrupts and then return

SSUCBufferFull:
	; If we get here the buffer must be full
	sei						;Enable interrupts again so transmitter can keep sending
	adiw	yl,1			;Increment the loop counter
	; Note: At 2,400bps, the UART should send a character about every 4.2 milliseconds
	; This buffer full loop has 8 instructions (10 cycles) and takes more than 2 microseconds at 4MHz
	;  so y shouldn't count to more than about 2100 (4200 / 10) before there's room for the next character
	cpi		yh,12			;Has y got to 12 * 256 = 3072?
	brlo	SendSUCharLoop	;No, keep waiting
	; What should we do here???
	ldi		ParamReg,SUBufferFullErrorCode
	rjmp	NonFatalProgramError	;Display the error code on the LEDs
									; and then enable interrupts, return, and try running again


;*****************************************************************************
;
;	SendLCDTxFString	Sends a null-terminated string from the FLASH
;							to the Tx and LCD output buffers
;
; Expects:	z = Flash string pointer
;
; Uses:		R0, y, z, TempUa, TempUc, ParamReg
;
; Returns:	R0 = 0
;
;*****************************************************************************
;
SendLCDTxFString:
	ldi		TempUa,OutToLCD+OutToTx
	rjmp	SendTxFStringCont	 ; and return


;*****************************************************************************
;
;	SendTxFString	Sends a null-terminated string from the FLASH to the Tx buffer
;
; Expects:	z = Flash string pointer
;
; Uses:		R0, y, z, TempUa, TempUc, ParamReg
;
; Returns:	R0 = 0
;
;*****************************************************************************
;
SendTxFString:
	ldi		TempUa,OutToTx
SendTxFStringCont:
	mov		StringOutControl,TempUa
	;rjmp	SendFString		 ; and return

;*****************************************************************************
;
;	SendFString	Sends a null-terminated string from the FLASH to the selected buffer
;
; Expects:	z = Flash string pointer
;			StringOutControl is set
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
	adiw	zl,1		;Increment the 16-bit buffer pointer for next time
	mov		ParamReg,r0	;Save byte ready to output
	rcall	SendChar
	rjmp	SendFString


;*****************************************************************************
;
;	SendSpaces		Sends the requested number of spaces to the LCD
;
;	Expects:	TempUc = Number of spaces to send
;
;*****************************************************************************
;
;SendSpaces:
;	ldi		ParamReg,' '	; Load the space
;SSLoop:
;	rcall	SendLCDChar		; Send it (doesn't change TempUc or ParamReg)
;	dec		TempUc
;	brnz	SSLoop
;	ret						; Done


;*****************************************************************************
;
;	LCDReset	Sends the standard header string to the LCD buffer
;				The interrupt routine then outputs the buffer automatically
;
;	Resets LCDUseTime
;
;*****************************************************************************
;
LCDReset:
	; Send the header string (Uses SendLCDChar which also resets LCDUseTime)
	LoadAndSendLCDEString	LCDHeaderString

; Zeroise the display modes
	SetDM	DMIdle			;Set into idle mode
	sts		EntryStatus,TempUa

; Do a few other checks while we're here (usually about every 10 seconds)
	; Check for diagnostic mode
	lds		TempUa,PowerByte
	andi	TempUa,DiagnosticBit
	brze	LCDRNotDiag
	LoadAndSendLCDEString	DLCDString
LCDRNotDiag:

	; Check the current voltage states
	lds		TempUa,BattVoltageReading	;Get the current battery state
	cpi		TempUa,BVLowThreshold
	brsh	BVOk
	LoadAndSendLCDEString	BLLCDString
	lds		TempUa,BVLowCount
	inc		TempUa						;Increment BV low count
	brnz	PC+2
	dec		TempUa						; but not past 255
	rjmp	BVDone
BVOk:
	clr		TempUa						;Reset BV low count
BVDone:
	sts		BVLowCount,TempUa			;Save new BV low count

	lds		TempUa,ChargeVoltageReading	;Read the current charging state
	cpi		TempUa,ChargingThreshold
	brlo	BCOk
	LoadAndSendLCDEString	BCLCDString
BCOk:
	
; Check and update the current logic states
	lds		TempUa,PowerManual
	tst		TempUa
	brnz	BVSOk					;Do nothing if in manual mode
	lds		TempUb,PowerByte		;What's our current logic state
	andi	TempUb,PowerBits
	cpi		TempUb,PowerNormal
	brne	NotNormalPower


	; Our logic state is normal
	lds		TempUa,BVLowCount		;See how long we've been low
	cpi		TempUa,3
	brlo	BVSOk					;If we're less than 3, maybe not really low yet
	; We've just gone from normal to low
	lds		TempUb,PowerByte
	andi	TempUb,NotPowerBits
	ori		TempUb,PowerLow
	sts		PowerByte,TempUb
	LoadAndSpeakEString	SPBattery
	LoadAndSpeakEString	SPLow
	rcall	SendPowerMessages
	DoBeep	Beep1200Hz,Beep0s1
	DoBeep	Beep600Hz,Beep0s2
	DoBeep	Beep400Hz,Beep0s3
	LoadAndSendLCDEString	BatteryLowLCDString
	LoadAndSendTxFString	PowerString
BVSOk:
	ret

NotNormalPower:
	; Our logic state is low (or off???)
	; Set our logic state to normal when we get over the BV Full Threshold
	lds		TempUa,BattVoltageReading	;Read the current battery state
	cpi		TempUa,BVFullThreshold
	brlo	BVSOk					;If we're lower, the current BV state is correct
	lds		TempUb,PowerByte
	andi	TempUb,NotPowerBits
	ori		TempUb,PowerNormal
	sts		PowerByte,TempUb
	LoadAndSpeakEString	SPBattery
	LoadAndSpeakEString	SPNormal
	rjmp	SendPowerMessages	;We've just gone from low to normal


;*****************************************************************************
;
;	DoPowerDownSeq	Beeps then turns the power off, i.e., commits suicide
;
;	Uses:			ParamReg, TempUa, TempUb, TempUc, y
;
;*****************************************************************************
;
DoPowerDownSeq:
; Advise the base we're about to die
	lds		TempUa,PowerByte
	andi	TempUa,NotPowerBits	;Set power bits to 00
	sts		PowerByte,TempUa
	rcall	SendPowerMessages	;Send the info to the base

; Do a dying scream (also gives time for the above warning to get there)
	DoBeep	Beep1200Hz,Beep0s2
	DoBeep	Beep600Hz,Beep0s3
	DoBeep	Beep300Hz,Beep0s4
HoldBreathLoop:	
	lds		TempUa,BeepBufCnt	;Hold our breath while we emit our last dying sounds
	tst		TempUa
	brnz	HoldBreathLoop		;Wait for the interrupt routines to do their work

	cbi		PowerPort,PowerPin	;Turn off the power to the system, i.e., commit suicide
	ret


;*****************************************************************************
;
;	InitDecimalByteEntry
;
;	Uses:	z,TempUa
;
;*****************************************************************************
;
InitDecimalByteEntry:
	ldi		TempUa,3
	sts		MaxEntryCharacters,TempUa	;MaxEntryCharacters = 3
	clr		zh
	ser		zl
	stsw	MaxValue,z					;MaxValue = 255
	rjmp	InitDecimalEntryCont


;*****************************************************************************
;
;	InitDecimalWordEntry
;
;	Uses:	z,TempUa
;
;*****************************************************************************
;
InitDecimalWordEntry:
	ldi		TempUa,5
	sts		MaxEntryCharacters,TempUa	;MaxEntryCharacters = 5
	ser		zh
	ser		zl
	stsw	MaxValue,z					;MaxValue = 65535
InitDecimalEntryCont:
	clrw	z
	sts		NumEnteredCharacters,zl		;NumEnteredCharacters = 0
	stsw	MinValue,z					;MinValue = 0
	ldi		TempUa,1
	sts		MinEntryCharacters,TempUa	;MinEntryCharacters = 1
	setES	ESDecimal					;Allow them to enter a decimal word
	ret


;*****************************************************************************
;
;	CheckInputs
;
;	Checks the IR
;
;*****************************************************************************
;
CheckInputs:

; Check the IR
	lds		zl,HaveIR
	tst		zl
	brnz	ActionIR
	ret

ActionIR:
	clr		TempUa
	sts		HaveIR,TempUa		;Clear the flag
	
;*****************************************************************************

; Check for repeat/error codes
	lds		zl,IRByte		;Get the IR code into zl
	cpi		zl,IRRepeat
	breq	IgnoreIR		;Ignore for now
	cpi		zl,IRError
	brne	CI1
	rcall	ErrorBeep
IgnoreIR:
	ret
CI1:

;*****************************************************************************
;
; There's a regular IR button
;
;*****************************************************************************
;
; Check these ones whatever the mode
;
;*****************************************************************************

	cpi		zl,IR_R_HALT
	brne	INHalt
; The halt button was pressed
	rcall	SendHaltMessages
	SayWord	SP_OVERRIDE
	ldi		ParamReg,SP_stop
	rjmp	SpeakFinishedIR		;Always resets back to idle mode
INHalt:
	cpi		zl,IR_R_CLEAR
	brne	INClear
; The clear button was pressed
	SayWord	SP_OVERRIDE
	ldi		ParamReg,SP_clear
	rjmp	SpeakFinishedIR		;Always resets back to idle mode
INClear:

;*****************************************************************************
;
;	Check the entry status
;
;*****************************************************************************

	lds		TempUa,EntryStatus
	tst		TempUa				;Idle ?
	brne	ESN0
	rjmp	ES0					;Yes, branch
ESN0:
; We're not idle	
	lds		TempUb,NumEnteredCharacters

; If Command=LEFT and have entered digits, erase last digit	
	cpi		zl,IR_R_LEFT
	brne	ESNotErase
	tst		TempUb
	brze	ESNotErase
	dec		TempUb			;--NumEnteredDigits
	sts		NumEnteredCharacters,TempUb
	ldi		ParamReg,SP_back
	rjmp	SpeakAcceptIR
ESNotErase:

;If Command=ENTER and have entered >= MinEntryCharacters
	cpi		zl,IR_R_ENTER
	brne	ESNotEnter
	lds		TempLa,MinEntryCharacters
	cp		TempUb,TempLa
	brlo	ESNotEnter
	clrw	y				;Default entered value to 0
	tst		TempUb			;NumEnteredDigits = 0?
	brze	ESEnterLoopDone
	ldiw	z,EntryBuffer
	ld		ParamReg,z+
	rcall	ProcessFirstDigit
	brcc	FDOk
	rcall	ErrorBeep
	rjmp	InvalidIR
FDOk:
ESEnterLoop:	;Process succeeding digits
	dec		TempUb			;NumEnteredDigits left = 0?
	brze	ESEnterLoopDone
	ld		ParamReg,z+
	rcall	ProcessNextDigit
	brcc	ESEnterLoop
	rcall	ErrorBeep
	rjmp	InvalidIR
ESEnterLoopDone:
	stsw	EnteredValue,y	;Save entered value
;Compare with MinValue and MaxValue
	ldsw	z,MinValue
	cp		yl,zl
	cpc		yh,zh
	brsh	MinOk
	LoadAndSpeakEString	SPTooSmall
	rjmp	AcceptIR
MinOk:
	ldsw	z,MaxValue
	cp		zl,yl
	cpc		zh,yh
	brsh	MaxOk
	LoadAndSpeakEString	SPTooBig
	rjmp	AcceptIR
MaxOk:
	setES	ESDone
	SayWord	SP_enter
	rjmp	ES0
ESNotEnter:

	cpi		TempUa,ESDecimal
	brne	ESNotDecimal
; In decimal entry mode -- accept digits	
	lds		TempLa,MaxEntryCharacters
	cp		TempUb,TempLa	;Have we already the max. number of characters?
	brsh	ESNotDecimal
	cpi		zl,9+1			;Is it a valid digit?
	brsh	ESNotDecimal
	addi	zl,'0'			;Yes, make it decimal
	ldiw	y,EntryBuffer	;Add number of entered characters to buffer offset
	add		yl,TempUb		; (Assuming buffer doesn't cross a 256 byte boundary)
	st		y,zl			;Save digit in buffer
	inc		TempUb			;Count it
	sts		NumEnteredCharacters,TempUb
	mov		ParamReg,zl
	rcall	TellDigit
	rjmp	AcceptIR
ESNotDecimal:
ES0:

;*****************************************************************************
;
; Now check the display mode
;
;*****************************************************************************

	lds		TempUa,DisplayMode	;Get current display mode
	tst		TempUa
	brze	DM0
	rjmp	DMN0
DM0:

;*****************************************************************************
;
; We are IDLE
;
;*****************************************************************************

	cpi		zl,IR_R_LIGHTS
	brne	INLights
; We are idle and the lights button was pressed
	SetDM	DMLights
	LoadAndSendLCDEString	LCDLightString
	LoadAndSendTxFString	LightsString
	LoadAndSpeakEString		SPLights
	rjmp	AcceptIR
INLights:

	cpi		zl,IR_R_POWER
	brne	INPower
; We are idle and the power button was pressed
	SetDM	DMPower
	LoadAndSendLCDEString	LCDPowerString
	LoadAndSendTxFString	PowerString
	LoadAndSpeakEString		SPPower
	rjmp	AcceptIR
INPower:

	cpi		zl,IR_R_STEALTH
	brne	INStealth
; We are idle and the stealth button was pressed
	SetDM	DMStealth
	LoadAndSendLCDEString	LCDStealthString
	LoadAndSendTxFString	StealthString
	LoadAndSpeakEString		SPStealth
	rjmp	AcceptIR
INStealth:

	cpi		zl,IR_R_DEMO
	brne	INDemo
; We are idle and the demo button was pressed
	clr		TempUa
	sts		StickyDemo,TempUa	;Set StickyDemo = false
	SetDM	DMDemo
	LoadAndSendLCDEString	LCDDemoString
	LoadAndSendTxFString	DemoString
	LoadAndSpeakEString		SPDemo
	rjmp	AcceptIR
INDemo:

	cpi		zl,IR_R_DIAGNOSTICS
	brne	INDiag
; We are idle and the diagnostics button was pressed
	SetDM	DMDiagnostics
	LoadAndSendLCDEString	LCDDiagnosticString
	LoadAndSendTxFString	DiagnosticsString
	LoadAndSpeakEString		SPDiagnostics
	rjmp	AcceptIR
INDiag:

	cpi		zl,IR_R_QUERY
	brne	INQuery
; We are idle and the query button was pressed
	SetDM	DMQuery
	;LoadAndSendLCDEString	LCDQueryString
	;LoadAndSendTxFString	QueryString
	LoadAndSpeakEString		SPQuery
	rjmp	AcceptIR
INQuery:

	cpi		zl,IR_R_HELP
	brne	INHelp
; We are idle and the help button was pressed
	LoadAndSpeakEString		SPHelp
	rjmp	AcceptIR
INHelp:

	cpi		zl,IR_R_STRAIGHT
	brne	INStraight
; We are idle and the straight button was pressed
	clrsw	Angle
	ldi		ParamReg,SP_straight
	rjmp	SpeakFinishedIR
INStraight:

	cpi		zl,IR_R_AUTOSTOP
	brne	INAutoStop
; We are idle and the AutoStop button was pressed
	SetDM	DMAutostop
	LoadAndSendLCDEString	LCDAutoStopString
	LoadAndSendTxFString	AutoStopString
	LoadAndSpeakEString		SPAutoStop
	rjmp	AcceptIR
INAutoStop:

	cpi		zl,IR_R_TRAVEL_MODE
	brne	INTravelMode
; We are idle and the travel mode button was pressed
	SetDM	DMTravelMode
	LoadAndSendLCDEString	LCDTravelModeString
	LoadAndSendTxFString	TravelModeString
	LoadAndSpeakEString		SPTravelMode
	rjmp	AcceptIR
INTravelMode:

	cpi		zl,IR_R_FRONT_BACK_MODE
	brne	INFrontBack
; We are idle and the Front/Back mode button was pressed
	SetDM	DMFrontBackMode
	LoadAndSendLCDEString	LCDFBSwitchModeString
	LoadAndSendTxFString	FBSwitchModeString
	LoadAndSpeakEString		SPFBSwitchMode
	rjmp	AcceptIR
INFrontBack:

	cpi		zl,IR_R_FORWARD
	brne	INForward
; We are idle and the forward button was pressed
	SetDM	DMForward
	rcall	InitDecimalWordEntry
	ldi		ParamReg,SP_forward
	rjmp	SpeakAcceptIR
INForward:

	cpi		zl,IR_R_REVERSE
	brne	INReverse
; We are idle and the reverse button was pressed
	SetDM	DMReverse
	rcall	InitDecimalWordEntry
	ldi		ParamReg,SP_reverse
	rjmp	SpeakAcceptIR
INReverse:

	cpi		zl,IR_R_ANGLE
	brne	INAngle
; We are idle and the angle button was pressed
	SetDM	DMAngle
	rcall	InitDecimalWordEntry
	ldiw	z,359
	stsw	MaxValue,z		;Don't let them enter angles more than 359
	ldi		ParamReg,SP_angle
	rjmp	SpeakAcceptIR
INAngle:

	cpi		zl,IR_R_SPEED
	brne	INSpeed
; We are idle and the speed button was pressed
	SetDM	DMSpeed
	rcall	InitDecimalByteEntry
	ldiw	z,20
	stsw	MinValue,z		;Don't let them enter speeds less than 20
	LoadAndSendLCDEString	LCDSpeedString
	LoadAndSendTxFString	SpeedString
	ldi		ParamReg,SP_speed
	rjmp	SpeakAcceptIR
INSpeed:

	cpi		zl,IR_R_INTENSITY
	brne	INIntensity
; We are idle and the intensity button was pressed
	SetDM	DMIntensity
	rcall	InitDecimalByteEntry
	ldiw	z,20
	stsw	MinValue,z		;Don't let them enter an intensity of less than 20
	LoadAndSendLCDEString	LCDIntensityString
	LoadAndSendTxFString	IntensityString
	;LoadAndSpeakEString		SPIntensity
	ldi		ParamReg,SP_intensity
	rjmp	SpeakAcceptIR
INIntensity:

	rjmp	InvalidIR
DMN0:

;*****************************************************************************

	cpi		TempUa,DMPower
	breq	DMIsPower
	rjmp	DMNP
DMIsPower:
; We are in power mode -- accept Off, On, Query, Auto, 1 (Manual power low)
	cpi		zl,IR_R_OFF
	brne	PNOff
	LoadAndSendLCDTxFString	OffString
	LoadAndSpeakEString		SPOff
	rjmp	DoPowerDownSeq		;and return (if it fails)
PNOff:

	cpi		zl,IR_R_ON
	brne	PNOn
	LoadAndSendLCDTxFString	OnString
	LoadAndSpeakEString		SPOn
	ser		TempUa
	sts		PowerManual,TempUa	;Set PowerManual to true
	lds		TempUa,PowerByte	;Get power byte into TempUa
	andi	TempUa,NotPowerBits	;Get all the other bits into TempUa
	ori		TempUa,PowerNormal	;Set power bits to normal
	rjmp	UpdateBasePower
PNOn:

	cpi		zl,IR_1
	brne	PN1
	LoadAndSendLCDTxFString	LowString
	LoadAndSpeakEString		SPLow
	ser		TempUa
	sts		PowerManual,TempUa	;Set PowerManual to true
	lds		TempUa,PowerByte	;Get power byte into TempUa
	andi	TempUa,NotPowerBits	;Get all the other bits into TempUa
	ori		TempUa,PowerLow		;Set power bits to low
	rjmp	UpdateBasePower
PN1:

	cpi		zl,IR_R_QUERY
	breq	DoTellPower

	cpi		zl,IR_R_AUTO
	brne	PNAuto
	clr		TempUa
	sts		PowerManual,TempUa		;Set PowerManual to false
	ldi		ParamReg,SP_automatic
	rjmp	SpeakFinishedIR
PNAuto:

	cpi		zl,IR_R_MANUAL
	brne	PNManual
	ser		TempUa
	sts		PowerManual,TempUa		;Set PowerManual to true
	ldi		ParamReg,SP_manual
	rjmp	SpeakFinishedIR
PNManual:

	rjmp	InvalidIR
DMNP:

;*****************************************************************************

	cpi		TempUa,DMQuery
	breq	DMDoQuery
	rjmp	DMNQuery
DMDoQuery:
; We are in query mode -- accept Lights, Power, Forward, etc.
	cpi		zl,IR_R_LIGHTS
	brne	QNLights
DoTellLights:	
	rcall	TellLights
	rjmp	FinishedIR
QNLights:

	cpi		zl,IR_R_POWER
	brne	QNPower
DoTellPower:	
	rcall	TellPower
	rjmp	FinishedIR
QNPower:

	cpi		zl,IR_R_STEALTH
	brne	QNStealth
	SayWord	SP_stealth
DoTellStealth:
	lds		ParamReg,PowerByte
	andi	ParamReg,StealthBit
	rcall	TellOffOn
	rjmp	FinishedIR
QNStealth:

	cpi		zl,IR_R_DIAGNOSTICS
	brne	QNDiagnostics
DoTellDiagnostics:
	lds		ParamReg,PowerByte
	andi	ParamReg,DiagnosticBit
	rcall	TellOffOn
	rjmp	FinishedIR
QNDiagnostics:

	cpi		zl,IR_R_AUTOSTOP
	brne	QNAutoStop
	LoadAndSpeakEString	SPAutoStop
DoTellAutoStop:
	lds		ParamReg,TravelByte
	andi	ParamReg,AutoStopBit
	rcall	TellOffOn
	rjmp	FinishedIR
QNAutoStop:

	cpi		zl,IR_R_ANGLE
	brne	QNAngle
	SayWord	SP_angle
DoTellAngle:	
	ldsw	z,Angle
	rcall	TellNumber
	SayWord	SP_degree
	ldi		ParamReg,PH_z
	rjmp	SpeakFinishedIR
QNAngle:

	cpi		zl,IR_R_SPEED
	brne	QNSpeed
	SayWord	SP_speed
DoTellSpeed:	
	lds		zl,Speed
	clr		zh
	rcall	TellNumber
	rjmp	FinishedIR
QNSpeed:
	cpi		zl,IR_R_INTENSITY
	brne	QNIntensity
	SayWord	SP_intensity
DoTellIntensity:	
	lds		zl,HeadlightIntensity
	clr		zh
	rcall	TellNumber
	rjmp	FinishedIR
QNIntensity:
	cpi		zl,IR_R_FORWARD
	breq	QDistance
	cpi		zl,IR_R_REVERSE
	brne	QNDistance
QDistance:
	LoadAndSpeakEString	SPDistance
DoTellDistance:	
	ldsw	z,Distance
	rcall	TellNumber
	LoadAndSpeakEString		SPmm
	rjmp	FinishedIR
QNDistance:

	cpi		zl,IR_R_TRAVEL_MODE
	brne	QNTM
	LoadAndSpeakEString	SPTravelMode
DoTellTravelMode:
	lds		TempUa,TravelByte
	andi	TempUa,TravelModeBits
	cpi		TempUa,TravelModeTS
	brne	QTMNotTS
	LoadAndSpeakEString		SPTMTS
	rjmp	FinishedIR
QTMNotTS:
	cpi		TempUa,TravelModeC
	brne	QTMNotC
	;LoadAndSpeakEString		SPTMC
	ldi		ParamReg,SP_circle
	rjmp	SpeakFinishedIR
QTMNotC:
	cpi		TempUa,TravelModeX
	brne	QTMNotX
	;LoadAndSpeakEString		SPTMX
	ldi		ParamReg,SP_extreme
	rjmp	SpeakFinishedIR
QTMNotX:
	LoadAndSpeakEString		SPInvalid
	rjmp	FinishedIR
QNTM:

	cpi		zl,IR_R_FRONT_BACK_MODE
	brne	QNFB
	LoadAndSpeakEString	SPFBSwitchMode
DoTellFrontBackMode:
	lds		TempUa,TravelByte
	andi	TempUa,FrontSwitchModeBit
	ldi		ParamReg,SP_Manual
	brze	QFBOk
	ldi		ParamReg,SP_automatic
QFBOk:
	rjmp	SpeakFinishedIR
QNFB:

	cpi		zl,IR_R_DEMO
	brne	QNGreeting
DoTellGreeting:
	LoadAndSpeakEString	SPGreeting
	rjmp	FinishedIR
QNGreeting:

	cpi		zl,IR_R_HELP
	brne	QNVersion
DoTellVersion:
	LoadAndSpeakEString	SPVersion
	rjmp	FinishedIR
QNVersion:

	rjmp	InvalidIR
DMNQuery:

;*****************************************************************************

	cpi		TempUa,DMLights
	breq	DML
	rjmp	DMNL
DML:
; We are in lights mode -- accept Query, 0 (Off), Off (Normal), On (Full), Demo/Diag (Test)
	cpi		zl,IR_R_QUERY
	brne	DMLNQ
	rjmp	DoTellLights
DMLNQ:

	cpi		zl,IR_0
	brne	LN0
	ser		TempUa
	sts		LightsManual,TempUa	;Set LightsManual to true
	LoadAndSendLCDTxFString	OffString
	LoadAndSpeakEString		SPOff
	lds		TempUa,PowerByte	;Get power byte into TempUa
	andi	TempUa,NotLightBits	;Get all the other bits into TempUa
	rjmp	UpdateBasePower
LN0:

	cpi		zl,IR_R_OFF
	brne	LNOff
	ser		TempUa
	sts		LightsManual,TempUa	;Set LightsManual to true
	LoadAndSendLCDTxFString	NormalString
	LoadAndSpeakEString		SPNormal
	lds		TempUa,PowerByte	;Get power byte into TempUa
	andi	TempUa,NotLightBits	;Get all the other bits into TempUa
	ori		TempUa,LightsNormal
	rjmp	UpdateBasePower
LNOff:

	cpi		zl,IR_R_ON
	brne	LNOn
	ser		TempUa
	sts		LightsManual,TempUa	;Set LightsManual to true
	LoadAndSendLCDTxFString	FullString
	LoadAndSpeakEString		SPFull
	lds		TempUa,PowerByte	;Get power byte into TempUa
	andi	TempUa,NotLightBits	;Get all the other bits into TempUa
	ori		TempUa,LightsFull
	rjmp	UpdateBasePower
LNOn:

	cpi		zl,IR_R_DEMO
	breq	DoLightsTest
	cpi		zl,IR_R_DIAGNOSTICS
	brne	LND
DoLightsTest:	
	LoadAndSendLCDTxFString	TestString
	LoadAndSpeakEString		SPTest
	lds		TempUa,PowerByte	;Get power byte into TempUa
	andi	TempUa,NotLightBits	;Get all the other bits into TempUa
	ori		TempUa,LightsTest
UpdateBasePower:	
	sts		PowerByte,TempUa
	rcall	SendPowerMessages
	rjmp	FinishedIR
LND:

	cpi		zl,IR_R_AUTO
	brne	LNAuto
	clr		TempUa
	sts		LightsManual,TempUa		;Set LightsManual to false
	ldi		ParamReg,SP_automatic
	rjmp	SpeakFinishedIR
LNAuto:

	cpi		zl,IR_R_MANUAL
	brne	LNManual
	ser		TempUa
	sts		LightsManual,TempUa		;Set LightsManual to true
	ldi		ParamReg,SP_manual
	rjmp	SpeakFinishedIR
LNManual:

	rjmp	InvalidIR
DMNL:
	
;*****************************************************************************

	cpi		TempUa,DMStealth
	brne	DMNS
; We are in stealth mode -- Off and On
	cpi		zl,IR_R_OFF
	brne	SNOff
	LoadAndSendLCDTxFString	OffString
	LoadAndSpeakEString		SPOff
	lds		TempUa,PowerByte	;Get power byte into TempUa
	andi	TempUa,NotStealthBit	;Get all the other bits into TempUa
	rjmp	UpdateBasePower
SNOff:

	cpi		zl,IR_R_ON
	brne	SNOn
	LoadAndSendLCDTxFString	OnString
	LoadAndSpeakEString		SPOn
	lds		TempUa,PowerByte	;Get power byte into TempUa
	ori		TempUa,StealthOn
	rjmp	UpdateBasePower
SNOn:

	rjmp	InvalidIR
DMNS:

;*****************************************************************************

	cpi		TempUa,DMIntensity
	brne	DMNI
; We are in intensity mode -- Query, Demo (Lights Test) or accept a value
	lds		TempUa,EntryStatus
	cpi		TempUa,ESDone
	brne	DMNotIntensityEntered
	lds		yl,EnteredValueLSB
	sts		HeadlightIntensity,yl
	rcall	SendIntensityMessages
	rjmp	FinishedIR
DMNotIntensityEntered:

	cpi		zl,IR_R_QUERY
	brne	DMINQuery
	rjmp	DoTellIntensity
DMINQuery:

	cpi		zl,IR_R_DEMO
	brne	INotDemo
	rjmp	DoLightsTest
INotDemo:

	rjmp	InvalidIR
DMNI:

;*****************************************************************************

	cpi		TempUa,DMAutoStop
	brne	DMNAS
; We are in autostop mode -- accept Off, On, Query
	cpi		zl,IR_R_QUERY
	brne	ASNQ
	rjmp	DoTellAutoStop
ASNQ:

	cpi		zl,IR_R_OFF
	brne	ASNOff
	LoadAndSendLCDTxFString	OffString
	LoadAndSpeakEString		SPOff
	lds		TempUa,TravelByte	;Get travel byte into TempUa
	andi	TempUa,NotAutoStopBit	;Get all the other bits into TempUa
	rjmp	UpdateBaseTravel
ASNOff:

	cpi		zl,IR_R_ON
	brne	ASNOn
	LoadAndSendLCDTxFString	OnString
	LoadAndSpeakEString		SPOn
	lds		TempUa,TravelByte	;Get travel byte into TempUa
	ori		TempUa,AutoStopBit
UpdateBaseTravel:	
	sts		TravelByte,TempUa
	rcall	SendTravelMessages
	rjmp	FinishedIR
ASNOn:

	rjmp	InvalidIR
DMNAS:
	
;*****************************************************************************

	cpi		TempUa,DMDemo
	breq	DMIsDemo
	rjmp	DMNDemo
DMIsDemo:

; We are in demo mode -- Lights/Intensity (Lights Test), Forward/Reverse (10m)
;	Left/Right (turn on spot), +/- (Change Manual Front)
;	Help (Speak Mode)

	cpi		zl,IR_R_DEMO
	brne	DNotDemo
	ser		TempUa
	sts		StickyDemo,TempUa	;Set StickyDemo = true
	LoadAndSpeakEString	SPSticky
	rjmp	AcceptIR
DNotDemo:

	cpi		zl,IR_0
	brne	DMNot0
	clrsw	Angle
	ser		zl
	sts		Speed,zl
	ldiw	z,500
	stsw	Distance,z
	rcall	SendGoMessages
	rcall	SendReverseMessages
	rjmp	DemoSayGo
DMNot0:

	cpi		zl,IR_1
	brne	DMNot1
	ldiw	z,360-45
	rjmp	Demo100Cont
DMNot1:

	cpi		zl,IR_3
	brne	DMNot3
	ldiw	z,45
Demo100Cont:
	stsw	Angle,z
	ser		zl
	sts		Speed,zl
	ldiw	z,100
	stsw	Distance,z
DemoDoGo:	
	rcall	SendGoMessages
DemoSayGo:	
	SayWord	SP_go
	rjmp	DoneDemo
DMNot3:

	cpi		zl,IR_4
	brne	DMNot4
	ldiw	z,360-90
	rjmp	Demo100Cont
DMNot4:

	cpi		zl,IR_6
	brne	DMNot6
	ldiw	z,90
	rjmp	Demo100Cont
DMNot6:

	cpi		zl,IR_7
	brne	DMNot7
	ldiw	z,360-135
	rjmp	Demo100Cont
DMNot7:

	cpi		zl,IR_9
	brne	DMNot9
	ldiw	z,135
	rjmp	Demo100Cont
DMNot9:

	cpi		zl,IR_5
	brne	DMNot5
	ser		zl
	sts		Speed,zl
	ldiw	z,300
	stsw	Distance,z
	ldiw	z,90
	stsw	Angle,z
	rcall	SendGoMessages
	rcall	SendGoMessages
	rcall	SendGoMessages
	rjmp	DemoDoGo		;Does the fourth go
DMNot5:

	cpi		zl,IR_R_SPEED
	brne	DMNotSpeed
	SayWord	SP_speed
	clrsw	Angle
	ldiw	z,200
	stsw	Distance,z
	ldi		zl,64
	sts		Speed,zl
	rcall	SendGoMessages
	ldi		zl,128
	sts		Speed,zl
	rcall	SendGoMessages
	ldi		zl,192
	sts		Speed,zl
	rcall	SendGoMessages
	ldi		zl,255
	sts		Speed,zl
	rjmp	DemoDoGo		;Does the fourth go
DMNotSpeed:

	cpi		zl,IR_R_LIGHTS
	brne	DMCheckIntensity
DMDoLightsTest:	
	rjmp	DoLightsTest
DMCheckIntensity:
	cpi		zl,IR_R_INTENSITY
	breq	DMDoLightsTest
DMNDLT:

	cpi		zl,IR_R_FORWARD
	brne	DNForward
	clrsw	Angle
	ldiw	z,10000
	stsw	Distance,z
	rcall	SendGoMessages
	LoadAndSendLCDEString	ForwardString
	SayWord	SP_forward
	rjmp	DoneDemo
DNForward:

	cpi		zl,IR_R_REVERSE
	brne	DNReverse
	clrsw	Angle
	ldiw	z,10000
	stsw	Distance,z
	rcall	SendReverseMessages
	LoadAndSendLCDEString	BackwardString
	SayWord	SP_reverse
DoneDemo:
	; If in sticky mode, stay in demo mode, else exit it
	lds		TempUa,StickyDemo
	tst		TempUa
	brze	DDNotSticky
	rjmp	AcceptIR
DDNotSticky:
	rjmp	FinishedIR
DNReverse:

	cpi		zl,IR_R_LEFT
	brne	DNLeft
	ldi		ParamReg,SP_left
	push	ParamReg
	ldiw	y,0xFFFF
	ldiw	z,255
	rjmp	DemoManual
DNLeft:

	cpi		zl,IR_R_RIGHT
	brne	DNRight
	ldi		ParamReg,SP_right
	push	ParamReg
	ldiw	y,255
	ldiw	z,0xFFFF
DemoManual:
	stsw	LeftMotorSpeed,y
	stsw	RightMotorSpeed,z
	rcall	SendManualMotorMessages
	pop		ParamReg
	rcall	SpeakWord
	rjmp	DoneDemo
DNRight:

	cpi		zl,IR_R_PLUS_MINUS
	brne	DNPM
	lds		zl,TravelByte
	mov		zh,zl			;Copy into zh
	andi	zl,NotFrontSwitchModeBits	;Puts into manual/front mode
	andi	zh,FrontBit
	brnz	IRPMOk			;Branch if was already set
	ori		zl,FrontBit		;Else set it now
IRPMOk:
	sts		TravelByte,zl	;Save complemented bit (along with other bits)
	rcall	SendTravelMessages
	DoBeep	Beep160Hz,Beep0s2	;Since nothing to say
	rjmp	DoneDemo
DNPM:

	cpi		zl,IR_R_HELP
	brne	DNHelp
	SetDM	DMSpeakW
	LoadAndSpeakEString		SPSpeak
	rjmp	AcceptIR
DNHelp:

	cpi		zl,IR_R_POWER
	brne	DNPower
	SetDM	DMSpeakS
	LoadAndSpeakEString		SPSpeak
	rjmp	AcceptIR
DNPower:

	rjmp	InvalidIR
DMNDemo:

;*****************************************************************************

	cpi		TempUa,DMForward
	brne	DMNForward
; We are in forward mode -- see if a distance has been entered
	lds		TempUa,EntryStatus
	cpi		TempUa,ESDone
	brne	DMForwardNotDone
	ldsw	y,EnteredValue
	stsw	Distance,y
	rjmp	DMGoForward
DMForwardNotDone:

	cpi		zl,IR_R_QUERY
	brne	DMForwardNotQuery
	rjmp	DoTellDistance
DMForwardNotQuery:

	cpi		zl,IR_R_ENTER
	breq	DMForwardEnter
	cpi		zl,IR_R_FORWARD
	brne	DMNForwardForward
; They pressed Enter or Forward without a distance value
DMForwardEnter:
	lds		TempUa,Distance
	lds		TempUb,Distance+1
	or		TempUa,TempUb
	brnz	DMGoForward
HaveZeroDistance:
	LoadAndSpeakEString		SPZeroDistance
	rjmp	FinishedIR
DMGoForward:	
	rcall	SendGoMessages
	ldi		ParamReg,SP_go
	rjmp	SpeakFinishedIR
DMNForwardForward:

	rjmp	InvalidIR
DMNForward:

;*****************************************************************************

	cpi		TempUa,DMReverse
	brne	DMNReverse
; We are in Reverse mode -- see if a distance has been entered
	lds		TempUa,EntryStatus
	cpi		TempUa,ESDone
	brne	DMReverseNotDone
	ldsw	y,EnteredValue
	stsw	Distance,y
	rjmp	DMGoReverse
DMReverseNotDone:

	cpi		zl,IR_R_QUERY
	brne	DMReverseNotQuery
	rjmp	DoTellDistance
DMReverseNotQuery:
	cpi		zl,IR_R_ENTER
	breq	DMReverseEnter
	cpi		zl,IR_R_REVERSE
	brne	DMNReverseReverse
; They pressed Enter or Reverse without a distance value
DMReverseEnter:
	lds		TempUa,Distance
	lds		TempUb,Distance+1
	or		TempUa,TempUb
	brze	HaveZeroDistance
DMGoReverse:
	rcall	SendReverseMessages
	SayWord	SP_reverse
	ldi		ParamReg,SP_go
	rjmp	SpeakFinishedIR
DMNReverseReverse:

	rjmp	InvalidIR
DMNReverse:

;*****************************************************************************

	cpi		TempUa,DMAngle
	brne	DMNAngle
; We are in angle mode -- see if a value has been entered
	lds		TempUa,EntryStatus
	cpi		TempUa,ESDone
	brne	DMNAngleEntered
	ldsw	y,EnteredValue
	stsw	Angle,y
	rjmp	FinishedIR
DMNAngleEntered:

	cpi		zl,IR_R_QUERY
	brne	ANotQuery
	rjmp	DoTellAngle
ANotQuery:

	rjmp	InvalidIR
DMNAngle:

;*****************************************************************************

	cpi		TempUa,DMSpeed
	brne	DMNSpeed
; We are in speed mode -- see if a value has been entered
	lds		TempUa,EntryStatus
	cpi		TempUa,ESDone
	brne	DMNSpeedEntered
	lds		yl,EnteredValueLSB
	sts		Speed,yl
	rjmp	AcceptIR
DMNSpeedEntered:

	cpi		zl,IR_R_QUERY
	brne	SPNotQuery
	rjmp	DoTellSpeed
SPNotQuery:

	rjmp	InvalidIR
DMNSpeed:

;*****************************************************************************

	cpi		TempUa,DMSpeakW
	brne	DMNSpW
; We are in speak word mode -- CLEAR gets us out (and so does HALT above)
	cpi		zl,IR_R_CLEAR
	brne	SpWMNClear
	rjmp	FinishedIR
SpWMNClear:
	SayWord	WordPause
	ldi		ParamReg,SP_zero
	add		ParamReg,zl			;temp
	rjmp	SpeakAcceptIR
DMNSpW:

;*****************************************************************************

	cpi		TempUa,DMSpeakS
	brne	DMNSpS
; We are in speak sound mode -- CLEAR gets us out (and so does HALT above)
	cpi		zl,IR_R_CLEAR
	brne	SpSMNClear
	rjmp	FinishedIR
SpSMNClear:
	SayWord	WordPause
	ldi		ParamReg,PH_IY
	add		ParamReg,zl			;temp
	rjmp	SpeakAcceptIR
DMNSpS:

;*****************************************************************************

	cpi		TempUa,DMDiagnostics
	brne	DMNDiagnostics

; We are in diagnostic mode -- Off, On, Query, Demo (Comms diag), Power (Reset)
	cpi		zl,IR_R_OFF
	brne	DNOff
	LoadAndSendLCDTxFString	OffString
	LoadAndSpeakEString		SPOff
	lds		TempUa,PowerByte	;Get power byte into TempUa
	andi	TempUa,NotDiagnosticBit	;Get all the other bits into TempUa
	rjmp	UpdateBasePower
DNOff:

	cpi		zl,IR_R_ON
	brne	DNOn
	LoadAndSendLCDTxFString	OnString
	LoadAndSpeakEString		SPOn
	lds		TempUa,PowerByte	;Get power byte into TempUa
	ori		TempUa,DiagnosticBit
	rjmp	UpdateBasePower
DNOn:

	cpi		zl,IR_R_QUERY
	brne	DNQuery
	rjmp	DoTellDiagnostics
DNQuery:

;	cpi		zl,IR_R_DEMO
;	brne	DNDemo
;	rjmp	MainDiag
;DNDemo:

	cpi		zl,IR_R_POWER
	brne	DiagNPower
	rjmp	Reset
DiagNPower:

	rjmp	InvalidIR
DMNDiagnostics:

;*****************************************************************************

	cpi		TempUa,DMFrontBackMode
	brne	DMNFBM

; We are in front back switch mode -- accept Query, Manual or Automatic
	cpi		zl,IR_R_QUERY
	brne	FBMNotQuery
	rjmp	DoTellFrontBackMode
FBMNotQuery:

	cpi		zl,IR_R_MANUAL
	brne	FBMNManual
	LoadAndSendLCDTxFString	ManualString
	SayWord	SP_manual
	lds		TempUa,TravelByte	;Get travel byte into TempUa
	andi	TempUa,NotFrontSwitchModeBit	;Clear the bit
	rjmp	UpdateBaseTravel
FBMNManual:

	cpi		zl,IR_R_AUTO
	brne	FBMNAuto
	LoadAndSendLCDTxFString	AutoString
	SayWord	SP_automatic
	lds		TempUa,TravelByte	;Get travel byte into TempUa
	ori		TempUa,FrontSwitchModeBit	;Set the bit
	rjmp	UpdateBaseTravel
FBMNAuto:

	rjmp	InvalidIR
DMNFBM:
	
;*****************************************************************************

	cpi		TempUa,DMTravelMode
	brne	DMNTM

; We are in travel mode -- accept 0, 1, 2, Query
	cpi		zl,IR_R_QUERY
	brne	TMNotQuery
	rjmp	DoTellTravelMode
TMNotQuery:

	cpi		zl,IR_0
	brne	TMNot0
	LoadAndSendLCDTxFString	TravelTSString
	LoadAndSpeakEString	SPTMTS
	lds		TempUa,TravelByte	;Get travel byte into TempUa
	andi	TempUa,NotTravelModeBits	;Clear the bits
	rjmp	UpdateBaseTravel
TMNot0:

	cpi		zl,IR_1
	brne	TMNot1
	LoadAndSendLCDTxFString	TravelCString
	;LoadAndSpeakEString	SPTMC
	SayWord	SP_circle
	lds		TempUa,TravelByte	;Get travel byte into TempUa
	andi	TempUa,NotTravelModeBits	;Clear the bits
	ori		TempUa,TravelModeC
	rjmp	UpdateBaseTravel
TMNot1:

	cpi		zl,IR_2
	brne	TMNot2
	LoadAndSendLCDTxFString	TravelXString
	;LoadAndSpeakEString	SPTMX
	SayWord	SP_extreme
	lds		TempUa,TravelByte	;Get travel byte into TempUa
	andi	TempUa,NotTravelModeBits	;Clear the bits
	ori		TempUa,TravelModeX
	rjmp	UpdateBaseTravel
TMNot2:

	rjmp	InvalidIR
DMNTM:

;*****************************************************************************

	rjmp	InvalidIR

InvalidIR:
	ldi		ParamReg,SP_oops
	rjmp	SpeakFinishedIR	;and return

SpeakAcceptIR:		;Expects word in ParamReg
	rcall	SpeakWord
	rjmp	AcceptIR

SpeakFinishedIR:	;Expects word in ParamReg
	rcall	SpeakWord
FinishedIR:
	rcall	LCDReset	;Go back to idle mode (also resets EntryStatus)
AcceptIR:
	lds		LCDUseTime,SecondsLSB
	ret


;*****************************************************************************
;
;	CheckAllComms
;
;	Checks the computer and then the slave communications
;
;	Accepts the following case-insensitive commands from the computer:
;		?			Help
;		@			Reset
;		#			Enter diagnostic mode
;		V			Display version numbers (also requests version from base)
;		Q			Query battery and charging voltages
;		P			Power off system
;
;		C			Communications display (polling) toggle
;
;		T=xx		Toggle switch xx (1-10)
;		H			Send halt message
;
;		L=+/-ddd	Set left speed variable
;		R=+/-ddd	Set right speed variable
;		M			Send manual go message (left/right)
;
;		S=ddd		Set speed variable
;		A=+/-ddd	Set angle variable
;		D=ddddd		Set distance variable
;		G			Send go message (uses speed, angle, and distance)
;		O=ddd		Override speed
;
;		I=ddd		Set headlight intensity variable and sends intensity message
;
;		FBmmm		Forward mmm message to base without modification
;
;		W			Display on LCD window
;
;		X			eXamine registers
;		Zaaaa(=vv)	Display/Set specified memory (or register or IO port) address
;						(Can have multiple values separated by commas)
;
;	Numbers can be entered in decimal or hex (PRECEDED by H)
;
;	Reports all base messages back to the computer prefixed by FB:
;
;	Called only from MainLoop so doesn't preserve any registers
;
;	Spare letters are:	K, U, Y
;
;*****************************************************************************
;
CheckAllComms:
; See if anything has been received from the computer
	tst		HaveComRxLine
	brnz	HaveComRxLineNow
	rjmp	NoComRxLine		;Branch if nothing yet

; We have a line in the Com Rx buffer -- process it
HaveComRxLineNow:
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
	LoadAndSendTxFString	HeaderString
	LoadAndSendFString		HelpString
	rjmp	ClearComRxLine
NotComQu:

	cpi		TempUb,'@'
	brne	NotComAt
	rjmp	Reset
NotComAt:

	cpi		TempUb,'#'
	brne	NotComHash
	rjmp	MainDiag
NotComHash:

	cpi		TempUb,'C'
	brne	NotComC
	com		DisplayPolling	;Reverse the flag
	rjmp	ClearComRxLine
NotComC:

	cpi		TempUb,'G'
	brne	NotComG
	rcall	SendGoMessages
	rjmp	ClearComRxLine
NotComG:

	cpi		TempUb,'H'
	brne	NotComH
	rcall	SendHaltMessages
	rjmp	ClearComRxLine
NotComH:

	cpi		TempUb,'V'
	brne	NotComV
	; Display this version number and request the version number from the base
	LoadAndSendTxFString	HeaderString
	ldi		ParamReg,'B'
	rcall	SendVersionRequestMessages
	ldi		ParamReg,'I'
	rcall	SendVersionRequestMessages
	ldi		ParamReg,'S'
	rcall	SendVersionRequestMessages
	rjmp	ClearComRxLine
NotComV:

	cpi		TempUb,'P'
	breq	ComP
	cpi		TempUb,'`'
	brne	NotComP
ComP:
	rcall	DoPowerDownSeq
	rjmp	ClearComRxLine
NotComP:

	cpi		TempUb,'M'
	brne	NotComM
	rcall	SendManualMotorMessages
	rjmp	ClearComRxLine
NotComM:

	cpi		TempUb,'Q'
	brne	NotComQ
;	LoadAndSendTxFString	SwString
;	clt							;Zero suppress number
;	lds		zl,ThisAISwReading
;	rcall	ConvertUByte		;Convert number in zl and send it
;	rcall	SendCString
	LoadAndSendTxFString	BattString
	clt							;Zero suppress number
	lds		zl,BattVoltageReading
	rcall	ConvertUByte		;Convert number in zl and send it
	rcall	SendCString
	LoadAndSendFString	ChargeString
	clt							;Zero suppress number
	lds		zl,ChargeVoltageReading
	rcall	ConvertUByte		;Convert number in zl and send it
	rcall	SendCString
	ldi		ParamReg,CR
	rcall	SendTxChar
	rjmp	ClearComRxLine
NotComQ:

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
	cpi		TempUb,'F'
	brne	NotComF
	; Check that the next char is a slave ID
	ld		TempUb,z
	cpi		TempUb,'B'
	breq	FValid
	cpi		TempUb,'I'
	breq	FValid
	cpi		TempUb,'S'
	breq	FValid
	rjmp	CInvalidMessage
FValid:
	; We must forward the rest of the line to the slave
	ldi		TempUc,OutToSlaves
	mov		StringOutControl,TempUc
	pushw	z
	rcall	SendSString		;z already points to the CR/Null terminated string
	ldi		TempUc,OutToTx
	mov		StringOutControl,TempUc
	ldi		ParamReg,'S'
	rcall	SendTxChar
	ldi		ParamReg,'t'
	rcall	SendTxChar
	ldi		ParamReg,'S'
	rcall	SendTxChar
	ldi		ParamReg,'l'
	rcall	SendTxChar
	ldi		ParamReg,':'
	rcall	SendTxChar
	ldi		ParamReg,' '
	rcall	SendTxChar
	popw	z
	rcall	SendSString
	rjmp	ClearComRxLine
NotComF:

	cpi		TempUb,'D'
	brne	NotComD
ComD:
	ld		TempUb,z+		;Get the next character after the D
	cpi		TempUb,' '
	breq	ComD			;Ignore spaces
	cpi		TempUb,'='
	breq	ComD1
	rjmp	CInvalidMessage
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
	stsw	Distance,y		;Save the distance
	; If we are displaying distance on the LCD then update it
	lds		TempUa,DisplayMode
;	cpi		TempUa,DMDistance
	brne	CDNoUpdate
	mvw		z,y
;	rcall	SwDisplayValue
CDNoUpdate:
	rjmp	ClearComRxLine
NotComD:

	cpi		TempUb,'S'
	brne	NotComS
ComS:
	; Check that there is an equals sign
	ld		ParamReg,z+		;Get the next character after the S
	cpi		ParamReg,' '
	breq	ComS			;Ignore spaces
	cpi		ParamReg,'='
	breq	ComS1
	rjmp	CInvalidMessage
	; Ignore any spaces after the equals
ComS1:
	ld		ParamReg,z+		;Get the next character (space or digit)
	cpi		ParamReg,' '
	breq	ComS1			;Ignore spaces
	;Get the digits
	rcall	ProcessFirstDigit
	brcc	ComSDigitLoop
	rjmp	CInvalidMessage	;Error if no first digit
ComSDigitLoop:
	ld		ParamReg,z+		;Get the next character
	cpi		ParamReg,CR
	breq	ComSDone		;Finished when hit CR
	rcall	ProcessNextDigit
	brcc	ComSDigitLoop
	rjmp	CInvalidMessage	;Branch if error
ComSDone:
	sts		Speed,yl	;Save the speed
	; If we are displaying angle on the LCD then update it
	lds		TempUa,DisplayMode
	cpi		TempUa,DMSpeed
	brne	CSNoUpdate
	mov		zl,yl
	clr		zh
;	rcall	SwDisplayValue
CSNoUpdate:
	rjmp	ClearComRxLine
NotComS:

	cpi		TempUb,'O'
	brne	NotComO
ComO:
	; Check that there is an equals sign
	ld		ParamReg,z+		;Get the next character after the O
	cpi		ParamReg,' '
	breq	ComO			;Ignore spaces
	cpi		ParamReg,'='
	breq	ComO1
	rjmp	CInvalidMessage
	; Ignore any spaces after the equals
ComO1:
	ld		ParamReg,z+		;Get the next character (space or digit)
	cpi		ParamReg,' '
	breq	ComO1			;Ignore spaces
	;Get the digits
	rcall	ProcessFirstDigit
	brcc	ComODigitLoop
	rjmp	CInvalidMessage	;Error if no first digit
ComODigitLoop:
	ld		ParamReg,z+		;Get the next character
	cpi		ParamReg,CR
	breq	ComODone		;Finished when hit CR
	rcall	ProcessNextDigit
	brcc	ComODigitLoop
	rjmp	CInvalidMessage	;Branch if error
ComODone:
	sts		Speed,yl	;Save the speed
	; If we are displaying angle on the LCD then update it
	lds		TempUa,DisplayMode
	cpi		TempUa,DMSpeed
	brne	CONoUpdate
	mov		zl,yl
	clr		zh
;	rcall	SwDisplayValue
CONoUpdate:
	rcall	SendSpeedMessages
	rjmp	ClearComRxLine
NotComO:

	cpi		TempUb,'A'
	brne	NotComA
ComA:
	ld		TempUb,z+		;Get the next character after the A
	cpi		TempUb,' '
	breq	ComA			;Ignore spaces
	cpi		TempUb,'='
	breq	PC+2
	rjmp	CInvalidMessage
	clr		TempUc			;Default to positive flag
ComA1:
	ld		ParamReg,z+		;Get the optional sign or next digit
	cpi		ParamReg,' '
	breq	ComA1			;Ignore spaces
	cpi		ParamReg,'-'
	brne	ComANotMinus
	com		TempUc			;Was 0 now FF
	rjmp	ComAHaveSign
ComANotMinus:
	cpi		ParamReg,'+'
	brne	ComADefaultSign
ComAHaveSign:
	ld		ParamReg,z+		;Preload next character (should be a digit)
ComADefaultSign:
	sts		AngleMSB,TempUc	;Yes, save it in the sign byte
	;Get the digits
	rcall	ProcessFirstDigit
	brcc	ComADigitLoop
	rjmp	CInvalidMessage	;Error if no first digit
ComADigitLoop:
	ld		ParamReg,z+		;Get the next character
	cpi		ParamReg,CR
	breq	ComADone		;Finished when hit CR
	rcall	ProcessNextDigit
	brcc	ComADigitLoop
	rjmp	CInvalidMessage	;Branch if error
ComADone:
	; Check that angle is not higher than 180
	cpi		yl,181
	brlo	PC+2
	rjmp	CInvalidMessage
	sts		AngleLSB,yl		;Save the angle
	lds		zh,AngleMSB		;Get the sign back
	tst		zh
	brze	ComAOk
	ldiw	z,360		;Convert the negative angle to 181-359 degrees
	sub		zl,yl		; by subtracting it from 360
	sbci	zh,0
	stsw	Angle,z
ComAOk:
	; If we are displaying angle on the LCD then update it
	lds		TempUa,DisplayMode
	cpi		TempUa,DMAngle
	brne	CANoUpdate
	ldsw	z,Angle
;	rcall	SwDisplayValue
CANoUpdate:
	rjmp	ClearComRxLine
NotComA:

	cpi		TempUb,'L'
	brne	NotComL
ComL:
	ld		TempUb,z+		;Get the next character after the L
	cpi		TempUb,' '
	breq	ComL			;Ignore spaces
	cpi		TempUb,'='
	breq	PC+2
	rjmp	CInvalidMessage
	clr		TempUc			;Default to positive flag
ComL1:
	ld		ParamReg,z+		;Get the optional sign or next digit
	cpi		ParamReg,' '
	breq	ComL1			;Ignore spaces
	cpi		ParamReg,'-'
	brne	ComLNotMinus
	com		TempUc			;Was 0 now FF
	rjmp	ComLHaveSign
ComLNotMinus:
	cpi		ParamReg,'+'
	brne	ComLDefaultSign
ComLHaveSign:
	ld		ParamReg,z+		;Preload next character (should be a digit)
ComLDefaultSign:
	sts		LeftMotorSpeedMSB,TempUc	;Yes, save it in the sign byte
	;Get the digits
	rcall	ProcessFirstDigit
	brcc	ComLDigitLoop
	rjmp	CInvalidMessage	;Error if no first digit
ComLDigitLoop:
	ld		ParamReg,z+		;Get the next character
	cpi		ParamReg,CR
	breq	ComLDone		;Finished when hit CR
	rcall	ProcessNextDigit
	brcc	ComLDigitLoop
	rjmp	CInvalidMessage	;Branch if error
ComLDone:
	sts		LeftMotorSpeedLSB,yl	;Save the speed
	; If we are displaying left speed on the LCD then update it
	lds		TempUa,DisplayMode
;	cpi		TempUa,DMLeftMotorSpeed
	brne	CLNoUpdate
	mov		zl,yl
	lds		zh,LeftMotorSpeedMSB	; The direction was saved up above
;	rcall	SwDisplayValue
CLNoUpdate:
	rjmp	ClearComRxLine
NotComL:

	cpi		TempUb,'R'
	brne	NotComR
ComR:
	ld		ParamReg,z+		;Get the next character after the R
	cpi		ParamReg,' '
	breq	ComR			;Ignore spaces
	cpi		ParamReg,'='
	breq	PC+2
	rjmp	CInvalidMessage
	clr		TempUc			;Default to positive flag
ComR1:
	ld		ParamReg,z+		;Get the optional sign or next digit
	cpi		ParamReg,' '
	breq	ComR1			;Ignore spaces
	cpi		ParamReg,'-'
	brne	ComRNotMinus
	com		TempUc			;Was 0 now FF
	rjmp	ComRHaveSign
ComRNotMinus:
	cpi		ParamReg,'+'
	brne	ComRDefaultSign
ComRHaveSign:
	ld		ParamReg,z+		;Preload next character (should be a digit)
ComRDefaultSign:
	sts		RightMotorSpeedMSB,TempUc	;Yes, save it in the sign byte

	;Get the digits
	rcall	ProcessFirstDigit
	brcc	ComRDigitLoop
	rjmp	CInvalidMessage	;Error if no first digit
ComRDigitLoop:
	ld		ParamReg,z+		;Get the next character
	cpi		ParamReg,CR
	breq	ComRDone		;Finished when hit CR
	rcall	ProcessNextDigit
	brcc	ComRDigitLoop
	rjmp	CInvalidMessage	;Branch if error
ComRDone:
	sts		RightMotorSpeedLSB,yl	;Save the speed
	; If we are displaying right on the LCD then update it
	lds		TempUa,DisplayMode
;	cpi		TempUa,DMRightMotorSpeed
	brne	CRNoUpdate
	mov		zl,yl
	lds		zh,RightMotorSpeedMSB	; The direction was saved up above
;	rcall	SwDisplayValue
CRNoUpdate:
	rjmp	ClearComRxLine
NotComR:

	cpi		TempUb,'I'
	brne	NotComI
ComI:
	ld		ParamReg,z+		;Get the next character after the I
	cpi		ParamReg,' '
	breq	ComI			;Ignore spaces
	cpi		ParamReg,'='
	breq	ComI1
	rjmp	CInvalidMessage
ComI1:
	ld		ParamReg,z+		;Get the next character (space or digit)
	cpi		ParamReg,' '
	breq	ComI1			;Ignore spaces
	;Get the digits
	rcall	ProcessFirstDigit
	brcc	ComIDigitLoop
	rjmp	CInvalidMessage	;Error if no first digit
ComIDigitLoop:
	ld		ParamReg,z+		;Get the next character
	cpi		ParamReg,CR
	breq	ComIDone		;Finished when hit CR
	rcall	ProcessNextDigit
	brcc	ComIDigitLoop
	rjmp	CInvalidMessage	;Branch if error
ComIDone:
	sts		HeadlightIntensity,yl	;Save the value
	 ; If we are intensity mode on the LCD then update it
	lds		TempUa,DisplayMode
	cpi		TempUa,DMIntensity
	brne	CINoUpdate
	mov		zl,yl
	clr		zh
;	rcall	SwDisplayValue
CINoUpdate:
	rcall	SendIntensityMessages
	rjmp	ClearComRxLine
NotComI:

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
	ldi		TempUa,OutToTX
	mov		StringOutControl,TempUa
	popw	y
	ld		zl,y			;Get the memory value
	rcall	ConvertHexByte	;Convert it to a string and send it
	rcall	SendCString
	ldi		ParamReg,CR
	rcall	SendTxChar		;Finish the line
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

	cpi		TempUb,'W'
	brne	NotComW
	ldi		ParamReg,LCDCommand
	rcall	SendLCDChar
	ldi		ParamReg,LCDCls
	rcall	SendLCDChar
ComWLoop:
	ld		ParamReg,z+		;Get the next character
	cpi		ParamReg,HT		;Tab means go to next line
	breq	ComWLine2
	cpi		ParamReg,CR		;CR means we're finished
	brne	ComWChar
	rjmp	ClearComRxLine
ComWChar:
	rcall	SendLCDChar
	rjmp	ComWLoop
ComWLine2:
	ldi		ParamReg,LCDCommand
	rcall	SendLCDChar
	ldi		ParamReg,LCDHome2
	rcall	SendLCDChar
	rjmp	ComWLoop
NotComW:

	cpi		TempUb,'T'
	brne	NotComT
ComT:
	; Check that there is an equals sign
	ld		ParamReg,z+		;Get the next character after the T
	cpi		ParamReg,' '
	breq	ComT			;Ignore spaces
	;Get the digits
	rcall	ProcessFirstDigit
	brcc	ComTDigitLoop
	rjmp	CInvalidMessage	;Error if no first digit
ComTDigitLoop:
	ld		ParamReg,z+		;Get the next character
	cpi		ParamReg,CR
	breq	ComTDone		;Finished when hit CR
	rcall	ProcessNextDigit
	brcc	ComTDigitLoop
	rjmp	CInvalidMessage	;Branch if error
ComTDone:
	mov		TempUc,yl	;Get the switch number
	tst		TempUc
	brze	CInvalidMessage	;No switch 0
	cpi		TempUc,11
	brsh	CInvalidMessage	;No switch 11
;	rcall	SwitchOn
	rjmp	ClearComRxLine
NotComT:

;*****************************************************************************

CInvalidMessage:
	; We got an invalid message
	rcall	ErrorBeep
	; Send them a message telling them what we think
	LoadAndSendTxFString	BadMessage

; Clear the line by setting the count to zero
ClearComRxLine:
	clr		HaveComRxLine				;Clear the flag
	sts		ComRxBufCnt,HaveComRxLine	; and zeroize the count
NoComRxLine:

;*****************************************************************************

; See if anything has been received from the base
	tst		HaveSlaveRxLine
	brnz	SlaveRxLine		;Branch if nothing yet
	rjmp	NoSlaveRxLine

InvalidSlave:
	lds		ISRTempU, SlaveCommsErrorCount
	inc		ISRTempU
	sts		SlaveCommsErrorCount, ISRTempU
	rjmp	ClearSlaveRxLine

SlaveRxLine:

; Check what slave it is from
	lds		TempUa, SlaveRxBuf
	ldfp	z, SlaveIDList
SMsgLp:
	lpm	
	cp		TempUa, r0
	breq	GotIt
	; This is not the right slave
	tst		r0
	breq	InvalidSlave	; This message does not belong to any slave
	adiw	zl, 4	; Go to the next entry
	rjmp	SMsgLp
GotIt:
	; This is a message from a slave
	sbr		zl, 1	; Get the index
	lpm	
	ldiw	y, SlaveDeadFlags
	add		yl, r0
	push	r0 ; Push the index

	ld		TempUa, y	;Were we already marked alive?
	cpi		TempUa, SDFAlive
	breq	NotDead		;Yes, branch
	; We were considered dead so initialize
	ldi		TempUa, SDFAlive ; Mark it as being alive
	st		y, TempUa
	; And load the address to and call the init function
	adiw	zl, 1
	lpm
	mov		TempUa, r0
	sbr		zl, 1 ; Advance to the next byte
	lpm
	mov		zh, r0
	mov		zl, TempUa
	icall	
	DoBeep	Beep400Hz,Beep0s2
	DoBeep	Beep600Hz,Beep0s3
NotDead:
	pop		TempUa	 ; Pop the index
	ldiw	Z, GotSlaveVersionTimes	; Load the useful data using the index
	add		ZL, TempUa
	; Clear the timeout
	lds		TempUa, SecondsLSB
	st		z, TempUa

; We have a line in the Slave Rx buffer -- process it
	ldi		ParamReg,'F'
	rcall	SendTxChar
	ldi		ParamReg,'r'
	rcall	SendTxChar
	ldi		ParamReg,'S'
	rcall	SendTxChar
	ldi		ParamReg,'l'
	rcall	SendTxChar
	ldi		ParamReg,':'
	rcall	SendTxChar
	ldi		ParamReg,' '
	rcall	SendTxChar
	ldi		TempUc,OutToTx
	mov		StringOutControl,TempUc
	ldiw	z,SlaveRxBuf		;Point z to the buffer	
	rcall	SendSString		;z points to the CR/Null terminated string
	
; We have receive a message from a slave and
; it has been echoed to the computer. Now process
; it and decide what to do with it.
	
	; SlaveRxBuf contains the message. The first byte is
	; the slave ID and the next is the message.
	ldiw	z, SlaveRxBuf
	ld		TempUa, z+
	
	cpi		TempUa, 'I' ; Check if is from the infrared
	brne	NotIMessage

	; This is a message from the infrared.
	; Check if it is a front or back message
	ld		TempUa, z+
	cpi		TempUa, 'F'			;Front message?
	breq	ReceivedIR
	cpi		TempUa, 'R'			;Rear message?
	breq	ReceivedIR
	rjmp	ClearSlaveRxLine
ReceivedIR:
	ldi		ParamReg,'H'
	rcall	ProcessFirstDigit	;Tell it we've got HEX digits coming
	ld		ParamReg,z+
	rcall	ProcessNextDigit
	brcc	RIR2
	rjmp	SlaveRxError		;Branch if error
RIR2:
	ld		ParamReg,z
	rcall	ProcessNextDigit	;Puts result in y
	brcs	SlaveRxError		;Branch if error
	sts		IRByte,yl
	ser		TempUa
	sts		HaveIR,TempUa		;Set Boolean flag
	rjmp	ClearSlaveRxLine
NotIMessage:

	cpi		TempUa, 'B' ; Check if is from the base
	brne	NotBMessage
; This is a message from the base
; Check if it is a switch message
	ld		TempUa,z+
	cpi		TempUa, 'S'			;Switch message?
	brne	NotBSMessage
	ldi		ParamReg,'H'		;Tell it it's hex
	rcall	ProcessFirstDigit
	brcs	SlaveRxError
	ld		ParamReg,z+			;Get the first byte of hex bumper switch data (2-bits)
	rcall	ProcessNextDigit
	brcs	SlaveRxError
	ld		ParamReg,z+			;Get the second byte of hex bumper switch data (4-bits)
	rcall	ProcessNextDigit	;Now yl contains bumper switch data (6-bits)
	brcs	SlaveRxError
	mov		TempLb,yl			;Save copy of bumper switch data in TempLb
	cpi		yl,0x3F
	breq	NoBumperSwitchesOn
	LoadAndSpeakEString	SPBumperSwitch
; Now work out exactly which switch(es) are/were on
	ldi		zl,6			;Number of switches
	mov		TempLc,zl		;Save in TempLc (TempL registers not affected by routines inside loop)
BSLoop:
	ror		TempLb			;Get next LS bumper bit
	brcs	BSOff			;It's off if the bit is set
	ldi		ParamReg,SP_zero
	add		ParamReg,TempLc
	rcall	SpeakWord		;Say the loop counter variable 6..1
	SayWord	WordPause
BSOff:
	dec		TempLc
	brnz	BSLoop			;Loop until all switch bits tested
NoBumperSwitchesOn:
	clrw	y					;Throw away bumper switch data
	ld		ParamReg,z+			;Get the tilt switch hex digits (first one should always be zero)
	rcall	ProcessNextDigit
	brcs	SlaveRxError
	ld		ParamReg,z+			;Get the tilt switch hex digits
	rcall	ProcessNextDigit
	brcs	SlaveRxError
	mov		TempLa,yl			;Save copy of bumper switch data in TempLa
	cpi		yl,0x0F
	breq	NoTiltSwitchesOn
	LoadAndSpeakEString	SPTiltSwitch
; Now work out exactly which switch(es) are/were on
	ldi		zl,4			;Number of switches
	mov		TempLc,zl		;Save in TempLc (TempL registers not affected by routines inside loop)
TSLoop:
	ror		TempLa			;Get next LS tilt bit
	brcs	TSOff			;It's off if the bit is set
	ldi		ParamReg,SP_zero
	add		ParamReg,TempLc
	rcall	SpeakWord		;Say the loop counter variable 4..1
	SayWord	WordPause
TSOff:
	dec		TempLc
	brnz	TSLoop			;Loop until all switch bits tested
NoTiltSwitchesOn:
NotBSMessage:
NotBMessage:

; A message from some other slave -- just ignore it
	rjmp	ClearSlaveRxLine

SlaveRxError:
	LoadAndSendTxFString	BadSlaveMessage
	DoBeep	Beep800Hz,Beep0s1
	DoBeep	Beep1600Hz,Beep0s2

; Clear the line by setting the count to zero
ClearSlaveRxLine:
	clr		HaveSlaveRxLine				;Clear the flag
	sts		SlaveRxBufCnt,HaveSlaveRxLine	; and zeroize the count
NoSlaveRxLine:
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
;	Changes no registers
;
;	Leaves interrupts disabled
;
;*****************************************************************************
;
ProgramError:
	cli			;Disable interrupts so nothing else can happen

	push	R0
	push	TempUb
	push	TempUc
	push	TempLa

	ldi		TempUb,12	;Number of times to flash all LEDs

	clr		r0			;Start by turning LEDs on
PEFlashLoop:
;	out		LEDPort,r0	;Turn on/off all the LEDs

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
;	out		LEDPort,ParamReg	;Display error code
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

	pop		TempLa
	pop		TempUc
	pop		TempUb
	pop		R0
		
	ret					;Return leaving interrupts disabled


;*****************************************************************************
;
;	ErrorBeep		Tweedles the beeper
;
;	Uses:			ParamReg, TempUa, TempUb, TempUc, y
;
;*****************************************************************************
;
ErrorBeep:
	clr		TempUa				;Error beeps cancel and override all others
	sts		BeepBufCnt,TempUa

	DoBeep	Beep600Hz,Beep0s1
	DoBeep	Beep800Hz,Beep0s1
	DoBeep	Beep400Hz,Beep0s1
	DoBeep	Beep800Hz,Beep0s1
EBReturn:
	ret


;*****************************************************************************
;
;	Beep			Adds a beep to the beep queue
;
;	Expects:	ParamReg = Wavelength value (1-255)
;					Frequency in Hz = 2400 / ParamReg
;					Note: 0 is invalid
;				TempUa = beep time in 8 msecs (0-255 = 0 to 2.04 seconds)
;					Note: This can be up to 8 msec off.
;
;	Sets up things so that the ISR beeps the beeper and turns it off when finished
;
;	Changes: TempUb, TempUc, y
;
;*****************************************************************************
;
Beep:
	; Stay silent if we're in stealth mode
	lds		TempUb,PowerByte
	andi	TempUb,StealthBit
	brnz	EBReturn		;Just return if we're in stealth mode

	; All we have to do here is to save the values in the queue (The ISRs do all the work)
	cli		; Disable interrupts temporarily
			;	so the SU interrupt can't change buffer control variables
	
	;See if there's room in the buffer
	lds		TempUc,BeepBufCnt	;Note: This is the number of ENTRIES (not bytes)
	cpi		TempUc,BeepBufSiz
	brsh	BeepExit			;Just ignore this and exit if the buffer's full
	
	; Add the start offset and the length together
	lds		TempUb,BeepBufO1	;Get the offset to the first entry
	add		TempUb,TempUc	;Add the BeepBufCnt (Note: Total must not exceed 256)
	add		TempUb,TempUc	; * 2
	
	; Now TempUb is sort of the the offset of the first empty space
	; We have to adjust it though, if it's past the end of the (circular) buffer
	cpi		TempUb,BeepBufSiz*BeepEntryLength
	brlo	BeepBNFOk			;Ok if the calculated offset is already inside the buffer
	subi	TempUb,BeepBufSiz*BeepEntryLength	;Otherwise, adjust it down

BeepBNFOk:
	
	; Now TempUb is the adjusted offset of the first empty space
	; Add it to the buffer address
	ldiw	y,BeepBuf
	add		yl,TempUb		;Note: Only works if buffer does not cross a 256-byte boundary
	
	; Now y is the address of the first empty space in the buffer
	st		y+,ParamReg		;Save the frequency count value
	st		y,TempUa		;Save the time count value
	inc		TempUc			;Increment and save the number of ENTRIES
	sts		BeepBufCnt,TempUc
BeepExit:	
	reti					;Reenable interrupts and then return


;*****************************************************************************
;
;	TellLights, TellLightState
;
; Tell the state of the lights
;
;*****************************************************************************
;
TellLights:
	LoadAndSpeakEString		SPTellLights
TellLightState:
	lds		TempUa,PowerByte
	andi	TempUa,LightBits

	clr		TempLa				;Use this to indicate off or "not-off"
	ldi		ParamReg,SP_off
	brze	TLDone
	dec		TempLa				;So "not-off"
	ldi		ParamReg,SP_normal
	cpi		TempUa,LightsNormal
	breq	TLDone
	ldi		ParamReg,SP_full
	cpi		TempUa,LightsFull
	breq	TLDone
	ldi		ParamReg,SP_test
TLDone:
	rcall	SpeakWord

; If lights are not off, just check that power is not low
	tst		TempLa
	brze	TLPDone
	lds		TempUa,PowerByte
	andi	TempUa,PowerBits
	cpi		TempUa,PowerNormal
	breq	TLPDone

; Power is low so explain why lights might not be on
	LoadAndSpeakEString		SPTellLightsPower
TLPDone:

; Tell if in manual/automatic mode
	lds		TempUa,LightsManual
	ldi		ParamReg,SP_automatic
	tst		TempUa
	brze	TL2Done
	ldi		ParamReg,SP_manual
TL2Done:
	rcall	SpeakWord
	LoadAndSpeakEString		SPWPMode
	ret


;*****************************************************************************
;
;	TellPower
;
; Tell the state of the power
;
;*****************************************************************************
;
TellPower:
; Tell if in off/low/normal power
	LoadAndSpeakEString		SPTellPower1
	lds		TempUa,PowerByte
	andi	TempUa,PowerBits

	ldi		ParamReg,SP_off
	brze	TP1Done
	ldi		ParamReg,SP_low
	cpi		TempUa,PowerLow
	breq	TP1Done
	ldi		ParamReg,SP_normal
	cpi		TempUa,PowerNormal
	breq	TP1Done
	LoadAndSpeakEString		SPInvalid
	rjmp	TP2
TP1Done:
	rcall	SpeakWord
	SayWord	SentencePause

; Tell if in manual/automatic mode
TP2:
	lds		TempUa,PowerManual
	ldi		ParamReg,SP_automatic
	tst		TempUa
	brze	TP2Done
	ldi		ParamReg,SP_manual
TP2Done:
	rcall	SpeakWord
	LoadAndSpeakEString		SPWPMode

; Tell battery level (if in diagnostic mode)
	lds		TempUa,PowerByte
	andi	TempUa,DiagnosticBit
	brze	TPSkip
	LoadAndSpeakEString		SPTellPower2
	lds		zl,BattVoltageReading
	rcall	TellByte
TPSkip:

; See if charging
	lds		zl,ChargeVoltageReading
	tst		zl
	brze	TP3Done
	LoadAndSpeakEString		SPTellPower3
	lds		zl,ChargeVoltageReading
	rcall	TellByte
TP3Done:
	ret


;*****************************************************************************
;
;	TellOffOn		Says off or on
;
;	Expects:	ParamReg = Boolean value
;
;*****************************************************************************
;
TellOffOn:
	tst		ParamReg
	ldi		ParamReg,SP_off
	brze	TOOOk
	ldi		ParamReg,SP_on
TOOOk:
	rjmp	SpeakWord		;and return


;*****************************************************************************
;
;	TellDigit (0..9)	(but will also work for numbers up to 20)
;
;	Expects:	ParamReg = ASCII digit '0'..'9'
;
;*****************************************************************************
;
TellDigit:
	subi	ParamReg,'0'-SP_zero	;Get absolute value 0..9 then add sound offset
	rjmp	SpeakWord		;and return


;*****************************************************************************
;
;	TellDoubleDigit	(0..99)
;
;	Expects:	ParamReg = ASCII digit '0'..'9'
;				TempUa = 2nd ASCII digit '0'..'9'
;
;*****************************************************************************
;
TellDoubleDigit:
	cpi		ParamReg,'0'	;Is the first digit zero?
	brne	TDD1Not0
	mov		ParamReg,TempUa	;Yes, just say the second digit
	rjmp	TellDigit		; and return
TDD1Not0:
	cpi		ParamReg,'1'
	brne	TDDNotTeen
; It's 10..19
	mov		ParamReg,TempUa	;Get second ASCII digit
	addi	ParamReg,10		;Put into teen range
	rjmp	TellDigit		;Speak and return
TDDNotTeen:
; It's 20..99
	addi	ParamReg,SP_twenty-'0'-2
	push	TempUa
	rcall	SpeakWord		;Say the first digit
	pop		ParamReg		;Get the second digit
	cpi		ParamReg,'0'	;Say nothing else if it's zero
	breq	TDDDone
	rjmp	TellDigit		;Say the second digit if it's non-zero and return
TDDDone:
	ret


;*****************************************************************************
;
;	TellByte
;
; Tells a number, e.g., two hundred (and) eighteen
;
;	Expects:	zl = number to tell
;
;*****************************************************************************
;
TellByte:
	clr		zh
	;rjmp	TellNumber

;*****************************************************************************
;
;	TellNumber
;
; Tells a number, e.g., seventeen thousand, one hundred (and) six
;
;	Expects:	z = number to tell
;
;*****************************************************************************
;
TellNumber:
	rcall	ConvertUWord	;Convert it to an ASCII string in ConvString
	clr		TempLa
	dec		TempLa			;Set to FF: Use for "not spoken anything" flag
	ldiw	y,ConvString
	ld		ParamReg,y+		;Get the first two digits
	ld		TempUa,y+
	mov		TempUb,ParamReg
	or		TempUb,TempUa
	cpi		TempUb,'0'
	breq	TN12Done		;Do nothing if both zero
	rcall	TellDoubleDigit
	SayWord	SP_thousand
	clr		TempLa
TN12Done:
	ldiw	y,ConvString+2
	ld		ParamReg,y+		;Get the third digit
	cpi		ParamReg,'0'
	breq	TN3Done
	rcall	TellDigit
	SayWord	SP_hundred
	clr		TempLa
TN3Done:
	ldiw	y,ConvString+3
	ld		ParamReg,y+		;Get the last two digits
	ld		TempUa,y+
	mov		TempUb,ParamReg
	or		TempUb,TempUa
	andi	TempUb,0x0F		;Get only the bottom nibble
	or		TempUb,TempLa	;Or with "not spoken anything" flag
	brnz	TellDoubleDigit	;If not zero, need to say something (and then return)
	ret						;If zero, digits 4/5 are zero and have already said something


;*****************************************************************************
;
;	Strings
;
;
;*****************************************************************************
;
SlaveIDList:		.db "B", 0
					.dw	InitializeBase
					.db "I", 1
					.dw	InitializeIR
					.db "S", 2
					.dw	InitializeSpeech
; Slave polling constants
				; For each entry is the slave name and then a number showing its position in the
				; slave lists (which are alphabetical)
SlavePollList:		.db	"B", 0
					.db "I", 1
					.db "S", 2
					.db "I", 1
					.dw	0

;*****************************************************************************
;
HelpString:	; NOTE: Each line must have an even number of characters
			;		so that an extra NULL doesn't get inserted
			;12345678901234567890123456789012345678901234567890123456789012345678901234567890
	; This is the summary help messages (if you have limited program space)
	.DB		"HELP ",CR
	.DB		" @ Reset ",CR
	.DB		" # Diagnostics ",CR
	.DB		" A Angle ",CR
;	.DB		" C Comms Dsplay",CR
			;12345678901234567890123456789012345678901234567890123456789012345678901234567890
	.DB		" D Distance",CR
	.DB		" F Forward msg ",CR
	.DB		" G Go",CR
			;12345678901234567890123456789012345678901234567890123456789012345678901234567890
	.DB		" H Halt",CR
	.DB		" I Intensity ",CR
;	.DB		" L Left speed",CR
			;12345678901234567890123456789012345678901234567890123456789012345678901234567890
	.DB		" M Manual",CR
	.DB		" O Override speed",CR
	.DB		" P Pwr off ",CR
			;12345678901234567890123456789012345678901234567890123456789012345678901234567890
	.DB		" Q Query voltages",CR
;	.DB		" R Right speed ",CR
;	.DB		" S Speed ",CR
	.DB		" T Toggle sw ",CR
	.DB		" V Version ",CR
	.DB		" W LCD window",CR
			;12345678901234567890123456789012345678901234567890123456789012345678901234567890
	.DB		" X eXamine registers ",CR
	.DB		" Z Display/Set memory/register/IO port address ",CR
			;12345678901234567890123456789012345678901234567890123456789012345678901234567890
	.DB		CR,0

	; This is the expanded help messages (if you have plenty of program space)
;	.DB		"HELP ",CR
;	.DB		" @        Reset processor",CR
;	.DB		" #        Enter diagnostics mode ",CR
;	.DB		" A=+/-ddd Set angle variable ",CR
;	.DB		" C        Communications display (polling) toggle",CR
;			;12345678901234567890123456789012345678901234567890123456789012345678901234567890
;	.DB		" D=ddddd  Set travel distance variable ",CR
;	.DB		" Fxmm     Forward mm to slave x",CR
;	.DB		" G        Send Go message (with speed, angle, & distance)",CR
;			;12345678901234567890123456789012345678901234567890123456789012345678901234567890
;	.DB		" H        Send Halt message",CR
;	.DB		" I=ddd    Set headlight Intensity",CR
;	.DB		" L=+/-ddd Set left motor speed ",CR
;			;12345678901234567890123456789012345678901234567890123456789012345678901234567890
;	.DB		" M        Send Manual motor messages ",CR
;	.DB		" O=ddd    Override speed ",CR
;	.DB		" P        Power off",CR
;			;12345678901234567890123456789012345678901234567890123456789012345678901234567890
;	.DB		" Q        Query voltages ",CR
;	.DB		" R=+/-ddd Set right motor speed",CR
;	.DB		" S=ddd    Set speed variable ",CR
;	.DB		" Txx      Toggle switch xx (1-10)",CR
;	.DB		" V        Display Version",CR
;	.DB		" W        Display on LCD window",CR
;			;12345678901234567890123456789012345678901234567890123456789012345678901234567890
;	.DB		" X        eXamine registers",CR
;	.DB		" Zaaaa(=vv) Display/Set specified memory (or register or IO port) address",CR
;	.DB		"           (Can have multiple values separated by commas)",CR
;			;12345678901234567890123456789012345678901234567890123456789012345678901234567890
;	.DB		"Numbers can be entered in decimal or in hexadecimal (PRECEDED by H)",CR  
;	.DB		CR,0


;*****************************************************************************
;
;	Miscellaneous Strings
;
;*****************************************************************************

BadMessage:			.DB		CR,LF,"Invalid command (?=help)",0
BadSlaveMessage:	.DB		CR,LF,"Bad Slave Msg",CR,LF,0
DeadString:			.DB		" not responding",CR,LF,0

BatteryLowString:	.DB	"<Batt low>",0
BattString:			.DB	"Battery=",0
ChargeString:		.DB	", Charge=",0

RxBufferOverflowErrorString:	.DB		" Rx Bf Ovf ",0
ComLineOverflowErrorString:		.DB		" Com Ln Ovfl ",0
SUFramingErrorString:			.DB		" SU Fr Err ",0
SUParityErrorString:			.DB		" SU Pa Err ",0
SURxBufferOverflowErrorString:	.DB		" SU Rx Bf Ovfl ",0
SULineOverflowErrorString:		.DB		" SU Ln Ovfl ",0
SlaveCommsErrorString:			.DB		" Slv Comms Err ",0

PowerString:		.DB		CR,"Power: ",0
LightsString:		.DB		CR,"Lights ",0
IntensityString:	.DB		CR,"Intensity ",0
SpeedString:		.DB		CR,"Speed ",0
DemoString:			.DB		CR,"Demo ",0
StealthString:		.DB		CR,"Stealth: ",0
DiagnosticsString:	.DB		CR,"Diagnostics: ",0
AutoStopString:		.DB		CR,"AutoStop ",0
TravelModeString:	.DB		CR,"Travel Mode: ",0
FBSwitchModeString:	.DB		CR,"Front/Back Switch Mode: ",0

TravelTSString:			.DB		"Turn & straight",0
TravelCString:			.DB		"Circle",0
TravelXString:			.DB		"Extreme",0
;TurningLeftString:		.DB		"Turn Left ",0
;TurningRightString:		.DB		"Turn Right ",0
ManualString:			.DB		"Manual",0
AutoString:				.DB		"Automatic    ",0
;FrontDefaultString:		.DB		"Front Def",0
;FrontReverseString:		.DB		"Front Rev",0	
;StopString:				.DB		"Stop",0
;ZeroDegreesString:		.DB		"Ahead",0
;OneEightyDegreesString:	.DB		"Reverse",0

OffString:		.DB		"Off",0
OnString:		.DB		"On",0
LowString:		.DB		"Low",0
NormalString:	.DB		"Normal",0
FullString:		.DB		"Full",0
TestString:		.DB		"Test",0


;*****************************************************************************
;
; Must be at the end of the file
AssemblerErrorCheck:	.DB	123	;To check for assembler label errors
NextFlashAddress:	;Just to cause an error if the flash is overallocated
					; (NextFlashAddress should be address 1000H (FLASHEND+1) or lower)
