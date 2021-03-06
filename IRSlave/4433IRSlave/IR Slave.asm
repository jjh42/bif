;*****************************************************************************
;
;	IR Slave.asm	InfraRed Slave program for Robot
;
;	Written By:		Robert Hunt			August 2001
;
;	Modified By:	Robert Hunt
;	Mod. Number:	7
;	Mod. Date:		15 October 2001
;
;	Note: Can remove code for PD LED once tested and debugged
;
;	Baud rate for comms is 19,200 baud, 7-bits with even parity.
;	Messages only end with a CR if it is specified.
;
;	Accepts the following messages:
;		i			Poll for response (replies j if nothing to send)
;		IV			Poll for version number (replies IVdddd)
;		ILfr		Set LED functions to f (front) and r (rear) hex digits:
;						'0'	;Always off
;						'1'	;Always on
;						'2'	;Normal: Flashes on when receiving
;						'3'	;Inverse: Flashes off when receiving
;						'4'	;Slow flash
;						'5'	;Fast flash
;		IDx			Dump where x is:
;						'E': EEPROM
;						'F': Flash
;						'R': Registers
;						'S': SRAM
;		IZxaaaadd	Set where x is either 'E' or 'S' above)
;						to set hex address aaaa to hex value dd (incl. register addresses)
;		IH7524		Turn off power to the rest of the robot and enter power-down mode
;		IF1342		Turn off power to the entire robot including this
;
;	Sends the following replies:
;		j			Response to i poll if nothing to say
;		IFhh		Response to i poll if FRONT IR code received from remote
;		IRhh		Response to i poll if REAR IR code received from remote
;						hh represents button on remote (0..38)
;						FE represents error
;						FF represents repeat
;		IBhh		Response to i poll if battery level has changed and/or needs updating
;		IChh		Response to i poll if charging level has changed and/or needs updating
;		IEcchhhhCR	Response to i poll if have an error
;					where	cc (hex) represents the ASCII character
;								F	Framing Error
;								P	Parity Error
;								B	Rx Buffer Overflow Error
;								L	Rx Line Overflow Error
;								I	Invalid Message Error
;					and hhhh is the error count.
;		IVdddd		Response to IV (major/minor/revision/fix digits)
;		IDxaaaadd...ddCR	Response to IDx
;
; Notes:
;	Will send an unsolicited message if gets a fatal program error
;	Now that we have three LEDs, could display fatal errors on LEDs if necessary
;
;*****************************************************************************

; This program is written for an 4433 (28-pin) with a 4MHz crystal
;	on a custom made board

; This is version 2.0.0.2
.EQU	MajorVersion	= 2
.EQU	MinorVersion	= 0
.EQU	RevisionNumber	= 0
.EQU	FixNumber		= 2

;*****************************************************************************
;
;	Version History:
;
;	V2.0.0.2	9 Sept. 2000	Enable TXC interrupt and reenable analog inputs
;	V2.0.0.1	5 Sept. 2000	Various small bug fixes
;	V2.0.0.0	26 August 2001	First version for 4433 board with power control
;								Added handling of two analog inputs and extra messages
;								Removed Tx enable/disable code, added DE/RE control for RS-485 instead
;								Allowed front and rear LEDs to be controlled separately
;	V1.2.0.1	21 August 2001	Fixed bug in dump routines
;	V1.2.0.0	18 August 2001	Slowed down startup LED flashing slightly, removed EEPROM subroutines
;								Adjusted IR codes to be contiguous
;								Changed comms protocol
;								Increased baud rate from 2400 to 19,200
;								Added output for RS-485 control
;	V1.0.1.0	28 June 2001	Switched from 2343 (8-pin) to 2313 (20-pin) with hardware UART
;								Removed software UART code
;								Added separate LEDs for front and back plus running LED
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
.include	"C:\Program Files\AVRTOOLS\asmpack\appnotes\4433def.inc"
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
.EQU	TxBufferFullErrorCode			= 5
.EQU	EEPROMAllocationErrorCode		= 6
.EQU	InvalidSituationErrorCode		= 7


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
.EQU	TCClkDiv64		= 0b011			; 62.5KHz		16us	4.1ms	1.05s
.EQU	TCClkDiv256		= 0b100			; 15.625KHz		64us	16.4ms	4.19s
.EQU	TCClkDiv1024	= 0b101			; 3906.25KHz	256us	65.5ms	16.8s
.EQU	TCClkExtFall	= 0b110
.EQU	TCClkExtRise	= 0b111
;
;*****************************************************************************
;
; Timer/Counter-0 (8-bit) 10KHz
.EQU	SYSTKTCCR	= TCCR0
.EQU	SYSTKTC		= TCNT0
.EQU	SYSTKTCIE	= TOIE0
.EQU	SYSTKPS		= TCClkDiv8
.EQU	SYSTKTCReload = 206	;256 - 206 = 50
								;4000000 / 8 / 50 = 10,000 Hz = 100us

; Values for SysTickH
.EQU	SlowFlashTime	= 30	;30 * 25.6ms = 768ms
.EQU	FastFlashTime	= 10	;10 * 25.6ms = 256ms
.EQU	AnalogUpdateTime = 50	;50 * 25.6ms = 1.3s
;
;*****************************************************************************
;
; Timer/Counter-1 (16-bit)
;	Unused
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

.EQU	ADCPSDiv	= ADCPSDiv64	;Speed's not important to us here


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

.EQU	WDDelay	= WD128	;Use 120 msec (128 cycles) delay for main loop


;*****************************************************************************
;
;	Port/Pin Definitions
;
;*****************************************************************************
;
; Port-B:
;	Pin-14	PB0	(ICP)	Out	FrontLED
;	Pin-15	PB1	(OC1)	Out	Rear LED
;	Pin-16	PB2	(/SS)	Out	LED Indicates RUNNING (on) vs IDLE SLEEP (off)
;	Pin-17	PB3	(MOSI)	Out LED Indicates POWER DOWN (on) vs NORMAL (off) for debugging only
;	Pin-18	PB4	(MISO)	In	Unused (except for programming)
;	Pin-19	PB5	(SCK)	In	Unused (except for programming)
;
.EQU	PortBSetup	= 0b001111
.EQU	LEDPort		= PORTB
	.EQU	FrontLEDPin		= 0		;Set bits high to turn LEDs off
	.EQU	RearLEDPin		= 1
	.EQU	RunningLEDPin	= 2
	.EQU	PDLEDPin		= 3
;
; Note: The PD LED can be connnected to the programming LED by connnecting
;		the adjacent MOSI and LED pins on the programming header.
;
;*****************************************************************************
;
; Port-C:
;	Pin-23	PC0	(ADC0)	In	Battery level
;	Pin-24	PC1	(ADC1)	In	Charging level
;	Pin-25	PC2	(ADC2)	In	Current in use
;	Pin-26	PC3	(ADC3)	In	Unused
;	Pin-27	PC4	(ADC4)	In	Unused
;	Pin-28	PC5	(ADC5)	InP	Soft turn on switch (0 = on)
;
;	Note: 		InP = Input with Pull-up resistor enabled
;
.EQU	PortCSetup	 = 0b000000
.EQU	PortCPullups = 0b100000
	.EQU	BatteryLevelInput	= 0
	.EQU	ChargeLevelInput	= 1
;	.EQU	CurrentUseInput		= 2
;
;*****************************************************************************
;
; Port-D:
;	Pin-2	PD0	(RXD)	In	Serial Rx data from master
;	Pin-3	PD1	(TXD)	Out	(only when transmitting) serial Tx data to master 
;	Pin-4	PD2	(INT0)	In	Front IR sensor
;	Pin-5	PD3	(INT1)	In	Rear IR sensor
;	Pin-6	PD4	(T0)	Out	Rest of robot power control (1 = on)
;	Pin-11	PD5	(T1)	Out	Entire robot power control (1 = on)
;	Pin-12	PD6	(AIN0)	Out RS-485 DE (0=off, 1=Tx)
;	Pin-13	PD7	(AIN1)	Out	RS-485 /RE (0=Rx, 1=off)
;
.EQU	PortDSetup	= 0b11110000	;Four inputs (leave TXD as input) and four outputs
.EQU	IRInput		= PIND
	.EQU	IRFrontBit	= 2
	.EQU	IRRearBit	= 3
.EQU	PowerControlPort = PORTD
	.EQU	RestOfRobotPowerPin = 4
	.EQU	EntireRobotPowerPin = 5
.EQU	CommsControlPort = PORTD
	.EQU	CommsDEPin	= 6		;0=off, 1=Tx
	.EQU	CommsNREPin	= 7		;0=Rx, 1=off
;
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
;	R6		HaveComRxMsg flag: 0=nothing, 1=line received
;	R7		TempLa: Temp 8-bit register for main program
;	R8		TempLb
;	R9		TempLc
;	R10		TempLd
;	R11		ISRTempL
;	R12		SysTick TC Reload value
;	R13		Front LED function
;	R14		Rear LED function
;	R15		InStandbyMode
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

.DEF	HaveComRxMsg	= r6
.DEF	TempLa			= r7
.DEF	TempLb			= r8
.DEF	TempLc			= r9
.DEF	TempLd			= r10
.DEF	ISRTempL		= r11
.DEF	SYSTKTCReloadR	= r12
.DEF	FLEDFn			= r13
.DEF	RLEDFn			= r14
	.EQU	LEDOff		= '0'	;Always off
	.EQU	LEDOn		= '1'	;Always on
	.EQU	LEDNormal	= '2'	;Flashes on when receiving
	.EQU	LEDInverse	= '3'	;Flashes off when receiving
	.EQU	LEDSlowFlash = '4'	;Slow flash
	.EQU	LEDFastFlash = '5'	;Fast flash
.DEF	InStandbyMode	= r15
;
;
;*****************************************************************************
;
;	All of the following registers can be addressed by the LDI instruction:
;
;	R16		TempUa: Temp 8-bit register for main program
;	R17		TempUb: Temp 8-bit register for main program
;	R18		TempUc: Temp 8-bit register for main program
;	R19		Temp 8-bit register for interrupt service routines only ISRTempUa
;	R20		Temp 8-bit register for interrupt service routines only ISRTempUb
;	R21		AD Msg Rdy flag
;	R22		ParamReg: Parameter 8-bit register
;	R23		A/D control register
.DEF	TempUa			= r16
.DEF	TempUb			= r17
.DEF	TempUc			= r18
.DEF	ISRTempUa		= r19
.DEF	ISRTempUb		= r20
.DEF	ADMsgRdy		= r21	;0 = no messages ready
	.EQU	BLMsgRdy = 1
	.EQU	CLMsgRdy = 2
.DEF	ParamReg		= r22
.DEF	ADCReg			= r23
	.EQU	ADIdle			= 0
	.EQU	ADBLConversion	= 1
	.EQU	ADCLConversion	= 2
;	.EQU	ADCUConversion	= 3
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
.DEF	SysTickL	= r24	;Increments every 100 usec
.DEF	SysTickH	= r25	;Increments every 25.6 msec


;*****************************************************************************
;
;	SRAM Variable Definitions
;
; Total RAM = 128 bytes starting at 0060 through to 00DF
;
; Note: On the 4433 the high address of RAM is always 00
;			(so nothing ever crosses a 256-byte boundary
;			 and the high byte of pointer registers is ignored)
;
;*****************************************************************************

	.DSEG

; Serial port buffers
; Our maximum message size should only be 9 characters plus a trailing NULL
.EQU	ComRxBufSiz		= 15	;Note: Maximum of 128 characters
ComRxBuf:		.byte	ComRxBufSiz
ComRxBufCnt:	.byte	1	;Number of characters in the buffer

.EQU	ComTxBufSiz		= 54	;Note: Maximum of 128 characters
ComTxBuf:		.byte	ComTxBufSiz	;This is a circular buffer
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

; LED Control
FLEDTime:		.byte	1	;Stores SysTickH value
RLEDTime:		.byte	1	;Stores SysTickH value

; Miscellaneous variables
MemAddress:		.byte	2	;Storage for address for set memory comms message
ConvString:		.byte	12	;Storage for null-terminated conversion string
							; (Sign plus five digits plus null)
							;But also used for forming comms messages
							; (IVMMRF plus null)

; AI variables
LastBattLevel:	.byte	1
BLUpdateTime:	.byte	1	;Stores SysTickH value
LastChrgLevel:	.byte	1
CLUpdateTime:	.byte	1	;Stores SysTickH value
;LastCrntLevel:	.byte	1
;CUUpdateTime:	.byte	1	;Stores SysTickH value

; Error Counters (All initialized to zero when RAM is cleared at RESET)
FramingErrorCount:			.byte	1
ParityErrorCount:			.byte	1
RxBufferOverflowErrorCount:	.byte	1
ComLineOverflowErrorCount:	.byte	1
InvalidMessageErrorCount:	.byte	1
.EQU	FramingErrorCode			= 'F'	;46H
.EQU	ParityErrorCode				= 'P'	;50H
.EQU	RxBufferOverflowErrorCode	= 'B'	;42H
.EQU	ComLineOverflowErrorCode	= 'L'	;4CH
.EQU	InvalidMessageErrorCode		= 'I'	;49H

; This next variable is here for error checking
;  (If it is not equal to RandomByteValue, then the stack has overflowed)
StackCheck:		.byte	1	;For error checking only -- contents should never change
	.EQU	RandomByteValue	= 0x96
Stack:			.byte	18	;Make sure that at least this many bytes are reserved for the stack
							; so that we get an assembler warning if we're low on RAM
NextSRAMAddress:	;Just to cause an error if there's no room for the stack
					; (NextSRAMAddress should be address E0H (RAMEND+1) or lower)


;*****************************************************************************
;
;	EEPROM Variable Definitions
;
; Total EEPROM = 256 bytes starting at 0000 through to 00FF
;
;*****************************************************************************

	.ESEG

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

.MACRO	ldep	;LoaD EEPROM Pointer into a register pair
				; e.g. ldep		z,SomeBuffer
; On a processor with 256 or less bytes of EEPROM, only zl needs to be loaded
	ldi		@0l,low(@1)
;	ldi		@0h,high(@1)
.ENDMACRO

.MACRO	ldrp	;LoaD RAM Pointer into a register pair
				; e.g. ldrp		z,SomeBuffer
; On a processor with 256 or less bytes of RAM, only zl needs to be loaded
	ldi		@0l,low(@1)
;	ldi		@0h,high(@1)
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
;	This chip has 2K 16-bit words (4K bytes) of flash memory
;	going from word addresses 000 to 7FF
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
  	rjmp	ISR_INT
;	reti					;Front IR (just used to kick me out of power-down mode)
  .ORG 	INT1addr
  	rjmp	ISR_INT
;	reti					;Rear IR (just used to kick me out of power-down mode)
  .ORG 	ICP1addr
	rjmp	UnusedInterruptError
  .ORG 	OC1Aaddr
	rjmp	UnusedInterruptError
  .ORG 	OVF1addr
	rjmp	UnusedInterruptError
  .ORG 	OVF0addr
 	rjmp	ISR_ST			;System Timer
  .ORG 	URXCaddr
	rjmp	ISR_URXC		;RX Char
  .ORG 	UDREaddr
	rjmp	ISR_UDRE		;TX ready
  .ORG 	UTXCaddr
	rjmp	ISR_UTXC		;TX complete
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
	rcall	ProgramError	;Transmit the error code
	pop		ParamReg
	RestoreSRegReti			;Then re-enable interrupts and carry on with the program


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


;*****************************************************************************
;*****************************************************************************
;
;	Interrupt Service Routines
;
;*****************************************************************************
;*****************************************************************************

;*****************************************************************************
;
;	INT0 and INT1 Interrupt Service Routine (for debugging only)
;
; Toggles the running LED
;
;*****************************************************************************

ISR_INT:
	SaveSReg			;Save the status register

	; Toggle the running LED
	ldi		ISRTempUb,(1<<RunningLEDPin)
	in		ISRTempUa,LEDPort
	eor		ISRTempUa,ISRTempUb
	out		LEDPort,ISRTempUa

	RestoreSREGReti	;Restore SREG, return, and automatically reenable interrupts


;*****************************************************************************
;
;	System Timer Interrupt Service Routine
;
; Services a timer interrupt every 100 microseconds
;
;*****************************************************************************

ISR_ST:
	; Reload the counter
	out		SYSTKTC,SYSTKTCReloadR

	SaveSReg			;Save the status register

	; Increment SysTick 16-bit variable
	adiw	SysTick,1

	RestoreSREGReti	;Restore SREG, return, and automatically reenable interrupts


;*****************************************************************************
;
;	RX Character Received Interrupt Service Routine
;
;	Stores the character in the buffer and sets flag when message done
;
;*****************************************************************************

ISR_URXC:
	SaveSReg			;Save the status register

	; See if we already have a line needing processing
	tst		HaveComRxMsg
	brze	IURNoDouble		;No, we're ok
	
	; Yes, we have doubled up somehow
	lds		ISRTempUa,ComLineOverflowErrorCount
	inc		ISRTempUa				;Count the error
	sts		ComLineOverflowErrorCount,ISRTempUa
	rjmp	ISUResetAfterError
IURNoDouble:

	; See if the RX buffer is already full
	lds		ISRTempUb,ComRxBufCnt
	cpi		ISRTempUb,ComRxBufSiz-1	;Allow room for the trailing NULL
	brlo	IUROk					;Ok if lower
	
	; Have buffer overflow
	lds		ISRTempUa,RxBufferOverflowErrorCount
	inc		ISRTempUa
	sts		RxBufferOverflowErrorCount,ISRTempUa
	rjmp	ISUResetAfterError
IUROK:

	; Calculate where to store the character in the buffer
	;  (ISRTempUb still contains ComRxBufCnt)
	ldrp	x,ComRxBuf
	add		xl,ISRTempUb		;Note: Only works if buffer does not cross a 256-byte boundary

	; Increment the count and save it (so we can use ISRTempUa for something else)
	inc		ISRTempUb
	sts		ComRxBufCnt,ISRTempUb
	
	; Get the character
	in		ISRTempUa,UDR

	; Check the parity of the received byte
	push	TempUa				;Save registers used
	push	ParamReg
	mov		ParamReg,ISRTempUa	;Get the received byte
	rcall	GetEvenParity		;Gets the expected parity bit in T
	rol		ParamReg			;Get the received parity bit into C
	pop		ParamReg
	pop		TempUa

	; If C and T are the same, parity was correct
	brcc	ISUCC
	brts	ISUParDone		;Ok if both C and T are set
ISUParityError:
	lds		ISRTempUa,ParityErrorCount
	inc		ISRTempUa
	sts		ParityErrorCount,ISRTempUa
ISUResetAfterError:	
	clr		ISRTempUa				;Clear buffer count
	sts		ComRxBufCnt,ISRTempUa
	rjmp	IURExit
ISUCC:
	brts	ISUParityError	;Error if C clear but T is set
ISUParDone:
	andi	ISRTempUa,0x7F	;Reduce to 7-bits (Ignore parity now -- it was checked above)
	st		x+,ISRTempUa		;Save it in the buffer

; Once we get here, we have received the character, checked it,
;	put it in the buffer, and incremented ComRxBufCnt
; We only accept "i", "IV", "ILhh", "IPWROFF", "IDx" amd "IZxaaaadd" messages
; The interrupt routine only validates the first two characters and then the message length
;	The character is still in ISRTempUa
;	The incremented count is still in ISRTempUb
;	x still points to the next empty space in the buffer
	cpi		ISRTempUb,1		;Is this the first character?
	brne	ISUNotFirst		;No, branch

; This is the first character
	cpi		ISRTempUa,'i'	;Single character poll message?
	breq	ISUAcceptMsg	;Yes, have a valid single character poll message
	cpi		ISRTempUa,'I'	;Is it something else for me?
	breq	IURExit			;Yes, branch for now
	rjmp	ISUResetAfterError ;No, ignore all others

; This isn't the first character
ISUNotFirst:
	cpi		ISRTempUb,2		;Is this the second character?
	brne	ISUNotSecond	;No, branch

; This is the second character
	cpi		ISRTempUa,'V'	;Version request message ?
	breq	ISUAcceptMsg	;Yes, acccept it
	cpi		ISRTempUa,'L'	;LED control message ?
	breq	IURExit			;Yes, accept the character
	cpi		ISRTempUa,'S'	;Standby message ?
	breq	IURExit			;Yes, accept the character
	cpi		ISRTempUa,'P'	;Power control message ?
	breq	IURExit			;Yes, accept the character
	cpi		ISRTempUa,'D'	;Dump memory message ?
	breq	IURExit			;Yes, accept the character
	cpi		ISRTempUa,'Z'	;Set memory message ?
	breq	IURExit			;Yes, accept the character

; We have an invalid message
ISUInvalidMsg:
	lds		ISRTempUa,InvalidMessageErrorCount
	inc		ISRTempUa				;Count the error
	sts		InvalidMessageErrorCount,ISRTempUa
	rjmp	ISUResetAfterError

; This isn't the first or second character
ISUNotSecond:
	lds		ISRTempUa,ComRxBuf+1	;Get the second character in ISRTempUa
	cpi		ISRTempUb,3		;Is this the third character?
	brne	ISUNotThird		;No, branch

; This is the third character
; Don't check it here, but check for end of three character messages
	cpi		ISRTempUa,'D'	;Check second character for Dump memory message
	breq	ISUAcceptMsg	;Yes, accept the three character message
	rjmp	IURExit			;Otherwise, accept this character for now
		
; This isn't the first, second or third character
ISUNotThird:
	cpi		ISRTempUb,4		;Is this the fourth character?
	brne	ISUNotFourth		;No, branch

; This is the fourth character
; Don't check it here, but check for end of four character messages
	cpi		ISRTempUa,'L'	;Check second character for LED control message
	breq	ISUAcceptMsg	;Yes, accept the four character message
	rjmp	IURExit			;Otherwise, accept this character for now

; This isn't the first, second, third or fourth character
ISUNotFourth:
	cpi		ISRTempUb,7		;Is this the seventh character?
	brne	ISUNotSeventh	;No, branch

; This is the seventh character -- end of possible PIPWROFF message
	cpi		ISRTempUa,'P'	;Check second character for Power-off message
	breq	ISUAcceptMsg	;Yes, accept the seven character message
	cpi		ISRTempUa,'S'	;Check second character for Standby message
	breq	ISUAcceptMsg	;Yes, accept the seven character message
	rjmp	IURExit			;Otherwise, accept this character for now

; This isn't the first, second, third, fourth, or seventh character
ISUNotSeventh:
	cpi		ISRTempUb,9		;Is this the ninth character?
	brne	IURExit			;No, accept the character
							;Yes, it should be a IZxaaaadd

	; Append a trailing NULL and set the EOL flag
ISUAcceptMsg:
	clr		ISRTempUa		;Store the trailing NULL	
	st		x,ISRTempUa
	com		HaveComRxMsg	;Was zero -- now FF

IURExit:
	RestoreSREGReti	;Restore SREG, return, and automatically reenable interrupts


;*****************************************************************************
;
;	TX Buffer Empty (UART Data Register Empty) Interrupt Service Routine
;
;	Sends the next character if there is one, else disables itself and the transmitter
;
;*****************************************************************************

ISR_UDRE:
	SaveSReg			;Save the status register

	; See if the count is non-zero
	lds		ISRTempUa,ComTxBufCnt
	tst		ISRTempUa
	brnz	IUHaveSome
	
	; No characters in buffer -- disable this interrupt
	cbi		UCSRB,UDRIE	;Disable this interrupt now
	rjmp	IUExit
	
IUHaveSome:
	; Decrement the count and save it again
	dec		ISRTempUa
	sts		ComTxBufCnt,ISRTempUa
	
	; Get the next character and send it
	; Get the buffer address and add the offset to the first character
	ldrp	x,ComTxBuf
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
;	TX Complete Interrupt Service Routine
;
;	Turns off the RS-485 transmitter and turns the receiver back on
;
;*****************************************************************************

ISR_UTXC:
	SaveSReg			;Save the status register

	cbi		CommsControlPort,CommsDEPin		;Turn RS-485 Tx off (set low)
	cbi		CommsControlPort,CommsNREPin	;Turn RS-485 Rx on (set low)
	;cbi		UCSRB,TXEN	;Turn off Transmitter Enable

	RestoreSREGReti	;Restore SREG, return, and automatically reenable interrupts


;*****************************************************************************
;*****************************************************************************
;
;	Start of Program Proper
;
;*****************************************************************************
;*****************************************************************************

ResetCont:
	cli			;Disable interrupts

	; Disable watchdog
	ldi 	TempUa,(1<<WDTOE) | (1<<WDE)
	out 	WDTCR,TempUa			;Set WDTOE while WDE is on also
	ldi 	TempUa,(1<<WDTOE)
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
	
	; Disable the analog comparator
	ldi		TempUa,(1<<ACD)	;Set Analog Comparator Disable bit
	out		ACSR,TempUa


;*****************************************************************************
;
; Setup IO Ports
;
;*****************************************************************************

	ldi 	TempUa,PortBSetup
	out 	DDRB,TempUa
	ldi 	TempUa,PortCSetup
	out 	DDRC,TempUa
	ldi 	TempUa,PortCPullups
	out 	PORTC,TempUa
	ldi 	TempUa,PortDSetup
	out 	DDRD,TempUa

	ldi		TempUa,(1<<RestOfRobotPowerPin) | (1<<EntireRobotPowerPin)
	out		PowerControlPort,TempUa		;Turn on both power relays (also turns RS-485 Rx on and Tx off)

;	ldi		TempUa,(1<<RearLEDPin) | (1<<RunningLEDPin) | (1<<PDLEDPin)
	ldi		TempUa,(1<<RearLEDPin) | (1<<RunningLEDPin)
	out		LEDPort,TempUa			;Turn off the rear and running LEDs and PowerDown LED
									; (Leaves all other outputs low)

; Flash the LEDs to say that we are alive
	ldi		yl,25
LEDLoop:
	; Toggle both IR LED outputs
;	ldi		TempUb,(1<<FrontLEDPin) | (1<<RearLEDPin)
	ldi		TempUb,(1<<FrontLEDPin) | (1<<RearLEDPin) | (1<<RunningLEDPin) | (1<<PDLEDPin)
	in		TempUa,LEDPort
	eor		TempUa,TempUb
	out		LEDPort,TempUa

	;z should always be zero here
LEDDelay:
	sbiw	zl,1
	brnz	LEDDelay
	dec		yl
	brnz	LEDLoop
	
	ldi		TempUa,(1<<FrontLEDPin) | (1<<RearLEDPin) | (1<<RunningLEDPin) | (1<<PDLEDPin)
	out		LEDPort,TempUa			;Turn off all the LEDs


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


; Check the RAM is not over allocated (since the assembler doesn't seem to check it)
	ldiw	z,NextSRAMAddress
	ldi		TempUa,high(RAMEND+2)	;For comparison later (there's no cpic instruction)
	cpi		zl,low(RAMEND+2)
	cpc		zh,TempUa
	brlo	RAMAllocationOk
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

; Initialize other registers that need to be something other than zero
	ldi		zl,SYSTKTCReload
	mov		SYSTKTCReloadR,zl	; to load lower register with immediate value

	ldi		zl,LEDNormal
	mov		FLEDFn,zl
	mov		RLEDFn,zl


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
	ldi		TempUa,-AnalogUpdateTime/2	;Set BLUpdateTime
	sts		BLUpdateTime,TempUa			; so exactly out of sync with CLUpdateTime


;*****************************************************************************
;
;	Load variables from EEPROM
;
;*****************************************************************************

;	ldi		zl,EEReload
;	rcall	ReadEEPROMByte			;Get value into R0
;	mov		xxx,R0


;*****************************************************************************
;
;	Setup Timer/Counters
;
;*****************************************************************************

; Set System Timer/Counter which runs all the time
	ldi 	TempUa,SYSTKPS		; Set the clock PreScaler
	out		SYSTKTCCR,TempUa
	
	out		SYSTKTC,SYSTKTCReloadR



; Enable interrupts for the timer
	in  	TempUa,TIMSK		;Clear the interrupt mask (Set the bit)
	ori 	TempUa,(1<<SYSTKTCIE)
	out 	TIMSK,TempUa		;This stays cleared all the time
	
	
;*****************************************************************************
;
;	Setup the UART for 19,200 baud communications
;
;	UBRR = (CLK / 16 /Baud) - 1			4000000/16/19200 - 1 = 12
;
;	Baud = CLK / (16 * (UBRR + 1))		4000000/(16*(12+1)) = 19231
;
;	Error = Actual - Desired / Desired	(19231 - 19200) / 19200 = 1.2%
;
;*****************************************************************************

	ldi		TempUa,12			;19,200 baud with 4MHz crystal
	out		UBRR,TempUa			;

	; Enable the receiver and the Rx and Tx Complete Interrupts and the transmitter
	;ldi		TempUa,(1<<RXEN) | (1<<RXCIE)
	ldi		TempUa,(1<<RXEN) | (1<<RXCIE) | (1<<TXEN) | (1<<TXCIE)
	out		UCSRB,TempUa

;	sbi		UCSRB,TXCIE		;Enable the TX complete interrupt


;*****************************************************************************
;
;	Other interrupts
;
;*****************************************************************************

	; Initialise the MCU Control Register to falling edge detection on INT0 and INT1
	ldi	 	TempUa,0b00001010	;SE=0, SM=0, ISC1=10, ISC0=10
	out 	MCUCR,TempUa


;*****************************************************************************
;
;	Finished the setup routine
;
;*****************************************************************************

	; Enable the Watchdog now
	wdr									;Kick it first so resets to zero
	ldi 	TempUa,(1<<WDE) | WDDelay
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

;*****************************************************************************
;*****************************************************************************
;
;	Main Loop
;
;*****************************************************************************
;*****************************************************************************
;
MainLoop:	
	cbi		LEDPort,RunningLEDPin		;Turn running LED on (set bit low)

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

	tst		IRRearStatus
	brnz	CheckRear
	rcall	CheckFrontIR	;Only check front IR if rear is idle

	tst		IRFrontStatus
	brnz	DontCheckRear
CheckRear:
	rcall	CheckRearIR		;Only check rear IR if front is idle
DontCheckRear:

;*****************************************************************************

	rcall	CheckADC		;Do power level readings as required

;*****************************************************************************

	rcall	SetFLED		;See to front LED
	rcall	SetRLED		;See to rear LED

;*****************************************************************************

	rcall	CheckRx

;*****************************************************************************

; See if we need to enter power-down mode?
	tst		InStandbyMode
	brze	MainCont

; We should be in standby mode
	tst		IRFrontStatus
	brnz	MainCont		;Might be receiving -- wait a bit
	tst		IRRearStatus
	brnz	MainCont		;Might be receiving -- wait a bit

; Enter standby (power down) mode
; Disable watchdog
	ldi 	TempUa,(1<<WDTOE) | (1<<WDE)
	out 	WDTCR,TempUa			;Set WDTOE while WDE is on also
	ldi 	TempUa,(1<<WDTOE)
	out 	WDTCR,TempUa			;Leave WDTOE but clear WDE

; Enable POWER-DOWN sleep mode
	in		TempUa,MCUCR		;Read the other register bits
	andi	TempUa,0x0F			;Preserve lower four bits (Interrupt sense control bits)
	ori		TempUa,(1<<SE) | (1<<SM)	;Enable sleep mode POWER DOWN (SM = 1)
	out		MCUCR,TempUa

; Enable the two external interrupts -- these are what will wake us up again
	ldi 	TempUa,(1<<INT1) | (1<<INT0)
	out		GIFR,TempUa			;Clear any possible pending interrupts
	out 	GIMSK,TempUa		;Enable the two interrupts

; Go to POWER-DOWN sleep until something else happens
	sbi		LEDPort,RunningLEDPin	;Turn running LED off (set pin high)
	cbi		LEDPort,PDLEDPin		;Turn power down LED on (set pin low)
	sleep							;Until reset or external interrupt
	sbi		LEDPort,PDLEDPin		;Turn power down LED off (set pin high)
;cbi		LEDPort,RunningLEDPin	;Turn running LED on (set pin high) for debugging only

	ldi		yl,10
LEDLoop2:
	; Toggle all LEDs
	ldi		TempUb,(1<<FrontLEDPin) | (1<<RearLEDPin) | (1<<RunningLEDPin) | (1<<PDLEDPin)
	in		TempUa,LEDPort
	eor		TempUa,TempUb
	out		LEDPort,TempUa

	;z should always be zero here
LEDDelay2:
	wdr				;Kick watchdog and slow down flashing
	wdr
	wdr
	wdr
	wdr
	wdr
	sbiw	zl,1
	brnz	LEDDelay2
	dec		yl
	brnz	LEDLoop2
	
	ldi		TempUa,(1<<FrontLEDPin) | (1<<RearLEDPin) | (1<<RunningLEDPin) | (1<<PDLEDPin)
	out		LEDPort,TempUa			;Turn off all the LEDs

; We've woken up again after an interrupt (presumably caused by an IR signal)
; Disable the two external interrupts again (just to save wasted processor time)
	clr 	TempUa
	out 	GIMSK,TempUa

; Reenable the Watchdog
	wdr								;Kick it first so resets to zero
	ldi 	TempUa,(1<<WDE) | WDDelay
	out 	WDTCR,TempUa
	rjmp	MainLoop				;Will turn running LED back on

;*****************************************************************************

MainCont:
	wdr							;Kick the watchdog before we sleep

; Enable IDLE sleep mode so that we can sleep later
	in		TempUa,MCUCR		;Read the other register bits
	andi	TempUa,0x0F			;Preserve lower four bits (Interrupt sense control bits)
	ori		TempUa,(1<<SE)		;Enable sleep mode IDLE (SM = 0)
	out		MCUCR,TempUa

; Go to IDLE sleep until something else happens
	sbi		LEDPort,RunningLEDPin		;Turn running LED off (set pin high)
	sleep

; We've woken up again after an interrupt - restart after IDLE is immediate
	rjmp	MainLoop			;Will turn running LED back on


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
;	SendRegisterDump	Sends a register dump to the TX buffer
;						The interrupt routine then outputs the buffer automatically
;
; Uses:	z, TempUa, ParamReg
; plus SendTxChar uses y, TempUa, TempUb
; plus ConvertUByte uses TempLa, TempLb, TempLc, TempLd, TempUa, TempUb, TempUc, y
;
;*****************************************************************************
;
SendRegisterDump:
	ldiw	z,0		;Start at address 0000

SRDLoop1:
	; Display the next line of characters
	ldi		ParamReg,'I'
	rcall	SendTxChar		;Doesn't alter z
	ldi		ParamReg,'D'
	rcall	SendTxChar
	ldi		ParamReg,'R'
	rcall	SendTxChar

	pushw	z			;Save the RAM address for this line

	; Display the SRAM address in hex
	rcall	ConvertHWord	;Convert RAM address already in z and send it

	popw	z				;z contains the SRAM address

; Send the 16 hex values
	ldi		TempUa,16		;Bytes per line
SRDLoop2:
	pushw	z				;Save the register memory address for this byte
	push	TempUa			;Save the number of bytes still to go

	ld		zl,z			;Get the register value
	rcall	ConvertHByte	;Convert it to a string and send it

	pop		TempUa			;Restore the number of bytes still to go
	popw	z				;Registor the register memory address

	adiw	zl,1			;Increment register memory address pointer
	
	dec		TempUa			;Bytes left to print on this line
	brnz	SRDLoop2
	
	
; Send a CR at the end of every line
	rcall	SendCR			;Doesn't alter z
	wdr						;Kick the watchdog here too
	
; Stop after displaying all of the registers
	cpi		zl,0x60
	brne	SRDLoop1

; Finished all 96 bytes -- send a final line
	ldi		ParamReg,'I'
	rcall	SendTxChar
	ldi		ParamReg,'D'
	rcall	SendTxChar
	ldi		ParamReg,'R'
	rcall	SendTxChar
	rjmp	SendCR		; and return


;*****************************************************************************
;
;	SendSRAMDump	Sends a static RAM dump to the TX buffer
;					The interrupt routine then outputs the buffer automatically
;
; Uses:	z, TempUa, ParamReg
; plus SendTxChar uses y, TempUa, TempUb
; plus ConvertUByte uses TempLa, TempLb, TempLc, TempLd, TempUa, TempUb, TempUc, y
;
;*****************************************************************************
;
SendSRAMDump:
	ldi		zl,0x60		;Start at address 0060
	clr		zh

DSRLoop1:
	; Display the next line of characters
	ldi		ParamReg,'I'
	rcall	SendTxChar		;Doesn't alter z
	ldi		ParamReg,'D'
	rcall	SendTxChar
	ldi		ParamReg,'S'
	rcall	SendTxChar

	pushw	z			;Save the RAM address for this line

	; Display the SRAM address in hex
	rcall	ConvertHWord	;Convert RAM address already in z and send it

	popw	z				;z contains the SRAM address

; Send the 16 hex values
	ldi		TempUa,16		;Bytes per line
DSRLoop2:
	pushw	z				;Save the SRAM address for this byte

	push	TempUa
	ld		zl,z			;Get the SRAM value
	rcall	ConvertHByte	;Convert it to a string and send it
	pop		TempUa

	popw	z				;Get the SRAM address for this byte
	adiw	zl,1			;Increment SRAM pointer
	
	dec		TempUa			;Bytes left to print on this line
	brnz	DSRLoop2
	
; Send a CR at the end of every line
	rcall	SendCR			;Doesn't alter z
	wdr						;Kick the watchdog here too
	
; Stop after displaying all of the RAM
	cpi		zl,low(RAMEND+1)
	brne	DSRLoop1
	cpi		zh,high(RAMEND+1)
	brne	DSRLoop1

; Finished all 128 bytes -- send a final line
	ldi		ParamReg,'I'
	rcall	SendTxChar
	ldi		ParamReg,'D'
	rcall	SendTxChar
	ldi		ParamReg,'S'
	rcall	SendTxChar
	rjmp	SendCR		; and return


;*****************************************************************************
;
;	SendFlashDump	Sends a Flash dump to the TX buffer
;					The interrupt routine then outputs the buffer automatically
;
; Uses:	z, TempUa, ParamReg
; plus SendTxChar uses y, TempUa, TempUb
; plus ConvertUByte uses TempLa, TempLb, TempLc, TempLd, TempUa, TempUb, TempUc, y
;
;*****************************************************************************
;
SendFlashDump:
	ldiw	z,0		;Start at address 0000

SFDLoop1:
	; Display the next line of characters
	ldi		ParamReg,'I'
	rcall	SendTxChar		;Doesn't alter z
	ldi		ParamReg,'D'
	rcall	SendTxChar
	ldi		ParamReg,'F'
	rcall	SendTxChar

	pushw	z			;Save the RAM address for this line

	; Display the SRAM address in hex
	rcall	ConvertHWord	;Convert RAM address already in z and send it

	popw	z				;z contains the SRAM address

; Send the 16 hex values
	ldi		TempUa,16		;Bytes per line
SFDLoop2:
	pushw	z				;Save the flash address for this byte

	push	TempUa
	lpm						;Get the flash value
	mov		zl,R0			; into R0
	rcall	ConvertHByte	;Convert it to a string and send it
	pop		TempUa

	popw	z				;Get the SRAM address for this byte
	adiw	zl,1			;Increment SRAM pointer
	
	dec		TempUa			;Bytes left to print on this line
	brnz	SFDLoop2
	
; Send a CR at the end of every line
	rcall	SendCR			;Doesn't alter z
	wdr						;Kick the watchdog here too
	
; Stop after displaying all of the flash
	cpi		zl,low(FLASHEND+1)
	brne	SFDLoop1
	cpi		zh,high(FLASHEND+1)
	brne	SFDLoop1

; Finished all 4K bytes -- send a final line
	ldi		ParamReg,'I'
	rcall	SendTxChar
	ldi		ParamReg,'D'
	rcall	SendTxChar
	ldi		ParamReg,'F'
	rcall	SendTxChar
	rjmp	SendCR			; and return


;*****************************************************************************
;
;	SendEEPROMDump	Sends a static EEPROM dump to the TX buffer
;					The interrupt routine then outputs the buffer automatically
;
; Uses:	z, TempUc, ParamReg
; plus SendTxChar uses y, TempUa, TempUb
; plus ConvertUByte uses TempLa, TempLb, TempLc, TempLd, TempUa, TempUb, TempUc, y
;
;*****************************************************************************
;
SendEEPROMDump:
	; Make sure that we're not writing to the EEPROM
DEEWait:
	bris	EECR,EEWE,DEEWait	;Loop if a write operation is still in progress

	clrw	z		;Start at address 0000

DEELoop1:
	; Display the next line of characters
	ldi		ParamReg,'I'
	rcall	SendTxChar		;Doesn't alter z
	ldi		ParamReg,'D'
	rcall	SendTxChar
	ldi		ParamReg,'E'
	rcall	SendTxChar

	pushw	z			;Save the EEPROM address for this line

	; Display the EEPROM address in hex
	rcall	ConvertHWord	;Convert EEPROM address already in z and send it

	popw	z				;z contains the EEPROM address

; Display the 16 hex values
	ldi		TempUa,16		;Bytes per line
DEELoop2:
	pushw	z				;Save the EEPROM address for this byte

	push	TempUa
	
	; Read the byte from the EEPROM into zl
	out		EEAR,zl			;Output the 8-bit address
	sbi		EECR,EERE		;Do the read command (will halt CPU for 4 cycles)
	in		zl,EEDR			;Get the EEPROM value
	
	; Display the SRAM contents in hex
	rcall	ConvertHByte	;Convert it to a string and send it
	pop		TempUa

	popw	z				;Get the EEPROM address for this byte
	adiw	zl,1			;Increment EEPROM pointer
	
	dec		TempUa			;Bytes left to print on this line
	brnz	DEELoop2
	
; Send a CR at the end of every line
	rcall	SendCR			;Doesn't alter z
	wdr						;Kick the watchdog here too
	
; Stop after displaying all of the EEPROM
	cpi		zl,low(E2END+1)
	brne	DEELoop1
	cpi		zh,high(E2END+1)
	brne	DEELoop1

; Finished all 128 bytes -- send a final line
	ldi		ParamReg,'I'
	rcall	SendTxChar
	ldi		ParamReg,'D'
	rcall	SendTxChar
	ldi		ParamReg,'E'
	rcall	SendTxChar
	rjmp	SendCR			; and return


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

	out		EEAR,zl			;Output the 8-bit address

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

	out		EEAR,zl			;Output the 8-bit address

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
;ConvertUByte:
;	clr		zh
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
;ConvertUWord:
	;Point y to the start of the string storage area
;	ldrp	y,ConvString
;ConvertUWord1:	
;	clr		TempLa
;	clr		TempLb
;	clr		TempLc
;	clr		TempLd
	
	;Divide by 10,000 first
;	ldi		TempUa,low(10000)
;	ldi		TempUb,high(10000)
;	rcall	CWCount

	;Divide by 1,000 next
;	ldi		TempUa,low(1000)
;	ldi		TempUb,high(1000)
;	rcall	CWCount

	;Divide by 100 next
;	ldi		TempUa,100
;	clr		TempUb		;high(100) = 0
;	rcall	CWCount

	;Divide by 10 next
;	ldi		TempUa,10		;TempUb is still zero
;	rcall	CWCount
	
	; The residual should be 0-9, convert to ASCII
;	addi	zl,'0'		;Convert the last digit to ASCII
;	st		y+,zl		;Append to string
;ConvertFinish:
;	st		y,TempUb	;Append the final null
	
	; Point z to ConvString
;	ldrp	z,ConvString
;	rjmp	SendSString	;Send string and then return


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
;CWCount:
;	ldi		TempUc,'0'		;Initialize count to ASCII '0'
;CWCountLoop:
;	cp		zl,TempUa
;	cpc		zh,TempUb
;	cpc		TempLa,TempLc
;	cpc		TempLb,TempLd
;	brlo	CWDigit		;Yes, we are done
;	sub		zl,TempUa		;No, ok to subtract it then
;	sbc		zh,TempUb
;	sbc		TempLa,TempLc
;	sbc		TempLb,TempLd
;	inc		TempUc			;Increment the ASCII digit
;	brne	CWCountLoop	;Keep doing this until an underflow would occur
;CWDigit:
;	brts	CWPrintAll	;Must keep zeroes
;	cpi		TempUc,'0'
;	breq	CWSkipZero
;	set					;Have a non-zero digit so must keep all following zeroes
;CWPrintAll:
;	;Need to add the character in TempUc to the string
;	st		y+,TempUc
;CWSkipZero:
;	ret


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
	ldrp	y,ConvString	;Point y to the start of the string storage area
	mov		TempUa,zl
	rcall	StoreHexByte
	clr		TempUb
;	rjmp	ConvertFinish
ConvertFinish:
	st		y,TempUb	;Append the final null
	
	; Point z to ConvString
	ldrp	z,ConvString
	rjmp	SendSString	;Send string and then return


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
	ldrp	y,ConvString	;Point y to the start of the string storage area
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
	;clc				;C = 0 for no error
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
	ldrp	y,ConvString
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
;	ldrp	z,IRFrontBytes
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
	rjmp	AdjustThenSend


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
AdjustThenSend:
	cpi		TempUa,IRRepeatCode		;Don't decrement repeat code
	breq	StoreHexByteThenSend
	cpi		TempUa,IRErrorCode		;Don't decrement error code
	breq	StoreHexByteThenSend
	dec		TempUa					;But decrement all others (because previously incremented)

; Now convert high values so that IR codes are contiguous
; Convert 70->16, 77->32, 78->33, 79->34, 80->35, 81->36, 85->37, 86->38
	cpi		TempUa,32				;Anything less than 31 is ok (except 16 is missing)
	brlo	StoreHexByteThenSend
	subi	TempUa,54				;Convert 70->16 by subtracting 54
	cpi		TempUa,16
	breq	StoreHexByteThenSend
	addi	TempUa,9				;Convert 77->32 by subtracting 45 (54 - 9)
	cpi		TempUa,32
	breq	StoreHexByteThenSend
	cpi		TempUa,33				;78 was converted to 33
	breq	StoreHexByteThenSend
	cpi		TempUa,34				;79 was converted to 34
	breq	StoreHexByteThenSend
	cpi		TempUa,35				;80 was converted to 35
	breq	StoreHexByteThenSend
	cpi		TempUa,36				;81 was converted to 36
	breq	StoreHexByteThenSend
	subi	TempUa,3				;Convert 85->37 by subtracting 48 (54 - 9 + 3)
	cpi		TempUa,37
	breq	StoreHexByteThenSend
	cpi		TempUa,38				;86 was converted to 38
	breq	StoreHexByteThenSend
	
; If we get here, must have an error -- send 99 so it can be detected
	ldi		TempUa,99
	rjmp	StoreHexByteThenSend


;*****************************************************************************
;
;	SendBatteryLevelMessage		Sends a battery level message
;
;	Automatically resets message ready flag
;
;*****************************************************************************
;
SendBatteryLevelMessage:
	clr		ADMsgRdy
	ldi		ParamReg,'B'
	rcall	FormCommsHeader	;Returns with buffer address in y
	lds		TempUa,LastBattLevel
	rjmp	StoreHexByteThenSend	;Store two hex chars from TempUa and return


;*****************************************************************************
;
;	SendChargeLevelMessage		Sends a charge level message
;
;	Automatically resets message ready flag
;
;*****************************************************************************
;
SendChargeLevelMessage:
	clr		ADMsgRdy
	ldi		ParamReg,'C'
	rcall	FormCommsHeader	;Returns with buffer address in y
	lds		TempUa,LastChrgLevel
	rjmp	StoreHexByteThenSend	;Store two hex chars from TempUa and return


;*****************************************************************************
;
;	SendVersionMessage		Sends a version number message IVhhhh
;
;*****************************************************************************
;
SendVersionMessage:
	ldi		ParamReg,'V'
	rcall	FormCommsHeader	;Returns with buffer address in y
	ldi		TempUa,MajorVersion+'0'
	st		y+,TempUa
	ldi		TempUa,MinorVersion+'0'
	st		y+,TempUa
	ldi		TempUa,RevisionNumber+'0'
	st		y+,TempUa
	ldi		TempUa,FixNumber+'0'
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
;	Expects:	y points to place to put null in buffer
;				z points to beginning of buffer
;
;	Uses:		TempUa, TempUc, y, z
;
;*****************************************************************************
;
SendControlMessage:
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
	rcall	SendTxChar	;Send (buffer) the character in ParamReg
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
;	SendCR		Sends a CR to the Tx buffer
;				The interrupt routine then outputs the buffer automatically
;
; Uses:	y, TempUa
;
; Must not change ParamReg, z, TempUc
;
;*****************************************************************************
;
SendCR:
	ldi		ParamReg,CR
	;rjmp	SendTxChar

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
	; Set the parity bit
	rcall	GetEvenParity	;Gets the result in T
	bld		ParamReg,7		;Set the parity into bit-7

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

	; Enable the TX ready (UDRE) interrupt (in case it wasn't already enabled)
	;sbi		UCSRB,TXEN		;Enable the transmitter
	sbi		CommsControlPort,CommsNREPin	;Turn RS-485 Rx off so don't get echoes (set high)
	sbi		CommsControlPort,CommsDEPin		;Turn RS-485 Tx on (set high)
	sbi		UCSRB,UDRIE		;Enable the TX ready (UDRIE) interrupt
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
;	Disables interrupts and then transmits error code
;	Then re-enables interrupts and returns
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

	rcall	SendTxChar	;Send (buffer) the character in ParamReg
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
; SysTickL increments every 100usec so these are our timeouts
;
.EQU	IRHeaderPulseCount			= 80	;Must be at least 8.0 msec
.EQU	IRHeaderSpaceCount			= 40	;Must be at least 4.0 msec
.EQU	IRMinHeaderSpaceCount		= 19	;Must be at least 1.9 msec
.EQU	IRPulseCount				= 4		;Must be at least 400 usec
.EQU	IRSpaceCount				= 10	;0 < 1.0 msec, 1 > 1.0 msec
.EQU	IRRepeatHeaderSpaceCount	= 31	;Must be < 3.1 usec
.EQU	IRTimeoutCount				= 100	;10 msec
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
	brne	IRFHaveError		;Error if different
	
	; We have a valid keypress
	rcall	ExitStandby			;Make sure that we jump out of stand-by mode if we were in it
	tst		IRFrontByte			;See if something already buffered
	brnz	IRFOverflow			;Yes, branch
IRFAccept:
	inc		TempUa				;All ok, increment value (from third byte) so cannot be zero
								; (Will be decremented again later when transmitted)
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
	brne	IRRHaveError		;Error if different
	
	; We have a valid keypress
	rcall	ExitStandby			;Make sure that we jump out of stand-by mode if we were in it
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
;	SetFLED
;
;	Sets the front IR indicator LED according to LEDFn and the IR status
;
;	Called only from MainLoop so doesn't preserve any registers
;
;*****************************************************************************
;
SetFLED:
	mov		TempUc,FLEDFn	;Get copy in TempUc so can use cpi instruction

; Check for always off / always on
	cpi		TempUc,LEDOff
	breq	DoFLEDOff		;Always off
	cpi		TempUc,LEDOn
	breq	DoFLEDOn		;Always on

; Check for slow flash / fast flash
	ldi		TempUa,SlowFlashTime	;Preload for later
	cpi		TempUc,LEDSlowFlash
	breq	DoFLEDFlash
	ldi		TempUa,FastFlashTime	;Preload for later
	cpi		TempUc,LEDFastFlash
	breq	DoFLEDFlash

; Check for normal / inverse IR modes
	tst		IRFrontStatus
	brze	FrontIdle
	; Front must be in action
	cpi		TempUc,LEDInverse
	breq	DoFLEDOff
DoFLEDOn:
	cbi		LEDPort,FrontLEDPin	;Turn it on (low)
	ret

FrontIdle:
	cpi		TempUc,LEDInverse
	breq	DoFLEDOn
DoFLEDOff:
	sbi		LEDPort,FrontLEDPin	;Turn it off (high)
	ret

; Handle flashing
DoFLEDFlash:	;TempUa has been preloaded with the correct compare count
	mov		TempUb,SysTickH
	lds		TempLa,FLEDTime	;Get number of SysTick increments since last change
	sub		TempUb,TempLa
	cp		TempUb,TempUa	;Is it time yet?
	brlo	FLEDDone			;No change if still less
	sts		FLEDTime,SysTickH ;Remember change time
	; Invert the LED state
	ldi		TempUb,(1<<FrontLEDPin)
	in		TempUa,LEDPort
	eor		TempUa,TempUb
	out		LEDPort,TempUa
FLEDDone:
	ret



;*****************************************************************************
;
;	SetRLED
;
;	Sets the rear IR indicator LED according to LEDFn and the IR status
;
;	Called only from MainLoop so doesn't preserve any registers
;
;*****************************************************************************
;
SetRLED:
	mov		TempUc,RLEDFn	;Get copy in TempUc so can use cpi instruction

; Check for always off / always on
	cpi		TempUc,LEDOff
	breq	DoRLEDOff		;Always off
	cpi		TempUc,LEDOn
	breq	DoRLEDOn		;Always on

; Check for slow flash / fast flash
	ldi		TempUa,SlowFlashTime	;Preload for later
	cpi		TempUc,LEDSlowFlash
	breq	DoRLEDFlash
	ldi		TempUa,FastFlashTime	;Preload for later
	cpi		TempUc,LEDFastFlash
	breq	DoRLEDFlash

; Check for normal / inverse IR modes
	tst		IRRearStatus
	brze	RearIdle
	; Rear must be in action
	cpi		TempUc,LEDInverse
	breq	DoRLEDOff
DoRLEDOn:
	cbi		LEDPort,RearLEDPin	;Turn it on (low)
	ret

RearIdle:
	cpi		TempUc,LEDInverse
	breq	DoRLEDOn
DoRLEDOff:
	sbi		LEDPort,RearLEDPin	;Turn it off (high)
	ret

; Handle flashing
DoRLEDFlash:	;TempUa has been preloaded with the correct compare count
	mov		TempUb,SysTickH
	lds		TempLa,RLEDTime	;Get number of SysTick increments since last change
	sub		TempUb,TempLa
	cp		TempUb,TempUa	;Is it time yet?
	brlo	RLEDDone			;No change if still less
	sts		RLEDTime,SysTickH ;Remember change time
	; Invert the LED state
	ldi		TempUb,(1<<RearLEDPin)
	in		TempUa,LEDPort
	eor		TempUa,TempUb
	out		LEDPort,TempUa
RLEDDone:
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
; See if anything has been received for me from the controller
	tst		HaveComRxMsg
	brnz	HandleComRxMsg	;Yes, handle it
	ret

;*****************************************************************************

HandleComRxMsg:
; We have a message for us -- now which message is it (i, IL, IV, ID, or IZ)?
	ldrp	z,ComRxBuf		;Point z to the buffer	
	ld		TempUb,z+		;Get the first character
	cpi		TempUb,'i'		;Is it a poll message
	breq	HavePollMsg
	rjmp	NotPollMsg		;No, branch

;*****************************************************************************

; We have a poll message
HavePollMsg:
	ld		TempUb,z		;Get the next character
	tst		TempUb			;Error if it's not the final null
	brze	GoodPollMsg
	rjmp	RxInvalidMessage
GoodPollMsg:
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
	rjmp	ClearComRxMsg
ComQuTestRear:
	tst		IRRearByte
	brze	ComQuB
ComQuDoRear:	
	rcall	SendRearMessage
	clr		IRRearByte
	rjmp	ClearComRxMsg
ComQuB:
	cpi		ADMsgRdy,BLMsgRdy	;See if we have an A/D update message that needs sending
	brne	ComPollNotBL
	rcall	SendBatteryLevelMessage
	rjmp	ClearComRxMsg
ComPollNotBL:
	cpi		ADMsgRdy,CLMsgRdy
	brne	ComPollNotCL
	rcall	SendChargeLevelMessage
	rjmp	ClearComRxMsg
ComPollNotCL:
	; No IR or AD messages -- check for error messages
	clc						;Clear carry (error) flag
	CheckError	ComLineOverflow		;Check least likely first
	CheckError	RxBufferOverflow
	CheckError	InvalidMessage
	CheckError	Parity
	CheckError	Framing
	brcs	RespondedToPoll
; Nothing to send so send a idle response
	ldi		ParamReg,'j'
	rcall	SendTxChar
RespondedToPoll:
	rjmp	ClearComRxMsg

NotPollMsg:
	cpi		TempUb,'I'		;Not a poll so must be an I
	breq	HaveMessageForMe
RxInvalidMessageJmp1:
	rjmp	RxInvalidMessage

;*****************************************************************************

; We have a valid I... message
HaveMessageForMe:
	ld		TempUb,z+		;Get the second character
	cpi		TempUb,'V'		;Is it a version request message?
	brne	NotComV
	ld		TempUb,z		;Get the next character
	tst		TempUb			;Error if it's not the final null
	brnz	RxInvalidMessageJmp1
	rcall	SendVersionMessage
	rjmp	ClearComRxMsg
NotComV:

	cpi		TempUb,'D'		;Is it a dump request message?
	brne	NotComD
; It's a dump message	
	ld		TempUb,z+		;Get the third character
	ld		TempUc,z		;Get the fourth character
	tst		TempUc			;Error if it's not the final null
	brnz	RxInvalidMessageJmp1
	cpi		TempUb,'E'		;Is it a dump EEPROM message?
	brne	NotComDE
	rcall	SendEEPROMDump
	rjmp	ClearComRxMsg
NotComDE:
	cpi		TempUb,'F'		;Is it a dump Flash message?
	brne	NotComDF
	rcall	SendFlashDump
	rjmp	ClearComRxMsg
NotComDF:
	cpi		TempUb,'R'		;Is it a dump registers message?
	brne	NotComDR
	rcall	SendRegisterDump
	rjmp	ClearComRxMsg
NotComDR:
	cpi		TempUb,'S'		;Is it a dump SRAM message?
	brne	NotComDS
	rcall	SendSRAMDump
	rjmp	ClearComRxMsg
NotComDS:
	rjmp	RxInvalidMessage
NotComD:

	cpi		TempUb,'L'
	brne	NotComL
	ld		TempUb,z+		;Get the first hex digit (for front LED)
	ld		TempUc,z+		;Get the second hex digit (for rear LED)
	ld		ParamReg,z
	tst		ParamReg		;Error if it's not the final null
	brnz	RxInvalidMessageJmp1
	; Look for valid values
	cpi		TempUb,LEDOff
	breq	ValidFChar
	cpi		TempUb,LEDOn
	breq	ValidFChar
	cpi		TempUb,LEDNormal
	breq	ValidFChar
	cpi		TempUb,LEDInverse
	breq	ValidFChar
	cpi		TempUb,LEDSlowFlash
	breq	ValidFChar
	cpi		TempUb,LEDFastFlash
	breq	ValidFChar
	rjmp	RxInvalidMessage
ValidFChar:
	cpi		TempUc,LEDOff
	breq	ValidRChar
	cpi		TempUc,LEDOn
	breq	ValidRChar
	cpi		TempUc,LEDNormal
	breq	ValidRChar
	cpi		TempUc,LEDInverse
	breq	ValidRChar
	cpi		TempUc,LEDSlowFlash
	breq	ValidRChar
	cpi		TempUc,LEDFastFlash
	breq	ValidRChar
	rjmp	RxInvalidMessage
ValidRChar:
	; Complete message has now been validated
	mov		FLEDFn,TempUb		;Save the validated function bytes
	mov		RLEDFn,TempUc
	sts		FLEDTime,SysTickH	;Remember the time (so LED flashing starts properly)
	sts		RLEDTime,SysTickH
	rjmp	ClearComRxMsg		;We're done
NotComL:

	cpi		TempUb,'Z'		;Is it a memory set message?
	brne	NotComZ
; It's a memory set message	(IZxaaaadd)
	ld		TempUb,z+		;Save the third character (Should be E or S)
	ld		ParamReg,z+		;Get the fourth character (first a)
	rcall	ProcessFirstDigit
	brcs	RxInvalidMessageJmp2
	ld		ParamReg,z+		;Get the fifth character (second a)
	rcall	ProcessNextDigit
	brcs	RxInvalidMessageJmp2
	ld		ParamReg,z+		;Get the sixth character (third a)
	rcall	ProcessNextDigit
	brcs	RxInvalidMessageJmp2
	ld		ParamReg,z+		;Get the seventh character (fourth a)
	rcall	ProcessNextDigit
	brcs	RxInvalidMessageJmp2
	stsw	MemAddress,y	;Save the memory address
	ld		ParamReg,z+		;Get the eighth character (first d)
	rcall	ProcessFirstDigit
	brcs	RxInvalidMessage
	ld		ParamReg,z+		;Get the ninth character (first d)
	rcall	ProcessNextDigit
	brcs	RxInvalidMessage
	ld		ParamReg,z
	tst		ParamReg		;Error if it's not the final null
	brnz	RxInvalidMessage
; Get the address back
	ldsw	z,MemAddress
	tst		zh				;Note that zh must always be zero for this processor
	brnz	RxInvalidMessage
; Now the address is in z, the character is in TempUb, and the value is in yl
	cpi		TempUb,'E'
	brne	NotZE
	mov		ParamReg,yl
	rcall	WriteEEPROMByte
	rjmp	ClearComRxMsg
NotZE:
	cpi		TempUb,'S'
	brne	NotZS
	st		z,yl		;Write the value to the static ram address (or register)
	rjmp	ClearComRxMsg
NotZS:
RxInvalidMessageJmp2:
	rjmp	RxInvalidMessage
NotComZ:

	cpi		TempUb,'P'		;Is it a Power off message?
	brne	NotComP
; It's a power off message (PWROFF)
	ld		ParamReg,z+		;Get the next character
	cpi		ParamReg,'W'	;Check it
	brne	RxInvalidMessage
	ld		ParamReg,z+		;Get the next character
	cpi		ParamReg,'R'	;Check it
	brne	RxInvalidMessage
	ld		ParamReg,z+		;Get the next character
	cpi		ParamReg,'O'	;Check it
	brne	RxInvalidMessage
	ld		ParamReg,z+		;Get the next character
	cpi		ParamReg,'F'	;Check it
	brne	RxInvalidMessage
	ld		ParamReg,z+		;Get the next character
	cpi		ParamReg,'F'	;Check it
	brne	RxInvalidMessage
; It really was a valid one -- now do it -- turn off EVERYTHING
	cbi		PowerControlPort,EntireRobotPowerPin	;Turn off power to entire robot (set pin low)
	rjmp	ClearComRxMsg
NotComP:

	cpi		TempUb,'S'		;Is it a Standby message?
	brne	NotComS
; It's a power down message (STNDBY)
	ld		ParamReg,z+		;Get the next character
	cpi		ParamReg,'T'	;Check it
	brne	RxInvalidMessage
	ld		ParamReg,z+		;Get the next character
	cpi		ParamReg,'N'	;Check it
	brne	RxInvalidMessage
	ld		ParamReg,z+		;Get the next character
	cpi		ParamReg,'D'	;Check it
	brne	RxInvalidMessage
	ld		ParamReg,z+		;Get the next character
	cpi		ParamReg,'B'	;Check it
	brne	RxInvalidMessage
	ld		ParamReg,z+		;Get the next character
	cpi		ParamReg,'Y'	;Check it
	brne	RxInvalidMessage
; It really was a valid one
	; Turn things off first
	cbi		PowerControlPort,RestOfRobotPowerPin	;Turn off power to rest of robot (set pin low)
	sbi		CommsControlPort,CommsNREPin	;Turn RS-485 Rx off (set /RE high) to save power
 	; Now just set the flag and the main loop will look after it
	clr		InStandbyMode	;0
	inc		InStandbyMode	;1
	rjmp	ClearComRxMsg
NotComS:

;*****************************************************************************

RxInvalidMessage:
	; We got an invalid message
	lds		TempUa,InvalidMessageErrorCount
	inc		TempUa
	sts		InvalidMessageErrorCount,TempUa
	;rjmp	ClearComRxMsg

; Clear the line by setting the count to zero
ClearComRxMsg:
	clr		HaveComRxMsg				;Clear the flag
	sts		ComRxBufCnt,HaveComRxMsg	; and zeroize the count
CheckRxReturn:
	ret


;*****************************************************************************
;
;	CheckADC		Check A/D convertor status
;
;	Called from the main loop
;
;*****************************************************************************
;
CheckADC:
	cpi		ADCReg,ADIdle
	brne	CADCNotIdle

; We are idle -- see if it's time to do anything yet
	lds		TempUb,BLUpdateTime
	mov		TempUa,SysTickH
	sub		TempUa,TempUb
	cpi		TempUa,AnalogUpdateTime
	brlo	CADCBLUOk
	; We need to start a BL conversion
	ldi		TempUa,BatteryLevelInput
	out		ADMUX,TempUa
	ldi		TempUa,(1<<ADEN) | (1<<ADSC) | ADCPSDiv
	out		ADCSR,TempUa
	ldi		ADCReg,ADBLConversion
	ret
CADCBLUOk:
	lds		TempUb,CLUpdateTime
	mov		TempUa,SysTickH
	sub		TempUa,TempUb
	cpi		TempUa,AnalogUpdateTime
	brlo	CADCCLUOk
	; We need to start a CL conversion
	ldi		TempUa,ChargeLevelInput
	out		ADMUX,TempUa
	ldi		TempUa,(1<<ADEN) | (1<<ADSC) | ADCPSDiv
	out		ADCSR,TempUa
	ldi		ADCReg,ADCLConversion
	ret
CADCCLUOk:
	ret

CADCNotIdle:
	cpi		ADCReg,ADBLConversion
	brne	CADCNotBLConv

; Should be doing a battery level conversion -- see if finished yet?
	in		TempUa,ADCSR
	andi	TempUa,(1<<ADIF)
	brnz	CADCBLDone
	ret					;Not done yet -- return

; Finished the battery level conversion
CADCBLDone:
	; Read the 10-bit conversion result into z
	in		zl,ADCL		;Must read ADCL first
	in		zh,ADCH

	; Get only the eight MS bits into zl
	lsr		zh			;Get Bit-9 into carry
	ror		zl			;Get Bit-9 into MS bit and discard LS bit
	lsr		zh			;Get Bit-10 into carry
	ror		zl			;Get Bit-10 into MS bit and discard LS bit

	; Reset status to idle and remember this time
	ldi		ADCReg,ADIdle
	sts		BLUpdateTime,SysTickH

	; Now see if same as last value
	lds		TempUa,LastBattLevel
	cp		zl,TempUa
	breq	CADCBLReturn	;They're the same -- nothing more to do
	sts		LastBattLevel,zl	;Save the new level
	ldi		ADMsgRdy,BLMsgRdy	;Set flag so message gets sent on next poll
CADCBLReturn:
	ret

CADCNotBLConv:
	cpi		ADCReg,ADCLConversion
	brne	CADCNotCLConv

; Should be doing a charge level conversion -- see if finished yet?
	in		TempUa,ADCSR
	andi	TempUa,(1<<ADIF)
	brnz	CADCCLDone
	ret					;Not done yet -- return

; Finished the charge level conversion
CADCCLDone:
	; Read the 10-bit conversion result into z
	in		zl,ADCL		;Must read ADCL first
	in		zh,ADCH

	; Get only the eight MS bits into zl
	lsr		zh			;Get Bit-9 into carry
	ror		zl			;Get Bit-9 into MS bit and discard LS bit
	lsr		zh			;Get Bit-10 into carry
	ror		zl			;Get Bit-10 into MS bit and discard LS bit

	; Reset status to idle and remember this time
	ldi		ADCReg,ADIdle
	sts		CLUpdateTime,SysTickH

	; Now see if same as last value
	lds		TempUa,LastChrgLevel
	cp		zl,TempUa
	breq	CADCCLReturn	;They're the same -- nothing more to do
	sts		LastChrgLevel,zl	;Save the new level
	ldi		ADMsgRdy,CLMsgRdy	;Set flag so message gets sent on next poll
CADCCLReturn:
	ret

CADCNotCLConv:
	ldi		ParamReg,InvalidSituationErrorCode
	rjmp	NonFatalProgramError


;*****************************************************************************
;
;	ExitStandby		Jump out of standby mode (if we were in it)
;
;	Called when a valid IR keypress is decoded
;
;	Must not change TempUa
;
;*****************************************************************************
;
ExitStandby:
	; Turn things back on
	sbi		PowerControlPort,RestOfRobotPowerPin	;Turn on power to rest of robot (set pin high)
	cbi		CommsControlPort,CommsNREPin	;Turn RS-485 Rx on (set /RE low) so can receive polls when they start

 	; Now just clear the flag and we should just carry on as usual
	clr		InStandbyMode
	ret


;*****************************************************************************
;
;	ProgramError		For fatal programming errors
;							(Not for expected operational errors)
;						Transmits an error code
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

	push	ParamReg	;Save the error code
	LoadAndSendFString	PEString1
;	clt	why
	pop		zl			;Get the error code (from ParamReg) into zl
	rcall	ConvertHByte
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


PEString1:	.DB	CR,LF,"<<IR Slave Program Error ",0
PEString2:	.DB	">>",CR,LF,0


;*****************************************************************************
;
; Must be at the end of the file
NextFlashAddress:	;Just to cause an error if the flash is overallocated
					; (NextFlashAddress should be address 800H (FLASHEND+1) or lower)
