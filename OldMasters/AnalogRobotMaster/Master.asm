;*****************************************************************************
;
;	Master.asm		Temporary master control program for Robot
;
;	Written By:		Robert Hunt			June-October 2000
;	 Some By:		Jonathan Hunt		August 2000	
;
;	Modified By:	Robert Hunt
;	Mod. Number:	60
;	Mod. Date:		31 October 2000
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
;.EQU	BS		= 0x08
.EQU	HT		= 0x09
.EQU	LF		= 0x0A
.EQU	CR		= 0x0D
.EQU	ESC		= 0x1B
;.EQU	DEL		= 0xFF

.EQU	DegreeSymbol	= 0xDF	;For Hitachi LCD chip

; Battery voltage:	The indicator voltage is the battery voltage / 3.24
;					The 8-bit count is the battery voltage * 15.8
.EQU	BVLowThreshold		= 180	;Battery voltage low threshold 11.4V
.EQU	BVFullThreshold		= 196	;Battery voltage normal threshold 12.4V

; Charging Voltage: Normally zero -- anything over 120 should be charging
.EQU	ChargingThreshold	= 150	;Charging voltage threshold


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
;.EQU	ADMUXErrorCode					= 11
;.EQU	RxBufferFullErrorCode			= 
;.EQU	SURxBufferFullErrorCode			= 
;.EQU	SURxFramingErrorCode			= 
;.EQU	InvalidFlashAddressErrorCode	= 
;.EQU	InvalidRAMAddressErrorCode		= 
;.EQU	ComRxLineOverflowErrorCode		= 
;.EQU	BaseRxLineOverflowErrorCode		= 
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
;	Samples at 4 x baud rate, so 4 * 1200 = 4800
.EQU	SWUARTTCCR	= TCCR2
.EQU	SWUARTTCOC	= OCR2
.EQU	SWUARTPS	= TCClkDiv8
.EQU	SWUARTTCCompare = 104	;4000000 / 8 / 104 = 4808 Hz = 0.208ms
.EQU	SWUARTTCIE	= OCIE2
;
; Note that the beeper pin can be toggled every interrupt (4800Hz)
; so the maximum frequency is the interrupt frequency divided by two = 2400Hz
.EQU	BeepSilent	= 255	;for the frequency count

.EQU	Beep160Hz	= 15	;2400 / 15 = 160
.EQU	Beep200Hz	= 12	;2400 / 12 = 200
.EQU	Beep240Hz	= 10	;2400 / 10 = 240
.EQU	Beep300Hz	= 8		;2400 / 8 = 300
.EQU	Beep400Hz	= 6		;2400 / 6 = 400
.EQU	Beep480Hz	= 5		;2400 / 5 = 480
.EQU	Beep600Hz	= 4		;2400 / 4 = 600
.EQU	Beep800Hz	= 3		;2400 / 3 = 800
.EQU	Beep1200Hz	= 2		;2400 / 2 = 1200
.EQU	Beep2400Hz	= 1		;2400 / 1 = 2400


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
;	Pin-40	PA0 (ADC0)	AIn		Analog switches on remote control
;	Pin-39	PA1 (ADC1)	AIn		Battery voltage
;	Pin-38	PA2 (ADC2)	AIn		Charge voltage
;	Pin-37	PA3 (ADC3)	In		IR input
;	Pin-36	PA4 (ADC4)	Unused
;	Pin-35	PA5 (ADC5)	Out		Remote LED
;	Pin-34	PA6 (ADC6)	Out		PowerControl
;	Pin-33	PA7 (ADC7)	Out 	Beeper
;
.EQU	AISwitch	= 0
.EQU	AIBattery	= 1
.EQU	AICharge	= 2
;
.EQU	RemoteLEDPort = PORTA
.EQU	RemoteLED	= 5
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
;	Pin-29	PC7	(TOSC2)	Out	TX	} (software UART -- 1200bps)
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
;	R6		HaveBaseRxLine flag: 0=nothing, 1=line received
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
.DEF	HaveBaseRxLine	= r6
.DEF	TempLa			= r7
.DEF	TempLb			= r8
.DEF	TempLc			= r9
.DEF	TempLd			= r10
.DEF	LCDUseTime		= r11
;		.EQU	LCDCountDownTime = 10+1	;10 seconds
.DEF	LCDStatus		= r12
		.EQU	LCDStartInit	= 2	;When it decrements to zero it is initialized
.DEF	StringOutControl = r13
		.EQU	OutToTx		= 0
		.EQU	OutToBase	= 1
		.EQU	OutToLCD	= 2
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
;	R24		} SysTick variable
;	R25		}
;	R26	XL	Used for ISRs only
;	R27	XH	Used for ISRs only
;	R28	YL	}
;	R29	YH	} For general
;	R30	ZL	}	use
;	R31 ZH	}
.DEF	SysTick		= r24	;and r25 (MSB)
.DEF	SysTickl	= r24
.DEF	SysTickh	= r25


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

.EQU	BaseRxBufSiz	= 100	;Note: Maximum of 128 characters
BaseRxBuf:		.byte	BaseRxBufSiz	;MUST NOT CROSS 256 byte boundary
BaseRxBufCnt:	.byte	1	;Number of characters in the buffer

.EQU	BaseTxBufSiz	= 50	;Note: Maximum of 128 characters
BaseTxBuf:		.byte	BaseTxBufSiz	;MUST NOT CROSS 256 byte boundary
BaseTxBufCnt:	.byte	1	;Number of characters in the buffer
BaseTxBufO1:		.byte	1	;Offset to 1st character in buffer


; LCD
.EQU	LCDOutBufSiz	= 65	;Note: Maximum of 128 characters
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
.EQU	BeepBufSiz		= 12	;Note: Maximum of 64 2-byte units or 128 bytes
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
Seconds:				.byte	2	;Counts up to 65535 seconds (1092 minutes = 18.2 hours)
	.EQU	SecondsLSB = Seconds
SentVersionRequestTime:	.byte	1	;Seconds counter for when last sent version request to base
GotBaseVersionTime:		.byte	1	;Seconds counter for when last received version number from base
LastPollTime:			.byte	1	;Seconds counter for when last sent poll to base
BaseDeadFlag:			.byte	1	;Keeps track of whether the base is dead or alive
	.EQU	BDFUnknown	= 0		;(Default at power-up)
	.EQU	BDFAlive	= 1
	.EQU	BDFDead		= 2

; AI variables
ThisSwReading:			.byte	1	;MS 8-bits of the current switch A/D input
BattVoltageReading:		.byte	1	;MS 8-bits of last battery voltage reading
ChargeVoltageReading:	.byte	1	;MS 8-bits of last charging voltage reading
BVLowCount:				.byte	1	;Number of consecutive times for battery low

; Switch variables
ThisAISwitch:	.byte	1	;Switch number 0,7-10 just read
PrevAISwitch:	.byte	1	;Switch number 0,7-10 previous reading
LastAISwitch:	.byte	1	;Switch number 0,7-10 previous accepted reading
HoldCount:		.byte	1	;Counts how long the LastAISwitch has been down for

; Miscellaneous variables
ConvString:		.byte	20	;Storage for null-terminated conversion string
							; (Sign plus five digits plus null)
							;But also used for forming messages to base
							; (BGssaaddddCR plus null)
							;And to computer (STB: BGssaaddddCR plus null)
CodeByte:		.byte	1	;Contains code sequence state for power off

; Base control variables
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
	.EQU	FrontSwitchModeBits = 0b00000011		;(Combined)

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
	.EQU	DMLeftMotorSpeed = 1	;-255..0..+255	(Zero Suppressed)
	.EQU	DMRightMotorSpeed = 2	;-255..0..+255	(Zero Suppressed)
	.EQU	DMSpeed		= 3			;0..255			(Zero Suppressed)
	.EQU	DMDistance	= 4			;0..65535		(Not Zero Suppressed)
	.EQU	DMAngle		= 5			;0..360			(Zero Suppressed)
	.EQU	DMFrontBack	= 6			;Auto..Front..Back
	.EQU	DMIntensity	= 7			;0..255			(Zero Suppressed)
	.EQU	DMSwitch1	= 8
	.EQU	DMSwitch2	= 9
	.EQU	DMSwitch3 	= 10
	.EQU	DMSwitch4	= 11
	.EQU	DMSwitch5	= 12
	.EQU	DMSwitch6	= 13
	.EQU	DMInvalid	= 14	;Must be the last value
DisplayValue:	.byte	2	;To remember our current setting
	.EQU	DisplayValueLSB = DisplayValue
	.EQU	DisplayValueMSB = DisplayValue+1
; When display is a signed 8-bit value or angle the high byte is set to 1 if
; the value is negative or 0 is the value is positive. For motor speed
; negative means backwards and for angle negative means to the left.
	.EQU	DMFBAuto	= 2
	.EQU	DMFBBack	= 1
	.EQU	DMFBFront	= 0 
	.EQU	DMFBInvalid	= 3	; Must be the last value

; Error Counters (All initialized to zero when RAM is cleared at RESET)
RxBufferOverflowErrorCount:		.byte	1
ComLineOverflowErrorCount:		.byte	1
SUFramingErrorCount:			.byte	1
SUParityErrorCount:				.byte	1
SURxBufferOverflowErrorCount:	.byte	1
SULineOverflowErrorCount:		.byte	1

;xxxxxxxxxx
;AICount:	.byte	2
;SWCount:	.byte	2
;BVCount:	.byte	2
;CVCount:	.byte	2
;CECount:	.byte	2
;CIECount:	.byte	2
;CEMUX0:		.byte	2
;CEMUX1:		.byte	2
;CEMUX2:		.byte	2
;CEMUX3:		.byte	2
;xxxxxxxxxxxxxx

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

.MACRO	LoadAndSendTxFString
				;	e.g. LoadAndSendTxFString	StringName
	; Uses z
	ldi		zl,low(@0<<1)
	ldi		zh,high(@0<<1)
	rcall	SendTxFString	;Uses: R0, y, z, TempUa, TempUb, TempUc, ParamReg
.ENDMACRO

.MACRO	LoadAndSendLCDFString
				;	e.g. LoadAndSendLCDFString	StringName
	; Uses z
	ldi		zl,OutToLCD
	mov		StringOutControl,zl
	ldi		zl,low(@0<<1)
	ldi		zh,high(@0<<1)
	rcall	SendFString	;Uses: R0, y, z, TempUa, TempUb, TempUc, ParamReg
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
	rjmp	ISR_SU			;Software UART
 .ORG 	OVF2addr
	rjmp	UnusedInterruptError
 .ORG 	ICP1addr
	rjmp	UnusedInterruptError
 .ORG 	OC1Aaddr
	rjmp	ISR_ST			;System Timer
 .ORG 	OC1Baddr
	rjmp	UnusedInterruptError
 .ORG 	OVF1addr
	rjmp	UnusedInterruptError
 .ORG 	OVF0addr
	rjmp	ISR_LCDT		;LCD Timer
 .ORG 	SPIaddr
	rjmp	UnusedInterruptError
 .ORG 	URXCaddr
	rjmp	ISR_URXC		;RX Char
 .ORG 	UDREaddr
	rjmp	ISR_UDRE		;TX ready
 .ORG 	UTXCaddr
	rjmp	UnusedInterruptError
 .ORG 	ADCCaddr
	rjmp	ISR_ADCC		;A/D Complete
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
	rcall	ProgramError	;Display the error code on the LEDs
	pop		ParamReg
	RestoreSRegReti			;Then re-enable interrupts and carry on with the program


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
HeaderString:	.DB		"Robot Master Test Program V2.00",CR,LF,0
LCDSetupString:	.DB		LCDCommand,LCDIncrement	;"Increment" entry mode
				.DB		LCDCommand,LCDCursorOff
LCDHeaderString:.DB		LCDCommand,LCDCls
				.DB		" Robot Master "	;Must be an even number of characters
				.DB		LCDCommand,LCDHome2,"    V2.00",0


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
; Setup IO Ports
;
;*****************************************************************************

; Port-A is all inputs except bits 7=beeper output, 6=power output, and 5=remote LED output
	ldi		TempUa,0b11100000
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
	ldi		TempUa,high(BaseTxBuf)
	cpi		TempUa,high(BaseTxBufCnt)
	brne	RAMAllocationError
	ldi		TempUa,high(BaseRxBuf)
	cpi		TempUa,high(BaseRxBufCnt)
	brne	RAMAllocationError
	ldi		TempUa,high(LCDOutBuf)
	cpi		TempUa,high(LCDOutBufCnt)
	brne	RAMAllocationError
	ldi		TempUa,high(BeepBuf)
	cpi		TempUa,high(BeepBufCnt)
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

	; Enable the Watchdog now
;	wdr									;Kick it first so resets to zero
;	ldi 	TempUa,(1 << WDE) | WD2048	;Enable a 1.9s time out
;	out 	WDTCR,TempUa

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
	cbi		LEDPort,RunningLED ;Turn RUNNING LED on (indicates reached Main)

; Send a CR to the base to make sure its buffer is cleared
	ldi		ParamReg,CR
	rcall	SendSUChar

;*****************************************************************************

; Check for special diagnostic mode
	in		TempUa,SwitchPort
	andi	TempUa,0b10000000	;Get switch PD7 only
	brze	MainDiag			;Diagnostic mode if it's on (pulled low)
	rjmp	MainNormal			;Normal mode if it's off

; We're in the special diagnostic mode
MainDiag:

; Wait until all the switches are off again
MainDiagWait1:
	in		TempUa,SwitchPort
	andi	TempUa,SwitchBits	;Get switches PD7-PD2 only
	cpi		TempUa,SwitchBits	;See if they're all off
	brne	MainDiagWait1

; Play a little tune again
	DoBeep	Beep1200Hz,Beep0s2
	DoBeep	Beep600Hz,Beep0s2
	DoBeep	Beep480Hz,Beep0s2
	DoBeep	Beep800Hz,Beep0s2
	DoBeep	Beep600Hz,Beep0s3

; Display the version number, etc.
	LoadAndSendTxFString	DiagString
	LoadAndSendLCDFString	LCDSetupString

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

	lds		TempUa,BaseRxBufCnt ;See how many characters there are
	tst		TempUa
	brze	NoBaseRx
	lds		ParamReg,BaseRxBuf	;Get the first character from the base
	rcall	SendTxChar			;Send it to the comms
	clr		HaveBaseRxLine
	sts		BaseRxBufCnt,HaveBaseRxLine
NoBaseRx:

; Check for power-off command
	in		TempUa,SwitchPort
	cpi		TempUa,0b00110000	;Switches 7,6,3,2 on
	brne	NotDiagPowerDown	;No, continue as usual
	rcall	DoPowerDownSeq		;Yes, do power down sequence
NotDiagPowerDown:

; Check for command to return to normal mode
	in		TempUa,SwitchPort
	andi	TempUa,0b01000000	;Get switch PD6 only
	brze	MainDiagWait2		;Branch if it's on
	rjmp	MainDiagLoop		;Stay in diagnostics if it's off

; Wait until all the switches are off again
MainDiagWait2:
	in		TempUa,SwitchPort
	andi	TempUa,SwitchBits	;Get switches PD7-PD2 only
	cpi		TempUa,SwitchBits	;See if they're all off
	brne	MainDiagWait2

;*****************************************************************************

; We're in normal running mode
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
	LoadAndSendLCDFString	LCDSetupString

; Initialize base module
	rcall	InitializeBase
	rcall	SendVersionRequestMessages	;To see if it's dead or alive
	
; Enable IDLE sleep mode so that we can sleep later
;	in		TempUa,MCUCR		;Read the other register bits
;	andi	TempUa,0x0F			;Preserve lower four bits (Interrupt sense control bits)
;	ori		TempUa,(1 << SE)	;Enable sleep mode IDLE (SM1/SM0 = 00)
;	out		MCUCR,TempUa


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
	cpi		TempUa,10
	brlo	LCDOk
	rcall	LCDReset	;Also resets LCDUseTime
LCDOk:

;*****************************************************************************

; Check for operational errors if the Tx buffer is empty
	lds		TempUa,ComTxBufCnt
	tst		TempUa
	brnz	NoCheck
	CheckError	RxBufferOverflow
	CheckError	ComLineOverflow
	CheckError	SUFraming
	CheckError	SUParity
	CheckError	SURxBufferOverflow
	CheckError	SULineOverflow
NoCheck:

;*****************************************************************************

	rcall	CheckSwitches
	rcall	CheckComms

;*****************************************************************************

; Send a version request to the base every now and then
	lds		TempUa,SentVersionRequestTime
	lds		TempUb,SecondsLSB
	sub		TempUb,TempUa
	cpi		TempUb,27		;Only request it every 27 seconds
	brlo	NotVersionTimeYet
	ldi		TempUa,OutToBase
	mov		StringOutControl,TempUa
	rcall	SendVersionRequestMessage	;(Doesn't echo on comms)
NotVersionTimeYet:

; Check that we received a version number from the base recently
	lds		TempUa,GotBaseVersionTime
	lds		TempUb,SecondsLSB
	sub		TempUb,TempUa
	cpi		TempUb,30		;See if we received one in the last 30 seconds
	brlo	GotVersionNumberInTime ;Branch if we did
	; We haven't received a version number response from the base recently
	lds		TempUa,BaseDeadFlag	;Was it already marked dead?
	cpi		TempUa,BDFDead
	breq	GotVersionNumberInTime	;Yes, ignore it now
	ser 	TempUa
	out		LEDPort,TempUa	;Set all bits high to turn all LEDs off
	ldi		TempUa,BDFDead
	sts		BaseDeadFlag,TempUa		;No, set it to DEAD
	DoBeep	Beep300Hz,Beep0s2
	DoBeep	Beep240Hz,Beep0s3
	LoadAndSendTxFString	DeadString
GotVersionNumberInTime:

;*****************************************************************************

; Poll the base for errors etc. every second if we're idle (i.e., nothing received, nothing being sent)
	lds		TempUa,LastPollTime
	lds		TempUb,SecondsLSB
	cp		TempUb,TempUa		;See if we sent one in the current second
	breq	TooBusy
	lds		TempUa,BaseRxBufCnt
	lds		TempUb,BaseTxBufCnt
	or		TempUa,TempUb		;Don't send one yet if we've got other traffic
	brnz	TooBusy
	rcall	PollBase
TooBusy:

;*****************************************************************************
;
; Enter sleep mode (as defined above in Main) until an interrupt occurs
;	Idle mode uses 1.9mA instead of 6.4mA on 8535 at 4MHz, 3V
;	Restart after IDLE is immediate
;
;*****************************************************************************

;	wdr							;Kick the watchdog before we sleep

; Go to IDLE sleep until something else happens
;	sbi		LEDPort,RunningLED 	;Turn RUNNING LED off
;	sleep

; We've woken up again after an interrupt
;	cbi		LEDPort,RunningLED 	;Turn RUNNING LED on
	rjmp	MainLoop


;*****************************************************************************
;
;	Strings
;
;*****************************************************************************

RxBufferOverflowErrorString:	.DB		" Rx Buff Ovrflow ",0
ComLineOverflowErrorString:		.DB		" Com Line Ovrflow ",0
SUFramingErrorString:			.DB		" SU Framing Err ",0
SUParityErrorString:			.DB		" SU Parity Err ",0
SURxBufferOverflowErrorString:	.DB		" SU Rx Buff Ovrflw ",0
SULineOverflowErrorString:		.DB		" SU Line Ovrflw ",0

DeadString:		.DB		CR,LF,"Base not responding ",0


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
	
	; Increment SysTick 16-bit variable (which is kept in registers)
	adiw	SysTick,1	;Increment it directly

	; See if the lowest 5-bits are zero (Every 32 interrupts or msec)
	; Note: Since SysTick gets reset to zero when it reaches 1000 (3E8),
	;			this timing is not perfect but it's good enough
	mov		ISRTempU,SysTickl
	andi	ISRTempU,0b00011111
	brnz	ISTNotZero
;	brze	ISTIsZero
;	rjmp	ISTNotZero
;ISTIsZero:

	; Only read the keyboard switches if it's zero, i.e., every 32 interrupts or msec
	in		ISRTempU,SwitchPort
	andi	ISRTempU,SwitchBits	;Get switches PD7-PD2 only
	mov		ThisSwitches,ISRTempU
;	rjmp	ISTBeeper

;ISTNotZero:
;	cpi		ISRTempU,4
;	brsh	ISTBeeper		;Branch if it's higher than 3
;xxxxxxxxxxxxxxxxxxx
; debug code
;xxxxxxxxxxxxxxxxxxx
; Check that there's no conversion currently in progress
;	push	ISRTempU
;	bric	ADCSR,ADSC,ADCisOk
;xxxxxxxxxxxxx
;	ldsw 	x,CECount		;Load it into x
;	adiw	xl,1			;Increment the 16-bit register x
;	stsw 	CECount,x		;Save it again in memory
;	in		ISRTempU,ADMUX
;	tst		ISRTempU
;	brnz	Not0here
;	ldsw 	x,CEMUX0		;Load it into x
;	adiw	xl,1			;Increment the 16-bit register x
;	stsw 	CEMUX0,x		;Save it again in memory
;	rjmp	ADCisOk
;Not0here:
;	dec		ISRTempU
;	brnz	Not1here
;	ldsw 	x,CEMUX1		;Load it into x
;	adiw	xl,1			;Increment the 16-bit register x
;	stsw 	CEMUX1,x		;Save it again in memory
;	rjmp	ADCisOk
;Not1here:
;	dec		ISRTempU
;	brnz	Not2here
;	ldsw 	x,CEMUX2		;Load it into x
;	adiw	xl,1			;Increment the 16-bit register x
;	stsw 	CEMUX2,x		;Save it again in memory
;	rjmp	ADCisOk
;Not2here:
;	ldsw 	x,CEMUX3		;Load it into x
;	adiw	xl,1			;Increment the 16-bit register x
;	stsw 	CEMUX3,x		;Save it again in memory
;ADCisOk:
;	bric	ADCSR,ADIE,ADCIEisOk
;xxxxxxxxxxxxx
;	ldsw 	x,CIECount		;Load it into x
;	adiw	xl,1			;Increment the 16-bit register x
;	stsw 	CIECount,x		;Save it again in memory
;ADCIEisOk:
;	pop		ISRTempU
;xxxxxxxxxxxxxxxxxxxxxx
;	dec		ISRTempU		;Get a number 0..2
	clr		ISRTempU
	out		ADMUX,ISRTempU	;Make that the channel number
	sbi		ADCSR,ADSC		;Start the conversion
	sbi		ADCSR,ADIE		;Enable the completion interrupt
ISTNotZero:
;	ldi		TempUa,(1<<ADEN)+(1<<ADSC)+(1<<ADIE)+ADCPSDiv64
;	out		ADCSR,TempUa		;Set ADC Control and Status Register
;ISTBeeper:

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
	mov		ISRTempU,SysTickl
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
	cpi		SysTickl,low(1000)
	cpc		SysTickh,ISRTempU
	brne	ISTNotASecond
	
	; Yes, reset it to zero
	clrw	SysTick			;Clears it from 1000 (3E8) to 0

	; Increment the seconds counter	
	ldsw 	x,Seconds		;Load it into x
	adiw	xl,1			;Increment the 16-bit register x
	stsw 	Seconds,x		;Save it again in memory
	
	; Decrement the LCD use timer if it's not zero or one
;	tst		LCDUseTime
;	brze	ISTNoDecrement	;Don't decrement if already zero
;	dec		LCDUseTime
;	brnz	ISTNoDecrement	;Branch if it's not zero now
;	inc		LCDUseTime		;If it was decremented to zero, increment it back to one
;ISTNoDecrement:				; (The main loop will set it to zero when it resets the display)

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

;xxxxxxxxxxxxx
;	ldsw 	x,AICount		;Load it into x
;	adiw	xl,1			;Increment the 16-bit register x
;	stsw 	AICount,x		;Save it again in memory
;xxxxxxxxxxxxxxx

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
	sts		ThisSwReading,xl	;Save the eight MS bits only
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
;		At 1200 baud this is 4800Hz or every 208usec
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
	lds		ISRTempU,BaseTxBufCnt
	tst		ISRTempU
	brnz	ISUTxHaveSome
	
	; No characters in buffer -- disable software transmitter
	ldi		SUTxStatus,SUTxIdle
	rjmp	ISUTxEnd
	
ISUTxHaveSome:
	; Decrement the count and save it again
	dec		ISRTempU
	sts		BaseTxBufCnt,ISRTempU
	
; Get the next character ready to send
	; Get the buffer address and add the offset to the first character
	ldiw	x,BaseTxBuf
	lds		ISRTempU,BaseTxBufO1
	add		xl,ISRTempU		;Note: Only works if buffer does not cross a 256-byte boundary
	ld		SUTxByte,x+		;Get the character and increment the pointer
	
	; Now we have to see if the incremented pointer has gone past the end of the (circular) buffer
	subi	xl,low(BaseTxBuf)	;Convert the incremented address back to an offset
	cpi		xl,BaseTxBufSiz
	brlo	ISUTxOk			;Ok if lower
	subi	xl,BaseTxBufSiz	;Adjust if was higher
ISUTxOk:
	; Store the new offset to the first character in the buffer
	sts		BaseTxBufO1,xl

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

	; Display the received byte on the LEDs
	mov		xl,SURxByte
	com		xl
	out		LEDPort,xl		;(Messes up the main loop indicator temporarily)

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
	tst		HaveBaseRxLine
	brze	ISURNoDouble	;No, we're ok
	
	; Yes, we have doubled up somehow
	lds		ISRTempU,SULineOverflowErrorCount
	inc		ISRTempU		;Count the error and then ignore it
	sts		SULineOverflowErrorCount,ISRTempU
ISURNoDouble:

	; See if the RX buffer is already full
	lds		ISRTempU,BaseRxBufCnt
	cpi		ISRTempU,BaseRxBufSiz-2	;Leave room for the CR and trailing null as well
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
	pop		ISRTempU		;Restore ISRTempU = BaseRxBufCnt and just continue
ISUROK:

	; Calculate where to store the character in the buffer
	;  (ISRTempU still contains BaseRxBufCnt)
	ldiw	x,BaseRxBuf
	add		xl,ISRTempU		;Note: Only works if buffer does not cross a 256-byte boundary

	; Increment the count and save it (so we can use ISRTempU for something else)
	inc		ISRTempU
	sts		BaseRxBufCnt,ISRTempU
	
	; Get the character and save it in the buffer
	mov		ISRTempU,SURxByte
	andi	ISRTempU,0x7F	;Reduce to 7-bits (Ignore parity now -- it was checked above)
	st		x+,ISRTempU
	
	; If it was a CR, set the EOL flag
	subi	ISRTempU,CR
	brne	ISURxDone		;No, we're done

	; It was a CR so append a trailing NULL and set the EOL flag
	st		x,ISRTempU		;(Set to zero by SUBI instruction)
	com		HaveBaseRxLine	;Was zero -- now FF

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
;	SendTXChar	Sends a character to the TX buffer
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
SendTXChar:
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
	rcall	ConvertUByte	;Convert register number already in zl and send it
	
	ldi		ParamReg,'='
	rcall	SendTXChar

	popw	y
	ld		zl,y+			;Get the register value from ComRxBuf
	pushw	y
	
	; Display the register value in hex
	rcall	ConvertHByte	;Convert it to a string and send it

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
	ldi		TempUa,OutToTX
	mov		StringOutControl,TempUa

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
	rcall	ConvertHByte	;Convert it to a string and send it

	ldi		ParamReg,' '
	rcall	SendTXChar

	popw	z				;Get the string address back into z
	
; Send a CR after every four registers
	pop		TempUa			;Get number of registers displayed
	inc		TempUa			;Increment it
	push	TempUa			;Save the incremented value on the stack
	andi	TempUa,0b00000011
	brnz	DNRLoop

	ldi		ParamReg,CR
	rcall	SendTXChar		;Doesn't alter z
	rjmp	DNRLoop

DNRDone:
	pop		TempUa			;Clean up stack
	ret						;Finished all registers

NRString: ;Nine bytes per entry followed by register address
	;    123456789		123456789	   123456789	  123456789
	.DB	"       R0", 0,"R1/ISRRSv", 1,"R2/AIDone", 2,"R3/ThisSw", 3
	.DB	"R4/LastSw", 4,"R5/HvComL", 5,"R6/HavBsL", 6,"R7/TempLa", 7
	.DB	"R8/TempLb", 8,"R9/TempLc", 9,"R10/TmpLd",10,"R11/LCDUT",11
	.DB	"R12/LCDSt",12,"R13/StOCn",13,"R14/SURxB",14,"R15/SUTxB",15
	.DB	"R16/TmpUa",16,"R17/TmpUb",17,"R18/TmpUc",18,"R19/ISRTU",19
	.DB	"R20/BpFrq",20,"R21/ParRg",21,"R22/SURxS",22,"R23/SUTxS",23
	.DB "R24/SyTkL",24,"R25/SyTkH",25,"R26/ISRXL",26,"R27/ISRXH",27
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
	ldi		TempUa,OutToTX
	mov		StringOutControl,TempUa

	ldi		zl,0x60		;Start at address 0060
	clr		zh

DSRLoop1:
	; Display the next line of characters
	pushw	z			;Save the RAM address for this line

	; Display the SRAM address in hex
	rcall	ConvertHWord	;Convert RAM address already in z and send it

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
	rcall	ConvertHByte	;Convert it to a string and send it

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
	ldi		TempUa,OutToTX
	mov		StringOutControl,TempUa

	; Make sure that we're not writing to the EEPROM
DEEWait:
	bris	EECR,EEWE,DEEWait	;Loop if a write operation is still in progress

	clrw	z		;Start at address 0000

DEELoop1:
	; Display the next line of characters
	pushw	z			;Save the EEPROM address for this line

	; Display the EEPROM address in hex
	rcall	ConvertHWord	;Convert EEPROM address already in z and send it

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
	rcall	ConvertHByte	;Convert it to a string and send it

	ldi		ParamReg,' '
	rcall	SendTXChar
	pop		TempUa

	; Insert an extra space after every eight bytes (i.e., in the middle and at the end)
	push	TempUa
	andi	TempUa,0b111
	cpi		TempUa,1
	brne	DEENot8a
	ldi		ParamReg,' '
	rcall	SendTXChar
DEENot8a:
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

	; Insert an extra space after eight bytes
;	cpi		TempUa,8+1
;	brne	DEENot8b
;	push	TempUa
;	ldi		ParamReg,' '
;	rcall	SendTXChar
;	pop		TempUa
;DEENot8b:

	dec		TempUa			;Bytes left to print on this line
	brnz	DEELoop3
	
; Send a CR at the end of every line
	ldi		ParamReg,CR
	rcall	SendTXChar		;Doesn't alter z
	
; Stop after displaying all of the EEPROM
	cpi		zl,low(E2END+1)
	brne	DEELoop1
	cpi		zh,high(E2END+1)
	brne	DEELoop1
	ret						;Finished all 512 bytes


;*****************************************************************************
;
;	ReadEEPROMByte		Read a byte from the EEPROM
;
; Expects:	z = EEPROM address
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

	out		EEARH,zh		;Output the 9-bit address
	out		EEARL,zl

	sbi		EECR,EERE		;Do the read command (will halt CPU for 4 cycles)
	in		R0,EEDR			;Get the EEPROM value
	ret


;*****************************************************************************
;
;	WriteEEPROMByte		Writes a byte to the EEPROM
;
; Expects:	z = EEPROM address
;			ParamReg = byte to write
;
; Waits in case a previous write operation is still in progress
;
; Doesn't change any registers
;
;*****************************************************************************
;
WriteEEPROMByte:
	bris	EECR,EEWE,WriteEEPROMByte	;Loop if a write operation is still in progress

	out		EEDR,ParamReg	;Output the value

	out		EEARH,zh		;Output the 9-bit address
	out		EEARL,zl

	cli						;Disable interrupts temporarily
	sbi		EECR,EEMWE		;Do the write enable command
	sbi		EECR,EEWE		;Do the write command (will halt CPU for 2 cycles)
	reti					;Reenable interrupts and then return


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
	;ldi		TempUa,LCDCountDownTime
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
;	ConvertSByte		Converts a signed byte to ASCII digits
;							and outputs it
;
; Expects:	T = 0 for zero suppression, non-zero for no zero suppression
;			ZL = byte to be converted
;			StringOut = destination
;
;*****************************************************************************
;
;ConvertSByte:
;	clr		zh		;Default to zero extend
;	sbrc	zh,7	;Skip next instruction if number is postive
;	ser		zh		;Is negative, extend negative sign bits
	;Fall through to ConvertSWord below
	
;*****************************************************************************
;
;	ConvertSWord		Converts a signed word to ASCII digits
;							and outputs it
;
; Expects:	T = 0 for zero suppression, non-zero for no zero suppression
;			ZL = byte to be converted
;			StringOut = destination
;
;*****************************************************************************
;
;ConvertSWord:
;	;Point y to the start of the string storage area
;	ldiw	y,ConvString
;	sbrs	zh,7			;Skip next instruction if number is negative
;	rjmp	ConvertUWord1	;Not negative, convert it
;	com		zl				;Is negative, get the absolute value
;	com		zh
;	adiw	zl,1			;Two's complement
;	ldi		TempUc,'-'		;Save the sign
;	st		y+,TempUc
;	rjmp	ConvertUWord1


;*****************************************************************************
;
;	ConvertUByte		Converts a unsigned byte to ASCII digits
;							and outputs it
;
; Expects:	T = 0 for zero suppression, non-zero for no zero suppression
;			ZL = byte to be converted
;			StringOut = destination
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
;			ZL = byte to be converted
;			StringOut = destination
;
; Uses:		TempLa, TempLb, TempLc, TempLd, TempUa, Tempb, TempUc, y, t
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
	addi	zl,'0'		;Convert the last digit to ASCII
	st		y+,zl		;Append to string
ConvertFinish:
	st		y,TempUb	;Append the final null
	
	; Point z to ConvString
	ldiw	z,ConvString
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
;			StringOut = destination
;
; StoreHexByte uses TempUa and TempUc, updates y
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
;	FormBaseCopyHeader		Starts to form a message to the base in ConvString
;
; Sets StringOutControl to OutToTx
; Places a "STB: " (for Sent to Base) in the buffer
; Places a 'B' (for Base) in the buffer
; Returns:	y pointing to next character position in the buffer
;			z pointing to start of buffer
;
;*****************************************************************************
;
FormBaseCopyHeader:
	ldi		yl,OutToTX
	mov		StringOutControl,yl

	;Point y to the start of the string storage area
	ldiw	y,ConvString
	mov		zl,yl			;Keep a copy of the buffer address in z
	mov		zh,yh

	ldi		TempUa,'S'
	st		y+,TempUa
	ldi		TempUa,'t'
	st		y+,TempUa
	ldi		TempUa,'B'
	st		y+,TempUa
	ldi		TempUa,':'
	st		y+,TempUa
	ldi		TempUa,' '
	st		y+,TempUa
	rjmp	FormBaseHeaderCont


;*****************************************************************************
;
;	FormBaseHeader		Starts to form a message to the base in ConvString
;
; Places a 'B' (for Base) in the buffer
; Returns:	y pointing to next character position in the buffer
;			z pointing to start of buffer
;
;*****************************************************************************
;
FormBaseHeader:
	;Point y to the start of the string storage area
	ldiw	y,ConvString
	mov		zl,yl			;Keep a copy of the buffer address in z
	mov		zh,yh

FormBaseHeaderCont:
	ldi		TempUa,'B'
	st		y+,TempUa
	ret


;*****************************************************************************
;
;	SendPowerMessages		Sends a "Power" message to the com and base
;
;*****************************************************************************
;
SendPowerMessages:
	rcall	FormBaseCopyHeader
	rcall	SendPowerMessageCont
	ldi		TempUa,OutToBase
	mov		StringOutControl,TempUa
	;rcall	SendPowerMessage

;*****************************************************************************
;
;	SendPowerMessage		Sends a "Power" message depending on StringOutControl
;
;*****************************************************************************
;
SendPowerMessage:
	rcall	FormBaseHeader	;Returns with buffer address in y
SendPowerMessageCont:
	ldi		TempUa,'P'
	st		y+,TempUa
	lds		TempUa,PowerByte
	rjmp	StoreHexByteThenSend


;*****************************************************************************
;
;	SendTravelMessages		Sends a "Travel" message to the com and base
;
;*****************************************************************************
;
SendTravelMessages:
	rcall	FormBaseCopyHeader
	rcall	SendTravelMessageCont
	ldi		TempUa,OutToBase
	mov		StringOutControl,TempUa
	;rcall	SendTravelMessage

;*****************************************************************************
;
;	SendTravelMessage		Sends a "Travel" message depending on StringOutControl
;
;*****************************************************************************
;
SendTravelMessage:
	rcall	FormBaseHeader	;Returns with buffer address in y
SendTravelMessageCont:
	ldi		TempUa,'T'
	st		y+,TempUa
	lds		TempUa,TravelByte
	rjmp	StoreHexByteThenSend


;*****************************************************************************
;
;	InitializeBase			Sends initialization messages to the base
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
;	SendIntensityMessages	Sends a "Intensity" message to the com and base
;
;*****************************************************************************
;
SendIntensityMessages:
	rcall	FormBaseCopyHeader
	rcall	SendIntensityMessageCont
	ldi		TempUa,OutToBase
	mov		StringOutControl,TempUa
	;rcall	SendIntensityMessage

;*****************************************************************************
;
;	SendIntensityMessage	Sends a "Intensity" message depending on StringOutControl
;
;*****************************************************************************
;
SendIntensityMessage:
	rcall	FormBaseHeader	;Returns with buffer address in y
SendIntensityMessageCont:
	ldi		TempUa,'I'
	st		y+,TempUa
	lds		TempUa,HeadlightIntensity
	rjmp	StoreHexByteThenSend


;*****************************************************************************
;
;	SendSpeedMessages		Sends a "Speed" message to the com and base
;
;*****************************************************************************
;
SendSpeedMessages:
	rcall	FormBaseCopyHeader
	rcall	SendSpeedMessageCont
	ldi		TempUa,OutToBase
	mov		StringOutControl,TempUa
;	;rcall	SendSpeedMessage

;*****************************************************************************
;
;	SendSpeedMessage		Sends a "Speed" message depending on StringOutControl
;
;*****************************************************************************
;
SendSpeedMessage:
	rcall	FormBaseHeader	;Returns with buffer address in y
SendSpeedMessageCont:
	ldi		TempUa,'S'
	st		y+,TempUa
	lds		TempUa,Speed
	rjmp	StoreHexByteThenSend


;*****************************************************************************
;
;	SendVersionRequestMessages			Sends a version number request message
;										 to the com and base
;
;*****************************************************************************
;
SendVersionRequestMessages:
	rcall	FormBaseCopyHeader
	rcall	SendVersionRequestMessageCont
	ldi		TempUa,OutToBase
	mov		StringOutControl,TempUa
	;rcall	SendVersionRequestMessage

;*****************************************************************************
;
;	SendVersionRequestMessage		Sends a message depending on StringOutControl
;
;*****************************************************************************
;
SendVersionRequestMessage:
	lds		TempUa,SecondsLSB	;Update the timer
	sts		SentVersionRequestTime,TempUa
	rcall	FormBaseHeader	;Returns with buffer address in y
SendVersionRequestMessageCont:
	ldi		TempUa,'V'
	rjmp	StoreCharThenSend


;*****************************************************************************
;
;	SendHaltMessages		Sends a "Halt" message to the com and base
;
;*****************************************************************************
;
SendHaltMessages:
	rcall	FormBaseCopyHeader
	rcall	SendHaltMessageCont
	ldi		TempUa,OutToBase
	mov		StringOutControl,TempUa
	;rcall	SendHaltMessage

;*****************************************************************************
;
;	SendHaltMessage			Sends a "Halt" message depending on StringOutControl
;
;*****************************************************************************
;
SendHaltMessage:
	rcall	FormBaseHeader	;Returns with buffer address in y
SendHaltMessageCont:
	ldi		TempUa,'H'
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
;	SendManualMotorMessages		Sends left and right motor messages to the com and base
;
; Uses LeftMotorSpeed and RightMotorSpeed variables
;
;*****************************************************************************
;
SendManualMotorMessages:
	ldsw	z,RightMotorSpeed
	clt				; Set T is reversing
	tst		zh
	brze	SMMM1
	set
SMMM1:
	rcall	SendRightMotorMessages
	
	ldsw	z,LeftMotorSpeed
	clt				; Set T is reversing
	tst		zh
	brze	SMMM2
	set
SMMM2:
	;rcall	SendLeftMotorMessages

;*****************************************************************************
;
;	SendLeftMotorMessages		Sends a left motor message to the com and base
;
; Expects t=0: go forward, t=1: go back
;
;*****************************************************************************
;
SendLeftMotorMessages:
	rcall	FormBaseCopyHeader
	rcall	SendLeftMotorMessageCont
	ldi		TempUa,OutToBase
	mov		StringOutControl,TempUa
	;rcall	SendLeftMotorMessage

;*****************************************************************************
;
;	SendLeftMotorMessage		Sends a left motor message depending on StringOutControl
;
; Expects t=0: go forward, t=1: go back
;
;*****************************************************************************
;
SendLeftMotorMessage:
	rcall	FormBaseHeader	;Returns with buffer address in y
SendLeftMotorMessageCont:
	brts	SLMMBack
	ldi		TempUa,'l'
	rjmp	SLMMNext
SLMMBack:
	ldi		TempUa,'L'
SLMMNext:
	st		y+,TempUa
	lds		TempUa,LeftMotorSpeedLSB
	rjmp	StoreHexByteThenSend


;*****************************************************************************
;
;	SendRightMotorMessages		Sends a right motor message to the com and base
;
; Expects t=0: go forward, t=1: go back
;
;*****************************************************************************
;
SendRightMotorMessages:
	rcall	FormBaseCopyHeader
	rcall	SendRightMotorMessageCont
	ldi		TempUa,OutToBase
	mov		StringOutControl,TempUa
	;rcall	SendRightMotorMessage

;*****************************************************************************
;
;	SendRightMotorMessage		Sends a right motor message depending on StringOutControl
;
; Expects t=0: go forward, t=1: go back
;
;*****************************************************************************
;
SendRightMotorMessage:
	rcall	FormBaseHeader	;Returns with buffer address in y
SendRightMotorMessageCont:
	brts	SRMMBack
	ldi		TempUa,'r'
	rjmp	SRMMNext
SRMMBack:
	ldi		TempUa,'R'
SRMMNext:
	st		y+,TempUa
	lds		TempUa,RightMotorSpeedLSB
	rjmp	StoreHexByteThenSend


;*****************************************************************************
;
;	SendGoMessages		Sends a "Go" message to the com and base
;
; Expects t=0: go left, t=1: go right
;
;*****************************************************************************
;
SendGoMessages:
	rcall	FormBaseCopyHeader
	rcall	SendGoMessageCont
	ldi		TempUa,OutToBase
	mov		StringOutControl,TempUa
	;rcall	SendGoMessage

;*****************************************************************************
;
;	SendGoMessage		Sends a "Go" message depending on StringOutControl
;
; Uses Angle and Distance variables
;
;*****************************************************************************
;
SendGoMessage:
	rcall	FormBaseHeader	;Returns with buffer address in y
SendGoMessageCont:
	lds		TempUa,AngleLSB
	lds		TempUb,AngleMSB
	
	tst		TempUb	; If set then we're going left
	brnz	STMLeft
	cpi		TempUa,180
	brsh	STMLeft
	
	ldi		TempUb,'G'			;Go right
	rjmp	STMNext
STMLeft:
	ldi		TempUb,'g'			;Go left
	; We are turning left so subtract it from 360
	subi	TempUa,low(360)
	neg		TempUa
	
STMNext:
	st		y+,TempUb		;Store the correct G/g character
	push	TempUa			;Save the adjusted angle info
	lds		TempUa,Speed
	rcall	StoreHexByte	;Send the speed
	pop		TempUa
	rcall	StoreHexByte	; Store the angle which is in TempUa
	lds		TempUa,DistanceMSB	;Send MS byte of distance first
	rcall	StoreHexByte
	lds		TempUa,DistanceLSB
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
;			StringOutControl is set
;
; Uses:		ParamReg, y, z, TempUa, TempUc
;
; Returns:	ParamReg = 0
;
;*****************************************************************************
;
SendSString:
	mov		TempUc,StringOutControl	;Ready for CPI instruction
SSS1:
	ld		ParamReg,z+		;Get byte pointed to by Z and then increment Z
	tst		ParamReg			;See if it's a null
	brze	Return2

	cpi		TempUc,OutToTx
	breq	SSSTX
	cpi		TempUc,OutToLCD
	breq	SSSLCD
	rcall	SendSUChar	;Send (buffer) the character in ParamReg
	rjmp	SSS1
SSSTX:
	rcall	SendTXChar	;Send (buffer) the character in ParamReg
	rjmp	SSS1
SSSLCD:
	rcall	SendLCDChar	;Send (buffer) the character in ParamReg
	rjmp	SSS1


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
;	PollBase			Sends a poll message to the base
;
;	Uses:	ParamReg
;
;	SendSUChar also uses y, TempUa, TempUb
;
;*****************************************************************************
;
PollBase:
	lds		TempUa,SecondsLSB	;Remember when we did it
	sts		LastPollTime,TempUa
	ldi		ParamReg,'B'
	rcall	SendSUChar
	ldi		ParamReg,'?'
	rcall	SendSUChar
	ldi		ParamReg,CR
	;rjmp	SendSUChar

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

	cli		; Disable interrupts temporarily
			;	so the SU interrupt can't change buffer control variables

	; See if there's room in the buffer
SSUCTxBusy:
	lds		TempUa,BaseTxBufCnt
	cpi		TempUa,BaseTxBufSiz
	brsh	SSUCBufferFull
	
	; Add the start offset and the length together
	lds		yl,BaseTxBufO1	;Get the offset to the first character
	add		yl,TempUa	;Add the TxBufCnt (Note: Total must not exceed 256)
	
	; Now yl is sort of the the offset of the first empty space
	; We have to adjust it though, if it's past the end of the (circular) buffer
	cpi		yl,BaseTxBufSiz
	brlo	SSUCBNFOk			;Ok if the calculated offset is already inside the buffer
	subi	yl,BaseTxBufSiz		;Otherwise, adjust it down
SSUCBNFOk:
	
	; Now yl is the adjusted offset of the first empty space
	addi	yl,low(BaseTxBuf)	;Add the actual buffer address
	ldi		yh,high(BaseTxBuf)	;Note: Only works if buffer does not cross a 256-byte boundary
	
	; Now y is the address of the first empty space in the buffer
	st		y,ParamReg
	inc		TempUa			;Increment and save the count
	sts		BaseTxBufCnt,TempUa

SSUCDone:	
	reti					;Reenable interrupts and then return

SSUCBufferFull:
	; If we get here the buffer must be full
	; What should we do here???
	ldi		ParamReg,SUBufferFullErrorCode
	rjmp	NonFatalProgramError	;Display the error code on the LEDs
									; and then enable interrupts, return, and try running again


;*****************************************************************************
;
;	SwitchOn		Someone has just pressed a switch on
;
;	Expects:	TempUc = Switch number (1-10)
;							Switches 1-6 are on the AVR Starter Board
;							Switches 7-10 are on the analog port
;
;	1 (PD2) Toggle Power Off/Low/Normal
;	2 (PD3) Toggle Lights Off/Normal/Full/Test
;	3 (PD4) Toggle Stealth mode Off/On
;	4 (PD5) Toggle AutoStop Off/On
;	5 (PD6) Toggle Turn-Straight/Circle Travel mode
;	6 (PD7) Toggle Diagnostics Off/On
;	7 (Back) Decrease
;	8 (Dictate) Increase
;	9 (Cue) Increment Mode
;	10 (Start) Execute
;
;	Uses zl, zh, TempUa, TempUb, TempUc
;
;*****************************************************************************
;
SwitchOn:
	cpi		TempUc,1
	brne	PC+2
	rjmp	Switch1On
	cpi		TempUc,2
	brne	PC+2
	rjmp	Switch2On
	cpi		TempUc,3
	brne	PC+2
	rjmp	Switch3On
	cpi		TempUc,4
	brne	PC+2
	rjmp	Switch4On
	cpi		TempUc,5
	brne	PC+2
	rjmp	Switch5On
	cpi		TempUc,6
	brne	PC+2
	rjmp	Switch6On
	cpi		TempUc,7
	brne	PC+2
	rjmp	Switch7On
	cpi		TempUc,8
	brne	PC+2
	rjmp	Switch8On
	cpi		TempUc,9
	brne	PC+2
	rjmp	Switch9On
	cpi		TempUc,10
	brne	PC+2
	rjmp	Switch10On
	
	; If we get here we have a programming error
	ldi		ParamReg,SWCaseErrorCode
	rjmp	ProgramErrorDump	;Disable interrupts and then display the error code on the LEDs
							; Then reenable interrupts and dump internal information to TX
							; and then return and try to continue operation


;*****************************************************************************
;
;	ConvAI		Converts the analog value to a switch number
;
;	Expects:	ParamReg = 8-bit analog value
;							  0 = Back (7)
;						 48->
;							 97 = Dictate (8)
;						115->
;							133 = Cue (9)
;						163->
;							194 = Start (10)
;						224->
;							255 = None (0)
;
;	Returns:	TempUc = Switch number
;						 0 = None
;						 7 = Back		 8 = Dictate
;						 9 = Cue		10 = Start
;
;	Uses:		zl, zh
;
;*****************************************************************************
;
ConvAI:
	clr		TempUc			;0
	cpi		ParamReg,224
	brlo	ConvAI1
	ret						;Return 0 if > 224
ConvAI1:
	ldi		TempUc,7		;7
	cpi		ParamReg,48
	brsh	ConvAI2
	ret						;Return 7 if < 48
ConvAI2:
	inc		TempUc			;8
	cpi		ParamReg,115
	brsh	ConvAI3
	ret						;Return 8 if < 115
ConvAI3:
	inc		TempUc			;9
	cpi		ParamReg,163
	brsh	ConvAI4
	ret						;Return 9 if < 163
ConvAI4:
	inc		TempUc			;10
Return1:
	ret						;Return 10 if > 163 (but less than 224)


;*****************************************************************************

Sw1FirstPush:
	; This was the first time this switch was pushed so don't increment the mode
	rcall	SaveOldMode
	; Now save it in this mode
	ldi		TempUb,DMSwitch1
	sts		DisplayMode,TempUb
	; And display the value
	rjmp	PwrOk
Switch1On:	;Power
	lds		TempUb,DisplayMode	; See if this is the first time we've been pushed
	cpi		TempUb,DMSwitch1
	brne	Sw1FirstPush
	lds		TempUa,PowerByte
	mov		TempUb,TempUa
	andi	TempUa,PowerBits
	andi	TempUb,NotPowerBits
	inc		TempUa
	cpi		TempUa,PowerBitsOver
	brne	Sw1Clr
	clr		TempUa		;There's no 11 so set to 00
Sw1Clr:
	or		TempUb,TempUa
	sts		PowerByte,TempUb
	rcall	SendPowerMessages
PwrOK:
	LoadAndSendLCDFString	LCDPowerString
	LoadAndSendTxFString	PowerString
	
	lds		TempUa,PowerByte
	andi	TempUa, PowerBits
	; Now send the state
	cpi		TempUa,PowerOff
	brne	SwPwr1
	ldsa	z,OffString
	rjmp	SwPwrDisplay
SwPwr1:
	cpi		TempUa,PowerLow
	brne	SwPwr2
	ldsa	z,LowString
	rjmp	SwPwrDisplay
SwPwr2:
	ldsa	z,NormalString
SwPwrDisplay:
	pushw	z
	ldi		TempUa,OutToLCD
	mov		StringOutControl,TempUa
	rcall	SendFString
	popw	z
	; Send the status of the power message to the Tx as well
	;rjmp	SendTxFString

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
	mov		TempUc,StringOutControl	;Ready for CPI instruction
SFS1:
	lpm					;Get byte pointed to by Z into R0
	tst		r0			;See if it's a null
	brze	Return1

	mov		ParamReg,r0	;Save byte ready to output
	adiw	zl,1		;Increment the 16-bit buffer pointer for next time

	cpi		TempUc,OutToTx
	breq	SFSTX
	cpi		TempUc,OutToLCD
	breq	SFSLCD
	rcall	SendSUChar	;Send (buffer) the character in ParamReg
	rjmp	SFS1
SFSTX:
	rcall	SendTXChar	;Send (buffer) the character in ParamReg
	rjmp	SFS1
SFSLCD:
	rcall	SendLCDChar	;Send (buffer) the character in ParamReg
	rjmp	SFS1


;*****************************************************************************

LCDPowerString:	.DB		LCDCommand,LCDCls,"Power",LCDCommand,LCDHome2,0
PowerString:	.DB		CR,"Power: ",0
OffString:		.DB		"Off",0
LowString:		.DB		"Low",0
NormalString:	.DB		"Normal",0

;*****************************************************************************

Sw2FirstPush:
	; This was the first time this switch was pushed so don't increment the mode
	rcall	SaveOldMode
	; Now save it in this mode
	ldi		TempUa,DMSwitch2
	sts		DisplayMode,TempUa
	; And display the value
	rjmp	Sw2Display
Switch2On:	;Lights
	lds		TempUb,DisplayMode
	cpi		TempUb,DMSwitch2
	brne	Sw2FirstPush
	lds		TempUa,PowerByte	;Get power byte into TempUa
	mov		TempUb,TempUa		;Save a copy in TempUb
	andi	TempUa,LightBits	;Get only the light bits into TempUa
	andi	TempUb,NotLightBits	;Get all the other bits into TempUb
	addi	TempUa,LightBitsIncr;Increment the bits
	cpi		TempUa,LightBitsOver;If over, should wrap to zero
	breq	LgtOK				;If it now should be zero then we don't need to or it back in
	or		TempUb,TempUa
LgtOK:
	sts		PowerByte,TempUb
	rcall	SendPowerMessages
Sw2Display:
	LoadAndSendLCDFString	LCDLightString
	lds		TempUa,PowerByte
	andi	TempUa,LightBits
	cpi		TempUa,LightsOff
	brne	SwLgt1
	ldsa	z,OffString
	rjmp	SwLgtDisplay
SwLgt1:
	cpi		TempUa,LightsNormal
	brne	SwLgt2
	ldsa	z,NormalString
	rjmp	SwLgtDisplay
SwLgt2:
	cpi		TempUa,LightsFull
	brne	SwLgt3
	ldsa	z,FullString
	rjmp	SwLgtDisplay
SwLgt3:
	ldsa	z,TestString
SwLgtDisplay:
	pushw	z
	LoadAndSendTxFString	LightsString
	popw	z
	pushw	z
	rcall	SendFString
	popw	z
	ldi		TempUa,OutToLCD
	mov		StringOutControl,TempUa
	rjmp	SendFString
LCDLightString:	.DB		LCDCommand,LCDCls,"Lights" ;Must be an even number of characters
LCDHome2String:	.DB		LCDCommand,LCDHome2,0
LightsString:	.DB		CR,"Lights ",0
FullString:		.DB		"Full",0
TestString:		.DB		"Test",0

;*****************************************************************************

Sw3FirstPush:
	; This was the first time this switch was pushed so don't increment the mode
	rcall	SaveOldMode
	; Now save it in this mode
	ldi		TempUa,DMSwitch3
	sts		DisplayMode,TempUa
	; And display the value
	rjmp	Sw3Display

Switch3On:	;Stealth
	lds		TempUb,DisplayMode
	cpi		TempUb,DMSwitch3
	brne	Sw3FirstPush
	lds		TempUa,PowerByte
	ldi		TempUb, StealthBit
	eor		TempUa, TempUb
	sts		PowerByte,TempUa
	rcall	SendPowerMessages
Sw3Display:
	LoadAndSendLCDFString	LCDStealthString
	lds		TempUa,PowerByte
	andi	TempUa, StealthBit
	tst		TempUa
	brnz	SwStl1
	ldsa	z,OffString
	rjmp	SwStlDisplay
SwStl1:
	ldsa	z,OnString
SwStlDisplay:
	pushw	z
	LoadAndSendTxFString	StealthString
	popw	z
	pushw	z
	rcall	SendFString
	popw	z
	ldi		TempUa,OutToLCD
	mov		StringOutControl,TempUa
	rjmp	SendFString
LCDStealthString:	.DB		LCDCommand,LCDCls,"Stealth mode",LCDCommand,LCDHome2,0
StealthString:		.DB		CR,"Stealth: ",0
OnString:			.DB		"On",0

;*****************************************************************************

Sw6FirstPush:
	; This was the first time this switch was pushed so don't increment the mode
	rcall	SaveOldMode
	; Now save it in this mode
	ldi		TempUa,DMSwitch6
	sts		DisplayMode,TempUa
	; And display the value
	rjmp	Sw6Display

Switch6On:	;Diagnostics
	lds		TempUb,DisplayMode
	cpi		TempUb,DMSwitch6
	brne	Sw6FirstPush
	lds		TempUa,PowerByte
	ldi		TempUb, DiagnosticBit
	eor		TempUa, TempUb
	sts		PowerByte,TempUa
	rcall	SendPowerMessages
Sw6Display:
	LoadAndSendLCDFString	LCDDiagnosticString
	lds		TempUa,PowerByte
	andi	TempUa, DiagnosticBit
	tst		TempUa
	brnz	SwDiag1
	ldsa	z,OffString
 	rjmp	SwDiagDisplay
SwDiag1:
	ldsa	z,OnString
SwDiagDisplay:
	pushw	z
	LoadAndSendTxFString	DiagnosticsString
	popw	z
	pushw	z
	rcall	SendFString
	popw	z
	ldi		TempUa,OutToLCD
	mov		StringOutControl,TempUa
	rjmp	SendFString
LCDDiagnosticString:	.DB		LCDCommand,LCDCls,"Diagnostic mode",LCDCommand,LCDHome2,0
DiagnosticsString:		.DB		CR,"Diagnostics: ",0

;*****************************************************************************

Sw4FirstPush:
	; This was the first time this switch was pushed so don't increment the mode
	rcall	SaveOldMode
	; Now save it in this mode
	ldi		TempUb,DMSwitch4
	sts		DisplayMode,TempUb
	; And display the value
	rjmp	Sw4Display
Switch4On:	;AutoStop
	lds		TempUb,DisplayMode
	cpi		TempUb,DMSwitch4
	brne	Sw4FirstPush
	lds		TempUa,TravelByte
	ldi		TempUb, AutoStopBit
	eor		TempUa, TempUb
	sts		TravelByte,TempUa
	rcall	SendTravelMessages
Sw4Display:
	LoadAndSendLCDFString	LCDAutoStopString
	lds		TempUa,TravelByte
	andi	TempUa, AutoStopBit
	tst		TempUa
	brnz	SwAutoStop1
	ldsa	z,OffString
	rjmp	SwAutoStopDisplay
SwAutoStop1:
	ldsa	z,OnString
SwAutoStopDisplay:
	pushw	z
	LoadAndSendTxFString	AutoStopString
	popw	z
	pushw	z
	rcall	SendFString
	popw	z
	ldi		TempUa,OutToLCD
	mov		StringOutControl,TempUa
	rjmp	SendFString
LCDAutoStopString:	.DB		LCDCommand,LCDCls,"AutoStop",LCDCommand,LCDHome2,0
AutoStopString:		.DB		CR,"AutoStop ",0

;*****************************************************************************

Sw5FirstPush:
	; This was the first time this switch was pushed so don't increment the mode
	rcall	SaveOldMode
	; Now save it in this mode
	ldi		TempUa,DMSwitch5
	sts		DisplayMode,TempUa
	; And display the value
	rjmp	Sw5Display
Switch5On:	;Travel Mode
	lds		TempUb,DisplayMode
	cpi		TempUb,DMSwitch5
	lds		TempUa,TravelByte
	brne	Sw5FirstPush
	andi	TempUa,TravelModeBits
	andi	TempUb,NotTravelModeBits
	addi	TempUa,TravelModeBitsIncr
	cpi		TempUa,TravelModeBitsOver
	brne	TvlOK
	clr		TempUa		;There's no 11 so set to 00
TvlOK:
	or		TempUb,TempUa
	sts		TravelByte,TempUb
	rcall	SendTravelMessages
Sw5Display:
	LoadAndSendLCDFString	LCDTravelModeString
	lds		TempUa,TravelByte
	andi	TempUa, TravelModeBits
	cpi		TempUa,TravelModeTS
	brne	SwTvl1
	ldsa	z,TravelTSString
	rjmp	SwTvlDisplay
SwTvl1:
	cpi		TempUa,TravelModeC
	brne	SwTvl2
	ldsa	z,TravelCString
	rjmp	SwTvlDisplay
SwTvl2:
	ldsa	z,TravelXString
SwTvlDisplay:
	pushw	z
	LoadAndSendTxFString	TravelModeString
	popw	z
	pushw	z
	rcall	SendFString
	popw	z
	ldi		TempUa,OutToLCD
	mov		StringOutControl,TempUa
	rjmp	SendFString
LCDTravelModeString:	.DB		LCDCommand,LCDCls,"Travel mode",LCDCommand,LCDHome2,0
TravelModeString:		.DB		CR,"Travel Mode: ",0
TravelTSString:			.DB		"Turn & straight",0
TravelCString:			.DB		"Circle",0
TravelXString:			.DB		"Extreme",0

;*****************************************************************************

Switch7On:	; Decrease (Back)
	; Don't allow this if idle
	lds		TempUa,DisplayMode
	cpi		TempUa,DMIdle
	brne	Sw7NotIdle

	; We're idle
	DoBeep	Beep1200Hz,Beep0s1
	DoBeep	Beep800Hz,Beep0s1
	DoBeep	Beep600Hz,Beep0s1
	DoBeep	Beep400Hz,Beep0s1

	; Increment code byte if it was 1 or 3 or 20 or 21
	lds		TempUa,CodeByte
	cpi		TempUa,1
	breq	IncSaveCB
	cpi		TempUa,3
	breq	IncSaveCB
	cpi		TempUa,20
	breq	IncSaveCB
	cpi		TempUa,21
	breq	IncSaveCB
	ser		TempUa			;Otherwise set to 255 so incremented to zero
IncSaveCB:
	inc		TempUa			;Increment code byte for power-off sequence
SaveCB:
	sts		CodeByte,TempUa
	ret

Sw7NotIdle:
	; Check it's not doing something with the board switches
	cpi		TempUa,DMSwitch1
	brlo	SwDecrementDisplayValue
SwPretend:
	; Otherwise pretend we're pressing one of them
	subi	TempUa,DMSwitch1-1	;Get the switch number (1-6)
	mov		TempUc,TempUa		; into TempUc
	rjmp	SwitchOn			;and pretend that we pressed one of those switches
								; and then return

;*****************************************************************************

SwDecrementDisplayValue:
	; We are not in idle mode. The mode we are in is in TempUa. We should
	; increment the value and display it on the screen, beeping if we are
	; already at the maximum value.
	ldsw		z,DisplayValue
	; Now display the value on the LCD
	; See what mode we are in
	clt		; Zero suppression by default
	cpi		TempUa,DMSpeed
	brlo	Sw7Signed9	; (Left motor speed - Right motor speed)
	breq	Sw7Unsigned8	; (Speed)
	cpi		TempUa,DMAngle
	brlo	Sw7Unsigned16; (Distance)
	breq	Sw7Angle9		; (Angle)
	cpi		TempUa,DMIntensity
	brsh	PC+2
	rjmp	Sw7FrontBack2	; (Front-Back mode)
	breq	Sw7Unsigned8	; (Intensity)
	; If it gets here it was an invalid mode
	ldi		ParamReg,DMCaseErrorCode
	rjmp	ProgramErrorDump	;Disable interrupts and then display the error code on the LEDs
							; Then reenable interrupts and dump internal information to TX
							; and then return and try to continue operation
	
Sw7Signed9:
	; This was signed nine bit one (motor speed)
	tst		zh
	breq	Sw7Forward
	; We are going backward so we should actually be incrementing zl
	inc		zl
	brze	PC+2
	rjmp	SwDisplayValue	
	; Its zero so that means it overflowed
	rjmp	ErrorBeep
Sw7Forward:
	; We are going forward so we should decrement the value
	tst		zl
	brnz	Sw7Decrement	;If is above zero then it is easy to do just decrement
	; Its zero so we should go to reverse now
	ldi		zl,1
	ldi		zh,1
	rjmp	SwDisplayValue
Sw7Decrement:
	dec		zl
	rjmp	SwDisplayValue

Sw7Unsigned8:
	; Nice and simple
	; Check its not zero already
	tst		zl
	brnz	PC+2
	rjmp	ErrorBeep
	; Its not zero so its safe to decrement
	dec		zl
	rjmp	SwDisplayValue
	
Sw7Unsigned16:
	tst		zh
	breq	Sw7U16Is0
	sbiw	zl,10			;Decrement by 10
	rjmp	SwDisplayValue	;Cannot overflow
Sw7U16Is0:
	sbiw	zl,1			;Decrement by 1 when getting low
	brcs	PC+2
	rjmp	SwDisplayValue	;The only time carry will be set is on an overflow
	rjmp	ErrorBeep
	
Sw7Angle9:
	; The angle can go from 0-359
	sbiw	zl,1
	brcs	PC+2
	rjmp	SwDisplayValue
	; It was zero now it wraps to 359
	ldi		zl, low(359)
	ldi		zh, high(359)
	rjmp	SwDisplayValue
	
Sw7TurningRight:
	inc		zl
	cpi		zl,181
	brsh	Sw7EB
Sw7DV:	
	rjmp	SwDisplayValue
	
Sw7FrontBack2:
	; We are going front or backwards
	dec		zl
	cpi		zl,0xff
	brne	Sw7DV	; If we didn't overflow
Sw7EB:
	rjmp	ErrorBeep	;Overflowed

;*****************************************************************************

Switch8On:	; Increase (Dictate)
	; Don't allow this if idle
	lds		TempUa,DisplayMode
	cpi		TempUa,DMIdle
	brne	Sw8NotIdle

	; We're idle
	DoBeep	Beep400Hz,Beep0s1
	DoBeep	Beep600Hz,Beep0s1
	DoBeep	Beep800Hz,Beep0s1
	DoBeep	Beep1200Hz,Beep0s1

	; Increment code byte if it was 0 or 2
	; or set to 20 if it was 1
	lds		TempUa,CodeByte
	cpi		TempUa,0
	breq	Sw8CBOk
	cpi		TempUa,2
	breq	Sw8CBOk
	cpi		TempUa,1
	brne	Sw8Inv
	ldi		TempUa,20
	rjmp	SaveCB
Sw8Inv:
	ser		TempUa			;Otherwise set to 255 so incremented to zero
Sw8CBOk:
	rjmp	IncSaveCB		;Increment and save it and then return

Sw8NotIdle:
	cpi		TempUa,DMSwitch1	;Are we in an analog switch mode
	brlo	SwIncrementDisplayValue	;Yes, branch
	rjmp	SwPretend			;No, pretend we're pressing an onboard switch

;*****************************************************************************

SwIncrementDisplayValue:
	; We are not in idle mode. The mode we are in is in TempUa. We should increment
	; the value and display it on the screen beeping if we are already at the maximum
	; value.
	ldsw	z,DisplayValue
	; Now display the value on the LCD
	; See what mode we are in
	clt		; Zero suppression by default
	cpi		TempUa,DMSpeed
	brlo	Sw8Signed9	; (Left motor speed - Right motor speed)
	breq	Sw8Unsigned8	; (Speed)
	cpi		TempUa,DMAngle
	brlo	Sw8Unsigned16; (Distance)
	breq	Sw8Angle9		; (Angle)
	cpi		TempUa,DMIntensity
	brsh	PC+2
	rjmp	Sw8FrontBack2	; (Front-Back mode)
	breq	Sw8Unsigned8	; (Intensity)
	; If it gets here it was an invalid mode
	ldi		ParamReg,DMCaseErrorCode
	rjmp	ProgramErrorDump	;Disable interrupts and then display the error code on the LEDs
							; Then reenable interrupts and dump internal information to TX
							; and then return and try to continue operation
	
Sw8Signed9:
	; This was signed nine bit one (motor speed)
	tst		zh
	breq	Sw8Forward
	; We are going backward so we should actually be decrementing zl
	dec		zl
	brnz	SwDisplayValue	
	; Its zero so that means we are stopped (which means forward)
	clr		zh
	rjmp	SwDisplayValue
Sw8Forward:
	; We are going forward so we should increment the value
	inc		zl
	brnz	SwDisplayValue	; The only time it will go to zero is on an overflow
	; There was on overflow. This means we got to the end of the line so beep.
	rjmp	ErrorBeep	; and return

Sw8Unsigned8:
	; Nice and simple
	inc		zl
	brnz	SwDisplayValue	; The only time it will be zero is on an overflow
	rjmp	ErrorBeep	; and return
	
Sw8Unsigned16:
	cpi		zh,255
	brne	Sw8U16Not255
	adiw	zl,1			;Increment by 1 when near top
	brnz	SwDisplayValue	;The only time it will be zero is on an overflow
	rjmp	ErrorBeep
Sw8U16Not255:
	adiw	zl,10			;Increment by 10
	rjmp	SwDisplayValue	;Cannot overflow
	
Sw8Angle9:
	; The angle can go from 0-359
	adiw	zl, 1
	; See if it went over 359
	cpi		zl, low(360)
	brne	SwDisplayValue
	cpi		zh, high(360)
	brlo	SwDisplayValue
	; It went over so go to zero
	clrw	z
	
Sw8FrontBack2:
	; We are going front or backwards
	inc		zl
	cpi		zl,DMFBInvalid
	brne	SwDisplayValue
	rjmp	ErrorBeep
	
;*****************************************************************************

SwDisplayValue:		; (This is called from Switch7Changed)
	; Should never be called when display is not in use for something on the analog
	; thing.
	
	; Store the value
	stsw	DisplayValue,z
	
	LoadAndSendLCDFString	LCDHome2String
	
	lds		TempUa,DisplayMode
	ldsw	z,DisplayValue
	; Now display the value on the LCD
	; See what mode we are in
	clt		; Zero suppression by default
	cpi		TempUa,DMSpeed
	brlo	SwSigned9	; (Left motor speed - Right motor speed)
	breq	SwUnsigned8	; (Speed)
	cpi		TempUa,DMAngle
	brlo	SwUnsigned16; (Distance)
	breq	SwAngle9		; (Angle)
	cpi		TempUa,DMIntensity
	brsh	PC+2
	rjmp	SwFrontBack2	; (Front-Back mode)
	breq	SwUnsigned8	; (Intensity)
	; If it gets here it was an invalid mode
	ldi		ParamReg,DMCaseErrorCode
	rjmp	ProgramErrorDump	;Disable interrupts and then display the error code on the LEDs
							; Then reenable interrupts and dump internal information to TX
							; and then return and try to continue operation
	
SwSigned9:
	tst		zl
	brnz	SwNotStop
	; We are stopping
	LoadAndSendLCDFString	StopString
	ldi		TempUc,6
	rjmp	SendSpaces		; And return
SwNotStop:
	tst		zh
	breq	SwGoingForward
	; We are going backwards
	LoadAndSendLCDFString	BackwardString
	rjmp	SwSendSpeed
SwGoingForward:
	LoadAndSendLCDFString	ForwardString
SwSendSpeed:
	lds		zl,DisplayValueLSB;Get the value again
	rcall	ConvertUByte
	ldi		TempUc,3	; Send some spaces to blank out old stuff
	;rjmp	SendSpaces

;*****************************************************************************
;
;	SendSpaces		Sends the requested number of spaces to the LCD
;
;	Expects:	TempUc = Number of spaces to send
;
;*****************************************************************************
;
SendSpaces:
	ldi		ParamReg,' '	; Load the space
SSLoop:
	rcall	SendLCDChar		; Send it (doesn't change TempUc or ParamReg)
	dec		TempUc
	brnz	SSLoop
	ret						; Done


;*****************************************************************************

SwUnsigned8:
	rcall	ConvertUByte	;Send the ASCII digits
	ldi		TempUc,2	; Send spaces
	rjmp	SendSpaces
	
SwUnsigned16:
	set		; Turn off zero suppression
	rjmp	ConvertUWord	;Send the ASCII digits and return
	
SwAngle9:
	tst		zl
	brnz	SwNot0D
	tst		zh
	brnz	SwNot0D
	; We are going 0 degrees
	LoadAndSendLCDFString	ZeroDegreesString
	ldi		TempUc,11
	rjmp	SendSpaces
SwNot0D:
	tst		zh		; If set then we're going left
	brnz	SwTurningLeft
	cpi		zl,180	; If 180 were going 180
	breq	SwFullReverse
	brsh	SwTurningLeft
	; We are turning right
	push	zl		; zl is changed by sending the string
	LoadAndSendLCDFString	TurningRightString
	rjmp	SwSendAngle
	
SwFullReverse:
	; We are going full reverse
	LoadAndSendLCDFString	OneEightyDegreesString
	ldi		TempUc,9
	rjmp	SendSpaces
SwTurningLeft:
	; We are turning left so subtract it from 360
	subi	zl,low(360)
	neg		zl	; zl - 360 = -(360 - zl)
	push	zl
	; We are turning left
	LoadAndSendLCDFString	TurningLeftString
	rjmp	SwSendAngle	
	
SwSendAngle:
	pop		zl				;Get the value again 
	rcall	ConvertUByte	;Display the actual angle
	ldi		ParamReg,DegreeSymbol
	rcall	SendLCDChar	
	ldi		TempUc,3
	rjmp	SendSpaces	; and return
	
SwFrontBack2:
	cpi		zl,DMFBAuto
	breq	SWAuto
	cpi		zl,DMFBFront
	breq	SWFrontDefault
	cpi		zl,DMFBBack
	breq	SWReverseDefault

	; If it gets here it was an invalid mode
	ldi		ParamReg,DMCaseErrorCode
	rjmp	ProgramErrorDump	;Disable interrupts and then display the error code on the LEDs
							; Then reenable interrupts and dump internal information to TX
							; and then return and try to continue operation
SWAuto:
	LoadAndSendLCDFString	AutoString
	ret
SWFrontDefault:
	LoadAndSendLCDFString	FrontDefaultString
	ret
SWReverseDefault:
	LoadAndSendLCDFString	FrontReverseString
	ret

TurningLeftString:		.DB		"Turn Left ",0
TurningRightString:		.DB		"Turn Right ",0
AutoString:				.DB		"Automatic    ",0
FrontDefaultString:		.DB		"Front Default",0
FrontReverseString:		.DB		"Front Reverse",0	
ForwardString:			.DB		"Forward ",0
BackwardString:			.DB		"Backward ",0
StopString:				.DB		"Stop",0
ZeroDegreesString:		.DB		"Ahead",0
OneEightyDegreesString:	.DB		"Reverse",0

;*****************************************************************************

Switch9On:	; Increment the mode (Cue)
IncrementMode:
	rcall	SaveOldMode

	; Increment the mode (Note: It may be incremented to DMInvalid)
	lds		TempUa,DisplayMode
	inc		TempUa
	sts		DisplayMode,TempUa

	; See what the new mode is
	cpi		TempUa,DMLeftMotorSpeed
	brne	Sw9aa
	
	; Now in left speed mode
	LoadAndSendLCDFString	LCDLeftMotorSpeedModeString
	ldsw	z,LeftMotorSpeed
	rjmp	SwDisplayValue
LCDLeftMotorSpeedModeString:	.DB		LCDCommand,LCDCls,"Left Speed",LCDCommand,LCDHome2,0
 
Sw9aa:
	cpi		TempUa,DMRightMotorSpeed
	brne	Sw9bb
	
	; Now in right speed mode
	LoadAndSendLCDFString	LCDRightMotorSpeedModeString
	ldsw	z,RightMotorSpeed
	rjmp	SwDisplayValue	; and return
LCDRightMotorSpeedModeString:	.DB		LCDCommand,LCDCls,"Right Speed",LCDCommand,LCDHome2,0

Sw9bb:
	cpi		TempUa,DMSpeed
	brne	Sw9cc

	; Now in speed mode
	LoadAndSendLCDFString	LCDSpeedModeString
	lds		zl,Speed
	clr		zh
	rjmp	SwDisplayValue	; and return
LCDSpeedModeString:		.DB		LCDCommand,LCDCls,"Speed",LCDCommand,LCDHome2,0

Sw9cc:
	cpi		TempUa,DMDistance
	brne	Sw9dd

	; Now in distance mode
	LoadAndSendLCDFString	LCDDistanceModeString
	ldsw	z,Distance
	rjmp	SwDisplayValue	; and return
LCDDistanceModeString:	.DB		LCDCommand,LCDCls,"Distance",LCDCommand,LCDHome2,0

Sw9dd:
	cpi		TempUa,DMAngle
	brne	Sw9ee

	; Now in angle mode
	LoadAndSendLCDFString	LCDAngleModeString
	ldsw	z,Angle
	rjmp	SwDisplayValue	; and return
LCDAngleModeString:		.DB		LCDCommand,LCDCls,"Angle",LCDCommand,LCDHome2,0

Sw9ee:
	cpi		TempUa,DMFrontBack
	brne	Sw9ff
	
	; Now in front/back mode
	LoadAndSendLCDFString	LCDFBSWitchModeString
	lds		zl,TravelByte
	andi	zl,FrontSwitchModeBits	; Only the bottom 2 bits matter
	sbrc	zl,1			;If we are in auto-turn mode
	cbr		zl,0b00000001	; clear the direction
	rjmp	SwDisplayValue	;Return
LCDFBSwitchModeString:	.DB		LCDCommand,LCDCls,"F/B switch mode",LCDCommand,LCDHome2,0

Sw9ff:
	cpi		TempUa,DMIntensity
	brne	Sw9gg

	; (Light) Intensity mode
	LoadAndSendLCDFString	LCDIntensityModeString
	lds		zl,HeadlightIntensity
	clr		zh
	rjmp	SwDisplayValue
LCDIntensityModeString:	.DB		LCDCommand,LCDCls,"Intensity",LCDCommand,LCDHome2,0

Sw9gg:
	cpi		TempUa,DMInvalid
	brne	Sw9xx		;No, must be simulating an onboard switch
	; We have to reset the mode to idle here because otherwise calling SaveOldMode
	; will give an error.
	ldi	TempUa, DMIdle
	sts	DisplayMode, TempUa
	rjmp	LCDReset	;Yes, reset the mode to idle and return

	; It must be in one of the simulate on-board switch modes
Sw9xx:
	ldi		TempUc,DMIdle	;Pretend we were in idle mode so it knows it's the first push
	sts		DisplayMode,TempUc
	rjmp	SwPretend	;Pretend we've pressed one of them (calculated from DisplayMode in TempUa)

;*****************************************************************************

SaveOldMode:
	; See what the old mode was
	lds		TempUa,DisplayMode
	cpi		TempUa,DMIdle
	brne	SOMa
	ret					;Just return if it was in idle mode

SOMa:
	ldsw	z,DisplayValue	;Load z in advance with DisplayValue
	cpi		TempUa,DMLeftMotorSpeed
	brne	SOMb
	
	; It was left speed mode
	stsw	LeftMotorSpeed,z
	ret

SOMb:
	cpi		TempUa,DMRightMotorSpeed
	brne	SOMc
	
	; It was right speed mode
	stsw	RightMotorSpeed,z
	ret

SOMc:
	cpi		TempUa,DMSpeed
	brne	SOMd
	
	; It was speed mode
	sts		Speed,zl
	ret

SOMd:
	cpi		TempUa,DMDistance
	brne	SOMe
	
	; It was distance mode
	stsw	Distance,z
	ret

SOMe:
	cpi		TempUa,DMAngle
	brne	SOMf
	
	; It was angle mode
	stsw	Angle,z
	ret

SOMf:
	cpi		TempUa,DMFrontBack
	brne	SOMg
	
	; It was front/back mode
	; save it
	lds		zl,DisplayValueLSB	; This should work out right to make the right message.
	lds		zh,TravelByte
	cbr		zh,FrontSwitchModeBits
	or		zh,zl
	sts		TravelByte,zh
	ret

SOMg:
	cpi		TempUa,DMIntensity
	brne	SOMh
	
	; It was (light) intensity mode
	sts		HeadlightIntensity,zl
	rjmp	SendIntensityMessages	;and return

SOMh:
	cpi		TempUa,DMInvalid
	brsh	SOMError	;Branch if weird
	ret

SOMError:
	; Something went wrong here
	ldi		ParamReg,DMCaseErrorCode
	rjmp	ProgramErrorDump	;Disable interrupts and then display the error code on the LEDs
							; Then reenable interrupts and dump internal information to TX
							; and then return and try to continue operation

;*****************************************************************************

Switch10On:	; Execute (Start)
	; See what mode we are in
	lds		TempUa,DisplayMode
	cpi		TempUa,DMIdle
	breq	DoHalt
	rjmp	Sw10a
DoHalt:
	; Check for codes
	lds		TempUa,CodeByte
	cpi		TempUa,4
	brne	NotCodePowerDown
	rcall	DoPowerDownSeq	;Do power down sequence if necessary
	rjmp	LCDReset
NotCodePowerDown:
	cpi		TempUa,22
	brne	DoHalt2
	rcall	SendDemoMessages
	rjmp	LCDReset

	; We are in idle mode -- send a halt message
DoHalt2:
	rcall	SendHaltMessages
	DoBeep	Beep1200Hz,Beep0s2
	;rjmp	LCDReset	;and return

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
	LoadAndSendLCDFString	LCDHeaderString

; Zeroise the display mode, i.e., set it to DMIdle
	rcall	SaveOldMode
	clr		TempUa
	sts		DisplayMode,TempUa		;Set into idle mode
	sts		CodeByte,TempUa			;Reset code sequence
	
; Do a few other checks while we're here (usually about every 10 seconds)
	; Check the current voltage states
	lds		TempUa,BattVoltageReading	;Read the current battery state
	cpi		TempUa,BVLowThreshold
	brsh	BVOk
	LoadAndSendLCDFString	BLLCDString
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
	LoadAndSendLCDFString	BCLCDString
BCOk:
	
; Check and update the current logic states
	lds		TempUb,PowerByte		;What's our current logic state
	andi	TempUb,PowerBits
	cpi		TempUb,PowerNormal
	brne	NotNormalPower

	; Our logic state is normal
	lds		TempUa,BVLowCount		;See how long we've been low
	cpi		TempUa,3
	brlo	BVSOk					;If we're less than 3, maybe not really low yet
	lds		TempUb,PowerByte
	andi	TempUb,NotPowerBits
	ori		TempUb,PowerLow
	sts		PowerByte,TempUb
	; We've just gone from normal to low
	rcall	SendPowerMessages
	DoBeep	Beep1200Hz,Beep0s1
	DoBeep	Beep600Hz,Beep0s2
	DoBeep	Beep400Hz,Beep0s3
	LoadAndSendLCDFString	BatteryLowLCDString
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
	rjmp	SendPowerMessages	;We've just gone from low to normal

BatteryLowLCDString:	.DB		LCDCommand,LCDHome2
BatteryLowString:		.DB		"<Battery low>",0
BLLCDString:			.DB		LCDCommand,0x80+0x40+14,"L",0
BCLCDString:			.DB		LCDCommand,0x80+0x40+15,"C",0

;*****************************************************************************

Sw10a:
	cpi		TempUa,DMSwitch1
	brlo	Sw10aa
	; We were doing something on the digital switches so just beep
	rjmp	LCDReset		;Just go back to idle mode

Sw10aa:
	ldsw	z,DisplayValue	;Load z in advance with DisplayValue
	cpi		TempUa,DMLeftMotorSpeed
	brne	SW10b

	; We are in left speed mode -- advance to right speed mode
Sw10Inc:
	stsw	LeftMotorSpeed,z
	rjmp	IncrementMode

Sw10b:
	cpi		TempUa,DMRightMotorSpeed
	brne	SW10c

	; We are in right speed mode -- send the two motor messages
	stsw	RightMotorSpeed,z
	rcall	SendManualMotorMessages
	rjmp	LCDReset	;and return

Sw10c:
	cpi		TempUa,DMSpeed
	brne	SW10d

	; We are in speed mode
	sts		Speed,zl
	rcall	SendSpeedMessages	;Send an override message
	rjmp	LCDReset	;and return

Sw10d:
	cpi		TempUa,DMDistance
	brne	SW10e

	; We are in distance mode
	stsw	Distance,z
Sw10Go:
	lds		zh,AngleMSB
	set			; Set T if going right
	tst		zh
	breq	PC+2
	clt
	rcall	SendGoMessages
	DoBeep	Beep2400Hz,Beep0s2
	rjmp	LCDReset	;and return

Sw10e:
	cpi		TempUa,DMAngle
	brne	SW10f

	; We are in angle mode
	stsw	Angle,z
	rjmp	Sw10Go

Sw10f:
	cpi		TempUa,DMFrontBack
	brne	SW10g
	
	; It was front/back mode
	; save it
	lds		zh,TravelByte
	cbr		zh,FrontSwitchModeBits
	or		zh,zl
	sts		TravelByte,zh
	rcall	SendTravelMessages
	rjmp	LCDReset	;and return

Sw10g:
	cpi		TempUa,DMIntensity
	brne	SW10h

	; We are in intensity mode
	sts		HeadlightIntensity,zl
	rcall	SendIntensityMessages
	rjmp	LCDReset	;and return

Sw10h:
	; Something went wrong here
	ldi		ParamReg,DMCaseErrorCode
	rjmp	ProgramErrorDump	;Disable interrupts and then display the error code on the LEDs
							; Then reenable interrupts and dump internal information to TX
							; and then return and try to continue operation


;*****************************************************************************
;
;	CheckSwitches
;
;	Checks the digital switches and then the analog switches
;
;*****************************************************************************
;
CheckSwitches:
	cp		LastSwitches,ThisSwitches
	breq	NoSwitchChanges
	mov		TempUa,LastSwitches			;Keep a copy of the previous reading
	mov		LastSwitches,ThisSwitches	;Update for next time
		
; A switch has changed -- we need to action it
;  (Remember that 1 is off, 0 is on)

	; Check for power-off combination
	mov		TempUb,ThisSwitches ;Get a copy of the latest reading
	cpi		TempUb,0b00110000	;Switches 7,6,3,2 on
	brne	NotPowerDown		;No, continue as usual
	;rjmp	DoPowerDownSeq		;Yes, do power down sequence and return from CheckSwitches

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

NotPowerDown:
	; Check for normal things
	mov		TempUb,ThisSwitches ;Get a copy of the latest reading
	ldi		TempUc,6		;Number of switches to check
CheckSwitchLoop:
	rol		TempUb			;Get the next MS switch bit into carry
	brcs	NextSwitch		;If it's off now, doesn't matter what it was before
	;This switch is on, see if it's just come on
	tst		TempUa			;See if TempUa is negative -- i.e., bit-7 is set
	brpl	NextSwitch		;No, it was on before
	push	TempUa
	push	TempUb
	push	TempUc
	rcall	SwitchOn		;Process the switch (Number is in TempUc)
	pop		TempUc
	pop		TempUb
	pop		TempUa
NextSwitch:
	rol		TempUa			;Need to shift the previous bits as well
	dec		TempUc
	brnz	CheckSwitchLoop
NoSwitchChanges:

;*****************************************************************************


; Debounce the analog switches
	tst		AIDone		;Should only happen every 32 msec
	brze	AINotDone	;Wait for the next reading

	; The interrupt routine has gotten a reading for us
	clr		AIDone		;Clear the flag again
	lds		ParamReg,ThisSwReading
	rcall	ConvAI			;Converts to a switch number 0,7-10 in TempUc
	sts		ThisAISwitch,TempUc
	lds		TempUa,PrevAISwitch	;Get the previous switch number
	sts		PrevAISwitch,TempUc ;Save the new switch number
	cp		TempUc,TempUa	;Was this the same as the immediate previous reading?
	brne	AIStillMoving	;No, it wasn't the same -- wait for it to stabilize
	
; Check if the analog switch has changed
	lds		TempUb,LastAISwitch ;Get the last acccepted value
	cp		TempUc,TempUb	;Are they the same?
	breq	NoAISwitchChange

; A switch has changed
	clr		TempUa			;Clear the hold count
	sts		HoldCount,TempUa
	sts		LastAISwitch,TempUc ;Save the switch number
	tst		TempUc
	brze	NoAISwitchOn	;Check in case the switch just went off
	rcall	SwitchOn		;Process the switch that's just been turned on (Number is in TempUc)
	rjmp	AIReadingDone

NoAISwitchChange:
	lds		TempUa,DisplayMode
	cpi		TempUa,DMIdle
	breq	AIReadingDone		;Yes, we're done

	; We're not idle and there is a switch being held down -- the switch number is in TempUb and TempUc
	lds		TempUa,HoldCount
	cpi		TempUa,24			;Don't increment past 24
	brsh	NoMoreIncrement
	inc		TempUa				;Increment the count
	sts		HoldCount,TempUa
NoMoreIncrement:
	lsr		TempUa				;Now divide it by 8
	lsr		TempUa
	lsr		TempUa				;(Anything less than 8 will now be zero)
	tst		TempUa				;Exit if it's zero (We don't want to loop 256 times)
	brze	AIReadingDone

	; See if it's switch 7 (decrement) or switch 8 (increment)
	; If it is, press the switch TempUa times (gives an ever increasing speed)
	cpi		TempUb,7
	brne	Not7
	; It's switch 7 (decrement)
Sw7Repeat:
	push	TempUa				;Save the repeat (loop) count
	rcall	Switch7on
	pop		TempUa
	dec		TempUa
	brnz	Sw7Repeat
	rjmp	AIReadingDone
Not7:
	cpi		TempUb,8
	brne	AIReadingDone
	; It's switch 8 (increment)
Sw8Repeat:
	push	TempUa				;Save the repeat (loop) count
	rcall	Switch8on
	pop		TempUa
	dec		TempUa
	brnz	Sw8Repeat
AIReadingDone:
NoAISwitchOn:					
AIStillMoving:
AINotDone:
	ret


;*****************************************************************************
;
;	CheckComms
;
;	Checks the computer and then the base communications
;
;	Accepts the following case-insensitive commands from the computer:
;		?			Help
;		@			Reset
;		#			Enter diagnostic mode
;		V			Display version numbers (also requests version from base)
;		Q			Query battery and charging voltages
;		P			Power off system
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
;		Bff:tt		Beep with frequency and time counts
;						(Can have multiple ff:tt sets separated by commas)
;		W			Display on LCD window
;
;		E			Display all EEPROM memory
;		N			Display named registers
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
;	Spare letters are:	C, K, U, Y
;
;*****************************************************************************
;
HelpString:	; NOTE: Each line must have an even number of characters
			;		so that an extra NULL doesn't get inserted
			;12345678901234567890123456789012345678901234567890123456789012345678901234567890
	.DB		"HELP ",CR
	.DB		" @ Reset ",CR
	.DB		" # Diagnostics ",CR
	.DB		" A Angle ",CR
;	.DB		" B Beep",CR
			;12345678901234567890123456789012345678901234567890123456789012345678901234567890
	.DB		" D Distance",CR
	.DB		" E EEPROM",CR
	.DB		" F Forward ",CR
	.DB		" G Go",CR
			;12345678901234567890123456789012345678901234567890123456789012345678901234567890
	.DB		" H Halt",CR
	.DB		" I Intensity ",CR
	.DB		" L Left speed",CR
			;12345678901234567890123456789012345678901234567890123456789012345678901234567890
	.DB		" M Manual",CR
;	.DB		" N Named registers ",CR
	.DB		" O Override speed",CR
	.DB		" P Power off ",CR
			;12345678901234567890123456789012345678901234567890123456789012345678901234567890
	.DB		" Q Query voltages",CR
	.DB		" R Right speed ",CR
	.DB		" S Speed ",CR
	.DB		" T Toggle switch ",CR
	.DB		" V Version ",CR
	.DB		" W LCD window",CR
			;12345678901234567890123456789012345678901234567890123456789012345678901234567890
;	.DB		" X eXamine registers ",CR
;	.DB		" Z Display/Set memory or register or IO port address ",CR
			;12345678901234567890123456789012345678901234567890123456789012345678901234567890
	.DB		CR,0

;	.DB		"HELP ",CR
;	.DB		" @        Reset processor",CR
;	.DB		" #        Enter diagnostics mode ",CR
;	.DB		" A=+/-ddd Set angle variable ",CR
;	.DB		" Bff:tt   Beep with frequency & time counts",CR
;	.DB		"           (Can have multiple ff:tt sets separated by commas)",CR
;			;12345678901234567890123456789012345678901234567890123456789012345678901234567890
;	.DB		" D=ddddd  Set travel distance variable ",CR
;	.DB		" E        Display all EEPROM memory",CR
;	.DB		" Eaaa(=vv)Display/Set specified EEPROM memory address",CR
;	.DB		"           (Can have multiple values separated by commas)",CR
;	.DB		" FBmm     Forward mm to base ",CR
;	.DB		" G        Send Go message (with speed, angle, & distance)",CR
;			;12345678901234567890123456789012345678901234567890123456789012345678901234567890
;	.DB		" H        Send Halt message",CR
;	.DB		" I=ddd    Set headlight Intensity",CR
;	.DB		" L=+/-ddd Set left motor speed ",CR
;			;12345678901234567890123456789012345678901234567890123456789012345678901234567890
;	.DB		" M        Send Manual motor messages ",CR
;	.DB		" N        Display Named registers",CR
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

BadMessage:	.DB		CR,LF,"Invalid command (Press ? for help)",0


;*****************************************************************************
;
CheckComms:
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

	cpi		TempUb,'N'
	brne	NotComN
	rcall	DumpNamedRegisters
	rjmp	ClearComRxLine
NotComN:

	cpi		TempUb,'Q'
	brne	NotComQ
	LoadAndSendTxFString	SwString
	clt							;Zero suppress number
	lds		zl,ThisSwReading
	rcall	ConvertUByte		;Convert number in zl and send it
	LoadAndSendFString	BattString
	clt							;Zero suppress number
	lds		zl,BattVoltageReading
	rcall	ConvertUByte		;Convert number in zl and send it
	LoadAndSendFString	ChargeString
	clt							;Zero suppress number
	lds		zl,ChargeVoltageReading
	rcall	ConvertUByte		;Convert number in zl and send it
	ldi		ParamReg,CR
	rcall	SendTxChar
	rjmp	ClearComRxLine
SwString:		.DB	"Switch=",0
BattString:		.DB	", Battery=",0
ChargeString:	.DB	", Charge=",0
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

	cpi		TempUb,'E'
	brne	NotComE
	rcall	DumpEEPROM
	rjmp	ClearComRxLine
NotComE:

; We got an invalid message so beep
	rjmp	CInvalidMessage

;*****************************************************************************

; We have a message longer than one character (plus CR)
ComMoreThan2:
	cpi		TempUb,'F'
	brne	NotComF
	; We must forward the rest of the line to the base
	ldi		TempUc,OutToBase
	mov		StringOutControl,TempUc
	pushw	z
	rcall	SendSString		;z already points to the CR/Null terminated string
	ldi		TempUc,OutToTx
	mov		StringOutControl,TempUc
	ldi		ParamReg,'S'
	rcall	SendTxChar
	ldi		ParamReg,'t'
	rcall	SendTxChar
	ldi		ParamReg,'B'
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
	cpi		TempUa,DMDistance
	brne	CDNoUpdate
	mvw		z,y
	rcall	SwDisplayValue
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
	rcall	SwDisplayValue
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
	rcall	SwDisplayValue
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
	rcall	SwDisplayValue
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
	cpi		TempUa,DMLeftMotorSpeed
	brne	CLNoUpdate
	mov		zl,yl
	lds		zh,LeftMotorSpeedMSB	; The direction was saved up above
	rcall	SwDisplayValue
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
	cpi		TempUa,DMRightMotorSpeed
	brne	CRNoUpdate
	mov		zl,yl
	lds		zh,RightMotorSpeedMSB	; The direction was saved up above
	rcall	SwDisplayValue
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
	rcall	SwDisplayValue
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
	rcall	ConvertHByte	;Convert it to a string and send it
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
	ldi		TempUa,OutToTX
	mov		StringOutControl,TempUa
	popw	z				;Pop the address into z
	rcall	ReadEEPROMByte	;Read the byte into R0
	mov		zl,R0			; and then move it into zl
	rcall	ConvertHByte	;Convert zl to a string and send it
	ldi		ParamReg,CR
	rcall	SendTxChar		;Finish the line
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
	; We have the address on the stack and the value in yl
	mov		ParamReg,yl		;Move the value into ParamReg
	popw	y				;Get the address into y
	pushw	z				;Save z which is comms buffer address
	mvw	z,y					;Move the address into z
	rcall	WriteEEPROMByte	;Write byte in ParamReg to address in z (Doesn't change any registers)
	popw	z				;Restore z which is comms buffer address
	adiw	yl,1			;Increment the EEPROM address
	cpi		ParamReg,','	;Was the terminator a comma?
	breq	ComEEAddDone	;Yes, get next value
	rjmp	ClearComRxLine
NotComEE:

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

	cpi		TempUb,'B'
	brne	NotComB
ComB:
	ld		ParamReg,z+		;Get the next character (space or digit)
	cpi		ParamReg,' '
	breq	ComB			;Ignore spaces
	;Get the frequency digits
	rcall	ProcessFirstDigit
	brcc	ComBDigitLoop1
	rjmp	CInvalidMessage	;Error if no first digit
ComBDigitLoop1:
	ld		ParamReg,z+		;Get the next character
	cpi		ParamReg,':'
	breq	ComBTime		;Finished when hit colon
	rcall	ProcessNextDigit
	brcc	ComBDigitLoop1
	rjmp	CInvalidMessage	;Branch if error
ComBTime:
	mov		TempUc,yl		;Save the frequency byte
ComB2:
	ld		ParamReg,z+		;Get the next character (space or digit)
	cpi		ParamReg,' '
	breq	ComB2			;Ignore spaces
	;Get the time digits
	rcall	ProcessFirstDigit
	brcc	ComBDigitLoop2
	rjmp	CInvalidMessage	;Error if no first digit
ComBDigitLoop2:
	ld		ParamReg,z+		;Get the next character
	cpi		ParamReg,','
	breq	ComBDone		;Finished when hit colon
	cpi		ParamReg,CR
	breq	ComBDone		;Finished when hit CR
	rcall	ProcessNextDigit
	brcc	ComBDigitLoop2
	rjmp	CInvalidMessage	;Branch if error
ComBDone:
	mov		TempUa,yl		;Save time byte in TempUa
	push	ParamReg		;Save the last character processed
	mov		ParamReg,TempUc	;Get freq byte into ParamReg
	rcall	Beep			;With parameters in ParamReg and TempUa
	pop		ParamReg		;Get the last character processed
	cpi		ParamReg,','	;Was it a comma
	breq	ComB			;Yes, we've got another beep coming
	rjmp	ClearComRxLine	;No, we're done
NotComB:

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
	rcall	SwitchOn
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
	tst		HaveBaseRxLine
	brze	NoBaseRxLine		;Branch if nothing yet

; See if it's a base version number message (tells us the base is alive)
	ldiw	z,BaseRxBuf		;Point z to the buffer	
	ld		TempUa,z+		;Get the first character
	cpi		TempUa,'V'		;Is it a version number message?
	brne	NotBaseV		;No, branch
	lds		TempUa,BaseRxBufCnt
	cpi		TempUa,8		;The version number message is eight bytes long (counting the CR)
	brne	NotBaseV
	lds		TempUa,SecondsLSB	;Remember the time when we got it
	sts		GotBaseVersionTime,TempUa
	lds		TempUa,BaseDeadFlag	;Were we already marked alive?
	cpi		TempUa,BDFAlive
	breq	NotBaseV		;Yes, branch
	rcall	InitializeBase
	DoBeep	Beep400Hz,Beep0s2
	DoBeep	Beep600Hz,Beep0s3
	ldi		TempUa,BDFAlive
	sts		BaseDeadFlag,TempUa	;Set BaseDeadFlag to ALIVE
NotBaseV:

; We have a line in the Base Rx buffer -- process it
	ldi		ParamReg,'F'
	rcall	SendTxChar
	ldi		ParamReg,'r'
	rcall	SendTxChar
	ldi		ParamReg,'B'
	rcall	SendTxChar
	ldi		ParamReg,':'
	rcall	SendTxChar
	ldi		ParamReg,' '
	rcall	SendTxChar
	ldi		TempUc,OutToTx
	mov		StringOutControl,TempUc
	ldiw	z,BaseRxBuf		;Point z to the buffer	
	rcall	SendSString		;z points to the CR/Null terminated string

; Clear the line by setting the count to zero
ClearBaseRxLine:
	clr		HaveBaseRxLine				;Clear the flag
	sts		BaseRxBufCnt,HaveBaseRxLine	; and zeroize the count
NoBaseRxLine:
	ret


;*****************************************************************************
;
;	SoftwareDelay
;
;	Expects:	R0 = Delay value
;
;	Delay is (R0 * 197,122) + 17 cycles
;
;	At 4MHz = R0 * 49.3 millisecs approximately
;
;	Max delay is R0=256 -> 12.6 seconds
;
;	Returns:	R0 = 0
;
;	Changes:	No other registers
;
;*****************************************************************************
;
;SoftwareDelay:					;4 for call for 16-bit PC (5 for 22-bit PC)
;	push	TempUa				;2
;	push	TempUb				;2

;	clr		TempUa				;1
;	clr		TempUb				;1

;SoftwareDelayLoop:
;	dec		TempUa				;1		(256 * 3) - 1 = 767
;	brnz	SoftwareDelayLoop	;2/1
;	dec		TempUb				;1		(256 * 770) - 1 = 197,119
;	brnz	SoftwareDelayLoop	;2/1
;	dec		r0					;1		(R0 * 197,122) - 1
;	brnz	SoftwareDelayLoop	;2/1

;	pop		TempUb				;2
;	pop		TempUa				;2
;	ret							;4 for 16-bit PC (5 for 22-bit PC)


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
;	SendDemoMessages
;
; These are hard-wired so they don't alter the internal speed/angle/distance variables, etc.
;
;*****************************************************************************
;
SendDemoMessages:
	ldi		TempUa,OutToBase
	mov		StringOutControl,TempUa
	LoadAndSendFString	Demo1
	ldi		TempUa,OutToTx
	mov		StringOutControl,TempUa
	LoadAndSendFString	Demo1
	ret

Demo1:	.DB	"BGff0001f4",CR,"BGffb401f4",CR,0	;Forward and back 500mm

;*****************************************************************************
;
; Must be at the end of the file
NextFlashAddress:	;Just to cause an error if the flash is overallocated
					; (NextFlashAddress should be address 1000H (FLASHEND+1) or lower)
