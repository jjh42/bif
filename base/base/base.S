;**************************************************************************
;
;	Base.S		Controls the base of the robot. That includes the motors, 
;			headlights and LEDs. Communicates with the master 
;			via a polled UART.
;**************************************************************************

; This program is written for an 8515 (40-pin digital) with a 4MHz crystal.
; It has a lot of extra ports because it uses a MM5451 which has 35 outputs.
; It takes two pins (Serial data and Clock).
;
.nolist
#include	<version.h>
#include	<8515def.h>
#include	<avrml/gend.h>
#include	<avrml/lib.h>
#include	<avrml/macros.h>
#include	<comms.h>
.list

; Version stuff
#define VERSION_STRING		"0.3.13"
#define VERSION			313

;**************************************************************************
;
;	Constants
;
;**************************************************************************

#define RX_IDLE         0
#define RX_RECEIVEMSG   1
#define RX_RECEIVEMSG2  2
#define RX_RECEIVEH     3
#define RX_RECEIVEL     4

; The two high bits of RLMMReg3 are used for indicators.
.equiv	MMClearBit	, 6
.equiv	MMRefreshBit	, 7
; The two lower bits are used for brake lights
.equiv	MMFrontRedBit	, 0
.equiv	MMBackRedBit	, 1
; 4 bit is the middle are used for status indicators
.equiv	MMBumperTiltBit	, 2
.equiv	MMGoBit		, 3
.equiv	MMStealthDiagnosticBit, 4
.equiv	MMPowerBit	, 5

; Battery Power
.equiv	BPOff		, 0
.equiv	BPLow		, 1
.equiv	BPNormal	, 2
.equiv	BPInvalid	, 3
; Lights
.equiv	LOff		, 0
.equiv	LNormal		, 1
.equiv	LFull		, 2
.equiv	LTest		, 3
.equiv	LInvalid	, 4
; Travel Mode
.equiv	TTurnAndStraight, 0
.equiv	TCircle		, 1
.equiv	TExtreme	, 2
.equiv	TInvalid	, 3

; Flag Register
; Bit 0	TxStatus	(set if sending the high nibble)
; Bit 1	Stealth		(set if in stealth mode)
; Bit 2 Debug Mode	(set if in debug mode)
; Bit 3 Bumper Status Changed (set if status has changed)
; Bit 4 Set when executing a go message
; Bit 5 Auto Stop	(set when enabled)
; Bit 6 Switch Mode	(set if can switch automatically)
; Bit 7 Direction	(set if reversing)
.equiv	TxStatusBit	, 0
.equiv	StealthBit	, 1
.equiv	DebugBit	, 2
.equiv	BumpersChangedBit,3
.equiv	GoBit		, 4
.equiv	AutoStopBit	, 5
.equiv	SwitchMode	, 6
.equiv	DirectionBit	, 7

.equiv	DefaultFlags	, ((1 << AutoStopBit) | (1 << SwitchMode) | (1 << TxStatusBit) | (1 << BumpersChangedBit))

; Go Flags Byte
; Bit 0 Finished Go	(Set when we empty our go buffer)
; Bit 1 Stopped because of bumpers (Set when the reason we stopped is
;			because our bumpers hit)
; Bit 2 We are halted at the moment.
; Bit 3
; Bit 4
; Bit 5
; Bit 6
; Bit 7
.equiv	FinishedGoBit	, 0
.equiv	StoppedBit	, 1
.equiv	HaltBit		, 2

.equiv	BlinkersOff	, 0
.equiv	BlinkersLeft	, 1
.equiv	BlinkersRight	, 2

.equiv	RxIdle		, 0
.equiv	RxIgnore	, 1
.equiv	RxRecieveMsg	, 2
.equiv	RxRecieveL	, 3
.equiv	RxRecieveH	, 4

; Lights Test Flags Byte
; Bit 0 Set when counting up
; Bit 1 Set when doing reverse light
; Bit 2
; Bit 3	Direction bit (set when turning lights off)
; Bit 4
; Bit 5
; Bit 6 Set to turn the lights off
; Bit 7	Set to show the test lights are going
.equiv	LTUp		, 0
.equiv	LTDirection	, 1
.equiv	LTGoing		, 7
.equiv	LTOff		, 6
.equiv TestMMDirectionBit	, 3
.equiv DefaultTestMM	, (1 << MMRefreshBit)
.equiv DefaultMMCountdownReload	, 36

; Used by the software headlight PWM
.equiv	HIntensityInvalid , 0x08

; The angle used for a reverse message
.equiv 	AngleReverse , 0xff

;**************************************************************************
;
;	/Constants
;
;**************************************************************************

;**************************************************************************
;
;	Global Parameters
;
;**************************************************************************
.equiv	CrystalFreq	, 4000000
#define CRYSTAL_FREQ	  4000000

; Stack size in bytes
#define STACK_SIZE	20

;**************************************************************************
; Coms
;**************************************************************************
.equiv	RxBufferSize	,	10	; Should be the size of the longest
;					; messages parameter (not including
;					; the message itself).
.equiv	TxBufferSize	,	10	; Should be the size of the longest
;					; message transmitted (not including
;					; the message itself).
.equiv	GoBufferSize	, 	20	; The maximum number of Go messages
					; that can be in the buffer at once
					; plus 1.
.equiv	TestCountReload ,	300	; Milliseconds for every change in
					; the lights test mode.
.equiv	StatusReload	,	500	; Millliseconds between flashing for
					; status lights.

#define MY_ID                   BASE_ID
#define MY_LID                  BASE_LID
;**************************************************************************
; /Coms
;**************************************************************************

;**************************************************************************
; 	Defaults
;**************************************************************************
.equiv	DefaultHIntensity,7		; A number between 0-7
.equiv	DefaultLights	, LOff
.equiv	DefaultBatPwr	, BPNormal
.equiv	DefaultTravelMode	, TTurnAndStraight
;**************************************************************************
; 	/Defaults
;**************************************************************************

.equiv	ReverseCountReload,	500	; The time in milliseconds between
					; each flash of the reverse lights.
					; (i.e. on for 500, off for 500).
;**************************************************************************
;
;	/Global Parameters
;
;**************************************************************************

;**************************************************************************
;
;	Timer/Counter Assignments
;
;**************************************************************************

; Timer 0 is used for the system tic every 1 millisecond.
.equiv	SysTicTCR	,	TCCR0
.equiv	SysTicCnt	,	TCNT0

.equiv	SysTicReload	,	0x83		; This should work out to give a timer approx.
;						; every 1/4 ms. Note: There is a ldi
;						; before the reload to Timer0 is outputed.
.equiv	SysTicDivide	,	Timer0CKD8
;**************************************************************************
; Timer 1 is used for the PWM and cant be used for anything else.
.equiv	MotorPWMTCRA	,	TCCR1A
.equiv	MotorPWMTCRB	,	TCCR1B

.equiv	MotorPWMCntL	,	TCNT1L
.equiv	MotorPWMCntH	,	TCNT1H

.equiv	MotorPWMLH	,	OCR1BH
.equiv	MotorPWMLL	,	OCR1BL
.equiv	MotorPWMRH	,	OCR1AH
.equiv	MotorPWMRL	,	OCR1AL
;**************************************************************************
; The initial value for the TIMSK register.
.equiv	DefaultTIMSK	,	((1 << TOIE0))
;**************************************************************************
;
;	/Timer/Counter Assignments
;
;**************************************************************************

;**************************************************************************
;
;	Port/Pin Definitions
;
;**************************************************************************
;
; Port-A:
;	PA0 (AD0)	InP	Tilt Switch 0
;	PA1 (AD1)	InP	Tilt Switch 1
;	PA2 (AD2)	InP	Tilt Switch 2
;	PA3 (AD3)	InP	Tilt Switch 3
;	PA4 (AD4)	InP	Motor Feedback Left Sin
;	PA5 (AD5)	InP	Motor Feedback Right Sin
;	PA6 (AD6)	Out	Right Motor Direction (0 is forward)
;	PA7 (AD7)	Out	Left Motor Direction (0 is forward)

; Generic
.equiv	DDForA		, 0b11000000
.equiv	InitialPORTA	, 0b00111111
; Tilt Switches
.equiv	TiltIn	, PINA
.equiv	TiltMsk	, 0b00001111
; Motor Direction
.equiv	MotorDirPort	, PORTA
.equiv	MotorDirR	, 6
.equiv	MotorDirL	, 7
;
;**************************************************************************
;
; Port-B:
;	PB0	(T0)	Idle pin (high when idle)
;	PB1	(T1)	
;	PB2	(AIN0)	
;	PB3	(AIN1)	
;	PB4	(/SS)	
;	PB5	(MOSI)	}
;	PB6	(MISO)	} These pins a reserved for ISP.
;	PB7	(SCK)	}

; Generic
.equiv	DDForB		, 0b00000001
.equiv	InitialPORTB	, 0b00000000
; Idle pin
.equiv	IdlePort	, PORTB
.equiv	IdlePin		, 0
;
;
;**************************************************************************
;
; Port-C:
;	PC0	(A8)	Out	MM5451 Clk Pin
;	PC1	(A9)	Out	MM5451 Data Pin
;	PC2	(A10)	InP	Bumper Front Left (0 is on)
;	PC3	(A11)	InP	Bumper Left Middle (0 is on)
;	PC4	(A12)	InP	Bumper Back Left (0 is on)
;	PC5	(A13)	InP	Bumper Back Right (0 is on)
;	PC6	(A14)	InP	Bumper Right Middle (0 is on)
;	PC7	(A15)	InP	Bumper Front Right (0 is on)
.equiv	DDForC		,	0b00000011
.equiv	InitialPORTC	,	0b11111100
; Bumper Switches
.equiv	BumperIn	,	PINC
.equiv	Bumper0		,	2
.equiv	Bumper1		,	3
.equiv	Bumper2		,	4
.equiv	Bumper3		,	5
.equiv	Bumper4		,	6
.equiv	Bumper5		,	7
; MM5451
.equiv	MMPort		,	PORTC
.equiv	MMClkPin	,	0
.equiv	MMDataPin	,	1
;
;**************************************************************************
;
; Port-D:
;	PD0	(RXD)	In	Comms from Master
;	PD1	(TXD)	Out	Comms to Master
;	PD2	(INT0)	InP	Motor Feedback Right Sin
;	PD3	(INT1)	InP	Motor Feedback Right Cos
;	PD4			NC	
;	PD5	(OC1A)	Out	PWM Motor L (1 is on)
;	PD6	(/WR)	Out	Front Headlight (1 is on)
;	PD7	(/RD)	Out	Back Headlight (1 is on)
.equiv	DDForD		, 0b11111010
.equiv	InitialPORTD	, 0b00000010
; Headlights
.equiv	HeadlightPort	, PORTD
.equiv	HeadlightF	, 6
.equiv	HeadlightB	, 7

; TEMP
.equiv  TxDirPort       , PORTD
.equiv  TxDirPin        , 4

;**************************************************************************
;
;	OC1B		Out	PWM Motor R		(1 is on)
;
;	Interupts
; 	INT0	Not used as an interupt
;	INT1	Not used as an interupt
;											; for interupt settings
;**************************************************************************
;
;	/Port/Pin Definitions
;
;**************************************************************************

;**************************************************************************
;
;	MM5451 Pins
;
;**************************************************************************
; The MM5451 has 35 pins. They must be clock in at below 500khz. These pins
; are connected to LEDs.
; 	Red	26/25/13  1/34/33
; 	White   11/12/24  35/2/3
;		 _______________
;	  	|     Front	|
;	  	|		|
;	  	|		|	
;	  	|		|
;	      23|		| 5
;	      14|Left	   Right| 32
;	      22|		| 4
;	  	|		|
;	  	|		|
;	  	|     Back	|
;	  	|_______________|
; 	White	15/16/18  6/29/30
; 	Red     21/20/19  31/8/7
;
;	Indicator lights
;	Pin	Colour	Use
;	28	Red	On for bumpers, Flashing for tilt switches
;	9	White	On for more commands in go buffer, Flashing for halt
;	27	Red	On for stealth, Flashing for diagnostics
;	10	Green	On for power normal, Flashing for power low

; For an explenation of the registers go to the register list (r5 is the
; first byte of the MM data).
.equiv	RLFWhiteReg	, 5 ;} The lights on the left are on the high side.
.equiv	RLBWhiteReg	, 6 ;} The lights are going out (ie 2 is the inmost)
.equiv	RLRunningReg	, 7 ; Left is on the high nibble. Lights go from from
; front to the back going out for the left and the opposite for the right.
.equiv	RLExtraReg	, 8 ; 2 higher bits are used for refresh and all-off. Tw
; lower bits are used for front and back brakes (front is bit 0).		

; Defaults
.equiv	MMDefault0	, 0b00000000	; Front W lights off
.equiv	MMDefault1	, 0000000000	; Rear W lights off
.equiv	MMDefault2	, 0b00000000	; Running lights off
.equiv	MMDefault3	, 0b00000000	; Rear R lights off.	
;**************************************************************************
;
;	/MM5451 Pins
;
;**************************************************************************

;**************************************************************************
;
;	Register Assignments
;
;**************************************************************************
;
;	R0
;	R1	Headlight Intensity
.equiv	RLHIntensity	,	1
;	R2	Count for the software PWM for the headlights.
.equiv	RLHIntensityCnt	,	2
;	R3	Temporary register RLT1
.equiv	RLT1	, 3
;	R4	Temporary register RLT2
.equiv	RLT2	, 4
;	R5	MM5451 Register 0
.equiv	RLMMReg0 	, 5
;	R6	MM5451 Register 1
.equiv	RLMMReg1	, 6
;	R7	MM5451 Register 2
.equiv	RLMMReg2	, 7
;	R8	MM5451 Register 3
.equiv	RLMMReg3	, 8
;	R9	Temporary register RLT3
.equiv	RLT3	, 9
;	R10	Last Bumper Switch State
.equiv	RLBumpersStatus	, 10
;	R11	Last Tilt Switch State
.equiv	RLTiltStatus	, 11
;	R12	Right Speed
.equiv	RLRightSpeed	,	12
;	R13	Left Speed
.equiv	RLLeftSpeed	,	13
;	R14	
;	R15	Interupt status register save
.equiv	RLStatusRegSave	, 15
;
;**************************************************************************
;
;	R16	Temporary register RHT1
.equiv	RHT1	,	16
;	R17	Temporary register RHT2
.equiv	RHT2	,	17
;	R18	Temporary register for ISRs
.equiv	RHIsr3	, 	18
;	R19	Temporary register for ISRs
.equiv	RHIsr2	,	19
;	R20	Blinker Status
.equiv	RHBlinkerStatus,20	
;	R21	Flags
.equiv	RHFlags	,	21
;	R22	Temporary register for ISRs
.equiv	RHIsr1	,	22
;	R23	Rx Status
.equiv	RHRxStatus ,	23
;**************************************************************************
;	R24 Time remaining before blinker change L
.equiv	RHLRunCntL	, 24
;	R25 Time remaining before blinker change H
.equiv	RHLRunCntH	, 25
;**************************************************************************
;	R26 XL	Time remaining before Left running right change - L
.equiv	RXRRunCntL	, 26
;	R27 XH 	Time remaining before Left running right change - H
.equiv	RXRRunCntH	, 27
;	R28 YL	Temporary register and pointer for ISRs
.equiv	RYIsrL		, 28
;	R29 YH	Temporary register and pointer for ISRs
.equiv	RYIsrH		, 29
;	R30 ZL	Temporary register and pointer for ISRs
.equiv	RZIsrL		, 30
;	R31 ZH	Temporary register and pointer for ISRs
.equiv	RZIsrH	, 31
;**************************************************************************
;
;	/Register Assignments
;
;**************************************************************************

;**************************************************************************
;
;	Errors
;
;**************************************************************************
.equiv	ComsParityErr		, 1
.equiv	ComsOverflowErr		, 2
.equiv	ComsInvalidMsgErr 	, 3
.equiv	ComsInvalidMsgLenErr 	, 4
.equiv	ComsBufferFullErr 	, 5
.equiv	ComsFramingErr		, 6
.equiv	ComsUnevenNibblesErr	, 7
.equiv	ComsInvalidDataErr	, 8
.equiv	TxFullErr		, 9
.equiv	EmptyRxBufErr		, 10
.equiv	NotImplementedErr	, 11
.equiv	ComsBufferInUse		, 12
.equiv	TxStatusInvalidErr	, 13
.equiv	InvalidMsgContentsErr	, 14
.equiv	NoMessageHeaderErr	, 15
.equiv	GoBufferFullErr		, 16
#define STACK_OVERFLOW_ERR	  28
#define COMMS_INVALIDSTATE_ERR    29
#define COMMS_INVALID_SECOND_MSG_ERR 30
.equiv  ComsOverrunErr          , 32

;*************************************************************************
;
;	/Errors
;
;**************************************************************************

;**************************************************************************
;
;	/Register Assignments
;
;**************************************************************************

;**************************************************************************
;
;	Variable Definitions
;
;**************************************************************************
; How this works is that at startup EEPROM is all copied into the RAM. So
; every SRAM variable has an EEPROM initialization as well.
	.data
	.org	0x000
RxMsg:		.byte	0 ; Contains messages we are recieving
RxMsg2:         .byte   0 ; Contains the second message parameter for a dump message
RxBuffer:	.space	RxBufferSize, 0xff ; Contains paramater to messages we
/* RxBufferLen is counted up while RxMsgLen is counted down. */
RxBufferLen:    .byte   0
RxMsgLen:	.byte	0 ; Length of message we are receiving

	.data
TxMsg:		.byte	0
TxBufferLen:	.byte	0 ; Contains the length of the Tx buffer
TxBuffer:	.space	TxBufferSize, 0xff ; Contains data to send.
			
	.data		
LastErr:	.byte	0
LastErrAddress:	.word	0

	.data
; These variables hold the two motor speeds.
LSpeed:		.byte	0
RSpeed:		.byte	0

	.data
; These variables are used when changing motor direction to ensure it isnt
; done right away.
LTimeToSwitch:	.byte	0
RTimeToSwitch:	.byte	0
; Time remaining before we should stop the motors (for a go message)
GoTimeRemaining: .word	0
GoTimeRemainingExtra:	.byte	0
; This is used for the blinker
BlinkersCnt:	.word   0
; Various Go Flags
GoFlags:	.byte	0
; Extra flags used when in Lights Test Mode
LTestFlags:	.byte	DefaultTestMM
LTestPauseOff:	.byte	0
; Headlight Intensity Count used when in Lights test mode.
LTHIntensity:	.byte	0
; Test MM Bytes
TestMM:		.space	5, 0xff
TestMMCount:	.word	TestCountReload
TestMMCountdown: .byte	0

	.data
; This is the battery power variable
BatPower:	.byte	DefaultBatPwr
Lights:		.byte	DefaultLights
TravelMode:	.byte	DefaultTravelMode

	.data
; These keep track of whats down. To send back to the master.
DownBumpers:	.byte	0b11111100
DownTilts:	.byte	TiltMsk

	.data
; These variables are used to load the counts again for the lights once they
; get to zero. If they counts are not running they are not valid.
LRunningReload:	.word	0
RRunningReload:	.word	0
BlinkersReload:	.word	0
ReverseCnt:	.word	0

	.data	; Variables used for the status lights
StatusCount:	.word   0

; Calibration Variables
	.data
; These two variables are used to calibrate the motors. Right motor speed
; is multiplied by 1 and divide by the other to calibrate it. Left motor speed
; is left alone.
RRatioMul:	.byte	1
RRatioDiv:	.byte	1
; This is the minimum speed
MinSpeed:	.byte	1
SpeedTimeFactor: .word  1000	; Time to travel (Distance * STF / Speed)

; Go Buffer		
	.data
GoBufferCount:	.byte	0
GoBufferO1:	.byte	0
	.org	0x100 - RAMStart, 0xff
; The buffer must not cross a boundary.
; Each buffer entry looks like this:
;	Byte	1	Speed
;	Byte	2	Angle (stored as 0-180)
;	Byte	3	Flags
;			Bit # 0 - Angle direction (set when going left)
.equiv	GoFlagDirectionBit	, 0
;	Byte	4-5	Distance
.equiv	GoBufferItemSize	, 5
GoBuffer:	.space	(GoBufferSize * GoBufferItemSize), 0xff

        .data
        .org    RAMEND - STACK_SIZE - 1 - RAMStart
#define STACK_CHECK 0xcb
StackCheck:	.byte     STACK_CHECK
Stack:	        .space    STACK_SIZE, 0xff

;**************************************************************************
;
;	/Variable Definitions
;
;**************************************************************************

;**************************************************************************
;
;	Macros
;
;**************************************************************************

;**************************************************************************
;	Macro SetCommsTx ClearCommsTx
; 	Expects:
;	Uses:
;	Words:	?
;	Cycles: ?
;
;	Sets Tx up for transmission or disables transmission.
;**************************************************************************
.macro	SetCommsTx
        sbi     TxDirPort, TxDirPin
.endm

.macro ClearCommsTx
        cbi     TxDirPort, TxDirPin
.endm
;**************************************************************************
;	/Set/Clear CommsTx
;**************************************************************************

;**************************************************************************
;	Macro RefreshMM
; 	Expects:
;	Uses: T-flag
;	Words:	2
;	Cycles: 2
;
;	Sets the bit so that the MM5451 refreshes.
;**************************************************************************
.macro	RefreshMM
	set			; Simple just set the MSB in RLMMReg4
	bld	RLMMReg3, MMRefreshBit	
.endm
;**************************************************************************
;	/RefreshMM
;**************************************************************************

;**************************************************************************
;	Macro ClearMM
; 	Expects:
;	Uses: RHIsr1
;	Words:	2
;	Cycles: 2
;
;	Sets the bit so that the MM5451 clears (turns all lights off).
;**************************************************************************
.macro	ClearMM
	ldi	RHIsr1, ((1 << MMClearBit) | (1 << MMRefreshBit))
	or	RLMMReg3, RHIsr1
.endm
;**************************************************************************
;	/ClearMM
;**************************************************************************

;**************************************************************************
;	Macro UnClearMM
; 	Expects:
;	Uses: T-flag
;	Words:	4
;	Cycles: 4
;
;	Clears the bit so that the MM5451 refreshes using the normal data.
;**************************************************************************
.macro	UnClearMM
	clt			
	bld	RLMMReg3, MMClearBit
	set
	bld	RLMMReg3, MMRefreshBit	; Set bit 7 so it refreshes.
.endm
;**************************************************************************
;	/UnClearMM
;**************************************************************************

;**************************************************************************
;	Macro SendBit
; 	Expects: @0 Register, @1 - Bit Number
;	Uses: T
;	Words:	?
;	Cycles: ?
;
;	Sends 1 bit to the MM5451.
;**************************************************************************
.macro	SendBit a0, a1
	bst	\a0,\a1
	rcall	MMClockInT
.endm
;**************************************************************************
;	/SendBit
;**************************************************************************

;**************************************************************************
;	Macro Error
; 	Expects: @0 - The error number
;	Uses: RHIsr1, RZIsrL, RZIsrH
;	Words:	?
;	Cycles: ?
;
;	Registers an error and returns.
;**************************************************************************
.macro	Error   errnum
	ldi	RHIsr1, \errnum
	rcall	ErrorHandler
.endm
;**************************************************************************
;	/Error
;**************************************************************************

;**************************************************************************
;	Macro ComsError
; 	Expects:
;	Uses: RHIsr1, RZIsrL, RZIsrH
;	Words:	?
;	Cycles: ?
;
;	Registers an error and empties the coms buffer.
;**************************************************************************
.macro	ComsError  errnum
	ldi	RHIsr1, \errnum
	rcall	ComsErrorHandler
.endm
;**************************************************************************
;	/ComsError
;**************************************************************************

;**************************************************************************
;	Macro NotImplemented
; 	Expects:
;	Uses: RHIsr1, RZIsrL, RZIsrH
;	Words:	?
;	Cycles: ?
;
;	Registers a NotImplemented error. Use the macro so that it can
; 	be searched for.
;**************************************************************************
.macro	NotImplemented
	ldi	RHIsr1, NotImplementedErr
	rcall	ErrorHandler
.endm
;**************************************************************************
;	/NotImplemented
;**************************************************************************

;**************************************************************************
;
;	/Macros
;
;**************************************************************************
				
;**************************************************************************
;
;	Interrupt Vector Table
;
;**************************************************************************
	.text

.ORG 	0x000
	rjmp	Reset
.ORG	INT0addr	;External Interrupt0 Vector Address
	reti
.ORG	INT1addr	;External Interrupt1 Vector Address
	reti
.ORG	ICP1addr	;Input Capture1 Interrupt Vector Address
	reti
.ORG	OC1Aaddr	;Output Compare1A Interrupt Vector Address
	reti
.ORG	OC1Baddr	;Output Compare1B Interrupt Vector Address
	reti
.ORG	OVF1addr	;Overflow1 Interrupt Vector Address
	reti
.ORG	OVF0addr	;Overflow0 Interrupt Vector Address
	rjmp	ISRSystemTic
.ORG	SPIaddr 	;SPI Interrupt Vector Address
	reti
.ORG	URXCaddr	;UART Receive Complete Interrupt Vector Address
	rjmp	ISRUARTRecieveComplete
.ORG	UDREaddr	;UART Data Register Empty Interrupt Vector Address
	rjmp	ISRUARTDataRegisterEmpty
.ORG	UTXCaddr	;UART Transmit Complete Interrupt Vector Address
	;rjmp    ISRUARTTXComplete
        /* WARNING SPEED HACK HERE */
        /* This is the Tx complete ISR here it is 1 line */
        ClearCommsTx
        /* END OF ISR - will continue down to reti in next vector */
.ORG	ACIaddr 	;Analog Comparator Interrupt Vector Address
	reti
;**************************************************************************
;
;	/Interrupt Vector Table
;
;**************************************************************************

;**************************************************************************
;**************************************************************************
;
;	Start of Program Proper
;
;**************************************************************************
;**************************************************************************
Reset:
	cli	
;**************************************************************************
;	Setup the watchdog
;**************************************************************************	
	wdr
	;ldi	RHT1, (1 << WDE)	; A prescale 
	; TEMP				; with a timeout of 30-60ms (000)
	;out	WDTCR, RHT1
;**************************************************************************
;	/Setup the watchdog
;**************************************************************************	

;**************************************************************************
;	Setup Stack
;**************************************************************************	
	; Setup the stack
	ldi	RHT1, lo8(RAMEND)
	out	SPL, RHT1
	ldi	RHT1, hi8(RAMEND)
	out	SPH, RHT1
;**************************************************************************
;	/Setup Stack
;**************************************************************************

;**************************************************************************
;	Setup Ports
;**************************************************************************
	; Now setup the ports to be the right direction and pullups etc.
	; PORTA
	ldi	RHT1, DDForA
	out	DDRA, RHT1
	ldi	RHT1, InitialPORTA
	out	PORTA, RHT1
	; PORTB
	ldi	RHT1, DDForB
	out	DDRB, RHT1
	ldi	RHT1, InitialPORTB
	out	PORTB, RHT1
	; PORTC
	ldi	RHT1, DDForC
	out	DDRC, RHT1
	ldi	RHT1, InitialPORTC
	out	PORTC, RHT1
	; PORTD
	ldi	RHT1, DDForD
	out	DDRD, RHT1
	ldi	RHT1, InitialPORTD
	out	PORTD, RHT1
;**************************************************************************
;	/Setup Ports
;**************************************************************************

;**************************************************************************
;	Initialize SRAM variables
;**************************************************************************
	; Copy all the EEPROM into SRAM (this is how we intialize).
	ldiw	RZIsr, RAMStart	;The 512 bytes RAM go from 0060 to 025F
	clrw	RYIsr 		; Load the EEPROM address in Y
InitRamLoop:
	; Get the data out of EEPROM
	outw	EEAR, RYIsr
	sbi	EECR, EERE
	in	RHT1, EEDR
	st	Z+,RHT1
	adiw	RYIsrL, 1
	cpi	RYIsrL,lo8(E2END+1)
	brne	InitRamLoop
	cpi	RYIsrH,hi8(E2END+1)
	brne	InitRamLoop
;**************************************************************************
;	/Initialize SRAM variables
;**************************************************************************

;**************************************************************************
;	Initialize register variables
;**************************************************************************
; Zeroize all of the registers
	clr	RHT1
	clrw	RZIsr	;Start at address 0000
ZRLoop:
	st	Z+,RHT1	;Zeroize the register
	cpi	RZIsrL,30	;Stop after clearing the first 30 of 32 registers
	brne	ZRLoop
	
; Initialize other registers that need to be something other than zero
	; Bumper Status
	; Initializing these to 0 will make the Timer code read in the 
	; switches right away. This causes the MM chip to have its data
	; clocked in twice. Doing these seems to fix a glitch in the chip
	; that it has a problem when clocking in the first bit.
	ldi	RHIsr1, 0x00
	mov	RLBumpersStatus, RHIsr1
	; Tilt Status
	ldi	RHIsr1, 0x00
	mov	RLTiltStatus, RHIsr1
	
	; Rx variables
	ldi	RHRxStatus, RxIdle
	; Tx Variables
	ldi	RHFlags, DefaultFlags
	; Initialize operating variables
	ldi	RHT1, DefaultHIntensity	; Headlight intensity
	mov	RLHIntensity, RHT1
	ldi	RHBlinkerStatus, BlinkersOff
	
	; Setup the MM5451 to initial values
	ldi	RHT1, MMDefault0
	mov	RLMMReg0, RHT1
	ldi	RHT1, MMDefault1
	mov	RLMMReg1, RHT1
	ldi	RHT1, MMDefault2
	mov	RLMMReg2, RHT1
	ldi	RHT1, (MMDefault3 | (1 << MMClearBit) | (1 << MMRefreshBit))
	mov	RLMMReg3, RHT1
	; set high so it will be clocked in along with clear because lights are off
	; initially.
;**************************************************************************
;	/Initialize register variables
;**************************************************************************

;**************************************************************************
;	Setup Timers
;**************************************************************************
	; Setup the timers
	; SysTic Timer
	ldi	RHT1, SysTicReload	; Reset the count first
	out	SysTicCnt, RHT1
	ldi	RHT1, SysTicDivide	; Output the divide and now it should start counting.
	out	SysTicTCR, RHT1
	
	; Setup Timer1 as a dual PWM
	clr	RHT1
	out	MotorPWMRH, RHT1	; Clear Right motor PWM (initially stopped)
	out	MotorPWMRL, RHT1
	out	MotorPWMLH, RHT1	; Clear Left motor  PWM (initially stopped)
	out	MotorPWMLL, RHT1
	; Now setup the Timer as an 8-bit PWM
	ldi	RHT1, ((1 << PWM10) | (1 << COM1A1) | (1 << COM1B1)) ; A non-inverting PWM
	out	MotorPWMTCRA, RHT1
	ldi	RHT1, (1 << CS10)	; CK (highest frequency PWM)
	out	MotorPWMTCRB, RHT1
	
	; Enable the appriate interupts
	ldi	RHT1, DefaultTIMSK
	out	TIMSK, RHT1
;**************************************************************************
;	/Setup Timers
;**************************************************************************

;**************************************************************************
;	Setup UART
;**************************************************************************
	; Load the correct baud rate
	ldi	RHT1, BAUDRATE(COMS_BAUD)
	out	UBRR, RHT1
	; Setup the control register (Tx operations are only enables when we are
	;	polled by the master).
	ldi	RHT1, ((1 << RXCIE) | (1 << RXEN) | (1 << TXCIE) | (1 << TXEN))
	out	UCR, RHT1
        ; TEMP
	ldi	RHT1, 'T'
	out	UDR, RHT1
;**************************************************************************
;	/Setup UART
;**************************************************************************

;**************************************************************************
;	Disable Analogue Comparator (to save power)
	sbi	ACSR, ACD
;**************************************************************************

;**************************************************************************
;	Enable Sleep Mode
	ldi	RHT1, (1 << SE) ; No interupts are enabled
	out	MCUCR, RHT1
;**************************************************************************
	sei	
;**************************************************************************
;
;	Main Loop
;
;**************************************************************************
	
R_Loop:
	wdr

	; Check the stack
	lds	RHT1, StackCheck
	cpi	RHT1, STACK_CHECK
	breq	R_Okay
	Error	STACK_OVERFLOW_ERR
        ; Restore stack check
        ldi     RHT1, STACK_CHECK
        sts     StackCheck, RHT1
R_Okay:
	
	; Check if the we need to clock in the 5451 data.
	bst	RLMMReg3, MMRefreshBit; Bit 7 is set when we need to clock it in again
	lbrtc	R_Sleep
	; Clock in the start bit
	set
	rcall	MMClockInT	; Clock it the start bit
	
	clt
	bld	RLMMReg3, MMRefreshBit

	lds	RHT1, Lights
	cpi	RHT1, LTest
	lbrne	R_Normal
	
	; If we are in test mode we clock in the data in memory instead
	
	; If we are in diagnostics mode we just turn them all on
	brrs	RHFlags, DebugBit, R_Debug
	; We have to clock in the data that is in memory
	; Now we need to clock in the data
	; This is the way lights test mode works:
	; 5 bytes (TestMM) are used to store 36 bits which keep moving along and turning
	; on and off. 12 lights at the front 12 at the back and the 6 on the side count
	; double and are ORed together.
	; The status lights continue as normal.
	; The bits start with the back-left running light and go around the white lights
	; and then the red.
	lds	RHT1, TestMM
	lds	RHT2, TestMM + 1
	lds	RLT1, TestMM + 2
	lds	RLT2, TestMM + 3
	lds	RLT3, TestMM + 4
	; A bitmap (Byte:Bit)
; 	Red	2:5,2:6,2:7 3:0,3:1,3:2
; 	White   0:3,0:4,0:5 0:6,0:7,1:0
;		 _______________
;	  	|     Front	|
;	  	|		|
;	  	|		|	
;	  	|		|
; 2:4     0:2   |		| 1:1 3:3
; 2:3     0:1   |Left	   Right| 1:2 3:4
; 2:2     0:0   |		| 1:3 3:5
;	  	|		|
;	  	|		|
;	  	|     Back	|
;	  	|_______________|
; 	White	2:1,2:0,1:7  1:6,1:5,1:4
; 	Red     4:3,4:2,4:1, 4:0,3:7,3:6

	; First or the two sets of running lights together
	; Left set
	push	RHT1
	lsl	RHT1
	lsl	RHT1
	andi	RHT1, 0b00011100
	or	RLT1, RHT1
	pop	RHT1
	; Right set
	push	RHT2
	lsl	RHT2
	lsl	RHT2
	andi	RHT2, 0b00111000
	or	RLT2, RHT2
	pop	RHT2

; 	Red	2:5,2:6,2:7 3:0,3:1,3:2
; 	White   0:3,0:4,0:5 0:6,0:7,1:0
;		 _______________
;	  	|     Front	|
;	  	|		|
;	  	|		|	
;	  	|		|
; 2:4     0:2   |		| 1:1 3:3
; 2:3     0:1   |Left	   Right| 1:2 3:4
; 2:2     0:0   |		| 1:3 3:5
;	  	|		|
;	  	|		|
;	  	|     Back	|
;	  	|_______________|
; 	White	2:1,2:0,1:7  1:6,1:5,1:4
; 	Red     4:3,4:2,4:1, 4:0,3:7,3:6

	; Okay now start clock it in
	SendBit	RLT2, 0				; Pin 1
	SendBit	RHT1, 7				; Pin 2
	SendBit	RHT2, 0				; Pin 3
	SendBit RLT2, 5				; Pin 4
	SendBit RLT2, 3				; Pin 5
	SendBit RHT2, 6				; Pin 6
	SendBit RLT2, 6				; Pin 7
	SendBit RLT2, 7				; Pin 8
	SendBit RLExtraReg, MMGoBit		; Pin 9
	SendBit	RLExtraReg, MMPowerBit		; Pin 10
	SendBit RHT1, 3				; Pin 11
	SendBit RHT1, 4				; Pin 12
	SendBit RLT1, 7				; Pin 13
	SendBit RLT1, 3				; Pin 14
	SendBit RLT1, 1				; Pin 15
	SendBit RLT1, 0				; Pin 16
	rcall	MMClockInT			; Pin 17 (Not Connected)
	SendBit RHT2, 7				; Pin 18
	SendBit RLT3, 1				; Pin 19
	SendBit RLT3, 2				; Pin 20
	SendBit RLT3, 3				; Pin 21
	SendBit	RLT1, 2				; Pin 22
	SendBit RLT1, 4				; Pin 23
	SendBit RHT1, 5				; Pin 24
	SendBit RLT1, 6				; Pin 25
	SendBit RLT1, 5				; Pin 26
	SendBit	RLExtraReg, MMStealthDiagnosticBit ; Pin 27
	SendBit RLExtraReg, MMBumperTiltBit	; Pin 28
	SendBit	RHT2, 5				; Pin 29
	SendBit RHT2, 4				; Pin 30
	SendBit RLT3, 0				; Pin 31
	SendBit RLT2, 4				; Pin 32
	SendBit RLT2, 2				; Pin 33
	SendBit RLT2, 1				; Pin 34
	SendBit RHT1, 6				; Pin 35	
	rjmp	R_Loop
R_Debug:
	; Clock in the start bit and turn all the outputs on except for the status lights.
	ser	RHT1
	sec
	ldi	RHT2, 8	
	rcall	DoClockIn			; Pins 1-8
	SendBit RLExtraReg, MMGoBit		; Pin 9
	SendBit	RLExtraReg, MMPowerBit		; Pin 10
	ldi	RHT2, 16
	rcall	DoClockIn			; Pins 11-26
	SendBit	RLExtraReg, MMStealthDiagnosticBit ; Pin 27
	SendBit RLExtraReg, MMBumperTiltBit	; Pin 28
	ldi	RHT2, 7				; Pins 29-35
	rcall	DoClockIn
nop
	rjmp	R_Loop
	
R_Sleep:
	;Nothing to do so go to sleep
	sbi	IdlePort, IdlePin	; Set the idle pin high when we go to sleep
	sleep
	cbi	IdlePort, IdlePin
	rjmp	R_Loop
	
R_Normal:
	; Before we start clocking in the data clear bit 7.
	; so that it can be set again. We dont need
	; to do it before now because we havent clocked in
	; any data just the start bit.
	; Bit 6 is used to indicate that all the lights should be off regardless
	; of the data in the registers.
	; If bit 6 is set them the thing is cleared
	bst	RLMMReg3, MMClearBit
	lbrts	R_Clear
	; Now we need to clock in the data
	SendBit	RLExtraReg, MMFrontRedBit	; Pin 1
	SendBit	RLFWhiteReg, 1			; Pin 2
	SendBit	RLFWhiteReg, 0			; Pin 3
	SendBit	RLRunningReg, 0			; Pin 4
	SendBit	RLRunningReg, 2			; Pin 5
	SendBit	RLBWhiteReg, 2			; Pin 6
	SendBit	RLExtraReg, MMBackRedBit	; Pin 7
	rcall	MMClockInT			; Pin 8
	SendBit RLExtraReg, MMGoBit		; Pin 9
	SendBit	RLExtraReg, MMPowerBit		; Pin 10
	SendBit RLFWhiteReg, 7			; Pin 11
	SendBit	RLFWhiteReg, 6			; Pin 12
	SendBit	RLExtraReg, MMFrontRedBit	; Pin 13
	SendBit RLRunningReg, 6			; Pin 14
	SendBit RLBWhiteReg, 7			; Pin 15
	SendBit RLBWhiteReg, 6			; Pin 16
	rcall	MMClockInT			; Pin 17 (Not used)
	SendBit	RLBWhiteReg, 5			; Pin 18
	SendBit RLExtraReg, MMBackRedBit	; Pin 19
	rcall	MMClockInT			; Pin 20
	rcall	MMClockInT			; Pin 21
	SendBit	RLRunningReg, 5			; Pin 22
	SendBit RLRunningReg, 7			; Pin 23
	SendBit RLFWhiteReg, 5			; Pin 24
	SendBit RLExtraReg, MMFrontRedBit	; Pin 25
nop
	rcall	MMClockInT			; Pin 26
	SendBit	RLExtraReg, MMStealthDiagnosticBit ; Pin 27
	SendBit RLExtraReg, MMBumperTiltBit	; Pin 28
	SendBit RLBWhiteReg, 1			; Pin 29
	SendBit RLBWhiteReg, 0			; Pin 30
	SendBit RLExtraReg, MMBackRedBit	; Pin 31
	SendBit	RLRunningReg, 1			; Pin 32
	SendBit	RLExtraReg, MMFrontRedBit	; Pin 33
	SendBit RLExtraReg, MMFrontRedBit	; Pin 34
	SendBit RLFWhiteReg, 2			; Pin 35
	; All done
	
	rjmp	R_Loop
	
R_Clear:	; Bit 6 is set so we just clock in all zeros except for the status bits
	clr	RHT1
	clc
	ldi	RHT2, 8	
	rcall	DoClockIn			; Pins 1-8
	SendBit RLExtraReg, MMGoBit		; Pin 9
	SendBit	RLExtraReg, MMPowerBit		; Pin 10
	ldi	RHT2, 16
	rcall	DoClockIn			; Pins 11-26
	SendBit	RLExtraReg, MMStealthDiagnosticBit ; Pin 27
	SendBit RLExtraReg, MMBumperTiltBit	; Pin 28
	ldi	RHT2, 7				; Pins 29-35
	rcall	DoClockIn
	rjmp	R_Loop
;**************************************************************************
;
;	/Main Loop
;
;**************************************************************************

;**************************************************************************
;
;	ISRs
;
;**************************************************************************

;**************************************************************************
;	ISRSystemTic
; This interupt is called every 1/4 of a millisecond and does a lot of things.
ISRSystemTic:
	ldi	RHIsr1, SysTicReload		; Reload the timer
	out	SysTicCnt, RHIsr1
	SaveSREG
	
	; Do the software PWM
	; See if headlights are on at all (Battery power is normal
	; and lights are on full).
	lds	RHIsr1, Lights	; Check if we are in test mode
	cpi	RHIsr1, LTest
	breq	ST_LTestPWM
	cpi	RHIsr1, LFull
	brne	ST_NoHeadlights
	lds	RHIsr1, BatPower
	cpi	RHIsr1, BPNormal
	brne	ST_NoHeadlights
	
	; Headlights are on. See to what degree.
	; RHHIntensityCnt holds a count for the PWM. This is a glitching
	; unsincronized PWM.
	; RHHIntensityCnt counts up. When it overflows the lights are turned
	; on and when it passes above the intensity register it turns the lights
	; off.
	cp	RLHIntensity, RLHIntensityCnt
	brsh	ST_TurnOn	; If intensity is lower than the count then turn
	; the lights off.
	; Turn the headlights off
	cbi	HeadlightPort, HeadlightF
	cbi	HeadlightPort, HeadlightB
	rjmp	ST_HDone
ST_TurnOn:
	; Turn the headlights on
	; Headlight forward is bit 6 and headlight backward is bit 7
	ldi	RHIsr1, (1 << HeadlightB)	; Put T in the higher bit
	; Shift it along if we are going forwards
	bst	RHFlags, DirectionBit
	brts	STH_GoingB
	; We are going backwards so shift it along 1 bit
	lsr	RHIsr1
STH_GoingB:
	; Put the two bits from RHIsr1 out without interfering with the
	; other bits.
	in	RZIsrL, HeadlightPort
	cbr	RZIsrL, ((1 << HeadlightF) | (1 << HeadlightB))
	or	RHIsr1, RZIsrL
	out	HeadlightPort, RHIsr1
	rjmp	ST_HDone
	
ST_LTestPWM:
	; Just ignore this if we are in debug mode
	bst	RHFlags, DebugBit
	brts	ST_HDone
	lds	RHIsr3, LTestFlags
	bst	RHIsr3, LTOff
	brts	ST_HDone
	; Headlights are on. See to what degree.
	; RHHIntensityCnt holds a count for the PWM. This is a glitching
	; unsincronized PWM.
	; RHHIntensityCnt counts up. When it overflows the lights are turned
	; on and when it passes above the intensity register it turns the lights
	; off.
	lds	RHIsr2, LTHIntensity
	cp	RHIsr2, RLHIntensityCnt
	brsh	ST_TurnOnT	; If intensity is lower than the count then turn
	; the lights off.
	; Turn the headlights off
	cbi	HeadlightPort, HeadlightF
	cbi	HeadlightPort, HeadlightB
	rjmp	ST_HDone
ST_TurnOnT:
	; Turn the headlights on
	; Headlight forward is bit 6 and headlight backward is bit 7
	ldi	RHIsr1, (1 << HeadlightB)	; Put T in the higher bit
	; Shift it along if we are going forwards
	bst	RHIsr3, LTDirection
	brts	STHT_GoingB
	; We are going forwards so shift it along 1 bit
	lsr	RHIsr1
STHT_GoingB:
	; Put the two bits from RHIsr1 out without interfering with the
	; other bits.
	in	RZIsrL, HeadlightPort
	cbr	RZIsrL, ((1 << HeadlightF) | (1 << HeadlightB))
	or	RHIsr1, RZIsrL
	out	HeadlightPort, RHIsr1
	
ST_HDone:
ST_NoHeadlights:
	; Only do the normal timer stuff every millisecond (every 4th time)
	inc	RLHIntensityCnt
	mov	RHIsr1, RLHIntensityCnt
	cpi	RHIsr1, HIntensityInvalid
	brne	IST_HOkay
	clr	RLHIntensityCnt
IST_HOkay:
	; See if this is divisible by 4
	mov	RHIsr1, RLHIntensityCnt
	andi	RHIsr1, 0b00000011
	brze	IST_4th
	RestoreSREGreti
IST_4th:
	
	; For go messages
	brrc	RHFlags, GoBit, IST_NoGo	; Check if were doing a go message
	; We are
	ldsw	RZIsr, GoTimeRemaining
	sbiw	RZIsrL, 1
	lds	RHIsr1, GoTimeRemainingExtra
	sbci	RHIsr1, 0
	brcc	IST_DoneGo
	; Okay were arrived at our destination (hopefully)
	MultiByteCircularQueueRemoveProc	IST_NoMoreGo, RYIsr, GoBuffer
	; There is more go messages so just keep processing them
	ld	RHIsr2, Y+	; Get the speed
	ld	RHIsr1, Y+	; The angle
	ld	RHIsr3, Y+	; The flags
	ldw	RZIsr, Y+	; And the distance
	rcall	GetGoing
	rjmp	IST_NoGo
IST_NoMoreGo:
	; There is no more go messages so stop
	rcall	Halt
	; Turn off the go light
	clt
	bld	RLExtraReg, MMGoBit
	; Show why we stopped
	ldi	RHIsr1, (1 << FinishedGoBit)
	sts	GoFlags, RHIsr1
	rjmp	IST_NoGo
IST_DoneGo:
	stsw	GoTimeRemaining, RZIsr
	sts	GoTimeRemainingExtra, RHIsr1
IST_NoGo:
	
	; Get the bumper switches and see if they changed. If they did
	; set a flag to show they changed
	in	RHIsr1, BumperIn
	andi	RHIsr1, 0b11111100
	; Compare it with the old one
	cp	RLBumpersStatus, RHIsr1
	breq	IST_NoBumpersChanged	
	mov	RLBumpersStatus, RHIsr1
	; andi with the bumper stuff
	lds	RHIsr1, DownBumpers
	and	RHIsr1, RLBumpersStatus
	sts	DownBumpers, RHIsr1
	sbr	RHFlags, (1 << BumpersChangedBit)
	; See if any bumpers are down
	ldi	RHIsr1, 0b11111100
	cp	RLBumpersStatus, RHIsr1
	brne	IST_BDown
	; Turn off the bumper if the tilts arent down
	ldi	RHIsr1, TiltMsk
	cp	RLTiltStatus, RHIsr1
	brne	IST_NoBumpersChanged
	clt	; If there arent turn off the light
	rjmp	IST_SetIn
IST_BDown:
	; If auto-stop enabled
	brrc	RHFlags, AutoStopBit, IST_NotAuto
	; And we are doing a go message
	brrc	RHFlags, GoBit, IST_NotAuto
	; Some bumpers are down so stop
	; Stop moving
	rcall	Halt
	; Set the flags to show why we stopped
	ldi	RHIsr1, (1 << StoppedBit)
	sts	GoFlags, RHIsr1
IST_NotAuto:
	; Turn on the bumper light
	set
IST_SetIn:
	bld	RLExtraReg, MMBumperTiltBit	; Turn the bumper lights off or on
	RefreshMM
IST_NoBumpersChanged:

	; See if the tilt switches have changed
	in	RHIsr1, TiltIn
	andi	RHIsr1, TiltMsk
	; Compare with the old one
	cp	RLTiltStatus, RHIsr1
	breq	IST_NoTiltChange
	; Save this new mode
	mov	RLTiltStatus, RHIsr1
	; Andi with tilt down
	lds	RHIsr1, DownTilts
	and	RHIsr1, RLTiltStatus
	sts	DownTilts, RHIsr1
	; See if any tilts are down
	ldi	RHIsr1, TiltMsk
	cp	RLTiltStatus, RHIsr1
	brne	IST_Down
	; All the tilts are off so turn of the indicator if the bumpers arent down.
	ldi	RHIsr1, 0b11111100
	cp	RLBumpersStatus, RHIsr1
	brne	IST_NoTiltChange
	; Turn off the bit
	clt
	bld	RLExtraReg, MMBumperTiltBit
	rjmp	IST_NoTiltChange
IST_Down:
	; If auto-stop enabled
	brrc	RHFlags, AutoStopBit, IST_TNotAuto
	; And we are doing a go message
	brrc	RHFlags, GoBit, IST_TNotAuto
	; Some tilts are down so stop
	; Stop moving
	rcall	Halt
	; Set the flags to show why we stopped
	ldi	RHIsr1, (1 << StoppedBit)
	sts	GoFlags, RHIsr1
	rjmp	IST_NoTiltChange
IST_TNotAuto:
	sbr	RHFlags, (1 << BumpersChangedBit)
	RefreshMM
IST_NoTiltChange:
	
	; Check if we are changing direction. This will show if the count
	; down is not zero.
	lds	RHIsr1, LTimeToSwitch
	tst	RHIsr1
	brze	LST_LeftOkay
	; This must be changing direction.
	dec	RHIsr1
	brnz	LST_LNotYet
	; We are done counting and it is time to switch direction
	; Go the opposite direction from how we are going now.
	in	RHIsr1, MotorDirPort
	ldi	RZIsrL, (1 << MotorDirL)
	eor	RHIsr1, RZIsrL
	out	MotorDirPort, RHIsr1
	; Output the speed we should be going
	clr	RHIsr1
	lds	RZIsrL, LSpeed
	out	MotorPWMLH, RHIsr1
	out	MotorPWMLL, RZIsrL
	
LST_LNotYet:
	; Save the milliseconds remaining
	sts	LTimeToSwitch, RHIsr1
LST_LeftOkay:

	; Check if we are changing direction. This will show if the speed
	; register is not the same as the value in the PWM
	lds	RHIsr1, RTimeToSwitch
	tst	RHIsr1
	brze	LST_RightOkay
	; This must be changing direction.
	dec	RHIsr1
	brnz	LST_RNotYet
	; We are done counting and it is time to switch direction
	in	RHIsr1, MotorDirPort
	ldi	RZIsrL, (1 << MotorDirR)
	eor	RHIsr1, RZIsrL
	out	MotorDirPort, RHIsr1
	; Output the speed we should be going
	clr	RHIsr1
	lds	RZIsrL, RSpeed
	out	MotorPWMRH, RHIsr1
	out	MotorPWMRL, RZIsrL
LST_RNotYet:
	; Save the milliseconds remaining
	sts	RTimeToSwitch, RHIsr1
LST_RightOkay:

	; Okay now for the status lights
	; Do the count down
	ldsw	RYIsr, StatusCount
	sbiw	RYIsrL, 1
	brnz	IST_DoneStatus
	; See what things should be flashed
	ldi	RHIsr1, TiltMsk
	cp	RLTiltStatus, RHIsr1
	breq	IST2_NoTiltChange
	; If bumpers are on we dont flash
	ldi	RHIsr1, 0b11111100
	cp	RLBumpersStatus, RHIsr1
	brne	IST2_NoTiltChange
	; Okay we should flash the bumpers
	sbr	RYIsrL, (1 << MMBumperTiltBit)
IST2_NoTiltChange:
	; Flash when we halt
	lds	RHIsr1, GoFlags
	bst	RHIsr1, HaltBit
	bld	RYIsrL, MMGoBit
	; Flash when diagnostics is on
	bst	RHFlags, DebugBit
	bld	RYIsrL, MMStealthDiagnosticBit

	; Flash when power is low
	lds	RHIsr1, BatPower
	cpi	RHIsr1, BPLow
	brne	IST_NotLow
	; Power is low so flash
	sbr	RYIsrL, (1 << MMPowerBit)
IST_NotLow:
	; Okay toggle the status
	eor	RLExtraReg, RYIsrL
	; Now reload the count
	ldiw	RYIsr, StatusReload
	RefreshMM
IST_DoneStatus:
	; Save the count again
	stsw	StatusCount, RYIsr

	; See if we are running a light show
	lds	RHIsr1, Lights
	cpi	RHIsr1, LTest
	lbrne	LST_NotTest
	; If we are in debug mode we can just return
	brrs	RHFlags, DebugBit, LS_Exit
	; We are running a light show
	ldsw	RZIsr, TestMMCount
	sbiw	RZIsrL, 1
	lbrcc	LS_DoneTest
	; Time to refresh
	RefreshMM
	; Okay do the lights
	clc
	ldiw	RZIsr, TestMM
	ldi	RYIsrL, 5	; First shift each one along
TestMMLoop:
	ld	RHIsr1, Z
	rol	RHIsr1
	st	Z+, RHIsr1
	dec	RYIsrL
	brnz	TestMMLoop
	; If carry is set put it back in the last one (carry is in bit 4)
	lds	RHIsr1, TestMM + 4
	bst	RHIsr1, 4
	lds	RHIsr1, TestMM
	bld	RHIsr1, 0
	sts	TestMM, RHIsr1
	; Okay now for the count
	lds	RHIsr1, TestMMCountdown
	dec	RHIsr1
	brnz	TM_CountNotZ	
	; The count is zero so now we turn a light off or on
	; depending on the flag
	lds	RHIsr1, LTestFlags
	bst	RHIsr1, TestMMDirectionBit
	; If T is set we are turning lights off
	ldiw	RZIsr, TestMM
	ldi	RYIsrL, 5
	brts	TM_Off
	; Set the lights of the last byte so it thinks theyre on
	lds	RHIsr1, TestMM + 4
	ori	RHIsr1, 0b11110000
	sts	TestMM + 4, RHIsr1
TM_LookOff:
	; Okay we go along the bytes looking for a light that is off
	ld	RHIsr1, Z+
	; See if any of these are off
	cpi	RHIsr1, 0xff
	breq	TM_AllOn
	; One of the lights is on - turn the first one that is off on
	ldi	RYIsrL, 1
	mov	RYIsrH, RHIsr1	; Save the orignal
TM_FindOff:
	lsl	RYIsrL
	lsr	RHIsr1
	brcs	TM_FindOff
	; Check if we shifted the bit off the end
	tst	RYIsrL
	brnz	TM_IsOff
	; We have so set the top bit
	ldi	RYIsrL, 0b10000000
	rjmp	TM_OrIn
TM_IsOff:
	; Turn this light on
	lsr	RYIsrL
TM_OrIn:
	or	RYIsrH, RYIsrL ; Or on the new light
	; Save it back
	st	-Z, RYIsrH
	rjmp	TM_DoneCNZ
TM_AllOn:
	dec	RYIsrL
	brnz	TM_LookOff
	; Toggle the direction
	rjmp	TM_Toggle
TM_Off:
	lds	RHIsr1, TestMM + 4
	cbr	RHIsr1, 0b11110000
	sts	TestMM + 4, RHIsr1	; Make it think theyre off
	; Okay we go along the bytes looking for a light that is on and turn it off
	
TM_LookOn:
	ld	RHIsr1, Z+
	; See if any off these are off
	tst	RHIsr1
	brze	TM_AllOff
	; One of the lights is on - turn the first one that is on off
	ldi	RYIsrL, 1
	mov	RYIsrH, RHIsr1	; Save the orignal
TM_FindOn:
	lsl	RYIsrL
	lsr	RHIsr1
	brcc	TM_FindOn
	; Check if we shifted the bit off the end
	tst	RYIsrL
	brnz	TM_IsOff2
	; We have to set the top bit
	ldi	RYIsrL, 0b10000000
	rjmp	TM_AndIn
TM_IsOff2:
	; Turn this light on
	lsr	RYIsrL

	; Turn this light off
	lsr	RYIsrL
TM_AndIn:
	com	RYIsrL
	and	RYIsrH, RYIsrL
	; Save it back
	st	-Z, RYIsrH
	rjmp	TM_DoneCNZ
TM_AllOff:
	dec	RYIsrL
	brnz	TM_LookOn
TM_Toggle:
	lds	RHIsr1, LTestFlags
	ldi	RZIsrL, (1 << TestMMDirectionBit)
	eor	RHIsr1, RZIsrL
	sts	LTestFlags, RHIsr1
TM_DoneCNZ:
	ldi	RHIsr1, DefaultMMCountdownReload
TM_CountNotZ:
	sts	TestMMCountdown, RHIsr1
	
	; Now change the headlight intensity
	lds	RHIsr1, LTestFlags
	lds	RHIsr3, LTHIntensity
	; Change the intensity and store it
	bst	RHIsr1, LTUp	; See if we are counting up or down	
	brts	ST_TUp
	; We are counting down
	subi	RHIsr3, 2
	brcc	ST_DoneChangeI
	; We got to the bottom so toggle to the other light counting up
	ldi	RHIsr2, (1 << LTDirection)
	eor	RHIsr1, RHIsr2
	; We are now counting up
	sbr	RHIsr1, ((1 << LTUp) | (1 << LTOff))
	cbi	HeadlightPort, HeadlightF
	cbi	HeadlightPort, HeadlightB
	; Start off low
	clr	RHIsr3
	ldi	RHIsr2, 5
	sts	LTestPauseOff, RHIsr2
	rjmp	ST_DoneChangeI
ST_TUp:
	lds	RHIsr2, LTestPauseOff
	tst	RHIsr2
	brze	ST_Okay
	; We are still pausing
	dec	RHIsr2
	sts	LTestPauseOff, RHIsr2
	rjmp	ST_DoneChangeINS
ST_Okay:
	cbr	RHIsr1, (1 << LTOff)
	; We are counting up
	inc	RHIsr3
	cpi	RHIsr3, HIntensityInvalid
	brlo	ST_DoneChangeI
	; We got to the top so start counting down
	cbr	RHIsr1, (1 << LTUp)
	ldi	RHIsr3, (HIntensityInvalid - 1)
ST_DoneChangeI:
	sts	LTHIntensity, RHIsr3
	sts	LTestFlags, RHIsr1
ST_DoneChangeINS:
	
	; And reload the count
	ldiw	RZIsr, TestCountReload
LS_DoneTest:
	stsw	TestMMCount, RZIsr
LS_Exit:
	RestoreSREGreti
LST_NotTest:

	; All lighting below here.
	bst	RLMMReg3, MMClearBit	; If lights are cleared then just jump to the end
	lbrts	ST_Exit
	
	; Move the left running lights if necessary
	tst	RLLeftSpeed
	breq	ST_NoLRunLights
	; We are moving so see if it is time to change them.
	sbiw	RHLRunCntL, 1		; Subtract 1. If the counter has reached zero
	brne	ST_NoLRunLights		; it is time to change the lights
	; First reload the counter
	ldsw	RHLRunCnt, LRunningReload
	rcall	GetLMotorDir
	; Now depending the direction rotate the lights.
	RefreshMM
	; If we are going forward then rotate them right.
	; Now rotate the lights depending on the direction we are going
	mov	RHIsr1, RLRunningReg
	brcs	ST_LRotateL
	; Rotate left (were going forward)
	lsl	RHIsr1
	brcc	ST_LRotatedR	; Carry will be set if the bit went off the edge
	sbr	RHIsr1, (1 << 5)
	rjmp	ST_LRotatedR
ST_LRotateL:
	lsr	RHIsr1
	bst	RHIsr1, 4
	brtc	ST_LRotatedR
	; If the bit when off the edge set bit 7 and it
	sbr	RHIsr1, (1 << 7) ; will be ANDed away later.
ST_LRotatedR:
	; Now put this back into the lights
	ldi	RZIsrL, 0b00011111	; Clear the old lights
	andi	RHIsr1, 0b11100000
	and	RLRunningReg, RZIsrL
	or	RLRunningReg, RHIsr1
	RefreshMM
ST_NoLRunLights:

	; Move the right running lights if necessary
	tst	RLRightSpeed
	brze	ST_NoRRunLights
	; We are moving so see if it is time to change them.
	sbiw	RXRRunCntL, 1		; Subtract 1. If the counter has reached
	brne	ST_NoRRunLights
	; It is time to change the lights
	; First reload the counter
	ldsw	RXRRunCnt, RRunningReload
	; Now depending the direction rotate the lights.
	RefreshMM
	; If we are going forward then rotate them left.
	; To get direction set T to the direction we are going
	rcall	GetRMotorDir
	; Now rotate the lights depending on the direction we are going
	mov	RHIsr1, RLRunningReg
	; Now use T to know what direction we are going
	brcs	ST_RRotateR
	; Rotate left (were going forward)
	lsl	RHIsr1
	bst	RHIsr1, 3
	brtc	ST_RotatedR
	; If the bit when off the edge set bit 0 and it
	sbr	RHIsr1, (1 << 0) ; will be ANDed away later.
	rjmp	ST_RotatedR
ST_RRotateR:
	lsr	RHIsr1
	brcc	ST_RotatedR	; Carry will be set if the bit went off the edge
	sbr	RHIsr1, (1 << 2)
ST_RotatedR:
	; Now put this back into the lights
	; Only the lower 3 bits are for the right lights
	andi	RHIsr1, 0b00000111
	ldi	RZIsrL, 0b11111000
	and	RLRunningReg, RZIsrL
	or	RLRunningReg, RHIsr1
	RefreshMM
ST_NoRRunLights:

	cpi	RHBlinkerStatus, BlinkersOff
	lbreq	ST_NoBlinkers
	ldsw	RYIsr, BlinkersCnt
	sbiw	RYIsrL, 1
	lbrnz	ST_BDone
	; We have reached the time to change the blinkers
	RefreshMM
	; Reload the count
	ldsw	RYIsr, BlinkersReload
	; Move the blinkers
	; There are 8 different combinations.
	;	F , Going Forward
	;	R , Going in Reverse
	;			 Blinking Left:    |	Blinking Right:
	; Blinkers Flashing On	: F / R 	   |	F/R
	; Blinkers Flashing Off	: F / R		   |	F/R
	
	; See if we are going backwards or forwards
	bst	RHFlags, DirectionBit
	brts	ST_BReversing
	; We are going forwards
	mov	RHIsr1, RLFWhiteReg
	mov	RZIsrL, RLFWhiteReg
	cpi	RHBlinkerStatus, BlinkersLeft
	brne	ST_BFToTheRight
	; We are going forwards left
	; Shift the bit along to the left
	andi	RHIsr1, 0b11100000
	cbr	RZIsrL, 0b11100000
	lsl	RHIsr1
	; Carry was just shifted off
	brcc	ST_BFSave
	; Reload the bit
	sbr	RHIsr1, (1 << 5)
	rjmp	ST_BFSave
ST_BFToTheRight:
	; We are going forwards to the right
	; Shift the bit along to the right
	andi	RHIsr1, 0b00000111
	cbr	RZIsrL, 0b00000111
	lsr	RHIsr1
	brcc	ST_BFSave
	; Reload the bit
	sbr	RHIsr1, (1 << 2)
	rjmp	ST_BFSave
ST_BFSave:
	or	RHIsr1, RZIsrL
	mov	RLFWhiteReg, RHIsr1
	rjmp	ST_BDone
	
ST_BReversing:
	; We are going backwards
	mov	RHIsr1, RLBWhiteReg
	mov	RZIsrL, RLBWhiteReg
	cpi	RHBlinkerStatus, BlinkersLeft
	brne	ST_BBToTheRight
	; We are going backwards left
	; Shift the bit along to the left
	andi	RHIsr1, 0b11100000
	lsl	RHIsr1
	cbr	RZIsrL, 0b11100000
	; Carry was just shifted off
	brcc	ST_BBSave
	; Reload the bit
	sbr	RHIsr1, (1 << 5)
	rjmp	ST_BBSave
ST_BBToTheRight:
	; We are going backwards to the right
	; Shift the bit along to the right
	andi	RHIsr1, 0b00000111
	lsr	RHIsr1
	cbr	RZIsrL, 0b00000111
	; We are flashing on
	brcc	ST_BBSave
	; Reload the bit
	sbr	RHIsr1, (1 << 2)
	rjmp	ST_BBSave
ST_BBSave:
	or	RHIsr1, RZIsrL
	mov	RLBWhiteReg, RHIsr1
ST_BDone:
	stsw	BlinkersCnt, RYIsr
ST_NoBlinkers:

	; Reverse lights
	; See if they are on.
	ldsw	RZIsr, ReverseCnt
	brwz	RZIsr, ST_ReverseLightsOff	; See if they are zero	
	sbiw	RZIsrL, 1	; Reverse lights are going so decrement the count
	brne	ST_ReverseLightsDone
ST_Toggle:
	RefreshMM
	; First reload the count
	ldiw	RZIsr, ReverseCountReload
	; Toggle the reverse lights.
	ldi	RHIsr1, 0b11100111
	bst	RHFlags, DirectionBit
	brts	ST_GoingBackwards
	; We are going forwards (so use the back lights) Toggle them
	eor	RLBWhiteReg, RHIsr1
	rjmp	ST_ReverseLightsDone
ST_GoingBackwards:
	; We are going backwards (so use the front lights) Toggle them
	eor	RLFWhiteReg, RHIsr1

ST_ReverseLightsDone:
	stsw	ReverseCnt, RZIsr; Save the count and then were done
ST_ReverseLightsOff:

ST_Exit:
	RestoreSREGreti
;**************************************************************************
;	/ISRSystemTic
;**************************************************************************

/* SPEED HACKED */
;**************************************************************************
;ISRUARTTXComplete:
;        ClearCommsTx
;        reti
;**************************************************************************
;       /ISRUARTTxComplete
;**************************************************************************


;**************************************************************************
;	ISRUARTRecieveComplete
; These are errors handlers for these conditions
; The RHComsStatus is a high register reserved for remember the coms status.
; There are 4 Rx states
; 0	Waiting for a message. The byte just recieved will be an address
; 1	A message is being sent to another computer. Ignore anything recieved
;	until a carriage return.
; 2	Recieving a message. The byte just recieved will be the hi8 nibble
;	of a byte.
; 3 	Recieving a message. The byte just recieved will be the lo8 nibble
;	of a byte.
IU_Error:
	bst	RHIsr1, FE
	brtc	RC_NoFramingError	; Check for a framing error
	bst	RHFlags, DebugBit	; Turn off debug mode temporarily to make sure
	cbr	RHFlags, (1 << DebugBit)	; we dont get a dump
	ComsError	ComsFramingErr
	bld	RHFlags, DebugBit
	rjmp	IU_DoneError
RC_NoFramingError:			; If its not it must be an overflo8
	bst	RHFlags, DebugBit	; Turn off debug mode temporarily to make sure
	cbr	RHFlags, (1 << DebugBit)	; we dont get a dump
	ComsError	ComsOverflowErr
	bld	RHFlags, DebugBit
	rjmp	IU_DoneError
RC_ParityError:
	bst	RHFlags, DebugBit	; Turn off debug mode temporarily to make sure
	cbr	RHFlags, (1 << DebugBit)	; we dont get a dump
	ComsError	ComsParityErr
	bld	RHFlags, DebugBit
	rjmp	RC_Done	; After this we have already read the byte so we dont
			; need to jump to IU_DoneError

Rx_InvalidState:
        ComsError       COMMS_INVALIDSTATE_ERR
        rjmp    RC_Done
IU_DoneError:
	; We just need to clear the interupt
	in	RHIsr1, UDR
	rjmp	RC_Done
	
	
ISRUARTRecieveComplete:
	SaveSREG
	
	; Check if there was any errors receiving this byte
	in	RHIsr1, USR
	andi	RHIsr1, ((1 << FE) | (1 << OR))
	brnz	IU_Error
	
	; Get the byte
	in	RHIsr1, UDR
	mov	RYIsrH, RHIsr1
	; Check parity and clear the 8th bit
	cbr	RHIsr1, (1 << 7)
	rcall	GetParity
	cp	RYIsrH, RHIsr1	; If theyre not the same parity is not right
	brne	RC_ParityError
	; Clear the 8th bit
	cbr	RHIsr1, 0b10000000
	
        ; Now handle this byte it is valid at least so far
        cpi     RHRxStatus, RX_IDLE
        breq    Rx_Idle
        cpi     RHRxStatus, RX_RECEIVEMSG
        breq    Rx_ReceiveMsg
        cpi     RHRxStatus, RX_RECEIVEMSG2
        lbreq    Rx_ReceiveMsg2
        cpi     RHRxStatus, RX_RECEIVEL + 1
        lbrlo    Rx_Receive
        ; Either hadnt processed the message or an invalid state
        rjmp    Rx_InvalidState

Rx_ReceivedMsg:
        ; We have an overrun. A message was not processed fast enough.
	ComsError	ComsOverrunErr
	rjmp	RC_DoneState

Rx_Idle:
        cpi     RHIsr1, MY_LID
        brne    Rx_NPolled
        rcall   Polled
        rjmp    RC_DoneState
Rx_NPolled:
        cpi     RHIsr1, MY_ID
        lbrne   RC_DoneState    ; Stay idle
        ; This is a message address to me
        ldi     RHRxStatus, RX_RECEIVEMSG
        rjmp    RC_DoneState

Rx_ReceiveMsg:
        ; This is a message addressed to us. Check its validty and either go
        ; to RX_RECEIVEMSG2 or RX_RECEIVEDATA or IDLE (in case of error).
        sts     RxMsg, RHIsr1

	cpi	RHIsr1, BHALT_MSG
	breq	RC_HaltMsg
        cpi     RHIsr1, BPOWER_MSG
        breq    RC_PowerMsg
        cpi     RHIsr1, BINTENSITY_MSG
        breq    RC_IntensityMsg
        cpi     RHIsr1, BTRAVEL_MSG
        breq    RC_TravelMsg
        cpi     RHIsr1, BGOLEFT_MSG
        breq    RC_GoLeftMsg
        cpi     RHIsr1, BGORIGHT_MSG
        breq    RC_GoRightMsg
        cpi     RHIsr1, BREVERSE_MSG
        breq    RC_ReverseMsg
        cpi     RHIsr1, BSPEED_MSG
        breq    RC_SpeedMsg
        cpi     RHIsr1, BGOLFWD_MSG
        breq    RC_GoLfwdMsg
        cpi     RHIsr1, BGOLBWD_MSG
        breq    RC_GoLbwdMsg
        cpi     RHIsr1, BGORFWD_MSG
        breq    RC_GoRfwdMsg
        cpi     RHIsr1, BGORBWD_MSG
        breq    RC_GoRbwdMsg
        cpi     RHIsr1, VERSION_MSG
        breq    RC_VersionMsg
        cpi     RHIsr1, DUMP_MSG
        breq    RC_DumpMsg
        cpi     RHIsr1, SET_MSG
        breq    RC_SetMsg
        ; Invalid message
        ComsError ComsInvalidMsgErr
        rjmp    RC_DoneState

RC_HaltMsg:
	ldi	RHIsr1, BHALT_MSG_LEN
	rjmp	RC_MsgD
RC_PowerMsg:
        ldi     RHIsr1, BPOWER_MSG_LEN
        rjmp    RC_MsgD
RC_IntensityMsg:
        ldi     RHIsr1, BINTENSITY_MSG_LEN
        rjmp    RC_MsgD
RC_TravelMsg:
        ldi     RHIsr1, BTRAVEL_MSG_LEN
        rjmp    RC_MsgD
RC_GoLeftMsg:
RC_GoRightMsg:
        ldi     RHIsr1, BGOLEFT_MSG_LEN
        rjmp    RC_MsgD
RC_ReverseMsg:
        ldi     RHIsr1, BREVERSE_MSG_LEN
        rjmp    RC_MsgD
RC_SpeedMsg:
        ldi     RHIsr1, BSPEED_MSG_LEN
        rjmp    RC_MsgD
RC_GoLfwdMsg:
RC_GoLbwdMsg:
RC_GoRfwdMsg:
RC_GoRbwdMsg:
        ldi     RHIsr1, BGOLFWD_MSG_LEN
        rjmp    RC_MsgD
RC_VersionMsg:
        ldi     RHIsr1, VERSION_MSG_LEN
        rjmp    RC_MsgD
RC_DumpMsg:
        ldi     RHIsr1, DUMP_MSG_LEN
        rjmp    RC_DMsg
RC_SetMsg:
        ldi     RHIsr1, SET_MSG_LEN

RC_DMsg:
        ; This is a message that has two message bytes
        ; Length of message is in RHIsr1
        sts     RxMsgLen, RHIsr1
        ldi     RHRxStatus, RX_RECEIVEMSG2
        rjmp    RC_DoneState

RC_MsgD:
        ; Length of message is in RHIsr1
        sts     RxMsgLen, RHIsr1
RC_ReceiveDataOrEnd:
        tst     RHIsr1
        brze    RC_ZeroMsg
        ; This message requires data
        ldi     RHRxStatus, RX_RECEIVEH
        clr     RHIsr1
        sts     RxBufferLen, RHIsr1
        rjmp    RC_DoneState

RC_ZeroMsg:
        rcall   ProcessComsMsg
RC_DoneMsg:
        ldi     RHRxStatus, RX_IDLE
        rjmp    RC_DoneState

Rx_ReceiveMsg2:
        ; This is the second msg byte
        sts     RxMsg2, RHIsr1
        lds     RHIsr1, RxMsgLen
        ; Process the message
        rjmp    RC_ReceiveDataOrEnd

RC_CR:
        lds     RHIsr1, RxMsgLen
        cpi     RHIsr1, CR_MSG
        breq    RC_CRMsg
        ComsError      ComsInvalidDataErr
        rjmp    RC_DoneState
RC_CRMsg:
        rjmp    RC_DoneMsg

Rx_Receive:
        cpi     RHIsr1, CR
        breq    RC_CR
	; Convert to a binary value from ASCII hex (lo8ercase for a-f)
	subi	RHIsr1, '0'
	; Test to see if it is higher than 9
	cpi	RHIsr1, 10
	brlo	RC_DoneConversion
	; It was either a-f or an error
	subi	RHIsr1, ('a' - '0' - 10)
	; Check that it is belo8 16 (if it isnt its an error)
	cpi	RHIsr1, 16
	brlo	RC_NotInvalid
	; This was invalid data
	ComsError	ComsInvalidDataErr
	rjmp	RC_DoneState
RC_NotInvalid:
RC_DoneConversion:
	; The converted byte was valid and is stored in RHIsr1
	; Store it in the buffer.
	; Load the buffer size and check it hasnt overflo8ed
	lds	RYIsrL, RxBufferLen
	cpi	RYIsrL, RxBufferSize
	brlo	RC_NoOverflo8
	; There was an overflo8
	ComsError	ComsOverflowErr
	rjmp	RC_DoneState
RC_NoOverflo8:
	; There was no overflow
	; RHIsr1 contains the binary nibble (4-bits)
	; RYIsrL contains the buffer length
	addi	RYIsrL, RxBuffer	; Add the RxBuffer
	ldi	RYIsrH, hi8(RxBuffer)
	; Y now points to the byte to store the next byte
	cpi	RHRxStatus, RX_RECEIVEL
	breq	RC_Savelo8
	; Simple were saving the hi8 nibble
	swap	RHIsr1	 ; Swap it into the hi8 nibble
	st	Y, RHIsr1
	; Next nibble is the lo8 nibble
	ldi	RHRxStatus, RX_RECEIVEL
	rjmp	RC_DoneState
RC_Savelo8:
	; Were saving the lo8 nibble so we have to and it with the old nibble
	; and change the buffer count.
	ld	RHIsr2, Y	; Load the old byte
	or	RHIsr1, RHIsr2 ; OR in the lo8er nibble thats already saved.
	st	Y, RHIsr1	; Store the complete byte back in the buffer
	; Store the incremented buffer size
	subi	RYIsrL, lo8(RxBuffer - 1)
	sts	RxBufferLen, RYIsrL
	; Next nibble is the hi8 nibble
	ldi	RHRxStatus, RX_RECEIVEH
        ; Decrement the amount remaining
        lds     RHIsr1, RxMsgLen
        cpi     RHIsr1, CR_MSG
        breq    RC_DoneState    ; This message is terminated by a CR
        dec     RHIsr1
        sts     RxMsgLen, RHIsr1
        brnz    RC_DoneState
        ; We have completed this message
        rcall   ProcessComsMsg
        ldi     RHRxStatus, RX_IDLE

RC_DoneState:
RC_Done:
	RestoreSREGreti
;**************************************************************************
;	/ISRUARTRecieveComplete
;**************************************************************************

;**************************************************************************
;	ISRUARTDataRegisterEmpty
ISRUARTDataRegisterEmpty:
; This interupt should only happen after we have been given permission to
; transmit by the master. The next character in the buffer is sent. If the
; buffer is empty then send a carriage return and disable this interupt
; from occuring again.
	SaveSREG
	
	; Check if we are meant to send our message
	lds	RHIsr1, TxMsg
	tst	RHIsr1
	brze	DRE_NotMsg
	; Send the message header
	rcall	GetParity
	; Output it
	out	UDR, RHIsr1
	clr	RHIsr1
	sts	TxMsg, RHIsr1
	RestoreSREGreti
DRE_NotMsg:
	; Load the next byte in the buffer
	lds	RHIsr2, TxBufferLen	; Add the length into the pointer
	tst	RHIsr2
	breq	DRE_Disable	; We have emptied our buffer so return

	; We are not done sending our buffer.
	ldi	RYIsrL, lo8(TxBuffer - 1)	; -1 because we add the buffer length.
	ldi	RYIsrH, hi8(TxBuffer)
	add	RYIsrL, RHIsr2
	; Get the byte to send
	ld	RHIsr1, Y
	; T flag is set if sending the hi8 nibble
	bst	RHFlags, TxStatusBit
	brtc	DRE_Nothi8
	; We are sending the hi8 nibble so swap it in to the lo8
	; nibble.
	swap	RHIsr1
	rjmp	DRE_Send
DRE_Nothi8:
	; Save the decremented length (if we are doing the  lo8 nibble go onto the next 1)
	dec	RHIsr2
	sts	TxBufferLen, RHIsr2
DRE_Send:
	; The nibble to send is contained in the lo8er half of RHIsr1
	; All we have to do is convert the nibble to ASCII (Y. parity), send it
	; -Convert the nibble to ASCII
	andi	RHIsr1, 0x0f	; AND off the upper nibble (not relevant)
	subi	RHIsr1, -48	; Add 0
	cpi	RHIsr1, 58	
	brlo	SAHN_NotOver2	; Check if it was between 0-9 or a-f
	subi	RHIsr1, -39
SAHN_NotOver2:
	rcall	GetParity
	; Output it
	out	UDR, RHIsr1
	
	; Next time send the opposite nibble
	ldi	RHIsr1, (1 << TxStatusBit)
	eor	RHFlags, RHIsr1
DRE_Exit:
	RestoreSREGreti

	; Called when buffer is empty
DRE_Disable:
	; Disable this interupt
	cbi	UCR, UDRIE
	; We should have been on to sending the hi8 nibble
	bst	RHFlags, TxStatusBit
	brts	DRE_Exit
	; For next time set our state to sending the hi8 nibble first
	sbr	RHFlags, (1 << TxStatusBit)
	; Thats an error
	ComsError TxStatusInvalidErr
	rjmp	DRE_Exit
;**************************************************************************
;	/ISRUARTDataRegisterEmpty
;**************************************************************************

;**************************************************************************
;
;	/ISRs
;
;**************************************************************************

;**************************************************************************
;
;	Routines
;
;**************************************************************************

;**************************************************************************
;	Polled
;
;	Expects:
;	Uses:	RHIsr1, RHIsr2, RHIsr3, RZIsrH, RZIsrL, RYIsrL, RYIsrH
;
;	Should be fairly fast as interupts are disabled and will not be enabled
;	until it returns.
;**************************************************************************
Polled:
	; They have polled us we can now transmit if we want.
	; First see if we have an error to tell them about
	lds	RYIsrL, LastErr
	tst	RYIsrL
	brze	PCM_NoError
	; There is an error
	ldi	RHIsr1, ERROR_REPLY
	ldi	RZIsrH, ERROR_REPLY_LEN	; The length
	rcall	BeginMessage
	; Put the error on the buffer
	sts	TxBuffer + 2, RYIsrL	; The error
	ldsw	RZIsr, LastErrAddress	; And the address
	sts	TxBuffer + 1, RZIsrH
	sts	TxBuffer, RZIsrL
	; Now clear it so another error can be stored
	clr	RHIsr1
	sts	LastErr, RHIsr1
	ret
PCM_NoError:
	
	; There was no error so lets see if we finished a go message
	lds	RHIsr2, GoFlags
	andi	RHIsr2, ((1 << FinishedGoBit) | (1 << StoppedBit))
	tst	RHIsr2
	brze	PCM_NotGo
	; Something changed our go flags
	ldi	RHIsr1, BMOVEMENT_REPLY
	ldi	RZIsrH, BMOVEMENT_REPLY_LEN
	rcall	BeginMessage
	; Okay now store the flags
	clr	RHIsr1
	bst	RHFlags, DirectionBit	; Direction
	bld	RHIsr1, 7
	; And reason
	bst	RHIsr2, FinishedGoBit	; And the reason we stopped
	bld	RHIsr1, 0
	sts	TxBuffer, RHIsr1	; Store the flags
	
	; Now clear the go flags
	lds	RHIsr1, GoFlags
	cbr	RHIsr1, ((1 << FinishedGoBit) | (1 << StoppedBit))
	sts	GoFlags, RHIsr1
	
	ret
	
PCM_NotGo:
	; There was no error so lets see if the bumper switches
	; changed.
	bst	RHFlags, BumpersChangedBit
	brtc	PCM_NoBumpersChange
	; The bumpers have changed so send it
	ldi	RHIsr1, BSWITCH_REPLY
	ldi	RZIsrH, BSWITCH_REPLY_LEN ; Store the length
	rcall	BeginMessage
	
	; Put the switch status on the buffer
	lds	RHIsr1, DownBumpers
	cp	RHIsr1, RLBumpersStatus
	in	RHIsr2, SREG	; Save the status register
	lsr	RHIsr1
	lsr	RHIsr1
	sts	TxBuffer + 1, RHIsr1
	; Save the tilts as well
	lds	RHIsr1, DownTilts
	sts	TxBuffer, RHIsr1

	; Set the masks to what is on the switches now
	sts	DownBumpers, RLBumpersStatus
	sts	DownTilts, RLTiltStatus
	; Clear the change flag unless the status was different from what
	; is really on the switches.
	out	SREG, RHIsr2 ; Restore the SREG from the compare with bumpers
	cpc	RHIsr1, RLTiltStatus
	breq	PCM_ClearS
	ret
	
PCM_ClearS:
	cbr	RHFlags, (1 << BumpersChangedBit)
	ret

PCM_NoBumpersChange:
	; Weve got nothing to send
        ; So send our ID
        SetCommsTx
        ldi     RHIsr1, (MY_LID + 1)
        rcall   GetParity
        out     UDR, RHIsr1

	ret	
;**************************************************************************
;       /Polled
;**************************************************************************

;**************************************************************************
;	ProcessComsMsg
;
;	Expects:A message to be stored in the RxMsg, RxBuffer and RxBufferLen
; 		to be valid.
;	Uses:	RHIsr1, RHIsr2, RHIsr3, RZIsrH, RZIsrL, RYIsrL, RYIsrH
;
;	Should be fairly fast as interupts are disabled and will not be enabled
;	until it returns. It also resets the RxBuffer.
;**************************************************************************
ProcessComsMsg:
	lds	RHIsr1, RxMsg
	; Load the length
	lds	RHIsr2, RxBufferLen
	
	cpi	RHIsr1, BHALT_MSG
	lbreq	PCM_HaltMsg
        cpi     RHIsr1, BPOWER_MSG
        lbreq   PCM_PowerMsg
        cpi     RHIsr1, BINTENSITY_MSG
        lbreq   PCM_IntensityMsg
        cpi     RHIsr1, BTRAVEL_MSG
        lbreq   PCM_TravelMsg
        cpi     RHIsr1, BGOLEFT_MSG
        lbreq   PCM_GoLeftMsg
        cpi     RHIsr1, BGORIGHT_MSG
        lbreq   PCM_GoRightMsg
        cpi     RHIsr1, BREVERSE_MSG
        lbreq   PCM_ReverseMsg
        cpi     RHIsr1, BSPEED_MSG
        lbreq   PCM_SpeedMsg
        cpi     RHIsr1, BGOLFWD_MSG
        lbreq   PCM_GoLFwdMsg
        cpi     RHIsr1, BGOLBWD_MSG
        lbreq   PCM_GoLBwdMsg
        cpi     RHIsr1, BGORFWD_MSG
        lbreq   PCM_GoRFwdMsg
        cpi     RHIsr1, BGORBWD_MSG
        lbreq   PCM_GoRBwdMsg
        cpi     RHIsr1, VERSION_MSG
        lbreq   PCM_VersionMsg
        cpi     RHIsr1, DUMP_MSG
        lbreq   PCM_DumpMsg
        cpi     RHIsr1, SET_MSG
        lbreq   PCM_SetMsg

	; If it gets here there was a invalid message sent
	ComsError	ComsInvalidMsgErr
	ret
	
PCM_InvalidMsgContents:
	ComsError	InvalidMsgContentsErr
	ret
	; All the messages are here. The buffer length is stored in
	; RZIsrH.
PCM_PowerMsg:
	; OH drat! We got a power message! Theyre a pain in the neck!!!
	lds	RHIsr1, RxBuffer
	; Bit 5 is diagnostics mode
	bst	RHIsr1, 5
	bld	RHFlags, DebugBit
	; Bit 4 is stealth mode
	bst	RHIsr1, 4
	bld	RHFlags, StealthBit
	; 1-2 is battery power
	mov	RHIsr2, RHIsr1
	andi	RHIsr2, 0x03
	cpi	RHIsr2, BPInvalid
	breq	PCM_InvalidMsgContents
	sts	BatPower, RHIsr2
	; 2-3 is lights
	lsr	RHIsr1
	lsr	RHIsr1
	andi	RHIsr1, 0x03
	sts	Lights, RHIsr1
	; Everything has been saved now we just need to update things
	; Change the power status lights
	lds	RHIsr1, BatPower
	cpi	RHIsr1, BPNormal
	breq	UC_On
	; If we are not meant to be flashing it (low power)
	cpi	RHIsr1, BPLow
	breq	UC_DoneL2	; Dont change the lights since it will mess it up
	clt	; Turn the status light off
	rjmp	UC_DoneL	
UC_On:
	set	; Turn the status light on
UC_DoneL:
	bld	RLExtraReg, MMPowerBit
UC_DoneL2:
	; Update the stealth/diagnostic bit
	bst	RHFlags, DebugBit
	brts	DSD_Update
	; We are not in debug mode so we might be in stealth
	bst	RHFlags, StealthBit
	bld	RLExtraReg, MMStealthDiagnosticBit
DSD_Update:

	rcall	UpdateConstantLights	; This will take care of the headlights
	rcall	UpdateSharedLights	; And this will take care of everything else
	; Note: Doing this will cause a disruption in the blinkers etc.
	; tail lights, and everything white lights.
	; Now if stealth mode is on or battery power is off or lights are off
	; then turn the MM bit clear bit on. Otherwise turn it off.
	bst	RHFlags, StealthBit
	brts	PCMP_TurnOff
	lds	RHIsr1, BatPower
	cpi	RHIsr1, BPOff
	breq	PCMP_TurnOff
	lds	RHIsr1, Lights
	cpi	RHIsr1, LOff
	breq	PCMP_TurnOff
	; Turn the lights on
	UnClearMM
	ret
PCMP_TurnOff:
	ClearMM
	ret
	
PCM_IntensityMsg:
	
	; Set headlight intensity (all we have to do is load it)
	; the rest will be taken care off later by the timer interupt.
	lds	RHIsr1, RxBuffer
	swap	RHIsr1
	lsr	RHIsr1	; Get the 3 MSBs into the LSBs.
	andi	RHIsr1, HIntensityInvalid - 1
	mov	RLHIntensity, RHIsr1
PCMT_Done:	 ; This is a jump for the travel
		; message to a return.
PCM_DoneSpeed:	; This is for the speed message completes
	ret
	
PCM_TravelMsg:
	; Set the travel globals
	lds	RHIsr1, RxBuffer
	; Set auto-stop mode
	bst	RHIsr1, 4
	bld	RHFlags, AutoStopBit
	; Get the travel mode
	mov	RHIsr2, RHIsr1
	andi	RHIsr2, 0b00001100
	lsr	RHIsr2	; Check if we got something invalid
	lsr	RHIsr2
	cpi	RHIsr2, TInvalid
	lbreq	PCM_InvalidMsgContents
	sts	TravelMode, RHIsr2
	
	; Bit 1 is the switch move
	bst	RHIsr1, 1	; Save the switch mode to the flags
	bld	RHFlags, SwitchMode
	; If switch mode is manual then look at the direction bit otherwise
	; ignore it.
	brts	PCMT_Done
	; We are in manual mode see if our direction has changed
	ror	RHIsr1	; Get direction in C
	bst	RHFlags, DirectionBit ; Get our current direction in T
	; Compare C with T
	brts	PCMT_TSet
	; T is cleared
	brcc	PCMT_Done	; There is no change we are done
	rjmp	SwapDirection
PCMT_TSet:
	brcs	PCMT_Done	; There is no change we are done
	rjmp	SwapDirection
	
PCM_HaltMsg:
	; We recieve a halt message
	; Set the halt bit unless we are already stopped
	lds	RHIsr1, LSpeed
	tst	RHIsr1
	brnz	PCM_SetHFlag
	lds	RHIsr1, RSpeed
	tst	RHIsr1
	brze	Halt
	ret
PCM_SetHFlag:
	ldi	RHIsr1, (1 << HaltBit)
	sts	GoFlags, RHIsr1
Halt:	; This is used as an entry
	rcall	EmptyGoBuffer
	; Stop moving
	clt	; Turn the relays off
	ldi	RHIsr1, 0
	ldi	RHIsr3, 0
	rcall	SetLMotorSpeed
	clt	; Turn the relays off
	ldi	RHIsr1, 0
	ldi	RHIsr3, 0
	rcall	SetRMotorSpeed	
	rjmp	UpdateSharedLights	; And return
	
PCM_ReverseMsg:
	; Load our parameters
	lds	RHIsr2, RxBuffer	; Speed
	ldi	RHIsr1, AngleReverse	; Angle
	lds	RZIsrL, RxBuffer + 2
	lds	RZIsrH, RxBuffer + 1	; Distance
	rjmp	PCM_GoReverse
		
PCM_GoLeftMsg:
	; We recieved a valid left message
	ser	RHIsr3	; Set angle as going left
	rjmp	PCM_GoMsg
		
PCM_GoRightMsg:
	; We recieved a valid right message
	clr	RHIsr3	; Set angle as going right
PCM_GoMsg:	; Left comes here as well
	rcall	ClearHaltBit
	; Get all our parameters out of the buffer
	lds	RHIsr2, RxBuffer	; Speed
	lds	RHIsr1, RxBuffer + 1	; Angle
	lds	RZIsrL, RxBuffer + 3
	lds	RZIsrH, RxBuffer + 2	; Distance
PCM_GoReverse: ; Reverse comes here
	; If we are all we have to do is put this message in the go buffer.
	brrc	RHFlags, GoBit, PCM_NotGoing
	; Store to go buffer and return
; Go Buffer
; RHIsr2  - Speed
; RHIsr1 - Angle
; RHIsr3 - Flags (DirectionBit)
; RZIsrH-L- Distance
StoreToGoBuffer:
MultiByteCircularQueueAddProc GoBufferFull, RYIsr, GoBuffer
	st	Y+, RHIsr2	; First store the speed
	st	Y+, RHIsr1	; The angle
	st	Y+, RHIsr3	; The flags
	stw	Y+, RZIsr	; And the distance
	ret

GoBufferFull:
	Error	GoBufferFullErr
	ret

PCM_NotGoing:
	; Turn on the go light
	set
	bld	RLExtraReg, MMGoBit
	; First of all set that we are going
	sbr	RHFlags, (1 << GoBit)
	; If we are not already going we need to get going.	
	rjmp	GetGoing ; And return
		
PCM_SpeedMsg:
	; Override the speed of the go message
	; If we are not moving on a go message we can safely
	; ignore this message.
	brrc	RHFlags, GoBit, PCM_DoneSpeed
	
	; Okay first of all we have to set the speed of every message
	; in the go buffer
	ldi	RHIsr2, GoBufferSize
	lds	RHIsr1, RxBuffer	; Get the speed to set them to
	ldiw	RZIsr, GoBuffer
PCM_SpeedL:
	st	Z, RHIsr1
	adiw	RZIsrL, GoBufferSize		; Go to the next one
	dec	RHIsr2
	brnz	PCM_SpeedL
	
	; Now since we are in the middle of a go message we have to
	; change the time remaining.
	; TEMP
	rcall	GetLMotorDir
	set	; Move C to T
	brcs	Skip1
	clt
Skip1:
	; Just alter the speed
	lds	RHIsr1, RxBuffer
	mov	RHIsr3, RHIsr1
	rcall	SetLMotorSpeed
	rcall	GetRMotorDir
	set	; Move C to T
	brcs	Skip2
	clt
Skip2:
	lds	RHIsr1, RxBuffer
	mov	RHIsr3, RHIsr1
	rcall	SetRMotorSpeed
	rjmp	UpdateSharedLights	; and return
		
PCM_GoLFwdMsg:

	rcall	EmptyGoBuffer
	rcall	ClearHaltBit
	; Move the left motor forward at this speed
	clt
	lds	RHIsr1, RxBuffer
	mov	RHIsr3, RHIsr1
	rcall	SetLMotorSpeed	
	rjmp	UpdateSharedLights; And return
	
PCM_GoLBwdMsg:
	; Empty the go buffer
	rcall	ClearHaltBit
	rcall	EmptyGoBuffer
	; Move the left motor backward at this speed
	set
	lds	RHIsr1, RxBuffer
	mov	RHIsr3, RHIsr1
	rcall	SetLMotorSpeed	
	rjmp	UpdateSharedLights; And return
	
PCM_GoRFwdMsg:
	rcall	ClearHaltBit
	rcall	EmptyGoBuffer
	; Move the right motor forward at this speed
	clt
	lds	RHIsr1, RxBuffer
	mov	RHIsr3, RHIsr1
	rcall	SetRMotorSpeed	
	rjmp	UpdateSharedLights	; And return
	
PCM_GoRBwdMsg:
	rcall	ClearHaltBit
	rcall	EmptyGoBuffer
	; Move the right motor backward at this speed
	set	
	lds	RHIsr1, RxBuffer
	mov	RHIsr3, RHIsr1
	rcall	SetRMotorSpeed	
	rjmp	UpdateSharedLights	; And return
			
PCM_VersionMsg:
	; This is a valid version msg
	ldi	RHIsr1, VERSION_REPLY
	ldi	RZIsrH, VERSION_REPLY_LEN
	rcall	BeginMessage
	; Now put our version stuff on the buffer
	ldi	RHIsr1, ( (VERSION_REVISION(VERSION) << 4) | VERSION_FIX(VERSION) )
	sts	TxBuffer, RHIsr1
	ldi	RHIsr1, ( (VERSION_MAJOR(VERSION) << 4) | VERSION_MINOR(VERSION) )
	sts	TxBuffer + 1, RHIsr1

	ret

PCM_SetMsg:
        ; Load address
        lds     RZIsrL, RxBuffer + 1
        lds     RZIsrH, RxBuffer
        lds     RHIsr1, RxBuffer + 2
        ; Set the value
        st      Z, RHIsr1

        ret

PCM_DumpMsg:
        rcall   BeginBigMessage
        ; This may dump the flash, ram or registers.
        lds     RHIsr1, RxMsg2
        cpi     RHIsr1, DUMP_EEPROM
        breq    DumpEEPROM
        cpi     RHIsr1, DUMP_FLASH
        lbreq    DumpFlash
        cpi     RHIsr1, DUMP_REGISTERS
        lbreq    DumpRegisters
        cpi     RHIsr1, DUMP_SRAM
        breq    DumpSram

        sei

        ComsError       COMMS_INVALID_SECOND_MSG_ERR
        ret
	
SendDumpMessage:	; This is a direct entry used when are in debug mode to
	; send a message right away.
        rcall   BeginBigMessage
DumpSram:
	; Dump all our registers, memory and RAM.
	clrw	RZIsr	;Start at address 0000
DSRLoopMain:
	; Send our ID to begin with
	ldi	RHIsr1, MY_ID
	rcall	SendByteToUART
	ldi	RHIsr1, DUMP_MSG
        rcall   SendByteToUART
	ldi	RHIsr1, DUMP_SRAM
	rcall	SendByteToUART

	; Send the SRAM address in hex
	rcall	SendHWord	;Convert RAM address already in RZT and send it

; Display the 16 hex values
	ldi	RYIsrH, 16	;Bytes per line
DSRLoopHex:
	ld	RHIsr1, Z+		;Get the SRAM value
	rcall	SendHByte
DSR_NoExtra:
	dec	RYIsrH		;Bytes left to print on this line
	brnz	DSRLoopHex
	
; Send a CR at the end of every line
	ldi	RHIsr1,CR
	rcall	SendByteToUART

; Stop after displaying all of the RAM
	cpi	RZIsrL,lo8(RAMEND+1)
	brne	DSRLoopMain
	cpi	RZIsrH,hi8(RAMEND+1)
	brne	DSRLoopMain
	
	; End with our ID
	ldi	RHIsr1, MY_ID
	rcall	SendByteToUART
	ldi	RHIsr1, DUMP_MSG
        rcall   SendByteToUART
	ldi	RHIsr1, DUMP_SRAM
	rcall	SendByteToUART
        ldi     RHIsr1, CR
        rcall   SendByteToUART

	; Clear the UART flags
	in	RHIsr1, UDR
        ClearCommsTx
	ret	

DumpEEPROM:

	clrw	RZIsr	;Start at address 0000
	
ESRLoopMain:
	ldi	RHIsr1, MY_ID
	rcall	SendByteToUART
	ldi	RHIsr1, DUMP_MSG
        rcall   SendByteToUART
	ldi	RHIsr1, DUMP_EEPROM
	rcall	SendByteToUART
	
	; Send the EEPROM address in hex
	rcall	SendHWord	;Convert RAM address already in RZT and send it
	
; Display the 16 hex values
	ldi	RYIsrH, 16	;Bytes per line
ESRLoopHex:
	; Wait for the EEPROM to stop working
EL_1:	bris	EECR, EEWE, EL_1
	out	EEARL, RZIsrL	;Get the EEPROM value
        out     EEARH, RZIsrH
	sbi	EECR, EERE
	in	RHIsr1, EEDR
	; Increment the pointer
	adiw	RZIsrL, 1
	; And send it
	rcall	SendHByte
	
	dec	RYIsrH		;Bytes left to print on this line
	brnz	ESRLoopHex
	
        ldi     RHIsr1, CR
        rcall   SendByteToUART
	
; Stop after displaying all of the EEPROM
	cpi	RZIsrL,lo8(E2END+1)
	brne	ESRLoopMain
	cpi	RZIsrH,hi8(E2END+1)
	brne	ESRLoopMain
	
		; End with our ID
	ldi	RHIsr1, MY_ID
	rcall	SendByteToUART
	ldi	RHIsr1, DUMP_MSG
        rcall   SendByteToUART
	ldi	RHIsr1, DUMP_EEPROM
	rcall	SendByteToUART
        ldi     RHIsr1, CR
        rcall   SendByteToUART

	; Clear the UART flags
	in	RHIsr1, UDR
        ClearCommsTx
	ret	


DumpRegisters:
	clrw	RZIsr	;Start at address 0000

	ldi	RHIsr1, MY_ID
	rcall	SendByteToUART
	ldi	RHIsr1, DUMP_MSG
        rcall   SendByteToUART
	ldi	RHIsr1, DUMP_REGISTERS
	rcall	SendByteToUART

DR_Loop:
        ld      RHIsr1, Z+
        rcall   SendHByte
        cpi     RZIsrL, 16
        brlo    DR_Loop
        ; Send CR
        ldi     RHIsr1, CR
        rcall   SendByteToUART

	ldi	RHIsr1, MY_ID
	rcall	SendByteToUART
	ldi	RHIsr1, DUMP_MSG
        rcall   SendByteToUART

DR_Loop2:
        ld      RHIsr1, Z+
        rcall   SendHByte
        cpi     RZIsrL, 32
        brlo    DR_Loop2
        ; Send CR
        ldi     RHIsr1, CR
        rcall   SendByteToUART

	; End with our ID
	ldi	RHIsr1, MY_ID
	rcall	SendByteToUART
	ldi	RHIsr1, DUMP_MSG
        rcall   SendByteToUART
	ldi	RHIsr1, DUMP_REGISTERS
	rcall	SendByteToUART
        ldi     RHIsr1, CR
        rcall   SendByteToUART

	; Clear the UART flags
	in	RHIsr1, UDR
        ClearCommsTx
	ret	; Return and enable interupts


DumpFlash:
        clrw    RZIsr
        ; Send 16 bytes at a time
DF_Loop:
        ldi	RHIsr1, MY_ID
	rcall	SendByteToUART
	ldi	RHIsr1, DUMP_MSG
        rcall   SendByteToUART
	ldi	RHIsr1, DUMP_FLASH
	rcall	SendByteToUART

        rcall   SendHWord
        ; Now send 16 bytes of data
        ldi     RYIsrH, 16
DF_LoopD:
        lpm
        mov     RHIsr1, r0
        adiw    RZIsrL, 1
        rcall   SendHByte
        dec     RYIsrH
        brnz    DF_LoopD

        ldi     RHIsr1, CR
        rcall   SendByteToUART

       	cpi	RZIsrL,lo8(FLASHEND+1)
	brne	DF_Loop
	cpi	RZIsrH,hi8(FLASHEND+1)
	brne	DF_Loop

	; End with our ID
	ldi	RHIsr1, MY_ID
	rcall	SendByteToUART
	ldi	RHIsr1, DUMP_MSG
        rcall   SendByteToUART
	ldi	RHIsr1, DUMP_FLASH
	rcall	SendByteToUART
        ldi     RHIsr1, CR
        rcall   SendByteToUART

	; Clear the UART flags
	in	RHIsr1, UDR
        ClearCommsTx
	ret	; Return and enable interupts

;**************************************************************************
;	/ProcessComsMsg
;**************************************************************************	

;**************************************************************************
;	ClearHaltBit
;
;	Expects:
;	Changes: RHIsr1
;	Must Not Change: Non ISR registers (called from an ISR)
;
;	Clear the halt bit in the go flags.
;**************************************************************************
ClearHaltBit:
	lds	RHIsr1, GoFlags	; Clear the halt bit
	cbr	RHIsr1, (1 << HaltBit)
	sts	GoFlags, RHIsr1
	ret
;**************************************************************************
;	/ClearHaltBit
;**************************************************************************

;**************************************************************************
;	EmptyGoBuffer
;
;	Expects:
;	Changes: RHIsr1
;	Must Not Change: Non ISR registers (called from an ISR)
;
;	Empties the go buffer
;**************************************************************************	
EmptyGoBuffer:
	lds	RHIsr1, GoFlags	; Clear all the flags but the halt one
	cbr	RHIsr1, ((1 << FinishedGoBit) | (1 << StoppedBit))
	sts	GoFlags, RHIsr1
	; Empty the go buffer
	clr	RHIsr1
	sts	GoBufferCount, RHIsr1
	; Turn off the go light
	clt
	bld	RLExtraReg, MMGoBit
	; We are no longer going.
	cbr	RHFlags, (1 << GoBit)
	ret
;**************************************************************************
;	/EmptyGoBuffer
;**************************************************************************

;**************************************************************************
;	GetGoing
;
;	Expects: RHIsr2 - Speed
;		 RHIsr1 - Angle  (0-180), T-flag angle direction 
;					(set to turn left)
;		 RZIsrH-L - Distance
;		 RHIsr3 - Set to go left otherwise cleared
;
;	Changes: RHIsr3
;	Must Not Change: Non ISR registers (called from an ISR)
;
;	Begins the execution of a go message.
;**************************************************************************	
GoBufferFull2:
	Error	GoBufferFullErr
	ret

GG_AngleGo:
	; Check for a revese first
	cpi	RHIsr1, AngleReverse
	brne	GG_NotR
	; This is a reverse message
	; Get our direction
	bst	RHFlags, DirectionBit
	ToggleT
	rjmp	GG_GoNowWT
	
GG_NotR:
	; When we get here T-flag contains our auto-switch mode.
	; First of all we have to push our go message back on the buffer
	; with angle cleared.
	push	RHIsr1
	clr	RHIsr1		; Clear the angle
	MultiByteCircularQueueAddFrontProc GoBufferFull2, RYIsr, GoBuffer
	st	Y+, RHIsr2	; First store the speed
	st	Y+, RHIsr1	; The angle
	st	Y+, RHIsr3	; The flags
	stw	Y+, RZIsr	; And the distance
	pop	RHIsr1		; Restore the angle
	
	; Okay now all we have to do is get us pointing in the right
	; direction and our go message will taken off the buffer and
	; executed.
	; First see if it is higher than 45 degrees if autoswitch is set
	brtc	GG_Turn
	
	cpi	RHIsr1, 90
	brsh	GG_Higher
	; This is lower than 90 degrees so we should not swap direction
GG_Turn:
	; Turn at 8 degrees a second
	; RHIsr3 decides whether we turn left or right
	; Go time is store in milliseconds
	; Angle turns at 1 degree every 1/8 of s a second
	; 1/8 of a second is 125 milliseconds ~= 128
	clr	RZIsrL
	mov	RZIsrH, RHIsr1	; Divide angle by 2
	lsr	RZIsrH
	ror	RZIsrL	
	stsw	GoTimeRemaining, RZIsr
	clr	RHIsr1
	sts	GoTimeRemainingExtra, RHIsr1
	
	; Now go at 255
	bst	RHFlags, DirectionBit
	brtc	GG_NT
	; When we are reverse left and right is swapped
	tst	RHIsr3
	brnz	GG_GoRight
	rjmp	GG_GoLeft
GG_NT:
	tst	RHIsr3
	brze	GG_GoRight
GG_GoLeft:	
	; Go left at 255
	bst	RHFlags, DirectionBit
	ldi	RHIsr1, 0xff
	ldi	RHIsr3, 0xff
	rcall	SetRMotorSpeed
	bst	RHFlags, DirectionBit
	ToggleT	; Left motor goes in reverse
	ldi	RHIsr1, 0xff
	ldi	RHIsr3, 0xff
	rcall	SetLMotorSpeed
	ret
	
GG_GoRight:
	; Go right at 255
	bst	RHFlags, DirectionBit
	ToggleT
	ldi	RHIsr1, 0xff
	ldi	RHIsr3, 0xff
	rcall	SetRMotorSpeed	; Right motor goes in reverse
	bst	RHFlags, DirectionBit
	ldi	RHIsr1, 0xff
	ldi	RHIsr3, 0xff
	rcall	SetLMotorSpeed
	ret
	
GG_Higher:
	push	RHIsr1	; Save angle
	push	RHIsr3  ; Direction
	pushw	RZIsr   ; distance
	rcall	SwapDirection
	popw	RZIsr
	pop	RHIsr3
	pop	RHIsr1
	; Subtract the angle from 180
	ldi	RHIsr2, 180
	sub	RHIsr2, RHIsr1
	; Move the result back
	mov	RHIsr1, RHIsr2
	; Swap the direction
	ldi	RHIsr2, GoFlagDirectionBit
	eor	RHIsr1, RHIsr2
	rjmp	GG_Turn

GetGoing:
	; Make sure speed is higher than the minimum speed.
	lds	RYIsrL, MinSpeed
	cp	RHIsr2, RYIsrL
	brsh	GG_SpeedOkay
	; Speed was not as high as the minimum speed
	mov	RHIsr2, RYIsrL	
GG_SpeedOkay:

	; If the angle is not 0 and we are not in auto-switch mode
	; that means we will have to turn.
	tst	RHIsr1
	brze	GG_NoAngleGo
	bst	RHFlags, SwitchMode
	lbrtc	GG_AngleGo
	; If we are in auto-switch direction mode and our angle is
	; 180 then we wont have to turn.
	cpi	RHIsr1, 180
	lbrne	GG_AngleGo
	; We have to swap direction before we can take care of this message
	; Once we swap direction it will be just like a straight ahead
	; messsage.
GG_SwapGo:
	push	RHIsr2	; Save Speed
	pushw	RZIsr	; Distance
	rcall	SwapDirection
	popw	RZIsr	; Distance
	pop	RHIsr2	; Get speed back
	
GG_NoAngleGo:
	; Okay this is a nice easy message becuase it is just straight
	; ahead at whatever speed for whatever distance.
	; Go the direction we are facing
	bst	RHFlags, DirectionBit
GG_GoNowWT:
	; Distance * SpeedTimeFactor / Speed = Number of milliseconds to go
	; TEMP
	;ldsw	RYIsr, SpeedTimeFactor
	;rcall	Mul16x16to32U
	; Now divide result by the speed we will be going and that tells
	; us how long it will take us (guessing).
	; Divide by speed
	;rcall	Div32d16to16U
	; The speed to go is now in Z - multiply by 16
	clr	RHIsr1
	lsl	RZIsrL
	rol	RZIsrH
	rol	RHIsr1	; * 2
	lsl	RZIsrL
	rol	RZIsrH
	rol	RHIsr1	; * 2 * 2
;	lsl	RZIsrL
;	rol	RZIsrH
;	rol	RHIsr1	; * 2 * 2 * 2
;	lsl	RZIsrL
;	rol	RZIsrH
;	rol	RHIsr1	; * 2 * 2 * 2 * 2 = * 16
	stsw	GoTimeRemaining, RZIsr
	sts	GoTimeRemainingExtra, RHIsr1
	
	in	RHIsr1, SREG
	push	RHIsr1	; Save T flag
	; Output the speed
	mov	RHIsr1, RHIsr2
	mov	RHIsr3, RHIsr1
	push	RHIsr1	; Save it for setting right speed
	rcall	SetLMotorSpeed
	
	pop	RHIsr1 ; Load the speed
	pop	RHIsr3	; Load T Flag
	out	SREG, RHIsr3
	mov	RHIsr3, RHIsr1	; Put the speed in RHIsr3 as well
	rcall	SetRMotorSpeed
	; Update the lights
	rjmp	UpdateSharedLights
;**************************************************************************	
;	/GetGoing
;**************************************************************************	

;**************************************************************************
;	SwapDirection
;
;	Expects: 
;	Changes: RHIsr1, RZIsrH, RZIsrL
;	Must Not Change: Non ISR registers (called from an ISR)
;
;	Changes direction to the opposite of what it was.
;**************************************************************************	
SwapDirection:
	; They are not equal we are changing direction.
	ldi	RHIsr1, (1 << DirectionBit)
	eor	RHFlags, RHIsr1
	; Now we need to update all the lights
	rcall	UpdateConstantLightsADC
	rjmp	UpdateSharedLights	; This will update things like the reversing
	; lights etc.
;**************************************************************************
;	/SwapDirection
;**************************************************************************

;**************************************************************************
;	SendByteToUART
;
;	Expects: RHIsr1 - Byte to send
;	Changes: RHIsr1, RYIsrL
;	Must Not Change: Non ISR registers (called from an ISR)
;
;	Waits for UDRE to be set and then outputs the byte.
;**************************************************************************	
SendByteToUART:
	rcall	GetParity
SBTU:	bric	USR, UDRE, SBTU
	out	UDR, RHIsr1
	ret
;**************************************************************************	
;	/SendByteToUART
;**************************************************************************	

;**************************************************************************
;	BeginBigMessage
;
;	Expects: RHIsr1 - header of the message to send
;	Changes: RHIsr1, RZIsrH, RHIsr2, RHIsr3
;	Must Not Change: Non ISR registers (called from an ISR)
;
;	Checks that the Tx buffer is empty. If it is not it logs and error and
;	double returns (ie returns from the routine that called it by popping
;	stuff off the stack. Otherwise enables the Tx and sends the first part
;	of the message. This is the samem as BeginMessage except it is for
;	big messages that do not use the buffer.
;**************************************************************************	
BeginBigMessage:
	; Check that the buffer is empty
	lds	RZIsrL, TxBufferLen
	tst	RZIsrL
	brnz	BBM_NotEmpty
	; Check that it has finished sending the last character (a CR).
	bris	UCR, UDRIE, BBM_NotEmpty
	; Check that its actually finished (not just started sending it).
	bris	USR, UDRE, BBM_Empty
BBM_NotEmpty:
	; The buffer was not empty
	; If we are in debug mode then disable it for a bit so that we dont spin
	; around in a loop (because the error handler will call dump).
	bst	RHFlags, DebugBit
	cbr	RHFlags, (1 << DebugBit)
	ComsError	ComsBufferInUse
	bld	RHFlags, DebugBit
	; And pop off the first return so we return from the other routine
	pop	RHIsr1
	pop	RHIsr1
	ret	; Return
BBM_Empty:
        SetCommsTx
        ret
;**************************************************************************
;	/BeginBigMessage
;**************************************************************************

;**************************************************************************
;	BeginMessage
;
;	Expects: RHIsr1 - header of the message to send
;		 RZIsrH - Length of the message to send
;	Changes: RHIsr1, RZIsrL, RHIsr2, RHIsr3
;	Must Not Change: Non ISR registers (called from an ISR)
;
;	Checks that the Tx buffer is empty. If it is not it logs and error and
;	double returns (ie returns from the routine that called it by popping
;	stuff off the stack. Otherwise enables the Tx and sends the first part
;	of the message.
;**************************************************************************	
BeginMessage:
	; Check that the buffer is empty
	lds	RZIsrL, TxBufferLen
	tst	RZIsrL
	brnz	CTBE_NotEmpty
	; Check that it has finished sending the last character (a CR).
	bris	UCR, UDRIE, CTBE_NotEmpty
	; Check that its actually finished (not just started sending it).
	bris	USR, UDRE, CTBE_Empty
CTBE_NotEmpty:
	; The buffer was not empty
	; If we are in debug mode then disable it for a bit so that we dont spin
	; around in a loop (because the error handler will call dump).
	bst	RHFlags, DebugBit
	cbr	RHFlags, (1 << DebugBit)
	ComsError	ComsBufferInUse
	bld	RHFlags, DebugBit
	; And pop off the first return so we return from the other routine
	pop	RHIsr1
	pop	RHIsr1
CTBE_Empty:
	; If it is empty then begin the message
        SetCommsTx
	sbi	UCR, UDRIE	; Must enable this interupt to send the buffer
	; Save the message
	sts	TxMsg, RHIsr1
	; Send our ID first
	ldi	RHIsr1, MY_ID
	rcall	GetParity
	out	UDR, RHIsr1
	; Save the length
	sts	TxBufferLen, RZIsrH
	
	ret
;**************************************************************************
;	/BeginMessage
;**************************************************************************

;**************************************************************************
;	SendHWord
;
;	Expects: RZIsr - Word to send in hex
;	Changes: RHIsr1
;	Must Not Change: Non ISR registers (called from an ISR)
;
;	Converts the data in RZIsrH to a hex word (with leading zeroes)
;	and sends it.
;**************************************************************************	
SendHWord:
	mov	RHIsr1, RZIsrH
	swap	RHIsr1			; Send the high nibble
SHW_1:	bric	USR, UDRE, SHW_1
	rcall	SendASCIIHexNibble
	mov	RHIsr1, RZIsrH
SHW_2:	bric	USR, UDRE, SHW_2
	rcall	SendASCIIHexNibble	; Send the low nibble
	mov	RHIsr1, RZIsrL
	swap	RHIsr1
SHW_3:	bric	USR, UDRE, SHW_3
	rcall	SendASCIIHexNibble
	mov	RHIsr1, RZIsrL
SHW_4:	bric	USR, UDRE, SHW_4
	rcall	SendASCIIHexNibble
	ret
;**************************************************************************
;	/SendHWord
;**************************************************************************

;**************************************************************************
;	SendHByte
;
;	Expects: RHIsr - Byte to send in hex
;	Changes: RHIsr1
;	Must Not Change: Non ISR registers (called from an ISR)
;
;	Converts the data in RHIsr1 to a hex word (with leading zeroes)
;	and sends it.
;**************************************************************************	
SendHByte:
	push	RHIsr1
	swap	RHIsr1			; Send the high nibble
SHB_1:	bric	USR, UDRE, SHB_1
	rcall	SendASCIIHexNibble	
	pop	RHIsr1			; Send the low nibble
SHB_2:	bric	USR, UDRE, SHB_2
	rcall	SendASCIIHexNibble
	ret
;**************************************************************************
;	/SendHByte
;**************************************************************************

;**************************************************************************
;	SendASCIIHexNibble
;
;	Expects: RHIsr1 - Nibble to convert (in lower nibble)
;	Changes: RHIsr1
;	Must Not Change: Non ISR registers (called from an ISR)
;
;	Converts the data in the lower nibble in RHIsr1 to ASCII hex and outputs
;	it (after adding parity). 
;**************************************************************************	
SendASCIIHexNibble:
	; The nibble to send is contained in the lower half of RHIsr1
	; All we have to do is convert the nibble to ASCII (w. parity), send it
	; and return.
	; -Convert the nibble to ASCII
	andi	RHIsr1, 0x0f	; AND off the upper nibble (not relevant)
	subi	RHIsr1, -48	; Add 0
	cpi	RHIsr1, 58	
	brlo	SAHN_NotOver	; Check if it was between 0-9 or a-f
	subi	RHIsr1, -39
SAHN_NotOver:
	rcall	GetParity
	; Output it
	out	UDR, RHIsr1
	ret
;***********************************************************************
;	/SendASCIIHexNibble
;***********************************************************************
	
;***********************************************************************
;	SetLMotorSpeed
;
;	Expects: A value in RHIsr1. It expects the direction
;	to be in T (set if reversing). RHIsr2 - The appearance speed you want to go
;	Changes: RHIsr1, RLLeftSpeed, RZIsrL, RZIsrH, RHIsr2
;	Must Not Change: Non ISR registers (called from an ISR)
;
;	Updates the motor speed and lighting for the left motor. After calling
;	this you need to call UpdateSharedLights.
;**************************************************************************	
ULM_ZeroSpeed:
	; This is called when we are changing direction but
	; our speed is zero.
	; Just toggle direction and jump to ULM_NoDirChange
	in	RZIsrL, MotorDirPort
	bld	RZIsrL, MotorDirL
	out	MotorDirPort, RZIsrL
	rjmp	ULM_NoDirChange

SetLMotorSpeed:
	; First off all store the speed we want to go
	sts	LSpeed, RHIsr1
	; Check if we are changing direction.
	bris	MotorDirPort, MotorDirL, ULM_TSet
	; C contains the direction we want to be going. Compare with how we are going.
	; Compare the two. If they are the same then we just output our speed.
	; Otherwise we have to wait to slow down.
	brtc	ULM_NoDirChange
	rjmp	ULM_Change
ULM_TSet:
	brts	ULM_NoDirChange
ULM_Change:
	; First check if our current speed is zero and we are not counting down
	; the time to switch then it is okay to change direction right away
	lds	RZIsrL, LTimeToSwitch	; If there is already a value there
	tst	RZIsrL			; than leave it. It means we were
	brnz	ULM_Done	; called again before we had time to 
	in	RZIsrH, MotorPWMLL	; change direction.
	tst	RZIsrH
	brze	ULM_ZeroSpeed
	; Direction is changing we cant put in the new value right
	; away.
	; Stop moving
	clr	RZIsrL
	out	MotorPWMLH, RZIsrL
	out	MotorPWMLL, RZIsrL
	; The time before we change direction is just our current
	; speed 0-255 in milliseconds.
	sts	LTimeToSwitch, RLLeftSpeed	; and save it.
	rjmp	ULM_Done

ULM_NoDirChange:
	; We are not changing direction so we can just output our direction
	; right away.
	clr	RZIsrL
	out	MotorPWMLH, RZIsrL
	out	MotorPWMLL, RHIsr1
	; Clear the time to switch count
	sts	LTimeToSwitch, RZIsrL

	; Just set the running lights and blinkers going if necessary
ULM_Done:
	; Store our speed in the speed register
	mov	RLLeftSpeed, RHIsr3
	tst	RLLeftSpeed
	brne	ULM_DontTurnOff
	; We are stopped on this side so turn off the running lights
	ldi	RHIsr1, 0b00011111
	and	RLRunningReg, RHIsr1
	clrw	RHLRunCnt	; Clear the left run count.
	ret
ULM_DontTurnOff:
	cp	RLLeftSpeed, RLRightSpeed
	brne	ULM_NotTheSame
	; Now we have to put the count in from the right side
	mvw	RHLRunCnt, RXRRunCnt
	; And the reload
	ldsw	RZIsr, RRunningReload
	stsw	LRunningReload, RZIsr
	; Compare our direction with R Motor direction
	rcall	GetRMotorDir
	brcs	ULM_Backwards
	brtc	ULM_TheSame
	rjmp	ULM_DifferentDir
ULM_Backwards:
	brts	ULM_TheSame
ULM_DifferentDir:
	; We are going a different direction but at the same speed so we should put 
	; both our lights at the same speed in the oppsite direction.
	bst	RLRunningReg, 0
	bld	RLRunningReg, 5
	bst	RLRunningReg, 1
	bld	RLRunningReg, 6
	bst	RLRunningReg, 2
	bld	RLRunningReg, 7
	ret
ULM_TheSame:
	; We are going the same speed as the right motor so our running lights should
	; be in sinc if we are going the same direction.
	mov	RHIsr1, RLRunningReg
	swap	RHIsr1
	lsl	RHIsr1
	andi	RHIsr1, 0b11100000
	ldi	RZIsrL, 0b00011111	; Clear the old lights
	and	RLRunningReg, RZIsrL
	or	RLRunningReg, RHIsr1
	; And now were done
	ret

ULM_NotTheSame:
	; Get the running lights going
	mov	RZIsrL, RLLeftSpeed	; Get the timeout which will be used later.
	rcall	GetMovingLightsTimeout	; Stored in Z
	; Save the reload
	stsw	LRunningReload, RZIsr	
	; Check if we are already updating lights
	brwnz	RHLRunCnt, SL_AlreadyMoving	
	; We were not already going so get the blinkers going.
	mvw	RHLRunCnt, RZIsr
	; Turn on the first light
	brts	SL_GoingBackwards
	; We are going forwards so start the light at the front
	set
	bld	RLRunningReg, 5	
	rjmp	Skip3
SL_GoingBackwards:
	bld	RLRunningReg, 7
Skip3:
	ret
	
SL_AlreadyMoving:
	; We were already moving so we just have to make sure this is 
	; not above the time out.
	brwh	RZIsr, RHLRunCnt, SL_NotHigher
	; Higher so reload
	mvw	RHLRunCnt, RZIsr
SL_NotHigher:	
	ret
;**************************************************************************
;	/SetLMotorSpeed
;**************************************************************************

;***********************************************************************
;	SetRMotorSpeed
;
;	Expects: A value in RHIsr1. It expects the direction
;	to be in T (set if reversing).  RHIsr3 - The appearance speed you want to go
;	Changes: RHIsr1, RLRightSpeed, RZIsrL, RZIsrH, RHIsr2, RHIsr3
;	Must Not Change: Non ISR registers (called from an ISR)
;
;	Updates the motor speed and lighting for the right motor. After calling
;	this you need to call UpdateSharedLights.
;**************************************************************************	
URM_ZeroSpeed:
	; This is called when we are changing direction but
	; our speed is zero.
	; Just toggle direction and jump to URM_NoDirChange
	in	RZIsrL, MotorDirPort
	bld	RZIsrL, MotorDirR
	out	MotorDirPort, RZIsrL
	rjmp	URM_NoDirChange

SetRMotorSpeed:
	; First off all store the speed we want to go
	sts	RSpeed, RHIsr1
	; Check if we are changing direction.
	bris	MotorDirPort, MotorDirR, URM_TSet
	; C contains the direction we want to be going. Compare with how we are going.
	; Compare the two. If they are the same then we just output our speed.
	; Otherwise we have to wait to slow down.
	brtc	URM_NoDirChange
	rjmp	URM_Change
URM_TSet:
	brts	URM_NoDirChange
URM_Change:
	; First check if our current speed is zero and we are not counting down
	; the time to switch then it is okay to change direction right away
	lds	RZIsrL, RTimeToSwitch	; If there is already a value there
	tst	RZIsrL			; than leave it. It means we were
	brnz	URM_Done	; called again before we had time to 
	in	RZIsrH, MotorPWMRL	; change direction.
	tst	RZIsrH
	brze	URM_ZeroSpeed
	; Direction is changing we cant put in the new value right
	; away.
	; Stop moving
	clr	RZIsrL
	out	MotorPWMRH, RZIsrL
	out	MotorPWMRL, RZIsrL
	; The time before we change direction is just our current
	; speed 0-255 in milliseconds.
	sts	RTimeToSwitch, RLRightSpeed	; and save it.
	rjmp	URM_Done

URM_NoDirChange:
	; We are not changing direction so we can just output our direction
	; right away.
	clr	RZIsrL
	out	MotorPWMRH, RZIsrL
	out	MotorPWMRL, RHIsr1
	; Clear the time to switch count
	sts	RTimeToSwitch, RZIsrL
	
	; Just set the running lights and blinkers going if necessary
URM_Done:
	; Store our speed in the speed register
	mov	RLRightSpeed, RHIsr3
	tst	RLRightSpeed
	brne	URM_DontTurnOff
	; We are stopped on this side so turn off the running lights
	ldi	RHIsr1, 0b11111000
	and	RLRunningReg, RHIsr1
	; Clear the run count
	clrw	RXRRunCnt
	ret
URM_DontTurnOff:
	cp	RLLeftSpeed, RLRightSpeed
	brne	URM_NotTheSame
	; Now we have to put the count in from the right side
	mvw	RXRRunCnt, RHLRunCnt
	; And the reload
	ldsw	RZIsr, LRunningReload
	stsw	RRunningReload, RZIsr
	; T contains our direction compare it with right direction.
	rcall	GetLMotorDir
	brcs	URM_Backwards
	brtc	URM_TheSame
	rjmp	URM_DifferentDir
URM_Backwards:
	brts	URM_TheSame
URM_DifferentDir:
	; We are going a different direction but at the same speed so we should put 
	; both our lights at the same speed in the oppsite direction.
	bst	RLRunningReg, 5
	bld	RLRunningReg, 0
	bst	RLRunningReg, 6
	bld	RLRunningReg, 1
	bst	RLRunningReg, 7
	bld	RLRunningReg, 2
	ret
URM_TheSame:
	; We are going the same speed as the right motor so our running lights should
	; be in sinc if we are going the same direction.
	mov	RHIsr1, RLRunningReg
	swap	RHIsr1
	lsr	RHIsr1
	andi	RHIsr1, 0b00000111
	ldi	RZIsrL, 0b11111000	; Clear the old lights
	and	RLRunningReg, RZIsrL
	or	RLRunningReg, RHIsr1
	; And now were done
	ret

URM_NotTheSame:
	; Get the running lights going
	mov	RZIsrL, RLRightSpeed	; Get the timeout which will be used later.
	rcall	GetMovingLightsTimeout	; Stored in Z
	; Save the reload
	stsw	RRunningReload, RZIsr
	
	; Check if we are already updating lights
	brwnz	RXRRunCnt, SR_AlreadyMoving	
	; We were not already going so get the blinkers going.
	mvw	RXRRunCnt, RZIsr
	; Turn on the first light
	brts	SR_GoingBackwards
	; We are going forwards so start the light at the front
	set
	bld	RLRunningReg, 0	
	rjmp	Skip4
SR_GoingBackwards:
	bld	RLRunningReg, 2
Skip4:
	ret
	
SR_AlreadyMoving:
	; We were already moving so we just have to make sure this is 
	; not above the time out.
	brwh	RZIsr, RXRRunCnt, SR_NotHigher
	; Higher so reload
	mvw	RXRRunCnt, RZIsr
SR_NotHigher:	
	ret
;**************************************************************************
;	/SetRMotorSpeed
;**************************************************************************

;**************************************************************************
;	UpdateConstantLights
;
;	Expects:	
;	Changes: RHIsr1, RYIsr
;	Must Not Change: Non ISR registers (called from an ISR)
;	Returns:
;
;	This subroutine updates the headlights and breaklights. To complete
;	switching direction you should also call UpdateSharedLights. Jump to
;	UpdateConstantLightsADC if we just changed direction otherwise
;	dont as this disrupts blinkers.
;
;**************************************************************************	
UCL_BeginTest:
	; If we are in debug mode we can just return
	brrs	RHFlags, DebugBit, UCL_Debug
	; See if we were doing this
	lds	RHIsr1, LTestFlags
	tst	RHIsr1
	brnz	UCL_DoneLT
	RefreshMM
	; Start doing something fancy
	ldi	RHIsr1, 1
	sts	TestMM, RHIsr1
	clr	RHIsr1
	sts	TestMM + 1, RHIsr1
	sts	TestMM + 2, RHIsr1
	sts	TestMM + 3, RHIsr1
	sts	TestMM + 4, RHIsr1
	; And clear the pause count
	sts	LTestPauseOff, RHIsr1
	; And the count
	ldi	RHIsr1, DefaultMMCountdownReload
	sts	TestMMCountdown, RHIsr1
	; Start of the headlight of the direction we are going
	ldi	RHIsr1, ((DefaultTestMM) | (1 << LTGoing))
	bst	RHFlags, DirectionBit
	bld	RHIsr1, LTDirection
	sts	LTestFlags, RHIsr1
	; Start off at full intensity
	ldi	RHIsr1, HIntensityInvalid
	sts	LTHIntensity, RHIsr1
	; A store the reload count
	ldiw	RZIsr, TestCountReload
	stsw	TestMMCount, RZIsr
UCL_DoneLT:
	ret
UCL_Debug:
	RefreshMM
	sbi	HeadlightPort, HeadlightF	; Turn on the headlights
	sbi	HeadlightPort, HeadlightB	; The MM lights will come on automatically
	clr	RHIsr1
	sts	LTestFlags, RHIsr1
	
	ret
UpdateConstantLightsADC:
	; We will be disrupting blinkers
	ldi	RHBlinkerStatus, BlinkersOff
	clrw	RZIsr
	stsw	ReverseCnt, RZIsr	; Clear the reverse count.
UpdateConstantLights:
	; We dont need to RefreshMM because UpdateSharedLights will
	; be called after us.
	; Check if headlights and brakelights should be on.
	lds	RHIsr2, Lights	; Keep lights in RHIsr2 for use later
	cpi	RHIsr2, LTest	; Check if we are testing
	breq	UCL_BeginTest	; See if lights should be all-off
	; If we are not clear the test flags
	ldi	RHIsr1, 0	; Use ldi so it doesnt affect the flags
	sts	LTestFlags, RHIsr1
	cpi	RHIsr2, LOff
	breq	UH_AllOff
	brrs	RHFlags, StealthBit, UH_AllOff
	lds	RHIsr1, BatPower
	cpi	RHIsr1, BPNormal
	brne	UH_AllOff
	
	; If headlights arent on turn them off
	cpi	RHIsr2, LFull
	breq	UH_OFLOn
	cbi	HeadlightPort, HeadlightF
	cbi	HeadlightPort, HeadlightB
UH_OFLOn:	; We dont need to turn them on - theyll come on automatically.

	; The lights should be on so turn them on and turn the other sides
	; brake lights. We can safely ignore the W lights that should be
	; turned off because the other subroutine UpdateSharedLights will
	; be called after us and it will turn them off if necessary.
	; Load our direction in T
	bst	RHFlags, DirectionBit
	brts	UH_OnBackwards
	; We are going forwards and lights should be on.
	; If we are changing
	; Turn on front W lights
	; If we are not changing direction (C cleared) then test what direction
	; blinkers are going (if blinkers were not on carry will have been
	; set).
	mov	RHIsr1, RLFWhiteReg
	rcall	TurnOnWLights
	mov	RLFWhiteReg, RHIsr1
	; Turn off front red lights
	clt
	bld	RLExtraReg, MMFrontRedBit
	; Turn on back red lights
	set
	bld	RLExtraReg, MMBackRedBit
	
	ret
	
UH_OnBackwards:
	; We are going backwards and the lights should be on
	; Turn on back W lights
	mov	RHIsr1, RLBWhiteReg
	rcall	TurnOnWLights
	mov	RLBWhiteReg, RHIsr1
	; Turn on front red lights
	set
	bld	RLExtraReg, MMFrontRedBit
	; Turn off back red lights
	clt
	bld	RLExtraReg, MMBackRedBit
	
	ret
	
UH_AllOff:
	; Headlights should be off, we dont know what direction we were
	; going so just turn off both.
	cbi	HeadlightPort, HeadlightF
	cbi	HeadlightPort, HeadlightB
	; Turn off front red lights
	clt
	bld	RLExtraReg, MMFrontRedBit
	; Turn off W lights
	bst	RHFlags, DirectionBit
	brts	UH_AllOffB
	
	; We are going forwards and W lights should be off except for blinkers.
	mov	RHIsr1, RLFWhiteReg
	rcall	TurnOffWLights
	mov	RLFWhiteReg, RHIsr1
	; Turn off back W lights
	clr	RLBWhiteReg
	; Turn off back headlight
	cbi	HeadlightPort, HeadlightF
	; Turn off back red light
	clt
	bld	RLExtraReg, MMBackRedBit
	ret
	
UH_AllOffB:
	; We are going backwards and W lights should be off except for blinkers.
	mov	RHIsr1, RLBWhiteReg
	rcall	TurnOffWLights
	mov	RLBWhiteReg, RHIsr1
	; Turn off front W lights
	clr	RLFWhiteReg
	; Turn off front headlight
	cbi	HeadlightPort, HeadlightF
	; Turn off back red lights
	clt
	bld	RLExtraReg, MMBackRedBit
	
	ret
;**************************************************************************
;	/UpdateConstantLights
;**************************************************************************

;**************************************************************************
;	TurnOffWLights
;
;	Expects: A value in RHIsr1
;	Changes: RHIsr1, RZIsrL
;	Must Not Change: Non ISR registers (called from an ISR)
;	Returns:
;
;	This is a helper function for UpdateConstantLights. Its is called
;	to turn off the W lights without causing trouble to the blinkers.
;
;**************************************************************************	
TurnOffWLights:
	cpi	RHBlinkerStatus, BlinkersLeft
	brlo	TOWL_ChangingDir	; Blinkers are off
	breq	TOWL_TurningLeft
	; We are turning right at the moment. Lights should be off except for the
	; blinking one. If lights were already on at least two of the lights
	; will be on. If lights were off only one of the lights could possibly be
	; on. This  means the W lights just went off and we need to invert 
	; the lights.
	bld	RHIsr1, 0
	brts	TOWL_OneOn
	; Test the second bit
	bld	RHIsr1, 1
	; If both 0 and 1 were on then the lights are on and 
	; need to be inverted.
	brts	TOWL_RightInvert
	; If 0 is on and 1 is off then we need to test bit 3
TOWL_Test3:
	bld	RHIsr1, 2
	; If 3 is clear then the lights were already off
	brtc	TOWL_Exit
	; Otherwise they need inverting.	
	rjmp	TOWL_RightInvert
TOWL_OneOn:
	bld	RHIsr1, 1
	; If both 0 and 1 were on then the lights are already on.
	brtc	TOWL_Test3
	; Otherwise we need to invert

TOWL_RightInvert:
	ldi	RZIsrL, 0b00000111	; Flip the blinkers on that side
	eor	RHIsr1, RZIsrL
	cbr	RHIsr1, 0b11100000	; Turn off the other lights
	
	ret
	
TOWL_TurningLeft:
	; We are turning lights at the moment. Lights should be off except for the
	; blinking one. If lights were already on at least two of the lights
	; will be on. If lights were only one of the lights could possibly be
	; on. This  means the W lights just came off and we need to invert 
	; the lights.
	bld	RHIsr1, 7
	brts	TOWL_LOneOn
	; Test the second bit
	bld	RHIsr1, 6
	; If both 0 and 1 were on then the lights are on and 
	; need to be inverted.
	brts	TOWL_LeftInvert
	; If 0 is on and 1 is off then we need to test bit 3
TOWL_LTest3:
	bld	RHIsr1, 5
	; If 3 is set then the lights were already on
	brtc	TOWL_Exit
	; Otherwise they need inverting.	
	rjmp	TOWL_LeftInvert
TOWL_LOneOn:
	bld	RHIsr1, 6
	; If both 0 and 1 were on then the lights are already on.
	brtc	TOWL_Exit
	rjmp	TOWL_LTest3	; Otherwise we need to test bit 3

TOWL_LeftInvert:
	ldi	RZIsrL, 0b11100000	; Flip the blinkers on that side
	eor	RHIsr1, RZIsrL
	cbr	RHIsr1, 0b00000111	; Turn off the other lights
	
	ret
	
TOWL_ChangingDir:
	cbr	RHIsr1, 0b11100111
TOWL_Exit:
	ret
;**************************************************************************
;	/TurnOffWLights
;**************************************************************************

;**************************************************************************
;	TurnOnWLights
;
;	Expects: A value in RHIsr1
;	Changes: RHIsr1, RZIsrL
;	Must Not Change: Non ISR registers (called from an ISR)
;	Returns:
;
;	This is a helper function for UpdateConstantLights. Its is called
;	to turn on the W lights without causing trouble to the blinkers.
;
;**************************************************************************	
TurnOnWLights:
	cpi	RHBlinkerStatus, BlinkersLeft
	brlo	UWL_ChangingDir
	breq	UWL_TurningLeft
	; We are turning right at the moment. Lights should be on except for the
	; blinking one. If lights were already on at least two of the lights
	; will be on. If lights were only one of the lights could possibly be
	; on. This  means the W lights just came on and we need to invert 
	; the lights.
	bld	RHIsr1, 0
	brts	UWL_OneOn
	; Test the second bit
	bld	RHIsr1, 1
	; If both 0 and 1 were off then the lights are off and 
	; need to be inverted.
	brtc	UWL_RightInvert
	; If 0 is on and 1 is off then we need to test bit 3
UWL_Test3:
	bld	RHIsr1, 2
	; If 3 is set then the lights were already on
	brts	UWL_Exit
	; Otherwise they need inverting.	
	rjmp	UWL_RightInvert
UWL_OneOn:
	bld	RHIsr1, 1
	; If both 0 and 1 were on then the lights are already on.
	brts	UWL_Exit
	rjmp	UWL_Test3	; Otherwise we need to test bit 3

UWL_RightInvert:
	ldi	RZIsrL, 0b00000111	; Flip the blinkers on that side
	eor	RHIsr1, RZIsrL
	sbr	RHIsr1, 0b11100000	; Turn on the other lights

	ret
	
UWL_TurningLeft:
	; We are turning lights at the moment. Lights should be on except for the
	; blinking one. If lights were already on at least two of the lights
	; will be on. If lights were only one of the lights could possibly be
	; on. This  means the W lights just came on and we need to invert 
	; the lights.
	bld	RHIsr1, 7
	brts	UWL_LOneOn
	; Test the second bit
	bld	RHIsr1, 6
	; If both 0 and 1 were off then the lights are off and 
	; need to be inverted.
	brtc	UWL_LeftInvert
	; If 0 is on and 1 is off then we need to test bit 3
UWL_LTest3:
	bld	RHIsr1, 5
	; If 3 is set then the lights were already on
	brts	UWL_Exit
	; Otherwise they need inverting.	
	rjmp	UWL_LeftInvert
UWL_LOneOn:
	bld	RHIsr1, 6
	; If both 0 and 1 were on then the lights are already on.
	brts	UWL_Exit
	rjmp	UWL_LTest3	; Otherwise we need to test bit 3

UWL_LeftInvert:
	ldi	RZIsrL, 0b11100000	; Flip the blinkers on that side
	eor	RHIsr1, RZIsrL
	sbr	RHIsr1, 0b00000111	; Turn on the other lights
		
	ret
	
UWL_ChangingDir:
	ori	RHIsr1, 0b11100111
UWL_Exit:
	ret
;**************************************************************************
;	/UpdateWLights
;**************************************************************************
		
;**************************************************************************
;	UpdateSharedLights
;
;	Expects: A value in RLRightSpeed, RLLeftSpeed
;	Changes: RHIsr1, RZIsrL, RZIsrH
;	Must Not Change: Non ISR registers (called from an ISR)
;	Returns: Carry set if blinkers are going
;
;	This is a subroutine to set the blinkers going and the reversing 
; 	lights. These are shared by the left and right motor.
;
;**************************************************************************	
UpdateSharedLights:	
	RefreshMM
	ser	RZIsrL	; First time through RZIsrL is set
	bst	RHFlags, DirectionBit
	tst	RLRightSpeed	; If the speed is 0 then it doesnt matter
	brze	USL_NotReversing	; what direction.
	; Turn on the reversing lights if either motor is reversing
	rcall	GetRMotorDir
USL_Compare:
	; Compare C to T
	brts	USL_GoingB
	brcs	USL_Reversing		; If R motor isnt going forwards too
	rjmp	USL_NotReversing
USL_GoingB:
	brcs	USL_NotReversing	; If R motor isnt going backwards too
USL_Reversing:
	; At least one side is reversing. Set the reversing count to 500 milliseconds.
	ldsw	RYIsr, ReverseCnt	; If it already has a value just leave it.
	brwnz	RYIsr, USL_AlreadyReversing
	; Were not already reversing so save the reverse count.
	ldiw	RYIsr, ReverseCountReload
	stsw	ReverseCnt, RYIsr
	; Turn on the lights because were reversing (they will be flashed
	; by the SysTic interupt.
	ldi	RHIsr1, 0b11100111
	brtc	USL_OnBack
	; Turn on the front headlights
	or	RLFWhiteReg, RHIsr1
	rjmp	USL_DoneReversingLights
USL_OnBack:
	or	RLBWhiteReg, RHIsr1
	rjmp	USL_DoneReversingLights
	
USL_NotReversing:	; The first time we get here repeat using the L side.
	; If we get here a second time turn off the reversing lights in case
	; they were on.
	tst	RZIsrL
	brze	USL_ReallyNotReversing
	; Repeat it this time testing the L side.
	tst	RLLeftSpeed		; If the speed is zero then the 
	brze	USL_ReallyNotReversing	; direction doesnt matter.
	clr	RZIsrL
	rcall	GetLMotorDir
	rjmp	USL_Compare
USL_ReallyNotReversing:
	; We are not reversing so turn off the reverse lights in case we were reversing
	clrw	RYIsr
	stsw	ReverseCnt, RYIsr
	; Clear the count
	ldi	RHIsr1, 0b00011000
	brtc	USL_OffBack
	and	RLFWhiteReg, RHIsr1
	rjmp	USL_OffFront
USL_OffBack:
	and	RLBWhiteReg, RHIsr1
USL_OffFront:
	; We are not reversing so do the blinkers here for going forward.
	; Figure out which direction we are turning
	cp	RLLeftSpeed, RLRightSpeed
	lbreq	ClearBlinkers	; The ret is from this subroutine
	; Calcluate the difference
	mov	RHIsr1, RLLeftSpeed
	sub	RHIsr1, RLRightSpeed
	; Difference is inverted if right is higher than left
	brcc	USL_TurningRight
	; We are turning left and the difference is inverted
	com	RHIsr1
	rjmp	USL_TurningLeft
USL_DoneReversingLights:
USL_AlreadyReversing:
	; At least one of the motors is going backwards.
	; If RYIsrL is set then it was the right side and the
	; right side is going backwards.
	tst	RZIsrL
	brze	USL_Different
	rcall	GetLMotorDir
	; T contains our current direction. R direction is opposite
	; T. C contains L direction. If T is the same as C then we are 
	; going in opposite directions. Otherwise we are going in full
	; reverse.
	brts	USL_TSet1
	brcc	USL_NotReverse
	rjmp	USL_FullReverse
USL_TSet1:
	brcs	USL_NotReverse
	rjmp	USL_FullReverse
USL_NotReverse:
	; We are not going in full reverse. Only one motor is reversing.
	; Which motor that is is shown by RZIsrL
USL_Different:
	; The difference is the two speeds added together
	mov	RHIsr1, RLLeftSpeed
	add	RHIsr1, RLRightSpeed
	; If RZIsrL is cleared if L is reversing (we are turning left)
	tst	RZIsrL
	brze	USL_TurningLeft
USL_TurningRight:
	; We are turning right (in relation to the direction we are going)
	; RHIsr1 contains the speed of our turn.
	mov	RZIsrL, RHIsr1
	rcall	GetMovingLightsTimeout
	stsw	BlinkersReload, RZIsr	; Save it to the reload
	
	; If we are already going the same direction then just check that then count
	; is lower than ours and return. Otherwise just return.
	cpi	RHBlinkerStatus, BlinkersRight
	breq	USL_AlreadyGoing
	; We are not already going so we need clear the last lights if the left was
	; on.
	rcall	ClearBlinkers
	; Now we just need to set our blinkers going.
	; Lights blink off if they were on and lights blink on if they
	; were off.
	bst	RHFlags, DirectionBit
	ldi	RHIsr1, (1 << 2)
	ldi	RHBlinkerStatus, BlinkersRight
	brts	USL_TurningRBackwards
	; We are turning forwards to the right (definite forwards).
	eor	RLFWhiteReg, RHIsr1
	; Were done
	rjmp	USL_SaveCount
USL_TurningRBackwards:
	; We are turning backwards to the right (definite forwards)
	eor	RLBWhiteReg, RHIsr1
	; Were done
	rjmp	USL_SaveCount
	
USL_AlreadyGoing:
	; We are already going so just make sure that the count is lower
	; than the reload.
	ldsw	RYIsr, BlinkersCnt
	cp	RZIsrH, RYIsrH
	brlo	USL_SaveCount
	brne	USL_Exit
	cp	RZIsrL, RYIsrL
	brsh	USL_Exit
USL_SaveCount:
	stsw	BlinkersCnt, RZIsr
USL_Exit:
	ret

USL_TurningLeft:
	; We are turning left (in relation to the direction we are going)
	; RHIsr1 contains the speed of our turn.
	mov	RZIsrL, RHIsr1
	rcall	GetMovingLightsTimeout
	stsw	BlinkersReload, RZIsr		; Save it to the reload
	; If we are already going the same direction then just check that then count
	; is lower than ours and return. Otherwise just return.
	cpi	RHBlinkerStatus, BlinkersLeft
	breq	USL_AlreadyGoing
	; We are not already going so we need clear the last lights if the left was
	; on.
	rcall	ClearBlinkers
	ldi	RHBlinkerStatus, BlinkersLeft
	; Now we just need to set our blinkers going.
	; Lights blink off if they were on and lights blink on if they
	; were off.
	bst	RHFlags, DirectionBit
	ldi	RHIsr1, (1 << 5)
	brts	USL_TurningLBackwards
	; We are turning forwards to the left (definite forwards).
	eor	RLFWhiteReg, RHIsr1
	; Were done
	rjmp	USL_SaveCount
USL_TurningLBackwards:
	; We are turning backwards to the left (definite forwards)
	eor	RLBWhiteReg, RHIsr1
	; Were done
	rjmp	USL_SaveCount

USL_FullReverse:
	; Both tracks are reversing. Whichever on is going faster is the direction we
	; are going.
	; We are not reversing so do the blinkers here.
	; Figure out which direction we are turning
	cp	RLLeftSpeed, RLRightSpeed
	breq	ClearBlinkers	; return is from ClearBlinkers
	; Calcluate the difference
	mov	RHIsr1, RLLeftSpeed
	sub	RHIsr1, RLRightSpeed
	lsr	RHIsr1
	; Difference is inverted if right is higher than left
	brcc	USL_TurningRight
	; We are turning left and the difference is inverted
	com	RHIsr1
	cbr	RHIsr1, 0b10000000
	rjmp	USL_TurningLeft
;**************************************************************************	
;	/UpdateSharedLights
;**************************************************************************	

;**************************************************************************
;	ClearBlinkers
;
;	Expects: A value in RHBlinkerStatus
;	Changes: RLFWhiteReg, RLBWhiteReg
;	Must Not Change: Non ISR registers (called from an ISR)
;	Returns:
;
;**************************************************************************	
ClearBlinkers:
	ldi	RHBlinkerStatus, BlinkersOff	; The blinkers are now off.
	lds	RHIsr1, BatPower	; Check battery power before and
	cpi	RHIsr1, BPLow
	bst	RHFlags, DirectionBit
	brts	CB_Backwards
	; Were going forward so turn them off at the front
	cpi	RHIsr1, BPLow
	breq	CBF_Off
	; Turn them on
	ldi	RHIsr1, 0b11100111
	or	RLFWhiteReg, RHIsr1
	ret
CBF_Off:
	; Turn them off
	ldi	RHIsr1, 0b00011000
	and	RLFWhiteReg, RHIsr1
	ret
CB_Backwards:
	; Were going backwards so turn them off at the back
	breq	CBB_Off
	; Turn them on
	ldi	RHIsr1, 0b11100111
	or	RLBWhiteReg, RHIsr1
	ret
CBB_Off:
	; Turn them off
	ldi	RHIsr1, 0b00011000
	and	RLBWhiteReg, RHIsr1
	ret
;**************************************************************************	
;	/ClearBlinkers
;**************************************************************************	

;**************************************************************************
;	GetMovingLightsTimeout
;
;	Expects: A value in RZIsrL
;	Changes: RHIsr1, RZIsrL, RZIsrH
;	Must Not Change: Non ISR registers (called from an ISR)
;	Returns: Timeout in RZIsrL, RZIsrH
;
;	This is used to calculate the timeout for RHIsr4. This the timeout
;	for the blinkers and running lights in milliseconds based on the 
;	value in RZIsrL.
;**************************************************************************	
GetMovingLightsTimeout:
	; Multiply the inverted motor speed by 8 and add 250
	com	RZIsrL
	clc
	clr	RZIsrH
	rol	RZIsrL		; Multiply the two registers by 8
	rol	RZIsrH
	rol	RZIsrL
	rol	RZIsrH
	rol	RZIsrL
	rol	RZIsrH
	ldi	RHIsr1, 250		; Add 250
	add	RZIsrL, RHIsr1
	clr	RHIsr1
	adc	RZIsrH, RHIsr1

	ret
;**************************************************************************	
;	/GetMovingLightsTimeout
;**************************************************************************	

;**************************************************************************
;	GetLMotorDir
;
;	Expects: -
;	Uses:	RHIsr1
;	Returns: Motor direction in C
;	
;	This function returns the direction wed like to be going (for
;	the left side). This may be the opposite of the direction we are
; 	actually going if we are in the middle of changing direction.
;
;**************************************************************************
GetLMotorDir:
	; Our actual direction is the opposite of our direction pin
	; if we are in the middle of changing direction.
	lds	RHIsr1, LTimeToSwitch
	tst	RHIsr1
	brze	GLMD_NoInvert
	; We should invert it
	clc
	sbis	MotorDirPort, MotorDirL
	sec
	ret
GLMD_NoInvert:
	sec
	sbis	MotorDirPort, MotorDirL
	clc
	
	ret
;**************************************************************************	
;	/GetLMotorDir
;**************************************************************************	

;**************************************************************************
;	GetRMotorDir
;
;	Expects: -
;	Uses:	RHIsr1
;	Returns: Motor direction in C
;	
;	This function returns the direction wed like to be going (for
;	the right side). This may be the opposite of the direction we are
; 	actually going if we are in the middle of changing direction.
;
;**************************************************************************	
GetRMotorDir:
	; Our actual direction is the opposite of our direction pin
	; if we are in the middle of changing direction.
	lds	RHIsr1, RTimeToSwitch
	tst	RHIsr1
	brze	GRMD_NoInvert
	; We should invert it
	clc
	sbis	MotorDirPort, MotorDirR
	sec
	ret
GRMD_NoInvert:
	sec
	sbis	MotorDirPort, MotorDirR
	clc
	
	ret
;**************************************************************************	
;	/GetRMotorDir
;**************************************************************************	

;**************************************************************************
;	ComsErrorHandler
;
;	Expects: An error code in RHIsr1
;	Uses:	RHIsr1, RZIsrL, RZIsrH (indirectly)
;
;	Does the same as Error except that it clears the Rx status.
;
;**************************************************************************	
ComsErrorHandler:
	; Empty the buffer
	clr	RZIsrL
	sts	RxBufferLen, RZIsrL
	; Set the status to idle waiting for a message
	ldi	RHRxStatus, RX_IDLE
        ClearCommsTx
	; Fall through to ErrorHandler
;**************************************************************************
;	/ComsErrorHandler
;**************************************************************************	

;**************************************************************************
;	ErrorHandler
;
;	Expects: An error code in RHIsr1
;	Uses:	RHIsr1, RZIsrL, RZIsrH
;
;	Saves a error and displays it on the LEDs (this is done automatically
;	by the main loop).
;
;**************************************************************************	
ErrorHandler:
	; If there is already an error leave in the original error
	lds	RZIsrL, LastErr
	tst	RZIsrL
	breq	E_NoErr	; If there is already an error then do
	; a dump without overwriting the error thats stored.
	; If there is an error stored and it is NotImplementedErr then
	; if this message is more important put it in its place.
	cpi	RZIsrL, NotImplementedErr
	brne	E_Dump
	cpi	RHIsr1, NotImplementedErr
	breq	E_Dump	; If there was already a NotImplementedErr and this is
	; and not implemented error then leave the old one there.
E_NoErr:
	; There was no error already stored so store ours
	sts	LastErr, RHIsr1
	
	pop	RZIsrH		; Pop off the address of whowever called us.
	pop	RZIsrL		; High byte first.
	stsw	LastErrAddress, RZIsr	; And store it.
	push	RZIsrL
	push	RZIsrH
	; Dump it if we are in debug mode
E_Dump:
	; Check if we are in debug mode
	sbrs	RHFlags, DebugBit
E_Exit:
	ret
	; Check that the buffer is empty (if its not then we dont try and send
	; a dump message).
	lds	RZIsrL, TxBufferLen
	tst	RZIsrL
	brnz	E_Exit
	; Check that it has finished sending the last character (a CR).
	bris	UCR, UDRIE, E_Exit
	; Check that its actually finished (not just started sending it).
	bric	USR, UDRE, E_Exit
	; If the buffer is empty then send the dump message
	rjmp	SendDumpMessage
;**************************************************************************
;	/ErrorHandler
;**************************************************************************	
	
;**************************************************************************
;	DoClockIn
;
;	Expects: A value in RHT1, and a number from 1-8 in RHT2 which tells
; 	it how many bits to clock in.
;	Uses:	RHT1, RHT2
;	Must Not Change: -
;
;	Clocks in 1-8 bits of data into the MM5451 and returns.
;	Clock must be low for 450 ns and data must be put on the data line.
;	Clock must stay low for 450 ns then go high for 900 ns and then 
;	repeat.
;	This routine should work at 4mhz.
;**************************************************************************	
DoClockIn:
	ror	RHT1	; Put a bit in carry
	brcs	DCI_Set	; Output to DATA
	cbi	MMPort, MMDataPin
	rjmp	DCI_Cleared
DCI_Set:
	sbi	MMPort, MMDataPin
	nop	; 450 ns delay
DCI_Cleared:

	; Data is now on the data line. Set CLK high and then low again
	sbi	MMPort, MMClkPin
	nop	;900 ns high = 4 cycles at 4mhz
	nop
	nop
	cbi	MMPort, MMClkPin
	
	dec	RHT2		; Do it again if count is not 0
	brne	DoClockIn
	
	ret
;**************************************************************************	
;	/DoClockIn
;**************************************************************************	

;**************************************************************************
;	MMClockInT
;
;	Expects: A value in T
;	Uses:	
;	Must Not Change: -
;
;	Clocks in 1 bit of data into the MM5451 and returns.
;	Clock must be low for 450 ns and data must be put on the data line.
;	Clock must stay low for 450 ns then go high for 900 ns and then 
;	repeat.
;	This routine should work at 4mhz.
;**************************************************************************	
MMClockInT:
	brts	MC_Set	; Output to DATA
	cbi	MMPort, MMDataPin
	rjmp	MC_Cleared
MC_Set:
	sbi	MMPort, MMDataPin
	nop	; 450 ns delay
MC_Cleared:

	; Data is now on the data line. Set CLK high and then low again
	sbi	MMPort, MMClkPin
	nop	;900 ns high = 4 cycles at 4mhz
	nop
	nop
	cbi	MMPort, MMClkPin
	
	ret
;**************************************************************************	
;	/MMClockInT
;**************************************************************************	


;**************************************************************************
;
;	/Routines
;
;**************************************************************************

;**************************************************************************
;**************************************************************************
;
;	/Start of Program Proper
;
;**************************************************************************
;**************************************************************************

;**************************************************************************
;**************************************************************************
;
;	/Includes
;
;**************************************************************************
; RHIsr1 is the multiplicand and RZIsrL is the multiplier and the low byte
; of the result.
;MulSpeed8x8to16U:
;MulSpeed8x8to16U	RHIsr1, RZIsrL, RZIsrH
;	ret
	
;Div16d8to8U:
; RZIsrH-L is divisor, RHIsr1 i the dividend and the result is returned in RHIsr2
; TODO
;DivSpeed16d8to8U	RHIsr1, RZIsr, RHIsr2
;	ret

;RHIsr2-RHIsr1-RZIsr is the dividend
;RYIsr is the divisor
;RHIsr3 is the counter.	
;Div32d16to16U:
;DivSize32d16to16U	RHIsr2, RHIsr1, RZIsr, RYIsr, RHIsr3
;TODO
;ret
	
;Mul16x16To32U:
; Takes two 16 bit unsigned numbers in RZIsr and RYIsr
; and multiplies then. It returns the result RIsr2-RHIsr1-RZIsr
;MulSize16x16to32U RYIsr, RZIsr, RHIsr1, RHIsr2, RHIsr3
;	ret
	
; Parity
GetParity:
GetEvenParity	RHIsr1, RHIsr2, RHIsr3
	ret
;**************************************************************************
;**************************************************************************
;
;	/Includes
;
;**************************************************************************
;**************************************************************************
.org	FLASHEND - (15 * 2), 0xff
Name:		.ascii 	__FILE__
.org	FLASHEND - (7 * 2), 0xff
Version:	.ascii	"Version:" VERSION_STRING
