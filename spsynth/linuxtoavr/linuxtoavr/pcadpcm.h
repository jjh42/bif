/***************************************************************************
                          pcadpcm.h  -  description
                             -------------------
    begin                : Wed Jan 17 2001
    copyright            : (C) 2001 by Jonathan Hunt
    email                : jhuntnz@users.sourceforge.net
 ***************************************************************************/

/***************************************************************************
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 ***************************************************************************/
/*****************************************************************************
* Filename: PCADPCM.H *
******************************************************************************
* Author: Rodger Richey *
* Title: Senior Applications Engineer *
* Company: Microchip Technology Incorporated *
* Revision: 0 *
* Date: 1-11-96 *
* Compiled using Borland C+ Version 3.1 *
******************************************************************************
* This is the header file that contains the ADPCM structure definition *
* and the function prototypes. *
*****************************************************************************/
struct ADPCMstate {
short prevsample;/* Predicted sample */
int previndex;/* Index into step size table */
};
/* Function prototype for the ADPCM Encoder routine */
char ADPCMEncoder(short , struct ADPCMstate *);
/* Function prototype for the ADPCM Decoder routine */
int ADPCMDecoder(char , struct ADPCMstate *);
