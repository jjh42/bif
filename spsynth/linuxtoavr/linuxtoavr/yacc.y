/***************************************************************************
                          yacc.y  -  description
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

/* Yacc file for parsing expressions in the input.conf file. See start of file
 * for summary of expressions.
 */

%{
        #include        <stdlib.h>
        #include        <string.h>
        #include        <stdio.h>

        #include        "bool.h"
        #include        "parse.h"

        extern int yylex();

        char *replace(char *tok, const char *repl);

        #define         YYDEBUG         1
%}

%union {
        char *str;
        int num;
       }

%token <num> NUMBER
%token <str> STRING
%token <str> TABLE
%token PROPERTY

%type <str> equals
%type <str> eequals
%type <str> extras

%start input

%%

input   : /* empty */
        | input line
        ;

line    : expr '\n'
        | '\n'
        | error '\n' { yyerrok; /* Recovery from syntax errors */ }
        ;

expr    : STRING NUMBER
                {
                        /* Pause entry */
                        parsed_pause($1, $2);
                }
        | STRING STRING STRING
                {
                        /* This is a simple - not table sound entry */
                        parsed_sound(NULL, NULL, replace($2, $1), replace($3, $1), NULL);
                        free($1);
                }
        | STRING STRING
                {
                        /* Simplest possible sound entry */
                        parsed_sound(NULL, NULL, $1, $2, NULL);
                }
        | TABLE STRING STRING STRING extras
                {
                        /* Table entry sound */
                        parsed_sound($1, $2, replace($3, $2), replace($4, $2), $5);
                }
        | TABLE STRING '=' equals
                {
                        /* Equals entry */
                        if(strchr($4, '*') && !lastsoundname) {
                                /* There was a * but there was no
                                 * sound last
                                 */
                                yyerror("Asterik with no sound last");
                        }
                        parsed_equals($1, $2, $4);
                }
	| TABLE PROPERTY STRING NUMBER 
		{
		    // Set property
			parsed_property($1, $3, $4);
		}
        ;

eequals : equals
        | /* empty */   { $$ = 0; }
        ;
/* This is because an empty equals is illegal */
equals  : STRING eequals {
                            if(lastsoundname)
                                $1 = replace($1, lastsoundname);

                           /* First check that $1 is defined */
                           if(!isdef($1)) {
                                /* This is either an undefined symbol
                                 * or else it is using another equals */
                                const char *def = getdefinefor($1);

                                if(!def)
                                        yyerror("Undefined symbol %s", $1);
                                else {
                                        /* This is another define */
                                        free($1);
                                        $1 = strdup(def);
                                }
                           }

                           if($2 != 0) {
                                char *str;
                                str = realloc($1, strlen($1) + strlen($2) + 2);
                                strcat(str, " ");
                                strcat(str, $2);
                                free($2);
                                $$ = str;
                           }
                           else
                                $$ = $1;
                          }
        ;

extras  : STRING extras {
                          if($2 != 0) {
                                char *str;
                                str = realloc($1, strlen($1) + strlen($2) + 2);
                                strcat(str, " ");
                                strcat(str, $2);
                                free($2);
                                $$ = str;
                          }
                          else
                                $$ = $1;
                        }
        |  /*empty */   { $$ = 0;  }
        ;

	
%%

/* Replace all occurences of '*' in tok with repl. Frees tok if necessary.
 * Returned string must be freed.
 */
char *replace(char *tok, const char *repl)
{
        const char *orgtok = tok;
        char *newstr = NULL;
        char *pos;
        size_t len = 1;
        size_t repllen = strlen(repl);

        while((pos = strchr(tok, '*'))) {
                *pos = 0;
                len += pos - tok + repllen;
                if(newstr)
                        newstr = realloc(newstr, len);
                else {
                        newstr = malloc(len);
                        *newstr = 0;
                }
                strcat(newstr, tok);
                strcat(newstr, repl);
                tok = pos + 1;
        }

        if(newstr ==NULL)
                return tok;
        /* Have to tack the rest of the item on the end */
        len += strlen(tok);
        newstr = realloc(newstr, len);
        strcat(newstr, tok);

        free((void*)orgtok);
        return newstr;
}