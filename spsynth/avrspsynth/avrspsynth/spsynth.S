;**************************************************************************
;
;	avrspsynth.asm	Controls the speech. Communicates with the master 
;			via a polled UART. Uses a 4-mbit SPI flash chip.
;**************************************************************************

; This program is written for an 4433 (28-pin digital) with a 8MHz crystal.
;
.nolist
#include	<version.h>
#include	<4433def.h>
; Uses AVR Macro library (avrml.sourceforge.net)
#include	<avrml/lib.h>
#include	<avrml/macros.h>
#include	<avrml/gend.h>
#include	<comms.h>
.list

#define VERSION_STRING "0.1.2.6"
#define VERSION 126

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
#define RX_RECEIVEDMSG  5
#define RX_INVALIDSTATE 6

; Flag Register
; Bit 0	TxStatus	(set if sending the hi8 nibble)
; Bit 1	ToneBit
; Bit 2 Debug Mode	(set if in debug mode)
; Bit 3
; Bit 4
; Bit 5
; Bit 6
; Bit 7
.equiv	TxStatusBit	, 0
.equiv	DebugBit	, 2
.equiv	DefaultFlags	, ((1 << DebugBit) | (1 << TxStatusBit))

; AT45D041A op codes
.equiv	FMMemoryPProgramTBufferUsingB2 , 0x85
.equiv	FMMemoryPRead , 0xd2
.equiv	FMArrayRead , 0xe8
.equiv	FMStatusRead , 0xd7
; And status bits
.equiv	FMReadyBit , 7

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
.equiv	CrystalFreq	, 8783300
#define CRYSTAL_FREQ	  8783300

;**************************************************************************
; Coms
;**************************************************************************
#define	RxBufferSize		16	; Should be the size of the longest
;					; messages parameter (not including
;					; the message itself). Must be at least 16
#define	TxBufferSize		3	; Should be the size of the longest
;					; message transmitted (not including
;					; the message itself).
#define	MY_ID			SPSYNTH_ID
#define MY_LID                  SPSYNTH_LID
; Size of the ToSay Buffer which stores things to say
.equiv	ToSayBufferSize	, 	40
; Size of the compressed buffer which stores data retrieved from the flash
; but not yet uncompressed.
.equiv	CompressedBufferSize ,  6
; Size of the play buffer which stores the uncompressed speech waiting to
; be played
.equiv	PlayBufferSize	, 6

; Stack size in bytes
#define STACK_SIZE	20

#define TONE_ESCAPE_CHAR        0xfd
;**************************************************************************
; /Coms
;**************************************************************************

;**************************************************************************
; 	Defaults
;**************************************************************************
;**************************************************************************
; 	/Defaults
;**************************************************************************

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
; Timer 0 is used for an 8000hz count for playing the sound
.equiv	PlayTCR	,	TCCR0
.equiv	PlayCnt	,	TCNT0
.equiv	PlayIE	,	TOIE0
.equiv	PlayReload	,	(~(CrystalFreq / 8 / 8000))
.equiv	PlayDivide	,	Timer0CKD8

; Timer 1 is used for a 8-bit PWM
.equiv	PWMH	, OCR1H
.equiv	PWML	, OCR1L
.equiv	PWMCRA 	, TCCR1A
.equiv	PWMCRB	, TCCR1B

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
;**************************************************************************
;
; Port-B:
;	PB0	(ICP)	Out	Idle Pin
;	PB1	(OC1)	Out	PWM Sound out
;	PB2	(/SS)	Out	/CS
;	PB3	(MOSI)	Out	Used by SPI
;	PB4	(MISO)	In	Used by SPI
;	PB5	(SCK)	Out	Used by SPI

; Generic
.equiv	DDForB		, 0b101111
.equiv	InitialPORTB	, 0b000100
; Idle pin
.equiv	IdlePort	, PORTB
.equiv	IdlePin		, 0
; CS
.equiv	ChipSelectPort	, PORTB
.equiv	CS0		, 2
;
;
;**************************************************************************
;
; Port-C:
;	PC0	(A8)	
;	PC1	(A9)	
;	PC2	(A10)	
;	PC3	(A11)	
;	PC4	(A12)	
;	PC5	(A13)	
.equiv	DDForC		,	0b000000
.equiv	InitialPORTC	,	0b000000
;
;**************************************************************************
;
; Port-D:
;	PD0	(RXD)	In
;	PD1	(TXD)   Out	
;	PD2	(INT0)  Out     Tx Direction (high to transmit)
;	PD3	(INT1)	
;	PD4		
;	PD5	(OC1A)
;	PD6	(/WR)	
;	PD7	(/RD)
.equiv	DDForD		, 0b00000110
.equiv	InitialPORTD	, 0b00000010

.equiv  TxDirPort       , PORTD
.equiv  TxDirPin        , 2

;**************************************************************************
;
;	OC1B		
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
;	Register Assignments
;
;**************************************************************************
;
;	R0
;	R1
;	R2
;	R3	Idle register (set when not idle)
.equiv	RLIdle , 3
;	R4	Set when we should be pausing
.equiv	RLPauseL , 4
;	R5	Set when we should be pausing
.equiv	RLPauseH , 5
;	R6
;	R7
;	R8
;	R9	hi8est byte of address
.equiv	RLAddressH , 9
.equiv	PRLAddressH , 9
;	R10	Middle byte of address
.equiv	RLAddressM , 10
;	R11	lo8 byte of address
.equiv	RLAddressL , 11
;	R12	Length still to load out of flash for this sound
.equiv	RLLengthH , 12
;	R13	Length still to load out of flash for this sound
.equiv	RLLengthL , 13
;	R14	Extra register used by SPI ISR
.equiv	RLExtra	, 14
;	R15	Interupt status register save
.equiv	RLStatusRegSave	, 15
;
;**************************************************************************
;
;	R16	Temporary register RHT1
.equiv	RHT1	,	16
;	R17	Temporary register RHT2
.equiv	RHT2	,	17
;	R18	
;	R19	Temporary register for ISRs
.equiv	RHIsr2	,	19
;	R20	SPI read status register
.equiv	RHSPISt	, 20
;	R21	Flags
.equiv	RHFlags	,	21
;	R22	Temporary register for ISRs
.equiv	RHIsr1	,	22
;	R23	Rx Status
.equiv	RHRxStatus ,	23
;**************************************************************************
;	R24 	Register for normal use
.equiv	RWTL	, 24
;	R25 	Register for normal use
.equiv	RWTH	, 25
;**************************************************************************
;	R26 XL	Register and pointer for normal use
.equiv	RXTL	, 26
;	R27 XH 	Register and pointer for normal use
.equiv	RXTH	, 27
;	R28 YL	Temporary register and pointer for ISRs
.equiv	RYIsrL	, 28
;	R29 YH	Temporary register and pointer for ISRs
.equiv	RYIsrH	, 29
;	R30 ZL	Register and pointer for normal use
.equiv	RZTL	, 30
;	R31 ZH	Register and pointer for normal use
.equiv	RZTH	, 31
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
.equiv	ComsOverflo8Err		, 2
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
.equiv	ToSayBufferFullErr	, 16
.equiv	ComsProgrammingErr	, 17
.equiv	EarlyCRErr		, 18
.equiv	PlayQueueEmpty		, 19
.equiv	DDEmptyBufErr		, 20
.equiv	DDBufFullErr		, 21
.equiv	SPOverflo8Err		, 22
.equiv	InvalidSPIStateErr	, 23
.equiv	EscapeErr		, 24
.equiv	ComsOverrunErr		, 25
.equiv  SmallSoundErr           , 26
#define INVALID_SOUND_ERR	  27
#define STACK_OVERFLOW_ERR	  28
#define COMMS_INVALIDSTATE_ERR    29
#define COMMS_INVALID_SECOND_MSG_ERR 30
#define SAY_BUFFER_EMPTY_ERR    31
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
	.org 0x0000
	.data
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
ToneReload:	.byte	0
ToneTime:       .word   0
ToneTable:      .word   0
TonePos:        .byte   0


	.data
LastErr:	.byte	0
LastErrAddress:	.word	0

	.data
ToSayBufferCount: .byte	0
ToSayBufferO1:	.byte 0
.equiv	ToSayBufferItemSize , 1
ToSayBuffer:	.space	(ToSayBufferSize * ToSayBufferItemSize), 0xff

	.data
CountTillReset:        .byte    0
CompressedBufferCount: .byte	0
CompressedBufferO1:	.byte   0
.equiv	CompressedBufferItemSize , 1
CompressedBuffer:	.space	(CompressedBufferSize * CompressedBufferItemSize), 0xff

	.data
PlayBufferCount: .byte	0
PlayBufferO1:	.byte 0
.equiv	PlayBufferItemSize , 1
PlayBuffer:	.space	(PlayBufferSize * PlayBufferItemSize), 0xff ; Data is stored hi8 byte first

	.data
DDIndex: .byte	0
DDPredSample: .word 0

	.data
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
;	Macro Error
; 	Expects: @0 - The error number
;	Uses: RHIsr1, RYIsrL, RYIsrH
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
;	Uses: RHIsr1, RYIsrL, RYIsrH
;	Words:	?
;	Cycles: ?
;
;	Registers an error and empties the coms buffer.
;**************************************************************************
.macro	ComsError     errnum
	ldi	RHIsr1, \errnum
	rcall	ComsErrorHandler
.endm
;**************************************************************************
;	/ComsError
;**************************************************************************

;**************************************************************************
;	Macro NotImplemented
; 	Expects:
;	Uses: RHIsr1, RYIsrL, RYIsrH
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
.ORG	OVF1addr	;Overflo81 Interrupt Vector Address
	reti
.ORG	OVF0addr	;Overflo80 Interrupt Vector Address
	rjmp	ISRPlay
.ORG	SPIaddr 	;SPI Interrupt Vector Address
	rjmp	ISRSPI
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
.ORG	ADCCaddr	;ADC Interrupt Vector Address
	reti
.ORG	ERDYaddr 	;EEPROM Interrupt Vector Address
	reti
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
;**************************************************************************
;	/Setup Stack
;**************************************************************************

;**************************************************************************
;	Setup Ports
;**************************************************************************
	; Now setup the ports to be the right direction and pullups etc.
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
	ldiw	RYIsr, RAMStart	;The 512 bytes RAM go from 0060 to 025F
	clrw	RZT 		; Load the EEPROM address in Z
InitRamLoop:
	; Get the data out of EEPROM
	out	EEAR, RZTL
	sbi	EECR, EERE
	in	RHT1, EEDR
	st	Y+,RHT1
	adiw	RZTL, 1
	cpi	RYIsrL,lo8(RAMEND+1)
	brne	InitRamLoop
	cpi	RYIsrH,hi8(RAMEND+1)
	brne	InitRamLoop
;**************************************************************************
;	/Initialize SRAM variables
;**************************************************************************

;**************************************************************************
;	Initialize register variables
;**************************************************************************
; Zeroize all of the registers
	clr	RHT1
	clrw	RZT	;Start at address 0000
ZRLoop:
	st	Z+,RHT1	;Zeroize the register
	cpi	RZTL,30	;Stop after clearing the first 30 of 32 registers
	brne	ZRLoop
	
; Initialize other registers that need to be something other than zero
	; Rx variables
	ldi	RHFlags, DefaultFlags
;**************************************************************************
;	/Initialize register variables
;**************************************************************************

;**************************************************************************
;	Setup Timers
;**************************************************************************
	; Setup timer 0 for an 8000 hz interupt but dont enable the interupt.
	ldi	RHT1, PlayDivide
	out	PlayTCR, RHT1
	
	; Setupt Timer 1 for a 8-bit PWM
	ldi	RHT1, ((1 << PWM10) | (1 << COM11))
	out	TCCR1A, RHT1
	ldi	RHT1, (1 << CS10)
	out	TCCR1B, RHT1
	; Set the PWM to 0xff
	ldi	RHT1, 0x00
	out	PWMH, RHT1
	ldi	RHT1, 0xff
	out	PWML, RHT1
;**************************************************************************
;	/Setup Timers
;**************************************************************************

;**************************************************************************
;	Setup UART
;**************************************************************************
	; Load the correct baud rate
	ldi	RHT1, BAUDRATE(COMS_BAUD)
	out	UBRR, RHT1
	; Setup the control register.
	ldi	RHT1, ((1 << RXCIE) | (1 << RXEN) | (1 << TXEN) | (1 << TXCIE))
	out	UCSRB, RHT1
;	ldi	RHT1, 'T'
;	out	UDR, RHT1
;**************************************************************************
;	/Setup UART
;**************************************************************************

;**************************************************************************
;	Setup SPI
;**************************************************************************
	ldi	RHT1, ((1 << SPE) | (1 << MSTR))
	out	SPCR, RHT1
;**************************************************************************
;	/Setup SPI
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
	clr	RLIdle	; Set that we are idle
	; Check the stack
	lds	RHT1, StackCheck
	cpi	RHT1, STACK_CHECK
	breq	R_Okay
	Error	STACK_OVERFLOW_ERR
        ; Restore stack check
        ldi     RHT1, STACK_CHECK
        sts     StackCheck, RHT1
R_Okay:
	; See if we have recieved a coms message
	cpi	RHRxStatus, RX_RECEIVEDMSG
	brne	R_NoMsg
	; Process the message
	rcall	ProcessComsMsg
	; We are now back in idle mode
	ldi	RHRxStatus, RX_IDLE

	ldi	RHT1, 0xff
	mov	RLIdle, RHT1 ; Busy
R_NoMsg:	
	
	; See if there is something to be decompressed
	lds	RHT1, CompressedBufferCount
	tst	RHT1
	brze	R_NoComp
	; Check there is room in the play buffer for two more items
	lds	RHT1, PlayBufferCount
	cpi	RHT1, (((PlayBufferSize - 2) * PlayBufferItemSize) + 1)
	brsh	R_NoComp
	; There is something compressed so decompress it and put it in the play buffer
	rcall	DoDecode
	ldi	RHT1, 0xff
	mov	RLIdle, RHT1 ; Busy
R_NoComp:

        rcall   CheckTone

	tst	RLIdle	; Check if we are idle
	brze	Idle
	rjmp	R_Loop
Idle:
	sbi	IdlePort, IdlePin
	sleep
	cbi	IdlePort, IdlePin
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
;	ISRSPI
;	Comes here when an SPI transfer is complete. Must start another transfer.
;
;	Here is the list of what happens
;	0 - Send 0x68 for continous read for lookup
;	1 - Send 1/3 of address (24 bits)
;	2 - Send 2/3 of address (24 bits)
;	3 - Send 3/3 of address (24 bits)
;	4 - Send 1/4 of clock (32 bits)
;	5 - Send 2/4 of clock (32 bits)
;	6 - Send 3/4 of clock (32 bits)
;	7 - Send 4/4 of clock (32 bits)
;	8 - Send blank to receive data (8 bits)
;	9 - Receive 1/5 of index data (40 bits)
;	10 - Receive 2/5 of index data (40 bits)
;	11 - Receive 3/5 of index data (40 bits)
;	12 - Receive 4/5 of index data (40 bits)
;	13 - Receive 5/5 of index data (40 bits)
;		> If NULL address do pause and reset state to 0
;		other load RLLength with the length and save the address
;		to memory.
;		> If not NULL begin the load by sending 0x68
;	14 - Send 1/3 of address (24 bits)
;	15 - Send 2/3 of address (24 bits)
;	16 - Send 3/3 of address (24 bits)
;	17 - Send 1/4 of clock (32 bits)
;	18 - Send 2/4 of clock (32 bits)
;	19 - Send 3/4 of clock (32 bits)
;	20 - Send 4/4 of clock (32 bits)
;	21 - Send a blank to receive data (8 bits)
;	22 - Receive data
SP_ErrIS:
        Error   InvalidSPIStateErr
        rjmp    SP_Begin
SP_Tone:
        ; Put the TONE_ESCAPE_CHAR back in. Then disable this interrupt
        ; while the tone plays
        MultiByteCircularQueueAddFrontProc SP_ErrIS, RYIsr, ToSayBuffer
        ldi     RHIsr1, TONE_ESCAPE_CHAR
        st      Y, RHIsr1
        ; Fall through to disable
SP_Disable:
	; Disable this interupt.
	cbi	SPCR, SPIE
	RestoreSREGreti

ISRSPI:
	SaveSREG
	in	RHIsr2, SPDR	; Always read the SPDR
	; Check if we are just doing an ordinary read (the most common)
	cpi	RHSPISt, 22
	lbreq	SP_Read
	; Okay there are several other things we could be doing
	tst	RHSPISt
	brnz	SP_NotBegin
SP_Begin:
        clr     RHSPISt
	; See if there is anything in the to say buffer
	MultiByteCircularQueueRemoveProc SP_Disable, RYIsr, ToSayBuffer
	; There is something to say
	ld	RHIsr1, Y
        cpi     RHIsr1, TONE_ESCAPE_CHAR
        breq    SP_Tone
	mov	RLAddressL, RHIsr1	; Multiply the address by 5 and then
	clr	RLAddressM
	clr	RLAddressH
	;get the index
	lsl	RLAddressL		; * 2
	rol	RLAddressM
	lsl	RLAddressL		; * 2 * 2 , * 4
	rol	RLAddressM
	add	RLAddressL, RHIsr1	; * 2 * 2 + 1 , * 5
	clr	RHIsr2
	adc	RLAddressM, RHIsr2
	; We now have the index but check it could have gone
	; over the 264 mark
SP_CheckLp:
	ldi	RHIsr1, lo8(264)
	cp	RLAddressL, RHIsr1
	ldi	RHIsr1, hi8(264)
	cpc	RLAddressM, RHIsr1
	brlo	SP_NotOver
	; This is over 264
	addi	RHIsr2, 2	; Add 2 (1 << 1)
	; Subtract 264 from the address
	ldi	RHIsr1, lo8(264)
	sub	RLAddressL, RHIsr1
	ldi	RHIsr1, hi8(264)
	sbc	RLAddressM, RHIsr1
	rjmp	SP_CheckLp
SP_NotOver:
	; Or in the segment address
	or	RLAddressM, RHIsr2
	; Send the start of a read
SP_BeginRead:
	sbi	ChipSelectPort, CS0 ; Select the chip first
	cbi	ChipSelectPort, CS0
	ldi	RHIsr1, FMArrayRead
	rjmp	SP_SendAndInc
SP_NotBegin:

	; We are somewhere in the process of loading a flash sound
	cpi	RHSPISt, 4
	brsh	SP_NotAddress
	; We are in the process of sending an address
	ldiw	RYIsr, (PRLAddressH - 1)
	add	RYIsrL, RHSPISt	; Get the pointer to the right byte
	ld	RHIsr1, Y
	rjmp	SP_SendAndInc
SP_NotAddress:

	cpi	RHSPISt, 9	; For clock we can just send junk (all we have to do is toggle
	lbrlo	SP_SendAndInc	; the clock).

	cpi	RHSPISt, 14
	brsh	SP_NotIndex

	; We are still just loading the index
	ldiw	RYIsr, (PRLAddressH - 9)
	add	RYIsrL, RHSPISt
	; Now save the data
	st	Y, RHIsr2
	; We are somewhere in the middle of loading index data.
	; The index data looks something like this
	; 0-2 Address (NULL for pause) 		Status 8-10
	; 3-4 Length or pause time		Status 11-12
	cpi	RHSPISt, 13
	lbrlo	SP_SendAndInc
	; We have finished reading the index. Now decide what to do with it
	clr	RHIsr1
	cp	RLAddressL, RHIsr1
	cpc	RLAddressM, RHIsr1
	cpc	RLAddressH, RHIsr1
	brze 	SP_Pause	; This is null - its a pause
	; Check for all ff - its invalid
	ldi	RHIsr1, 0xff
	cp	RLAddressL, RHIsr1
	cpc	RLAddressM, RHIsr1
	cpc	RLAddressH, RHIsr1
	cpc	RLLengthL, RHIsr1
	cpc	RLLengthH, RHIsr1
	brne	SP_NotPause	
	; This is all ffs (invalid)
	Error	INVALID_SOUND_ERR
	rjmp	SP_Begin
SP_Pause:
	; Add to the pause buffer
	add	RLPauseL, RLLengthL
	adc	RLPauseH, RLLengthH
	; If it overflo8s set the pause to ffs.
	lbrcc	SP_Begin
	ser	RHIsr1
	mov	RLPauseL, RHIsr1
	mov	RLPauseH, RHIsr1
	rjmp	SP_Begin
SP_NotPause:
	rjmp	SP_BeginRead
	; This was not a pause so begin a lookup
SP_NotIndex:

	cpi	RHSPISt, 17
	brsh	SP_NotAddress2
	; We are in the process of sending an address
	mov	RYIsrL, RHSPISt
	clr	RYIsrH
	subi	RYIsrL, (14 - PRLAddressH)
	; Get the pointer to the right byte
	ld	RHIsr1, Y
	rjmp	SP_SendAndInc
SP_NotAddress2:

        cpi     RHSPISt, 21     ; On the last clock
        brlo    SP_SendAndInc	; For clock we can just send junk (all we have to do is toggle
	                        ; the clock).
        cpi     RHSPISt, 21
        brne    SP_InvalidState
        ; This is the last interupt before we actually begin playing
        ; a sound. Set if the Decompression stuff needs to be reset.
        lds     RHIsr1, CountTillReset ; Check if CountTillReset is already set
        tst     RHIsr1
        brnz    SP_SmallSound
        lds     RHIsr1, CompressedBufferCount
        sts     CountTillReset, RHIsr1
        tst     RHIsr1
        brnz    SP_CheckFull         ; If there is something in the buffer that is all we have to do
        ldiw    RYIsr, 0              ; Otherwise we have to reset the state ourselves
        stsw    DDPredSample, RYIsr
        sts     DDIndex, RYIsrL
        rjmp    SP_SendAndInc
	
SP_CheckFull:
	; The next thing is to begin putting data in the compressed buffer. If it is full
	; this interupt must be disabled.
	ldi	RHSPISt, 22	; Begin reading
	rjmp	SP_CheckRoom

SP_SmallSound:
        ; This happens if two small sounds are played in a row. This is a design
        ; problem not a bug. It happens because CountTillReset can only remember
        ; one reset at a time.
        Error   SmallSoundErr
        rjmp    SP_Exit

SP_InvalidState:
	; If we get here there was something wrong
	Error	InvalidSPIStateErr

SP_Exit:
	RestoreSREGreti

SP_Read:
	; We are just doing a read
	MultiByteCircularQueueAddProc	SP_Overflo8, RYIsr, CompressedBuffer
	st	Y, RHIsr2	; Store this compressed data
	mvw	RYIsr, RLLength
	sbiw	RYIsrL, 1
	mvw	RLLength, RYIsr
	lbrze   SP_Begin                     ; Decrement the count and wait some more

SP_CheckRoom:
	; There is still more to read. Check it the is room in the compresseds buffer
	MultiByteCircularQueueHasRoomProc	SP_Disable2, RHIsr1, CompressedBuffer
	; There is room
	; Initiate another read
SP_Send:
	out	SPDR, RHIsr1
	RestoreSREGreti

SP_SendAndInc:
	inc	RHSPISt	; Increment our status
	rjmp	SP_Send
	
SP_Overflo8:
	Error	SPOverflo8Err	

SP_Disable2:
	; Disable this interupt.
	cbi	SPCR, SPIE
	RestoreSREGreti
;**************************************************************************
;	/ISRSPI
;**************************************************************************

;**************************************************************************
;	ISRPlay
ISRPlay:
	SaveSREG

        ; Check if we are playing a tone
        lds     RHIsr1, ToneReload
        tst     RHIsr1
        brnz    IP_Tone

	ldi	RHIsr1, PlayReload
	out	PlayCnt, RHIsr1	; Reload the count

	; First of all see if we are pausing
	brwnz	RLPause, IP_Pause
	; Remove a value to play from the queue
	MultiByteCircularQueueRemoveProc	IP_Empty, RYIsr, PlayBuffer
	; Play this data
	ld	RHIsr1, Y	; We play only the hi8 byte
	clr	RHIsr2
	out	PWMH, RHIsr2
	out	PWML, RHIsr1
	
IP_CheckEmpty:
	; Now if the buffer is empty disable this interupt
	lds	RHIsr1, PlayBufferCount
	tst	RHIsr1
	brnz	IP_Exit
	; Disable this interupt
	clr	RHIsr1
	out	TIMSK, RHIsr1
IP_Exit:
	RestoreSREGreti
	
IP_Empty:
	clr	RHIsr1
	out	TIMSK, RHIsr1
	Error	PlayQueueEmpty
	RestoreSREGreti
	
IP_Pause:
	ldi	RHIsr1, 1
	sub	RLPauseL, RHIsr1	; Decrement the count and wait some more
	clr	RHIsr1
	sbc	RLPauseH, RHIsr1
	brze	IP_CheckEmpty
	RestoreSREGreti

IP_Tone:
        out     PlayCnt, RHIsr1

        ; We are meant to be generating a tone
        ; Put in the next PWM output
        pushw   RZT     ; Must use Z for lpm
        push    r0
        ldsw    RZT, ToneTable
        lds     RHIsr1, TonePos
        add     RZTL, RHIsr1
        ldi     RHIsr2, 0
        adc     RZTH, RHIsr2
        ; RYIsr now contains a pointer to the next value to put in
        lpm
        mov     RHIsr2, r0
        pop     r0
        popw    RZT

	; Output the new output
	clr	RYIsrL
	out	PWMH, RYIsrL
	out	PWML, RHIsr2

        ; We have output the new output now increment the position in the
        ; table to the next entry.
        inc     RHIsr1
        cpi     RHIsr1, 32
        brlo    IP_L
        ; This is over 32 so go to zero
        ; Also decrement the timeout
        ldsw    RYIsr, ToneTime
        sbiw    RYIsrL, 1
        brcs    IP_StopTone
        stsw    ToneTime, RYIsr
        clr     RHIsr1
IP_L:
        sts     TonePos, RHIsr1

	RestoreSREGreti

IP_StopTone:
        ; Tone is done now so disable it
        clr     RHIsr1
        sts     ToneReload, RHIsr1
        ; Set the timer back to 8000 hz
	ldi	RHT1, PlayDivide
	out	PlayTCR, RHT1
        ; Disable the interrupt if necessary
        lds     RHIsr1, PlayBufferCount
        tst     RHIsr1
        brnz    IP_Playing
        ; Disable timer
        clr     RHIsr1
        out     TIMSK, RHIsr1

IP_Playing:
        lds     RHIsr1, ToSayBufferCount
        tst     RHIsr1
        brze    IP_Exit2
        ; Start the SPI interrupt again if necessary
       	tst	RHSPISt
	brnz	IP_Exit2	; If the status is not zero we dont need to do anything
	; If the SPIF is not set then we need to set it
	bris	SPCR, SPIE, IP_Exit
	out	SPDR, RHIsr1
	; Make sure to enable SPI interupt
	sbi	SPCR, SPIE

IP_Exit2:
	RestoreSREGreti

;**************************************************************************
; 	/ISRPlay
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
	ComsError	ComsOverflo8Err
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
	in	RHIsr1, UCSRA
	andi	RHIsr1, ((1 << FE) | (1 << OR))
	brnz	IU_Error
	
	; Get the byte
	in	RHIsr1, UDR
	mov	RYIsrH, RHIsr1
	; Check parity and clear the 8th bit
	cbr	RHIsr1, (1 << 7)
	rcall	ISRGetParity
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
        ; This is valid poll message.
        sts     RxMsg, RHIsr1
        ldi     RHRxStatus, RX_RECEIVEDMSG
        rjmp    RC_DoneState
Rx_NPolled:
        cpi     RHIsr1, MY_ID
        lbrne   RC_DoneState    ; Stay idle
        ldi     RHRxStatus, RX_RECEIVEMSG
        rjmp    RC_DoneState

Rx_ReceiveMsg:
        ; This is a message addressed to us. Check its validty and either go
        ; to RX_RECEIVEMSG2 or RX_RECEIVEDATA or IDLE (in case of error).
        sts     RxMsg, RHIsr1

        cpi     RHIsr1, SSAY_MSG
        breq    RC_SayMsg
        cpi     RHIsr1, SPROGRAM_MSG
        breq    RC_ProgMsg
        cpi     RHIsr1, VERSION_MSG
        breq    RC_VersionMsg
        cpi     RHIsr1, SREAD_MSG
        breq    RC_ReadMsg
        cpi     RHIsr1, STEST_MSG
        breq    RC_TestMsg
        cpi     RHIsr1, SSPIDEBUG_MSG
        breq    RC_SPIDMsg
        cpi     RHIsr1, SFLAG_MSG
        breq    RC_FlagMsg
        cpi     RHIsr1, STONE_MSG
        breq    RC_ToneMsg
        cpi     RHIsr1, DUMP_MSG
        breq    RC_DumpMsg
        cpi     RHIsr1, SET_MSG
        breq    RC_SetMsg
        ; Invalid message
        ComsError ComsInvalidMsgErr
        rjmp    RC_DoneState

RC_SayMsg:
        ldi     RHIsr1, SSAY_MSG_LEN
        rjmp    RC_MsgD
RC_ProgMsg:
        ldi    RHIsr1, SPROGRAM_MSG_LEN
        rjmp    RC_MsgD
RC_VersionMsg:
        ldi     RHIsr1, VERSION_MSG_LEN
        rjmp    RC_MsgD
RC_ReadMsg:
        ldi     RHIsr1, SREAD_MSG_LEN
        rjmp    RC_MsgD
RC_TestMsg:
        ldi     RHIsr1, STEST_MSG_LEN
        rjmp    RC_MsgD
RC_SPIDMsg:
        ldi     RHIsr1, SSPIDEBUG_MSG_LEN
        rjmp    RC_MsgD
RC_FlagMsg:
        ldi     RHIsr1, SFLAG_MSG_LEN
        rjmp    RC_MsgD
RC_ToneMsg:
        ldi     RHIsr1, STONE_MSG_LEN
        rjmp    RC_DMsg
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
        ldi     RHRxStatus, RX_RECEIVEDMSG
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
        ldi     RHRxStatus, RX_RECEIVEDMSG
        rjmp    RC_DoneState

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
	ComsError	ComsOverflo8Err
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
        ldi     RHRxStatus, RX_RECEIVEDMSG

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
	rcall	ISRGetParity
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
	rcall	ISRGetParity
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
	cbi	UCSRB, UDRIE
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
;	ProcessComsMsg
;
;	Expects:A message to be stored in the RxMsg, RxBuffer and RxBufferLen
; 		to be valid.
;	Uses:	
;
;	Should be fairly fast as interupts are disabled and will not be enabled
;	until it returns. It also resets the RxBuffer.
;**************************************************************************
ProcessComsMsg:
	lds	RHT1, RxMsg
	; Load the length
	lds	RHT2, RxBufferLen
	
	; Check what message it is
	cpi	RHT1, MY_LID    ; Lowercase ID is sign of a poll
	breq	PCM_PollMsg
	cpi	RHT1, SSAY_MSG
	lbreq	PCM_SayMsg
	cpi	RHT1, VERSION_MSG
	lbreq	PCM_VersionMsg
	cpi	RHT1, STONE_MSG
	lbreq	PCM_ToneMsg
	cpi	RHT1, SFLAG_MSG
	lbreq	PCM_FlagMsg
	cpi	RHT1, DUMP_MSG
	lbreq	PCM_DumpMsg
        cpi     RHT1, SET_MSG
        lbreq   PCM_SetMsg
	cpi	RHT1, SREAD_MSG
	lbreq	PCM_ReadMsg
	cpi	RHT1, STEST_MSG
	lbreq	PCM_DoTestMsg
	cpi	RHT1, SPROGRAM_MSG
	lbreq	DoProgramMsg
	cpi	RHT1, SSPIDEBUG_MSG
	lbreq	PCM_SPIDebugMsg
	; If it gets here there was a invalid message sent
	ComsError	ComsInvalidMsgErr
	ret
	
PCM_InvalidMsgContents:
	ComsError	InvalidMsgContentsErr
	ret
	; All the messages are here. The buffer length is stored in
	; RYIsrH.
	
PCM_PollMsg:
	; They have polled us we can now transmit if we want.
	; First see if we have an error to tell them about
	lds	RZTL, LastErr
	tst	RZTL
	brze	PCM_NoError
	; There is an error
	ldi	RHT1, ERROR_REPLY
	ldi	RXTH, ERROR_REPLY_LEN	; The length
	rcall	BeginMessage
	; Put the error on the buffer
	lds	RZTL, LastErr
	sts	TxBuffer + 2, RZTL	; The error
	ldsw	RZT, LastErrAddress	; And the address
	sts	TxBuffer + 1, RZTH
	sts	TxBuffer, RZTL
	; Now clear it so another error can be stored
	clr	RHT1
	sts	LastErr, RHT1
	reti	; Return and enable interupts
PCM_NoError:

        ; See if the buffer is not empty
        lds     RHT1,ToSayBufferCount
        tst     RHT1
        brze    PCM_NoCount
        ; There is something in the buffer.
        ; Send the amount remaining
        ldi     RHT1, SFREE_REPLY
        ldi     RXTH, SFREE_REPLY_LEN
        rcall   BeginMessage
        ; Calculate the number of free spaces in buffer
        lds     RHT1, ToSayBufferCount
        ldi     RHT2, ToSayBufferSize
        sub     RHT2, RHT1
        sts     TxBuffer, RHT2
        reti

PCM_NoCount:
        ; Now to send

        SetCommsTx
        ldi     RHT1, (MY_LID + 1)
        rcall   GetParity
        out     UDR, RHT1
	ret

PCM_ClearBuf:
	; We received an ff so we should empty the speech buffer
	cli
	; Set the SPI state to 0
	clr	RHSPISt
	; Empty all the buffers
	sts	ToSayBufferCount, RHSPISt
	sts	CompressedBufferCount, RHSPISt
	sts	PlayBufferCount, RHSPISt
	; Disable the SPI interupt
	cbi	SPCR, SPIE
	; Disable the play timer	
	out	TIMSK, RHSPISt
	; Also shut up the tone generater
	sts	ToneReload, RHSPISt
	; Last but definetely not least clear the counttillreset buffer.
	sts	CountTillReset, RHSPISt
	sei
	rjmp	PCM_Loop
	
PCM_SayMsg: ; Put something in the say buffer
	tst	RHT2
        lbrze    PCM_InvalidMsgLen
	
	ldiw	RZT, RxBuffer
PCM_SMLoop:
	; Say all of this
	ld	RHT1, Z+
	cpi	RHT1, 0xff	; Check if it is a clear buffer (0xff)
	breq	PCM_ClearBuf
	dec	RHT1
	cli
	MultiByteCircularQueueAddProc PCM_BufferFull, RXT, ToSayBuffer
	st	X+, RHT1
	sei
	; Loop
PCM_Loop:
	dec	RHT2
	brnz	PCM_SMLoop

	lds	RHT1, ToSayBufferCount
	tst	RHT1
	brze	PCM_Ret2	; If the buffer is empty dont do anything

	tst	RHSPISt
	brnz	PCM_Ret2	; If the status is not zero we dont need to do anything
	; If the SPIF is not set then we need to set it
	bris	SPCR, SPIE, PCM_Ret2
	out	SPDR, RHT1
	; Make sure to enable SPI interupt
	sbi	SPCR, SPIE
PCM_Ret2:
	ret

PCM_BufferFull:
	Error	ToSayBufferFullErr
	reti

PCM_InvalidMsg:
        Error   ComsInvalidDataErr
        ret

PCM_ToneMsg:
;	Expects: RXTL - Type of tone requested.
;                RWT - Tone freq (in hz)
;                RXTH - Tone time (in 1/10 of a sec)
        lds     RXTL, RxMsg2
        subi    RXTL, '0'
        lds     RWTL, RxBuffer + 1
        lds     RWTH, RxBuffer
        lds     RXTH, RxBuffer + 2
        rjmp    BeginTone

PCM_FlagMsg:
	; Get the flags
	lds	RHT1, RxBuffer
	bst	RHT1, 0             ; Set the Debug bit
	bld	RHFlags, DebugBit
	
	ret
			  		
PCM_VersionMsg:
	; This is a valid version msg
	ldi	RHT1, VERSION_REPLY
	ldi	RXTH, VERSION_REPLY_LEN
	rcall	BeginMessage
	; Now put our version stuff on the buffer

	ldi	RHT1, ( (VERSION_REVISION(VERSION) << 4) | VERSION_FIX(VERSION) )
	sts	TxBuffer, RHT1
	ldi	RHT1, ( (VERSION_MAJOR(VERSION) << 4) | VERSION_MINOR(VERSION) )
	sts	TxBuffer + 1, RHT1
	reti	; Return and enable interupts

PCM_SetMsg:
        ; Load address
        lds     RZTL, RxBuffer + 1
        lds     RZTH, RxBuffer
        lds     RHT1, RxBuffer + 2
        ; Set the value
        st      Z, RHT1

        ret

PCM_DumpMsg:
        rcall   BeginBigMessage
        ; This may dump the flash, ram or registers.
        lds     RHT1, RxMsg2
        cpi     RHT1, DUMP_EEPROM
        breq    DumpEEPROM
        cpi     RHT1, DUMP_FLASH
        lbreq    DumpFlash
        cpi     RHT1, DUMP_REGISTERS
        lbreq    DumpRegisters
        cpi     RHT1, DUMP_SRAM
        breq    DumpSram

        sei

        ComsError       COMMS_INVALID_SECOND_MSG_ERR
        ret
	
SendDumpMessage:	; This is a direct entry used when are in debug mode to
	; send a message right away.
        rcall   BeginBigMessage
DumpSram:
	; Dump all our registers, memory and RAM.
	clrw	RZT	;Start at address 0000
DSRLoopMain:
	; Send our ID to begin with
	ldi	RHT1, MY_ID
	rcall	SendByteToUART
	ldi	RHT1, DUMP_MSG
        rcall   SendByteToUART
	ldi	RHT1, DUMP_SRAM
	rcall	SendByteToUART

	; Send the SRAM address in hex
	rcall	SendHWord	;Convert RAM address already in RZT and send it

; Display the 16 hex values
	ldi	RXTH, 16	;Bytes per line
DSRLoopHex:
	ld	RHT1, Z+		;Get the SRAM value
	rcall	SendHByte
DSR_NoExtra:
	dec	RXTH		;Bytes left to print on this line
	brnz	DSRLoopHex
	
; Send a CR at the end of every line
	ldi	RHT1,CR
	rcall	SendByteToUART

; Stop after displaying all of the RAM
	cpi	RZTL,lo8(RAMEND+1)
	brne	DSRLoopMain
	cpi	RZTH,hi8(RAMEND+1)
	brne	DSRLoopMain
	
	; End with our ID
	ldi	RHT1, MY_ID
	rcall	SendByteToUART
	ldi	RHT1, DUMP_MSG
        rcall   SendByteToUART
	ldi	RHT1, DUMP_SRAM
	rcall	SendByteToUART	
        ldi     RHT1, CR
        rcall   SendByteToUART

	; Clear the UART flags
	in	RHT1, UDR
        ClearCommsTx
	reti	; Return and enable interupts

DumpEEPROM:

	clrw	RZT	;Start at address 0000
	
ESRLoopMain:
	ldi	RHT1, MY_ID
	rcall	SendByteToUART
	ldi	RHT1, DUMP_MSG
        rcall   SendByteToUART
	ldi	RHT1, DUMP_EEPROM
	rcall	SendByteToUART


	; Send the EEPROM address in hex
	rcall	SendHWord	;Convert RAM address already in RZT and send it
	
; Display the 16 hex values
	ldi	RXTH, 16	;Bytes per line
ESRLoopHex:
	; Wait for the EEPROM to stop working
EL_1:	bris	EECR, EEWE, EL_1
	out	EEAR, RZTL	;Get the EEPROM value
	sbi	EECR, EERE
	in	RHT1, EEDR
	; Increment the pointer
	adiw	RZTL, 1
	; And send it
	rcall	SendHByte
	
	dec	RXTH		;Bytes left to print on this line
	brnz	ESRLoopHex
	
        ldi     RHT1, CR
        rcall   SendByteToUART
	
; Stop after displaying all of the EEPROM
	cpi	RZTL,lo8(E2END+1)
	brne	ESRLoopMain
	cpi	RZTH,hi8(E2END+1)
	brne	ESRLoopMain
	
		; End with our ID
	ldi	RHT1, MY_ID
	rcall	SendByteToUART
	ldi	RHT1, DUMP_MSG
        rcall   SendByteToUART
	ldi	RHT1, DUMP_EEPROM
	rcall	SendByteToUART	
        ldi     RHT1, CR
        rcall   SendByteToUART

	; Clear the UART flags
	in	RHT1, UDR
        ClearCommsTx
	reti	; Return and enable interupts


DumpRegisters:
	clrw	RZT	;Start at address 0000

	ldi	RHT1, MY_ID
	rcall	SendByteToUART
	ldi	RHT1, DUMP_MSG
        rcall   SendByteToUART
	ldi	RHT1, DUMP_REGISTERS
	rcall	SendByteToUART	

DR_Loop:
        ld      RHT1, Z+
        rcall   SendHByte
        cpi     RZTL, 16
        brlo    DR_Loop
        ; Send CR
        ldi     RHT1, CR
        rcall   SendByteToUART

	ldi	RHT1, MY_ID
	rcall	SendByteToUART
	ldi	RHT1, DUMP_MSG
        rcall   SendByteToUART

DR_Loop2:
        ld      RHT1, Z+
        rcall   SendHByte
        cpi     RZTL, 32
        brlo    DR_Loop2
        ; Send CR
        ldi     RHT1, CR
        rcall   SendByteToUART

	; End with our ID
	ldi	RHT1, MY_ID
	rcall	SendByteToUART
	ldi	RHT1, DUMP_MSG
        rcall   SendByteToUART
	ldi	RHT1, DUMP_REGISTERS
	rcall	SendByteToUART	
        ldi     RHT1, CR
        rcall   SendByteToUART

	; Clear the UART flags
	in	RHT1, UDR
        ClearCommsTx
	reti	; Return and enable interupts


DumpFlash:
        clrw    RZT
        ; Send 16 bytes at a time
DF_Loop:
        ldi	RHT1, MY_ID
	rcall	SendByteToUART
	ldi	RHT1, DUMP_MSG
        rcall   SendByteToUART
	ldi	RHT1, DUMP_FLASH
	rcall	SendByteToUART	

        rcall   SendHWord
        ; Now send 16 bytes of data
        ldi     RXTH, 16
DF_LoopD:
        lpm
        mov     RHT1, r0
        adiw    RZTL, 1
        rcall   SendHByte
        dec     RXTH
        brnz    DF_LoopD

        ldi     RHT1, CR
        rcall   SendByteToUART

       	cpi	RZTL,lo8(FLASHEND+1)
	brne	DF_Loop
	cpi	RZTH,hi8(FLASHEND+1)
	brne	DF_Loop

	; End with our ID
	ldi	RHT1, MY_ID
	rcall	SendByteToUART
	ldi	RHT1, DUMP_MSG
        rcall   SendByteToUART
	ldi	RHT1, DUMP_FLASH
	rcall	SendByteToUART	
        ldi     RHT1, CR
        rcall   SendByteToUART

	; Clear the UART flags
	in	RHT1, UDR
        ClearCommsTx
	reti	; Return and enable interupts
							

PCM_ReadMsg:
	; Send a message right away.
	; Check that the buffer is empty
	rcall	BeginBigMessage
	ldi	RHT1, SREAD_MSG
        rcall   SendByteToUART
	; Send a CR to begin with
	ldi	RHT1, CR
	rcall	SendByteToUART
	; Dump this flash stuff
	; First start reading from the flash
	rcall	TakeOverSPI
	ldi	RHT1, FMMemoryPRead
	rcall	SRSPIByte 	; Start the read
	; Now send the address
	lds	RHT2, RxBuffer + 1
	lds	RHT1, RxBuffer
	lsl	RHT2
	rol	RHT1
	rcall	SRSPIByte
	mov	RHT1, RHT2
	rcall	SRSPIByte
	
	; Send a 0 to start at the beginning of the block
	clr	RHT1
	rcall	SRSPIByte
	
	; And 4 dont care bytes
	rcall	SRSPIByte
	rcall	SRSPIByte
	rcall	SRSPIByte
	rcall	SRSPIByte
	
	; Ready to start dumping stuff now
	clrw	RWT	; Send 264 bytes of data from the flash
	
FRLoopMain:
	mvw	RZT, RWT
	; Send the SRAM address in hex
	rcall	SendHWord	;Convert RAM address already in RZT and send it

	ldi	RHT1,'='
	rcall	SendByteToUART
; Display the 16 hex values
	ldi	RXTH, 16	;Bytes per line
	ldiw	RZT, RxBuffer	; Store the data in RxBuffer
FRLoopHex:
	; Get the flash value
	rcall	SRSPIByte
	st	Z+, RHT1	; Store it for the text
	; And send it
	rcall	SendHByte
	; Send a space
	ldi	RHT1, ' '
	rcall	SendByteToUART
	; Send an extra space between the 8 and 9th bytes
	cpi	RXTH, 9
	brne	FR_NoExtra
	ldi	RHT1, ' '
	rcall	SendByteToUART
FR_NoExtra:
	dec	RXTH		;Bytes left to print on this line
	brnz	FRLoopHex
	
	; Send 3 spaces between this and the hex
	ldi	RHT1, ' '
	rcall	SendByteToUART
	ldi	RHT1, ' '
	rcall	SendByteToUART
	ldi	RHT1, ' '
	rcall	SendByteToUART
; Display the 16 ASCII characters
	ldi	RXTH, 16		;Bytes per line
	ldiw	RZT, RxBuffer	; Load the data in RxBuffer
FRLoopASCII:
	ld	RHT1, Z+
	; Display the SRAM contents in ASCII
	cpi	RHT1,' '
	brlo	FRDispDot		;Display a dot if its less than ASCII space
	cpi	RHT1,0x80
	brlo	FRDispASC		;Display a dot if its over 7F
FRDispDot:
	ldi	RHT1,'.'
FRDispASC:
	rcall	SendByteToUART
	; Send an extra space between the 8 and 9th bytes
	cpi	RXTH, 9
	brne	FR_NoExtraT
	ldi	RHT1, ' '
	rcall	SendByteToUART
FR_NoExtraT:

	dec	RXTH
	brnz	FRLoopASCII
	
; Send a CR at the end of every line
	ldi	RHT1,CR
	rcall	SendByteToUART
	
; Stop after displaying all of the flash segment
	adiw	RWTL, 16
	; See if it is done
	cpi	RWTH,hi8(264)
	brne	FRLoopMain
	cpi	RWTL,lo8(264)
	brlo	FRLoopMain

	rjmp	DPM_CleanUp	; Clean up the mess we made

PCM_EscErr:
	Error	EscapeErr
	rjmp	DPM_CleanUp

PCM_DoTestMsg:
       	; We are now doing a test of the flash
	rcall	TakeOverSPI
	; First figure out how large the flash chip is
	; Now wait until the status register is no longer busy
	ldi	RHT1, FMStatusRead
	rcall	SRSPIByte
	rcall	SRSPIByte
	; RHT1 now has the status register which tells
	; us the size of the flash chip.
	; Bit 3 is the start of the size
	; Multiply by two (shift right only 2 times)
	lsr	RHT1
	lsr	RHT1
	andi	RHT1, 0b00001110
	; Look up the size in our table
	ldfp	RZT, SizeTable
	; Add the offset
	add	RZTL, RHT1
	ldi	RHT1, 0
	adc	RZTH, RHT1
	; Now get the number of segments (which is multiplied by 2)
	lpm
	mov	RXTL, r0
	inc	RZTL
	lpm
	mov	RXTH, r0
	; We can now begin writing the segments
	; Now begin writing the first 264 bytes of a segment
PCM_TestSeg:
	sbi	ChipSelectPort, CS0
	cbi	ChipSelectPort, CS0
	; Start the program
	ldi	RHT1, FMMemoryPProgramTBufferUsingB2
	rcall	SRSPIByte	; Start the operation
	; Now send the address
	; Now send the address (it is already shifted left)
	mov	RHT1, RXTH
	rcall	SRSPIByte
	mov	RHT1, RXTL
	rcall	SRSPIByte
	clr	RHT1     	; Plus one more byte to clear the start
	rcall	SRSPIByte	

	; Now write our program memory
	ldiw	RZT, 264
PCM_WriteLp:
	lpm	
	mov	RHT1, r0
	rcall	SRSPIByte
	; Go to the next byte
	sbiw	RZTL, 1
	brnz	PCM_WriteLp	
	; Okay we have a CR so program it
	sbi	ChipSelectPort, CS0
	cbi	ChipSelectPort, CS0
	; Now wait until the status register is no longer busy
	ldi	RHT1, FMStatusRead
	rcall	SRSPIByte
	rcall	SRSPIByte
StillBusy:
	; First check for an escape
	in	RHT1, UDR
	cpi	RHT1, 0x1b ; Check for ESC
	breq	PCM_EscErr
	; Read the status back
	rcall	SRSPIByte
	; Check if it is busy
	andi	RHT1, (1 << FMReadyBit)
	brze	StillBusy

	; We have now written this segment so lets read it back
	; First select the chip again
	sbi	ChipSelectPort, CS0
	cbi	ChipSelectPort, CS0
	; Start the read
	ldi	RHT1, FMMemoryPRead
	rcall	SRSPIByte 	; Start the read
	; Now send the address (it is already shifted left)
	mov	RHT1, RXTH
	rcall	SRSPIByte
	mov	RHT1, RXTL
	rcall	SRSPIByte
	clr	RHT1     	; Plus one more byte to clear the start
	rcall	SRSPIByte	
	; And 4 dont care bytes
	rcall	SRSPIByte
	rcall	SRSPIByte
	rcall	SRSPIByte
	rcall	SRSPIByte
	
	; Now begin reading the data
	; Now write our program memory
	ldiw	RZT, 264
PCM_ReadLp:
	rcall	SRSPIByte
	lpm
	cp	RHT1, r0
	brnz	PCM_TestErr
	; Go to the next byte
	sbiw	RZTL, 1
	brnz	PCM_ReadLp
	; We successfully reached the end of this segment
	; Send a Q
	ldi	RHT1,'Q'
	rcall	SendByteToUART
	
	; Now loop if this was not the last segment
	sbiw	RXTL, 2 ;(2 because the page address is shifted left)
	brcc	PCM_TestSeg

	; Send an O at the end
	ldi	RHT1,'C'
	rcall	SendByteToUART
	
	rjmp	DPM_CleanUp

PCM_TestErr:
	push	r0  	; What the value should have been
	push	RHT1	; What it was
	ldi	RHT1,'E'      ; Send an error
	rcall	SendByteToUART
	; Now the segment
	pushw	RZT  ; Save the address
	mvw	RZT, RXT
	rcall	SendHWord
	popw	RZT ; Restore the address
	; And the address in the segment
	rcall	SendHWord	;Convert the address already in RZT and send it		
	; What it was
	pop	RHT1
	rcall	SendHByte
	; And what it should have been
	pop	r0
	rcall	SendHByte
	rjmp	DPM_CleanUp

PCM_SendE:
	ldi	RHT1, 'E'
	rcall	SendByteToUART
	rjmp	PCM_GetB
	
PCM_SPIDebugMsg:
	; We are now doing a test of the flash
	rcall	TakeOverSPI
	; Say hello
	ldi	RHT1, 'H'
	rcall	SendByteToUART
	clr	RHT1
	sts	RxMsg, RHT1 ; We can overwrite our message
PCM_GetB:
	rcall	GetUARTByte
	brcs	PCM_SendE	; If there was an error
	brhs	PCM_ExitLp
	; We have received a byte
	rcall	SRSPIByte
	; Now send whatever we got
	rcall	SendHByte
	clr	RHT1		; Clear the exit flag
	sts	RxMsg, RHT1
	rjmp	PCM_GetB
PCM_ExitLp:
	ldi	RHT1, 'S'
	rcall	SendByteToUART
	; If this is the first enter then reselect the flash
	sbi	ChipSelectPort, CS0
	cbi	ChipSelectPort, CS0	; Select the chip
	lds	RHT1, RxMsg
	tst	RHT1
	ser	RHT1	; Wont affect the flags from the compare
	sts	RxMsg, RHT1	
	brze	PCM_GetB
	ldi	RHT1, 'X'
	rcall	SendByteToUART		
	rjmp	DPM_CleanUp

PCM_InvalidMsgLen:
	; Gets here when we get an invalid message length
	ComsError	ComsInvalidMsgLenErr
	rjmp	DPM_CleanUp
;**************************************************************************
;	/ProcessComsMsg
;**************************************************************************	

;**************************************************************************
;	BeginTone
;
;	Expects: RXTL - Type of tone requested.
;                RWT - Tone freq (in hz)
;                RXTH - Tone time (in 1/10 of a sec)
;	Changes:
;	Must Not Change:
;
;	Disables interupts and takes over using the SPI bus.
;**************************************************************************	
BT_InvalidMsg:
        pop     RHT1    ; Pop stack to remove save RXTH
        rjmp    PCM_InvalidMsg

BeginTone:
        push    RXTH    ; Save tone length
        ; First get the type of tone they want
        cpi     RXTL, lo8(Num_Tones)
        brsh    BT_InvalidMsg
        ; Valid tone
        clr     RXTH
        ; Multiply by 32 to get position
        lsl     RXTL
        rol     RXTH    ; * 2
        lsl     RXTL
        rol     RXTH    ; * 2 * 2
        lsl     RXTL
        rol     RXTH    ; * 2 * 2 * 2
        lsl     RXTL
        rol     RXTH    ; * 2 * 2 * 2 * 2
        lsl     RXTL
        rol     RXTH    ; * 2 * 2 * 2 * 2 * 2 = * 32
        ; Add offset of table
        subi    RXTL, lo8(-(ToneTables))
        sbci    RXTH, hi8(-(ToneTables))
        stsw    ToneTable, RXT
        clr     RHT1
        ; Start at position 0 in the table
        sts     TonePos, RHT1

        ; We have set up the tone type now set up Timer 0
        mvw    RXT, RWT             ; Load the requested frequency
        ; Check to see if frequency is out of bounds
        ; If should be between 20 and 2000
        tst     RXTH
        brnz    PCM_Nz
        cpi     RXTL, 20
        brlo    BT_InvalidMsg
        rjmp    PCM_ValidFreq
PCM_Nz:
        cpi     RXTL, lo8(2000 + 1)
        ldi     RHT1, hi8(2000 + 1)
        cpc     RXTH, RHT1
        lbrsh    PCM_InvalidMsg

PCM_ValidFreq:
        ; Divide clock by 32 (because timer must go at * 32 of the wanted
        ; frequency). Divide again by 8 to make it a 16-bit number.
        ldiw    RZT, (CRYSTAL_FREQ / 32 / 8)
        ;* Divides RZT by RYT and puts result in RZT and remainder in RHT3-2
        ; RZT contains wanted frequency
        rcall   div16u
        ; RZT now contains what we want to divide the clock by divided by 8
        ; If the upper byte is 0 we can put this straight in the timer
        tst     RZTH
        brze    PCM_SetupTimer
        ; This number is too large. Well have to use the 64 bit divide
        ; Divide number by 8 (64 / 8 = 8)
        lsr     RZTH
        ror     RZTL    ; / 2
        lsr     RZTH
        ror     RZTL    ; / 2 / 2
        lsr     RZTH
        ror     RZTL    ; / 2 / 2 / 2 = /8

        ; Put in x64 divide
        ldi     RHT1, Timer0CKD64
        out     PlayTCR, RHT1
        rjmp    PCM_FinishSet
PCM_SetupTimer:
        ; Put in x8 divide
        ldi     RHT1, Timer0CKD8
        out     PlayTCR, RHT1
PCM_FinishSet:
        ; Timer counts up so invert value
        com     RZTL
        sts     ToneReload, RZTL

        ; All done now except we have to work out the timeout
        mvw    RXT, RWT                ; Load the requested frequency
        pop     RZTL                    ; And the time in 10ths of a second
        ; Check that time is valid
        tst     RZTL
        lbrze    PCM_InvalidMsg
        cpi     RZTL, 31                ; Max sound time is 30 (3 secs)
        lbrsh    PCM_InvalidMsg
        clr     RZTH
        rcall   mpy16u                  ; Multiply it
        ; Now divide it by 10
        ldiw    RXT, 10
        rcall   div16u                  ; Divide it
        ; Now store the result
        stsw    ToneTime, RZT

        ; Now enable the timer interupt
        ldi     RHT1, (1 << PlayIE)
        out     TIMSK, RHT1
	ret
;**************************************************************************
;	/BeginTone
;**************************************************************************

;**************************************************************************
;	TakeOverSPI
;
;	Expects:
;	Changes:
;	Must Not Change:
;
;	Disables interupts and takes over using the SPI bus.
;**************************************************************************	
TakeOverSPI:
	cli
	; Clear SPIF
	in	RHT1, SPSR
	in	RHT1, SPDR
	; Take over the SPI
	sbi	ChipSelectPort, CS0
	cbi	ChipSelectPort, CS0	; Select the chip

	ret
;**************************************************************************
;	/TakeOverSPI
;**************************************************************************

;**************************************************************************
;	SRSPIByte
;
;	Expects: RHT1 - to have the byte to send
;	Changes: RHT1
;	Must Not Change:
;
;	For use after using TakeOverSPI. Sends and receives 1 byte from
;	the SPI bus.
;**************************************************************************	
SRSPIByte:
	; Send a byte
	out	SPDR, RHT1
	; Wait for it to finish sending
DPM_WFS:
	in	RHT1, SPSR
	brrc	RHT1, SPIF, DPM_WFS
	; Now clear SPIF
	in	RHT1, SPSR
	in	RHT1, SPDR
	ret
;**************************************************************************
;	/SRSPIByte
;**************************************************************************

	
;**************************************************************************
;	GetUARTChar
;
;	Expects:
;	Changes: RHT1, RXTH
;	Must Not Change:
;
;	Gets a byte from the UART, checks parity and returns with it
;	in RHT1. Sets C if there was an eror
;	
;**************************************************************************	
GetUARTChar:
	; Get a byte from the UART
	bric	UCSRA, RXC, GetUARTChar
	; Check the parity and framing
	in	RHT1, UCSRA
	andi	RHT1, ((1 << FE) | (1 << OR))
	brnz	GB_Error
	; Now check parity
	; Get the byte
	in	RHT1, UDR
	mov	RXTH, RHT1
	; Check parity and clear the 8th bit
	cbr	RHT1, (1 << 7)
	rcall	GetParity	; Will return parity in bit 7
	cp	RXTH, RHT1	; If theyre not the same parity is not right
	brne	GB_Error
	; Clear the 8th bit
	cbr	RHT1, 0b10000000
	clc
	ret
GB_Error:
	sec
	ret
;**************************************************************************
;	/GetUARTChar
;**************************************************************************

;**************************************************************************
;	GetUARTByte
;
;	Expects:
;	Changes:
;	Must Not Change:
;
;	Gets a 2 chars from the UART, checks parity , converts to binary
;	and returns with it in RHT1. Sets C if there was an error. Sets
;	H if it received a CR (H is undefined if C is set)
;	
;**************************************************************************	
GetUARTByte:
	clr	RZTL
DPM_GetNibble:
	rcall	GetUARTChar
	brcc	DPM_NoErr
	ret	; There was an error
DPM_NoErr:
	; See if this a CR
	cpi	RHT1, CR
	brne	DPM_NotCR
	; This is a CR
	seh
	clc
	ret
DPM_NotCR:
	
	; Convert to a binary value from ASCII hex (lo8ercase for a-f)
	subi	RHT1, '0'
	; Test to see if it is hi8er than 9
	cpi	RHT1, 10
	brlo	DPM_DoneConversion
	; It was either a-f or an error
	subi	RHT1, ('a' - '0' - 10)
	; Check that it is belo8 16 (if it isnt its an error)
	cpi	RHT1, 16
	brsh	GB_Error
DPM_DoneConversion:
	; Return with the data in RHT1 if RZTL is set
	tst	RZTL
	brnz	DPM_GBRet
	; Swap this into the hi8 nibble
	mov	RZTH, RHT1
	ser	RZTL
	rjmp	DPM_GetNibble
DPM_GBRet:
	; First get the old nibble
	swap	RZTH
	or	RHT1, RZTH
	; Byte is now in RHT1
	clc
	clh
	ret
;**************************************************************************
;	/GetUARTByte
;**************************************************************************

;**************************************************************************
;	DoProgramMsg
;
;	Expects:
;	Changes:
;	Must Not Change:
;
;	This handles in a non-realtime way programming the flash.
;**************************************************************************	
DoProgramMsg:
	; This is a valid program message

	rcall	TakeOverSPI
	clt	; Show that we are not ready for a program
	; Start the program
	ldi	RHT1, FMMemoryPProgramTBufferUsingB2
	rcall	SRSPIByte	; Start the operation
	
	; Get the address
	rcall	DPM_GetByte
	sts	RxMsg, RHT1 ; Save the hi8 byte
	rcall	DPM_GetByte
	mov	RHT2, RHT1
	lds	RHT1, RxMsg ; Load the byte
	lsl	RHT2
	rol	RHT1	; The address is shifted left one
	rcall	SRSPIByte
	mov	RHT1, RHT2
	rcall	SRSPIByte
	clr	RHT1	; Start at buffer address 0
	rcall	SRSPIByte
	
	; Okay now we start receiving data
DPM_Loop:
	rcall	DPM_GetByte
	rcall	SRSPIByte	; And sending it
	set
	rjmp	DPM_Loop
DPM_CR:
	brtc	DPM_CRErr; If T was clear we werent ready for a CR
	
	; Okay we have a CR so program it
	sbi	ChipSelectPort, CS0
	; And send a Q message
	ldi	RHT1, 'Q'
	rcall	ProgSendByteToUART
	ldi	RHT1, CR
	rcall	ProgSendByteToUART
	; Now we are done
	sbi	ChipSelectPort, CS0

	; Double return (this was called in DPM_Loop)
	pop	RHT1
	pop	RHT1
	
DPM_CleanUp:	; This is called by the flash dump as well
	; Lastly set the comms back up
	clr	RHSPISt
        ClearCommsTx
	reti	; Return and enable interupts
	
DPM_GetByte:
	rcall	GetUARTByte
	; Now if there was an error
	brcs	DPM_Error
	brhs	DPM_CR
	; Return with the byte in RHT1
	ret
	
DPM_CRErr:
	Error	EarlyCRErr
	pop	RHT1
	pop	RHT1 ; Double return
	rjmp	DPM_CleanUp
			
DPM_Error:
	Error	ComsProgrammingErr
	pop	RHT1
	pop	RHT1 ; Double return
	rjmp	DPM_CleanUp
;**************************************************************************
;	/DoProgramMsg
;**************************************************************************	

;**************************************************************************
;	SendByteToUART
;
;	Expects: RHT1 - Byte to send
;	Changes: RHT1, RHT2, RXTL
;	Must Not Change: Non ISR registers (called from an ISR)
;
;	Waits for UDRE to be set and then outputs the byte.
; 	ProgSendByteToUART first enables Tx and then disables it.
;**************************************************************************	
SendByteToUART:
	rcall	GetParity
SBTU:	bric	UCSRA, UDRE, SBTU
	out	UDR, RHT1
	ret
		
ProgSendByteToUART:
	SetCommsTx
	rcall	GetParity
SBTU3:	bric	UCSRA, UDRE, SBTU3
	out	UDR, RHT1
	
; Wait for it to stop be send then disable Tx
SBTU2:	bric	UCSRA, TXC, SBTU2
	sbi	UCSRA, TXC	; Have to clear the bit by writing a 1 to it
	ClearCommsTx
	ret
;**************************************************************************	
;	/SendByteToUART
;**************************************************************************	

;**************************************************************************
;	BeginBigMessage
;
;	Expects:
;	Changes:
;	Must Not Change: Non ISR registers (called from an ISR)
;
;	Checks that the Tx buffer is empty. If it is not it logs and error and
;	double returns (ie returns from the routine that called it by popping
;	stuff off the stack. Otherwise enables the Tx transmitter.
;**************************************************************************	
BeginBigMessage:
	; Check that the buffer is empty
	lds	RZTL, TxBufferLen
	tst	RZTL
	brnz	BBM_NotEmpty
	; Check that it has finished sending the last character (a CR).
	bris	UCSRB, UDRIE, BBM_NotEmpty
	; Check that its actually finished (not just started sending it).
	bris	UCSRA, UDRE, BBM_Empty
BBM_NotEmpty:
	; The buffer was not empty
	; If we are in debug mode then disable it for a bit so that we dont spin
	; around in a loop (because the error handler will call dump).
	bst	RHFlags, DebugBit
	cbr	RHFlags, (1 << DebugBit)
	ComsError	ComsBufferInUse
	bld	RHFlags, DebugBit
	; And pop off the first return so we return from the other routine
	pop	RHT1
	pop	RHT1
	ret	; Return
BBM_Empty:
	cli	; Disable interupts
        SetCommsTx
        ret
;**************************************************************************
;	/BeginBigMessage
;**************************************************************************

;**************************************************************************
;	BeginMessage
;
;	Expects: RHT1 - header of the message to send
;		 RXTH - Length of the message to send
;	Changes:
;	Must Not Change: Non ISR registers (called from an ISR)
;
;	Checks that the Tx buffer is empty. If it is not it logs and error and
;	double returns (ie returns from the routine that called it by popping
;	stuff off the stack. Otherwise enables the Tx and sends the first part
;	of the message.
;**************************************************************************	
BeginMessage:
	; Check that the buffer is empty
	lds	RZTL, TxBufferLen
	tst	RZTL
	brnz	CTBE_NotEmpty
	; Check that it has finished sending the last character (a CR).
	bris	UCSRB, UDRIE, CTBE_NotEmpty
	; Check that its actually finished (not just started sending it).
	bris	UCSRA, UDRE, CTBE_Empty
CTBE_NotEmpty:
	; The buffer was not empty
	; If we are in debug mode then disable it for a bit so that we dont spin
	; around in a loop (because the error handler will call dump).
	bst	RHFlags, DebugBit
	cbr	RHFlags, (1 << DebugBit)
	ComsError	ComsBufferInUse
	bld	RHFlags, DebugBit
	; And pop off the first return so we return from the other routine
	pop	RHT1
	pop	RHT1
	ret
CTBE_Empty:
	cli	; Disable interupts while we fill the buffer
	; If it is empty then begin the message
        SetCommsTx
	sbi	UCSRB, UDRIE	; Must enable this interupt to send the buffer
	; Save the message
	sts	TxMsg, RHT1
	; Save the length
	sts	TxBufferLen, RXTH
	; Send our ID first
	ldi	RHT1, MY_ID
	rcall	GetParity
	out	UDR, RHT1
	
	ret
;**************************************************************************
;	/BeginMessage
;**************************************************************************

;**************************************************************************
;	SendHWord
;
;	Expects: RZT - Word to send in hex
;	Changes:
;	Must Not Change:
;
;	Converts the data in RYIsrH to a hex word (with leading zeroes)
;	and sends it.
;**************************************************************************	
SendHWord:
	mov	RHT1, RZTH
	swap	RHT1		; Send the hi8 nibble
SHW_1:	bric	UCSRA, UDRE, SHW_1
	rcall	SendASCIIHexNibble
	mov	RHT1, RZTH
SHW_2:	bric	UCSRA, UDRE, SHW_2
	rcall	SendASCIIHexNibble	; Send the lo8 nibble
	mov	RHT1, RZTL
	swap	RHT1
SHW_3:	bric	UCSRA, UDRE, SHW_3
	rcall	SendASCIIHexNibble
	mov	RHT1, RZTL
SHW_4:	bric	UCSRA, UDRE, SHW_4
	rcall	SendASCIIHexNibble
	ret
;**************************************************************************
;	/SendHWord
;**************************************************************************

;**************************************************************************
;	SendHByte
;
;	Expects: RHT1 - Word to send in hex
;	Changes: RHT2, RXTL
;	Must Not Change:
;
;	Converts the data in RHIsr1 to a hex word (with leading zeroes)
;	and sends it.
;**************************************************************************	
SendHByte:
	push	RHT1
	swap	RHT1			; Send the hi8 nibble
SHB_1:	bric	UCSRA, UDRE, SHB_1
	rcall	SendASCIIHexNibble	
	pop	RHT1			; Send the lo8 nibble
SHB_2:	bric	UCSRA, UDRE, SHB_2
	rjmp	SendASCIIHexNibble	; and return
;**************************************************************************
;	/SendHByte
;**************************************************************************

;**************************************************************************
;	SendASCIIHexNibble
;
;	Expects: RHT1 - Nibble to convert (in lo8er nibble)
;	Changes:
;	Must Not Change:
;
;	Converts the data in the lo8er nibble in RHIsr1 to ASCII hex and outputs
;	it (after adding parity).
;**************************************************************************	
SendASCIIHexNibble:
	; The nibble to send is contained in the lo8er half of RHIsr1
	; All we have to do is convert the nibble to ASCII (Y. parity), send it
	; and return.
	; -Convert the nibble to ASCII
	andi	RHT1, 0x0f	; AND off the upper nibble (not relevant)
	subi	RHT1, -48	; Add 0
	cpi	RHT1, 58	
	brlo	SAHN_NotOver	; Check if it was between 0-9 or a-f
	subi	RHT1, -39
SAHN_NotOver:
	rcall	GetParity
	; Output it
	out	UDR, RHT1
CT_Ret2:
	ret
;***********************************************************************
;	/SendASCIIHexNibble
;***********************************************************************

;**************************************************************************
;	CheckTone
;
;	Expects:
;	Uses:	
;
;       Check if there is a tone waiting to play. If there is then
;       starting it playing.
;
;**************************************************************************	
CT_Err:
        Error   SAY_BUFFER_EMPTY_ERR
        rjmp    CT_Ret

CheckTone:
        ; Check if there is a TONE_ESCAPE_CHAR in the speech buffer
        MultiByteCircularQueueQueryProc CT_Ret2, RZT, ToSayBuffer
        ld      RHT1, Z
        cpi     RHT1, TONE_ESCAPE_CHAR
        brne    CT_Ret2

        ; There is a sound in the buffer

        ; Check that is we are not playing the last tone still
        lds     RHT1, ToneReload
        tst     RHT1
        brnz    CT_Ret2

        ; Check that all the needed
        ; data is there as well
        lds     RHT1, ToSayBufferCount
        cpi     RHT1, 5
        brlo    CT_Ret2  ; Not enough room
        ; Also wait until weve finished playing the sound before we mess
        ; up the timer.
        lds     RHT1, PlayBufferCount
        tst     RHT1
        brnz    CT_Ret2

        cli
        ; Remove TONE_ESCAPE_CHAR first
        MultiByteCircularQueueRemoveProc CT_Err, RZT, ToSayBuffer

        ; Then type
        MultiByteCircularQueueRemoveProc CT_Err, RZT, ToSayBuffer
        ld      RXTL, Z
        ; Then frequency
        MultiByteCircularQueueRemoveProc CT_Err2, RZT, ToSayBuffer
        ld      RWTH, Z         ; Type of tone requested.
        MultiByteCircularQueueRemoveProc CT_Err2, RZT, ToSayBuffer
        ld      RWTL, Z
        ; Then time
        MultiByteCircularQueueRemoveProc CT_Err2, RZT, ToSayBuffer
        ld      RXTH, Z
        sei
        rcall   BeginTone
CT_Ret:
        ret
CT_Err2:
        rjmp    CT_Err
;**************************************************************************
;       /CheckTone	
;**************************************************************************

;**************************************************************************
;	ComsErrorHandler
;
;	Expects: An error code in RHIsr1
;	Uses:	RHIsr1, RYIsrL, RYIsrH (indirectly)
;
;	Does the same as Error except that it clears the Rx status.
;
;**************************************************************************	
ComsErrorHandler:
        ; Disable transmitter
        ClearCommsTx
	; Empty the buffer
	clr	RYIsrL
	sts	RxBufferLen, RYIsrL
	; Set the status to idle waiting for a message
	ldi	RHRxStatus, RX_IDLE
	; Fall through to ErrorHandler
;**************************************************************************
;	/ComsErrorHandler
;**************************************************************************	

;**************************************************************************
;	ErrorHandler
;
;	Expects: An error code in RHIsr1
;	Uses:	RHIsr1, RYIsrL, RYIsrH
;
;	Saves a error and displays it on the LEDs (this is done automatically
;	by the main loop).
;
;**************************************************************************	
ErrorHandler:
	; If there is already an error leave in the original error
	lds	RYIsrL, LastErr
	tst	RYIsrL
	breq	E_NoErr	; If there is already an error then do
	; a dump without overwriting the error thats stored.
	; If there is an error stored and it is NotImplementedErr then
	; if this message is more important put it in its place.
	cpi	RYIsrL, NotImplementedErr
	brne	E_Dump
	cpi	RHIsr1, NotImplementedErr
	breq	E_Dump	; If there was already a NotImplementedErr and this is
	; and not implemented error then leave the old one there.
E_NoErr:
	; There was no error already stored so store ours
	sts	LastErr, RHIsr1
	
	pop	RYIsrH		; Pop off the address of whowever called us.
	pop	RYIsrL		; hi8 byte first.
	stsw	LastErrAddress, RYIsr	; And store it.
	push	RYIsrL
	push	RYIsrH
	; Dump it if we are in debug mode
E_Dump:
	; Check if we are in debug mode
	sbrs	RHFlags, DebugBit
E_Exit:
	ret
	; Check that the buffer is empty (if its not then we dont try and send
	; a dump message).
	lds	RYIsrL, TxBufferLen
	tst	RYIsrL
	brnz	E_Exit
	; Check that it has finished sending the last character (a CR).
	bris	UCSRB, UDRIE, E_Exit
	; Check that its actually finished (not just started sending it).
	bric	UCSRA, UDRE, E_Exit
	; If the buffer is empty then send the dump message
	; Push all the register
	push	RHT1
	push	RHT2
	pushw	RZT
	pushw	RXT
	rcall	SendDumpMessage
	popw	RXT
	popw	RZT
	pop	RHT2
	pop	RHT1
	ret
;**************************************************************************
;	/ErrorHandler
;**************************************************************************	

;**************************************************************************
;	DoDecode:
;
;	Expects: A item in CompressedBuffer
;	Uses:	
;
;	Decompresses an item in the buffer and stores it in the play buffer
;	enabling the play timer.
;
;**************************************************************************
DD_EmptyBuf:	; We should never get an empty buffer
	Error	DDEmptyBufErr
DD_Ret:
	reti

DoDecode:
	cli
	; Load the item
	MultiByteCircularQueueRemoveProc	DD_EmptyBuf, RZT, CompressedBuffer
	ld	RHT1, Z
	; Also enable if the we are loading a sound
	tst	RHSPISt
	brze	DD_NoE
DD_Enable:
	; Dont enable it if it is already enabled
	bris	SPCR, SPIE, DD_NoE
	; Make sure to enable SPI interupt
	out	SPDR, RHT2
	sbi	SPCR, SPIE
DD_NoE:
	sei

	set	; To show that we should loop
	; Save this hi8 nibble for next time
	mov	RWTH, RHT1
	swap	RHT1	; hi8 nibble first
	
	lds	RHT2, DDIndex ; Load the last index
	; Find quantizer step size from lookup table using index
DD_Loop:
	andi	RHT1, 0x0f	; And off the hi8 nibble
	ldfp	RZT, DDStepSizeTable
	clr	RWTL	; For adding carry
	add	RZTL, RHT2	; Add twice to shift it left
	adc	RZTH, RWTL
	add	RZTL, RHT2
	adc	RZTH, RWTL
	; Now load the value
	lpm
	mov	RXTL, r0 ; Load the lo8 byte first
	inc	RZTL
	lpm
	mov	RXTH, r0
	
	; Save the step
	mvw	RZT, RXT
	
	; Inverse quantize the ADPCM code into a difference using the
	; quantizer step size
	lsr	RXTH	; Shift right 3 times (/ 8)
	ror	RXTL
	lsr	RXTH
	ror	RXTL
	lsr	RXTH
	ror	RXTL
	
	brrc	RHT1, 2, DD_Notx04 ; if(code & 4)
	addw	RXT, RZT	; diffq +, step
DD_Notx04:
	brrc	RHT1, 1, DD_Notx02 ; if(code & 2)
	mov	RHT2, RZTH		; diffq +, step >> 1
	mov	RWTL, RZTL
	lsr	RZTH
	ror	RZTL
	addw	RXT, RZT
	mov	RZTL, RWTL
	mov	RZTH, RHT2
DD_Notx02:
	brrc	RHT1, 0, DD_Notx01 ; if(code & 1)
	; diffq +, step >> 2
	lsr	RZTH
	ror	RZTL
	lsr	RZTH
	ror	RZTL
	addw	RXT, RZT
DD_Notx01:

	ldsw	RZT, DDPredSample
	; Add the difference to the predicted sample
	brrc	RHT1, 3, DD_Notx08 ; if(code & 8)
	subw	RZT, RXT	; predsample -, diffq
	; Check for overflo8
	brvc	DD_Wasx08
	ldiw	RZT, -32768
	rjmp	DD_Wasx08
DD_Notx08:
	addw	RZT, RXT	; predsample +, diffq
	; Check for overflo8 (carry cannot be used) so used MSB
	brvc	DD_Wasx08
	ldiw	RZT, 32767
DD_Wasx08:

	; Save the sample
	stsw	DDPredSample, RZT
	; Convert the converted sample to an 8-bit unsigned value
	subi	RZTH, 0x80
	cli
	; All so save it in the play buffer
	MultiByteCircularQueueAddProc	DD_BufFull, RXT, PlayBuffer
	; Now store it hi8 byte first
	st	X+, RZTH

	; Now enable the timer interupt
	sei
	ldi	RHT2, (1 << PlayIE)
	out	TIMSK, RHT2

DD_FinishOff:
	; Find new quantizer step size index
	ldfp	RZT, DDIndexTable
	clr	RWTL
	add	RZTL, RHT1		; RHT1 has the sample value
	adc	RZTH, RWTL
	lpm
	lds	RHT2, DDIndex
	add	RHT2, r0
	brpl	DD_Plus
	; Went belo8 zero
	clr	RHT2
	rjmp	DD_DoneI
DD_Plus:
	; Check for overflo8
	cpi	RHT2, 89
	brlo	DD_DoneI
	ldi	RHT2, 88
	
DD_DoneI:
	sts	DDIndex, RHT2
	; See if we are looping (we go twice)
	brtc	DD_RD
	clt	; Clear T for next time
	mov	RHT1, RWTH	; Load the 4-bit value saved in RWTH
	; And back
	rjmp	DD_Loop
DD_RD:

        ; Now check if it is time to reset back to our original state
        lds     RHT1, CountTillReset
        tst     RHT1
        brze    DD_NoCount
        ; There is a countdown till reset
        dec     RHT1
        brnz    DD_NoResetYet
        ; Reset the state for the beginning of another sound
        ldiw    RZT, 0
        stsw    DDPredSample, RZT
        sts     DDIndex, RZTL
DD_NoResetYet:
        ; Save the count
        sts     CountTillReset, RHT1
DD_NoCount:
	ret

DD_BufFull:
	sei
	; The buffer is full
	Error	DDBufFullErr
	rjmp	DD_FinishOff


;***************************************************************************
;*
;* "div16u" - 16/16 Bit Unsigned Division
;*
;* This subroutine divides the two 16-bit numbers
;* "dd8uH:dd8uL" (dividend) and "dv16uH:dv16uL" (divisor).
;* The result is placed in "dres16uH:dres16uL" and the remainder in
;* "drem16uH:drem16uL".
;*
;* Number of words	:19
;* Number of cycles	:235/251 (Min/Max)
;* Low registers used	:2 (drem16uL,drem16uH)
;* High registers used  :5 (dres16uL/dd16uL,dres16uH/dd16uH,dv16uL,dv16uH,
;*			    dcnt16u)
;*
;* Divides RZT by RYT and puts result in RZT and remainder in RHT3-2
;***************************************************************************

;***** Subroutine Register Variables

#define drem16uL RWTL
#define	drem16uH RHT2
#define	dres16uL RZTL
#define	dres16uH RZTH
#define	dd16uL	RZTL
#define	dd16uH	RZTH
#define	dv16uL	RXTL
#define	dv16uH	RXTH
#define	dcnt16u	RHT1

;***** Code

div16u:	clr	drem16uL	;clear remainder Low byte
	sub	drem16uH,drem16uH;clear remainder High byte and carry
	ldi	dcnt16u,17	;init loop counter
d16u_1:	rol	dd16uL		;shift left dividend
	rol	dd16uH
	dec	dcnt16u		;decrement counter
	brne	d16u_2		;if done
	ret			;    return
d16u_2:	rol	drem16uL	;shift dividend into remainder
	rol	drem16uH
	sub	drem16uL,dv16uL	;remainder = remainder - divisor
	sbc	drem16uH,dv16uH	;
	brcc	d16u_3		;if result negative
	add	drem16uL,dv16uL	;    restore remainder
	adc	drem16uH,dv16uH
	clc			;    clear carry to be shifted into result
	rjmp	d16u_1		;else
d16u_3:	sec			;    set carry to be shifted into result
	rjmp	d16u_1


;***************************************************************************
;*
;* "mpy16u" - 16x16 Bit Unsigned Multiplication
;*
;* This subroutine multiplies the two 16-bit register variables
;* mp16uH:mp16uL and mc16uH:mc16uL.
;* The result is placed in m16u3:m16u2:m16u1:m16u0.
;*
;* Number of words	:14 + return
;* Number of cycles	:153 + return
;* Low registers used	:None
;* High registers used  :7 (mp16uL,mp16uH,mc16uL/m16u0,mc16uH/m16u1,m16u2,
;*                          m16u3,mcnt16u)	
;*
; Multiplies RYT by RZT and stores result in RZT-RHT1-RHT2
;***************************************************************************

;***** Subroutine Register Variables

#define	mc16uL	RXTL
;multiplicand low byte
#define	mc16uH	RXTH
;multiplicand high byte
#define	mp16uL	RZTL
;multiplier low byte
#define	mp16uH	RZTH
;multiplier high byte
#define	m16u0	RZTL
;result byte 0 (LSB)
#define	m16u1	RZTH
;result byte 1
#define	m16u2	RHT1
;result byte 2
#define	m16u3	RHT2
;result byte 3 (MSB)
#define	mcnt16u	RWTL
;loop counter

;***** Code

mpy16u:	clr	m16u3		;clear 2 highest bytes of result
	clr	m16u2
	ldi	mcnt16u,16	;init loop counter
	lsr	mp16uH
	ror	mp16uL

m16u_1:	brcc	noad8		;if bit 0 of multiplier set
	add	m16u2,mc16uL	;add multiplicand Low to byte 2 of res
	adc	m16u3,mc16uH	;add multiplicand high to byte 3 of res
noad8:	ror	m16u3		;shift right result byte 3
	ror	m16u2		;rotate right result byte 2
	ror	m16u1		;rotate result byte 1 and multiplier High
	ror	m16u0		;rotate result byte 0 and multiplier Low
	dec	mcnt16u		;decrement loop counter
	brne	m16u_1		;if not done, loop more
	ret


; Frequency table lists
; Each entry is 32 bytes long
ToneTables:
        ; Silent wave
        .byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
        .byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
        .byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
        .byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
        ; Square wave
        .byte 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff
        .byte 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff
        .byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
        .byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
        ; Triangle wave
        .byte 16,  32,  47,  64,  80,  96,  112, 128
        .byte 143, 159, 175, 191, 207, 223, 239, 255
        .byte 239, 223, 207, 191, 175, 159, 143, 128
        .byte 112, 96,  80,  64,  47,  32,  16,  0
        ; Sine wave
        .byte 152, 177, 199, 218, 234, 245, 253, 255
        .byte 253, 245, 234, 218, 199, 177, 152, 128
        .byte 104, 79,  57,  38,  22,  11,  3,   1
        .byte 3,   11,  22,  38,  57,  79,  104, 128
EndToneTables:
Num_Tones = (ToneTables - EndToneTables) / 32

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
;	Includes
;
;**************************************************************************	
; Parity
GetParity:
GetEvenParity	RHT1, RHT2, RXTL
	ret
ISRGetParity:	; ISR version of GetParity
GetEvenParity	RHIsr1, RHIsr2, RYIsrL
	ret
	
	
DDIndexTable:
	; This table looks backwards to make it work right
	.byte	-1, -1, -1, -1, 2, 4, 6, 8
	.byte	-1, -1, -1, -1, 2, 4, 6, 8
	
DDStepSizeTable:
	.word	7, 8, 9, 10, 11, 12, 13, 14, 16, 17
	.word	19, 21, 23, 25, 28, 31, 34, 37, 41, 45
	.word	50, 55, 60, 66, 73, 80, 88, 97, 107, 118
	.word	130, 143, 157, 173, 190, 209, 230, 253, 279, 307
	.word	337, 371, 408, 449, 494, 544, 598, 658, 724, 796
	.word	876, 963, 1060, 1166, 1282, 1411, 1552, 1707, 1878, 2066
	.word	2272, 2499, 2749, 3024, 3327, 3660, 4026, 4428, 4871, 5358
	.word	5894, 6484, 7132, 7845, 8630, 9493, 10442, 11487, 12635, 13899
	.word	15289, 16818, 18500, 20350, 22385, 24623, 27086, 29794, 32767

SizeTable:
	; Number of segments for each size in the status register
	; See Appnote for explanation
	.word	((256 - 1) << 1)
	.word   ((512 - 1) << 1)
	.word     ((1024 - 1) << 1)
	.word    ((2048 - 1) << 1)
	.word     ((4096 - 1) << 1)
	.word     ((8192 - 1) << 1)
	.word     ((16384 - 1) << 1)
	.word     ((32768 - 1) << 1)
;**************************************************************************
;**************************************************************************
;
;	/Includes
;
;**************************************************************************
;**************************************************************************
 .org	FLASHEND - (15 * 2), 0xff
Name:		.ascii	__FILE__

.org	FLASHEND - (7 * 2), 0xff
Version:	.ascii	"Version:" VERSION_STRING

