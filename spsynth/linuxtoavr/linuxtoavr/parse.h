/***************************************************************************
                          parse.h  -  description
                             -------------------
    begin                : Sun Aug 12 2001
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

extern int yyerror(char *err, ...);
extern BOOL parse_input(FILE *input_file);
extern void parsed_pause(const char *define, int len);
extern const char *lastsoundname;
void parsed_sound(const char *table /* NULL if not in table */,
                        const char *tablename /* NULL if not in table */,
                        const char *define, const char *filename,
                        char *extras);
void parsed_equals(const char *table, const char *tablename,
                        char *extras /* Space seperated */);
void parsed_pause(const char *name, int len);
void parsed_property(const char *table, const char *property, int val);
BOOL isdef(const char *def);
const char *getdefinefor(const char *eq);
