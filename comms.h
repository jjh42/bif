/***************************************************************************
;
;	coms.h		This is the include file for the UART serial 
;			communcations. It contains a description of how the
;			coms messages look etc and all the addresses of the
;			processor addresses and all the messages that to each
;			processor.
;
;**************************************************************************/

/*** Beginheader */
#ifndef _COMS_H
#define _COMS_H

/**************************************************************************
;
;	Baud Rates
;
;*************************************************************************/
#define COMMS_BAUD      19200
#define COMS_BAUD       COMMS_BAUD
/**************************************************************************
;
;	/Baud Rates
;
;*************************************************************************/

#ifndef CR
#define	CR			0x0D
#endif /* CR */

/* A message with a length of CR_MSG is a message that is not a set length but
 * is terminated by a CR. */
#ifndef CR_MSG
#define CR_MSG			0xff
#endif /* CR_MSG */


//**************************************************************************
//
//	Processor Addresses
//
//**************************************************************************
//	Processor Name		ASCII Id		Type		
//--------------------------------------------------------------------------
//	Base			B			AT90S8515	
//	SpSynth			S			AT90S4433
//	Infrared		I			AT90S2313

#define	BASE_ID		'M'
#define BASE_LID	'm'
#define	SPSYNTH_ID	'S'
#define SPSYNTH_LID	's'
#define IR_ID		'I'
#define IR_LID		'i'

//**************************************************************************
//
//	/Processor Addresses
//
//**************************************************************************

/**************************************************************************
//
//	Generic Messages
//
*************************************************************************/



#define	DUMP_MSG	'D'
#define DUMP_MSG_LEN	0

/* Second message usable for dump messages. */
#define DUMP_EEPROM	'E'
#define DUMP_FLASH	'F'
#define DUMP_REGISTERS	'R'
#define DUMP_SRAM	'S'

#define SET_MSG		'Z'
#define SET_MSG_LEN	3

#define VERSION_MSG	'V'
#define VERSION_MSG_LEN	0

/**************************************************************************
//
//	/Generic Messages
//
*************************************************************************/

/**************************************************************************
//
//	Generic Replies
//
*************************************************************************/

#define	VERSION_REPLY	'V'
#define VERSION_REPLY_LEN 2

#define ERROR_REPLY     'E'
#define ERROR_REPLY_LEN 3

/**************************************************************************
//
//	/Generic Replies
//
*************************************************************************/

//**************************************************************************
//
//	Base
//
//**************************************************************************
//**************************************************************************
// Accepts
//**************************************************************************
// Base messages
#define BPOWER_MSG      'P'
#define BPOWER_MSG_LEN   1
// 1 byte - Power Globals
	// Bit #
	// 0-1	Power
	// 2-3	Lights
	// 4	Stealth
	// 5	Diagnostics Mode
#define	BINTENSITY_MSG	 'I'	// Set Headlight Intensity
#define	BINTENSITY_MSG_LEN 1
// 1 byte - 0-255 Intensity setting (255 full-on 0 off)
#define	BTRAVEL_MSG	 'T'	// Set the travel globals
#define	BTRAVEL_MSG_LEN	 1
// 1 byte - Travel Globals
	// Bit #
	// 0	Set front (Set to reverse)
	// 1	Switch mode (Set if auto-switching is allowed)
	// 2-3	Travel mode (0 - Turn	 and Straight 1 - Circle 2 - Extreme)
	// 4	Auto-Stop (Set when auto-stop is enabled)
								
#define	BHALT_MSG	 'H'	// Stop and clear all instructions.
#define	BHALT_MSG_LEN	 0
// [No Data]
#define	BGOLEFT_MSG	 'g'	// Go left	
#define	BGOLEFT_MSG_LEN	 4
// 1 byte - 0-256 Speed to go
// 1 byte - 0-180 Degrees from current angle
// 2 bytes- 0-65535 millimeters to move
#define	BGORIGHT_MSG	 'G'	// Go right
#define BGORIGHT_MSG_LEN 4
// 1 byte - 0-256 Speed to go
// 1 byte - 0-180 Degrees from current angle
// 2 bytes- 0-65535- Millimeters to move
#define	BREVERSE_MSG	 'b'	// Go in reverse
#define BREVERSE_MSG_LEN 3
// 1 byte - 0-255 Speed to go
// 2 bytes- 0-65535- Millimeters to move
#define	BSPEED_MSG	 'S'	// Override Go speed
#define	BSPEED_MSG_LEN	 1
// 1 byte - 0-256 Override.
#define	BGOLFWD_MSG	 'l'	// Set Left motor going forward
#define	BGOLFWD_MSG_LEN	 1
// 1 byte - Speed
#define	BGOLBWD_MSG	 'L'	// Set Left motor going backwards
#define	BGoLBWD_MSG_LEN	 1
// 1 byte - Speed
#define	BGORFWD_MSG	 'r'	// Set Right motor going forward
#define	BGORFWD_MSG_LEN	 1
// 1 byte GoRBwdMsg	 'R'	// Set Right motor going backwards
#define	BGORBWD_MSG	 'R'
#define	BGORBWD_MSG_LEN	 1
// 1 byte - Speed
//**************************************************************************
// /Accepts
//**************************************************************************
//**************************************************************************
// Sends When Polled
//**************************************************************************
#define	BSWITCH_REPLY	 'Z'
#define	BSWITCH_REPLY_LEN 2
// 1 byte
	// Bit #
#define	BMOVEMENT_REPLY	   'M'
#define	BMOVEMENT_REPLY_LEN 1
// 1 byte
	// Bit #
	// 0	Set if we stopped because the go buffer was empty
	//		(not because of bumper switches).
	// 7	Set if reversing otherwise cleared
//**************************************************************************
// /Sends When Polled
//**************************************************************************

//**************************************************************************
//
//	/Base
//
//**************************************************************************

//**************************************************************************
//
//	SpSynth
//
//**************************************************************************
//**************************************************************************
// Accepts
//**************************************************************************
//**************************************************************************
// Accepts
//**************************************************************************

#define SSAY_MSG	'T'	
#define SSAY_MSG_LEN	CR_MSG

#define	SPROGRAM_MSG	'P' // Program External Flash
#define	SPROGRAM_MSG_LEN 0

#define	SREAD_MSG	'R'	// Read Flash
#define	SREAD_MSG_LEN	2	
	// 2 bytes address
	// Will reply with the data dump of the page
#define	STEST_MSG  	'T' // Test flash
#define	STEST_MSG_LEN  	0
	// Will reply with an error or Q if flash is okay
#define	SSPIDEBUG_MSG  'D' // Debug flash
#define	SSPIDEBUG_MSG_LEN  0
#define	SFLAG_MSG  'F'	// Flag Message
#define	SFLAG_MSG_LEN  1
	// 1 byte of flags
	// Bit 0 Debug bit
#define	STONE_MSG  'G' // Generate Tone
#define	STONE_MSG_LEN  3
	
//**************************************************************************
// /Accepts
//**************************************************************************
//**************************************************************************
// Sends When Polled
//**************************************************************************
#define	SFREE_REPLY	'F'
#define SFREE_REPLY_LEN	1
//**************************************************************************
// /Sends When Polled
//**************************************************************************
//**************************************************************************
//
//	/SpSynth
//
//**************************************************************************

#endif

/*** endheader */
