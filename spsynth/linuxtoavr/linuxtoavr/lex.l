/***************************************************************************
                          lex.l  -  description                              
                             -------------------                                         
    begin                : Fri Jul 20 2001                                           
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

%option	yylineno
%option	noyywrap

%{
    #include <stdlib.h>
    #include <stdio.h>
    #include <string.h>

    #include "yacc.h"
    #include "bool.h"
    #include "parse.h"

    YYSTYPE yylval;

%}

delim		[ \t\r]
ws		{delim}+
digit		[0-9]
number		{digit}+
character       [a-zA-Z\_\*\!\.\/\@\-]
string          {character}*[{character}{number}]*
table           \#{string}

%%

{ws}		{ /* Do nothing - ignore */ }
"property"	{ return PROPERTY; }
{string}        {
                        /* This is either a string or comment or both */
                        char *comment;

                        comment = strstr(yytext, "//");
                        if(comment) {
                                char c;

                                *comment = 0;

                                while((c = input()) != '\n' && c != 0);

                                if(c == '\n')
                                        unput('\n');

                        }

                        if(comment != yytext) {
                                yylval.str = strdup(yytext);
                                return STRING;
                        }
                }
{number}	{
                        /* First convert the number to decimal. */
                        yylval.num = atoi(yytext);
                        return NUMBER;
                }
{table}         {
                        yylval.str = strdup(yytext + 1);
                        return TABLE;
                }
['\n'\=]      {
                        return *yytext;
                }
.               {
                        char tmp[256];
                        sprintf(tmp, "Invalid char '%c'", *yytext);
                        yyerror(tmp);
                }

%%

