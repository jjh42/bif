; This file is made automatically by linuxtoavr
; (C) Jonathan Hunt. It is available under the GNU
; license version 2 or any later version (at your option)
;
; Any changes made to this file will be overwritten
;
;
.equ ShortPause = 0x1 ; 1
.equ WordPause = 0x2 ; 2
.equ SentencePause = 0x3 ; 3

.equ PH_IY = 0x4 ; 4
.equ PH_EY = 0x5 ; 5
.equ PH_AE = 0x6 ; 6
.equ PH_AO = 0x7 ; 7
.equ PH_UH = 0x8 ; 8
.equ PH_ER = 0x9 ; 9
.equ PH_AH = 0xa ; 10
.equ PH_AW = 0xb ; 11
.equ PH_IH = 0xc ; 12
.equ PH_EH = 0xd ; 13
.equ PH_AA = 0xe ; 14
.equ PH_OW = 0xf ; 15
.equ PH_UW = 0x10 ; 16
.equ PH_AX = 0x11 ; 17
.equ PH_AY = 0x12 ; 18
.equ PH_OY = 0x13 ; 19
.equ PH_OX = 0x14 ; 20

.equ PH_p = 0x15 ; 21
.equ PH_t = 0x16 ; 22
.equ PH_k = 0x17 ; 23
.equ PH_f = 0x18 ; 24
.equ PH_TH = 0x19 ; 25
.equ PH_s = 0x1a ; 26
.equ PH_SH = 0x1b ; 27
.equ PH_h = 0x1c ; 28
.equ PH_n = 0x1d ; 29
.equ PH_l = 0x1e ; 30
.equ PH_y = 0x1f ; 31
.equ PH_CH = 0x20 ; 32
.equ PH_WH = 0x21 ; 33
.equ PH_b = 0x22 ; 34
.equ PH_d = 0x23 ; 35
.equ PH_g = 0x24 ; 36
.equ PH_v = 0x25 ; 37
.equ PH_DH = 0x26 ; 38
.equ PH_z = 0x27 ; 39
.equ PH_ZH = 0x28 ; 40
.equ PH_m = 0x29 ; 41
.equ PH_NG = 0x2a ; 42
.equ PH_w = 0x2b ; 43
.equ PH_r = 0x2c ; 44
.equ PH_j = 0x2d ; 45

.equ SP_point = 0x2e ; 46

.equ SP_zero = 0x2f ; 47
.equ SP_one = 0x30 ; 48
.equ SP_two = 0x31 ; 49
.equ SP_three = 0x32 ; 50
.equ SP_four = 0x33 ; 51
.equ SP_five = 0x34 ; 52
.equ SP_six = 0x35 ; 53
.equ SP_seven = 0x36 ; 54
.equ SP_eight = 0x37 ; 55
.equ SP_nine = 0x38 ; 56
.equ SP_ten = 0x39 ; 57
.equ SP_eleven = 0x3a ; 58
.equ SP_twelve = 0x3b ; 59
.equ SP_thirteen = 0x3c ; 60
.equ SP_fourteen = 0x3d ; 61
.equ SP_fifteen = 0x3e ; 62
.equ SP_sixteen = 0x3f ; 63
.equ SP_seventeen = 0x40 ; 64
.equ SP_eighteen = 0x41 ; 65
.equ SP_nineteen = 0x42 ; 66
.equ SP_twenty = 0x43 ; 67
.equ SP_thirty = 0x44 ; 68
.equ SP_forty = 0x45 ; 69
.equ SP_fifty = 0x46 ; 70
.equ SP_sixty = 0x47 ; 71
.equ SP_seventy = 0x48 ; 72
.equ SP_eighty = 0x49 ; 73
.equ SP_ninety = 0x4a ; 74
.equ SP_hundred = 0x4b ; 75
.equ SP_thousand = 0x4c ; 76
.equ SP_million = 0x4d ; 77

.equ SP_first = 0x4e ; 78
.equ SP_second = 0x4f ; 79
.equ SP_third = 0x50 ; 80

.equ SP_a = 0x51 ; 81
.equ SP_the = 0x52 ; 82
.equ SP_am = 0x53 ; 83
.equ SP_is = 0x54 ; 84
.equ SP_are = 0x55 ; 85
.equ SP_and = 0x56 ; 86
.equ SP_but = 0x57 ; 87
.equ SP_not = 0x58 ; 88
.equ SP_yet = 0x59 ; 89

.equ SP_at = 0x5a ; 90
.equ SP_in = 0x5b ; 91

.equ SP_yes = 0x5c ; 92
.equ SP_no = 0x5d ; 93

.equ SP_off = 0x5e ; 94
.equ SP_on = 0x5f ; 95

.equ SP_low = 0x60 ; 96
.equ SP_high = 0x61 ; 97

.equ SP_left = 0x62 ; 98
.equ SP_right = 0x63 ; 99

.equ SP_forward = 0x64 ; 100
.equ SP_reverse = 0x65 ; 101

.equ SP_stop = 0x66 ; 102
.equ SP_go = 0x67 ; 103

.equ SP_front = 0x68 ; 104
.equ SP_back = 0x69 ; 105

.equ SP_automatic = 0x6a ; 106
.equ SP_manual = 0x6b ; 107

.equ SP_big = 0x6c ; 108
.equ SP_small = 0x6d ; 109

.equ SP_attack = 0x6e ; 110
.equ SP_retreat = 0x6f ; 111

.equ SP_reset = 0x70 ; 112
.equ SP_clear = 0x71 ; 113
.equ SP_enter = 0x72 ; 114
.equ SP_number = 0x73 ; 115
.equ SP_digit = 0x74 ; 116
.equ SP_letter = 0x75 ; 117

.equ SP_valid = 0x76 ; 118
.equ SP_correct = 0x77 ; 119

.equ SP_normal = 0x78 ; 120
.equ SP_test = 0x79 ; 121
.equ SP_full = 0x7a ; 122

.equ SP_query = 0x7b ; 123
.equ SP_speak = 0x7c ; 124
.equ SP_mode = 0x7d ; 125
.equ SP_diagnostic = 0x7e ; 126
.equ SP_light = 0x7f ; 127
.equ SP_power = 0x80 ; 128
.equ SP_speed = 0x81 ; 129
.equ SP_stealth = 0x82 ; 130
.equ SP_intensity = 0x83 ; 131
.equ SP_distance = 0x84 ; 132
.equ SP_position = 0x85 ; 133

.equ SP_switch = 0x86 ; 134
.equ SP_bumper = 0x87 ; 135
.equ SP_tilt = 0x88 ; 136

.equ SP_battery = 0x89 ; 137
.equ SP_level = 0x8a ; 138
.equ SP_charge = 0x8b ; 139
.equ SP_charging = 0x8c ; 140

.equ SP_travel = 0x8d ; 141
.equ SP_turn = 0x8e ; 142
.equ SP_straight = 0x8f ; 143
.equ SP_angle = 0x90 ; 144
.equ SP_circle = 0x91 ; 145
.equ SP_extreme = 0x92 ; 146

.equ SP_demo = 0x93 ; 147
.equ SP_help = 0x94 ; 148
.equ SP_error = 0x95 ; 149
.equ SP_hello = 0x96 ; 150
.equ SP_sorry = 0x97 ; 151
.equ SP_name = 0x98 ; 152
.equ SP_robot = 0x99 ; 153
.equ SP_version = 0x9a ; 154

.equ SP_date = 0x9b ; 155
.equ SP_time = 0x9c ; 156
.equ SP_lattitude = 0x9d ; 157
.equ SP_longitude = 0x9e ; 158
.equ SP_bearing = 0x9f ; 159
.equ SP_temperature = 0xa0 ; 160
.equ SP_Celsius = 0xa1 ; 161
.equ SP_Fahrenheit = 0xa2 ; 162
.equ SP_millimetre = 0xa3 ; 163
.equ SP_degree = 0xa4 ; 164
.equ SP_hour = 0xa5 ; 165
.equ SP_minute = 0xa6 ; 166

.equ SP_oops = 0xa7 ; 167

.equ SP_Ouch = 0xa8 ; 168
