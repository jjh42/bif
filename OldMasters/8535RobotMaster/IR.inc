;*****************************************************
;
;	Name: InfraRed (IR.INC)
;	Description: Definitions for InfraRed sensor
;	Author: Robert Hunt
;	Created: November 2000
;
;	Mod. Number: 7
;	Last Updated: 23 June 2001
;	Updated by: Robert Hunt
;
;******************************************************

;*****************************************************
;
; Public Constants
;
;****************************************************

; Infrared remote buttons by row and column starting from top-left
.EQU IR_R1_C1 = 77
.EQU IR_R1_C2 = 86
.EQU IR_R1_C3 = 79
.EQU IR_R1_C4 = 70
.EQU IR_R2_C1 = 78
.EQU IR_R2_C2 = 80
.EQU IR_R2_C3 = 85
.EQU IR_R2_C4 = 81
.EQU IR_R3_C1 = 1
.EQU IR_R3_C2 = 2
.EQU IR_R3_C3 = 3
.EQU IR_R3_C4 = 29
.EQU IR_R4_C1 = 4
.EQU IR_R4_C2 = 5
.EQU IR_R4_C3 = 6
.EQU IR_R5_C1 = 7
.EQU IR_R5_C2 = 8
.EQU IR_R5_C3 = 9
.EQU IR_R5_C4 = 12
.EQU IR_R6_C1 = 10
.EQU IR_R6_C2 = 0
.EQU IR_R6_C3 = 11
.EQU IR_R6_C4 = 13
.EQU IR_R7_C1 = 23
.EQU IR_R7_C2 = 22
.EQU IR_R7_C3 = 19
.EQU IR_R7_C4 = 18
.EQU IR_R8_C1 = 27
.EQU IR_R8_C2 = 26
.EQU IR_R8_C3 = 21
.EQU IR_R8_C4 = 20
.EQU IR_R9_C1 = 31
.EQU IR_R9_C2 = 30
.EQU IR_R9_C3 = 25
.EQU IR_R9_C4 = 24
.EQU IR_R10_C1 = 15
.EQU IR_R10_C2 = 14
.EQU IR_R10_C3 = 17
.EQU IR_R10_C4 = 28


; Infrared remote buttons by original function name
.EQU IR_0 = IR_R6_C2
.EQU IR_1 = IR_R3_C1
.EQU IR_2 = IR_R3_C2
.EQU IR_3 = IR_R3_C3
.EQU IR_4 = IR_R4_C1
.EQU IR_5 = IR_R4_C2
.EQU IR_6 = IR_R4_C3
.EQU IR_7 = IR_R5_C1
.EQU IR_8 = IR_R5_C2
.EQU IR_9 = IR_R5_C3

.EQU IR_1MINUS = IR_R6_C1
.EQU IR_2MINUS = IR_R6_C2

.EQU IR_ALT = IR_R3_C4
.EQU IR_UP = IR_R5_C4
.EQU IR_DOWN = IR_R6_C4

.EQU IR_VOLUME_DOWN = IR_R7_C1
.EQU IR_VOLUME_UP = IR_R7_C2
.EQU IR_CHANNEL_DOWN = IR_R7_C3
.EQU IR_CHANNEL_UP = IR_R7_C4
.EQU IR_BRIGHTNESS_DOWN = IR_R9_C1
.EQU IR_BRIGHTNESS_UP = IR_R9_C2
.EQU IR_CONTRAST_DOWN = IR_R10_C1
.EQU IR_CONTRAST_UP = IR_R10_C2
.EQU IR_MUTE = IR_R8_C3
.EQU IR_TV_VIDEO = IR_R8_C4
.EQU IR_TRACKING = IR_R10_C3
.EQU IR_POWER = IR_R10_C4


; Infrared remote buttons by our robot function name
.EQU IR_R_FORWARD = IR_R1_C1
.EQU IR_R_STRAIGHT = IR_R1_C2
.EQU IR_R_SPEED = IR_R1_C3
.EQU IR_R_LIGHTS = IR_R1_C4
.EQU IR_R_REVERSE = IR_R2_C1
.EQU IR_R_ANGLE = IR_R2_C2
.EQU IR_R_STEALTH = IR_R2_C3
.EQU IR_R_INTENSITY = IR_R2_C4
.EQU IR_R_ENTER = IR_R3_C4
.EQU IR_R_CLEAR = IR_R6_C1
.EQU IR_R_PLUS_MINUS = IR_R6_C3
.EQU IR_R_LEFT = IR_R7_C1
.EQU IR_R_RIGHT = IR_R7_C2
.EQU IR_R_OFF = IR_R7_C3
.EQU IR_R_ON = IR_R7_C4
.EQU IR_R_QUERY = IR_R8_C1

.EQU IR_R_MANUAL = IR_R8_C3
.EQU IR_R_AUTO = IR_R8_C4
.EQU IR_R_DIAGNOSTICS = IR_R9_C1
.EQU IR_R_AUTOSTOP = IR_R9_C2
.EQU IR_R_TRAVEL_MODE = IR_R9_C3
.EQU IR_R_FRONT_BACK_MODE = IR_R9_C4
.EQU IR_R_HELP = IR_R10_C1
.EQU IR_R_DEMO = IR_R10_C2
.EQU IR_R_POWER = IR_R10_C3
.EQU IR_R_HALT = IR_R10_C4

; Other definitions

.EQU IRRepeat = 0xFF
.EQU IRError = 0xFE
.EQU IRNoCommand = 0xFD
.EQU IRHighestValidCommand = 86


;***** End of IR.inc *****
