/***************************************************************************
                          parse.c  -  description
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

#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>

#include "bool.h"
#include "main.h"
#include "parse.h"
#include "makedump.h"

/* Maximum number of languages allowed. */
#define MAX_LANGAUGES   10
#define FILE_PREFIX     "sounds_"
#define FILE_POSTFIX    ".c"
#define MAX_LANGS       10


struct LANGTABLEENTRYtag;
struct LANGTABLEENTRYtag {
                struct LANGTABLEENTRYtag *next; /* Linked list */
                const char *name;
                const char *define;
        };
typedef struct LANGTABLEENTRYtag LANGTABLEENTRY;


typedef struct {
                const char *lang;
                /* Properties of this language */
                int prop_inclusivetable;
                LANGTABLEENTRY *firstentry;
                LANGTABLEENTRY *lastentry;
        } LANGENTRY;
int numlangs = 0;
LANGENTRY langs[MAX_LANGS];

extern FILE *yyin;
extern int yydebug;
extern int yylineno;

int numerrs = 0;
const char *lastsoundname = 0;

struct DEFINETABLEENTRYtag;
typedef struct DEFINETABLEENTRYtag {
                struct DEFINETABLEENTRYtag *next; /* Linked list */
                const char *define;
        } DEFINETABLEENTRY;
DEFINETABLEENTRY *deffirstentry = 0;
DEFINETABLEENTRY *deflastentry = 0;

int yyerror(char *err, ...)
{
        va_list args;

        va_start(args, err);

        fprintf(stderr, "input.conf:%d: ", yylineno);
        vfprintf(stderr, err, args);
        fprintf(stderr, "\n");

        numerrs++;

        va_end(args);
}

/* Add to a list of valid defines. */
void addvaliddef(const char *define)
{
        DEFINETABLEENTRY *entry;

        if(isdef(define)) {
                yyerror("Duplicate definition of %s", define);
                return;
        }

        entry = malloc(sizeof(DEFINETABLEENTRY));
        entry->next = 0;
        entry->define = define;

        if(!deffirstentry)
                deffirstentry = entry;

        if(deflastentry)
                deflastentry->next = entry;
        deflastentry = entry;
}

/* Check if something is listed in the define table */
BOOL isdef(const char *def)
{
        DEFINETABLEENTRY *entry = deffirstentry;

        while(entry) {
                /* Check if entry matches */
                if(strcmp(entry->define, def) == 0)
                        return TRUE;

                entry = entry->next;
        }

        return FALSE;
}

/* Delete define list */
void cleanupdefs()
{
        DEFINETABLEENTRY *entry = deffirstentry;
        DEFINETABLEENTRY *next;

        while(entry) {
                free((void*)entry->define);
                next = entry->next;
                free((void*)entry);
                entry = next;
        }
}

/* Check if this symbol is defined anywhere in the lang tables. If it is
 * then return a pointer to the define otherwise NULL.
 */
const char *getdefinefor(const char *eq)
{
        int i;

        for(i = 0; i < numlangs; i++) {
                LANGTABLEENTRY *entry = langs[i].firstentry;
                int ret;

                while(entry) {
                        ret = strcmp(eq, entry->name);
                        if(ret == 0)
                                return entry->define;
                        else if(ret < 0)
                                break;

                        entry = entry->next;
                }
        }

        return 0;
}

/* Get the lang table entry for this language. Create if necessary
 */
LANGENTRY *getlang(const char *lang)
{
        int i;

        for(i = 0; i < numlangs; i++) {
                if(strcmp(langs[i].lang, lang) == 0) {
                        /* This is the right language */
                        return &(langs[i]);
                }
        }

        /* No match have to make our own. */
        if(debuglevel > 1)
                printf("Creating language %s\n", lang);

        if(numlangs >= MAX_LANGS) {
                yyerror("Error creating language - out of room");
                return 0;
        }

        /* Setup structure */
        langs[numlangs].lang = strdup(lang);
        langs[numlangs].firstentry = 0;
        langs[numlangs].lastentry = 0;
        /* Setup properties of this language to default. */
        langs[numlangs].prop_inclusivetable = 0;
        numlangs++;

        return &(langs[numlangs - 1]);
}

/* Add this entry to list of language */
void addtolist(LANGENTRY *lang, const char *name, const char *def)
{
        LANGTABLEENTRY *entry = malloc(sizeof(LANGTABLEENTRY));
        LANGTABLEENTRY *nextentry;
        LANGTABLEENTRY *preventry;

        entry->name = name;
        entry->define = def;


        /* This list is alphabectically sorted. Go through looking for it's place
         * in the list.
         */
        nextentry = lang->firstentry;
        preventry = 0;

        while(nextentry) {
                int ret;
                ret = strcmp(name, nextentry->name);
                if(ret == 0) { /* Double entry */
                        yyerror("Double entry name");
                        return;
                }
                else if(ret < 0)
                        break;
                preventry = nextentry;
                nextentry = nextentry->next;
        }

        /* Preventry is now either the entry we go after or 0 */
        if(preventry)
                preventry->next = entry;
        else
                /* We go first */
                lang->firstentry = entry;

        if(nextentry)
                entry->next = nextentry;
        else {
                lang->lastentry = entry;
                entry->next = 0;
        }
}

/* Add tablename to table. Tablename and def must stay valid. They will
 * be free'd later.
 */
void addtotable(const char *table, const char *tablename, const char *defs)
{
        LANGENTRY *lang;

        if(debuglevel >= 2) {
                printf("Adding to table %s of name %s define as %s\n", table,
                        tablename, defs);
        }

        lang = getlang(table);
        if(!lang)
                return;

        if(isdef(tablename)) {
                yyerror("Previously defined as a define '%s'", tablename);
                return;
        }

        /* Now add this thing to the table */
        addtolist(lang, tablename, defs);
}

void parsed_pause(const char *name, int len)
{
        if(debuglevel >= 1)
                printf("Addeding %s pause %d len\n", name, len);

        if(!add_pause(len, name))
                yyerror("Failed to add pause");

        addvaliddef(name);

        if(lastsoundname) {
                free((void*)lastsoundname);
                lastsoundname = 0;
        }
}

void parsed_property(const char *table, const char *property, int val)
{
        LANGENTRY *lang;

        lang = getlang(table);
        if(!lang)
                return;

        // Have the language now set the property.
        if(strcmp(property, "inclusivetable") == 0) {
                // Match
                lang->prop_inclusivetable = val;
        }
        else {
                // Bad property name
                yyerror("Invalid property name %s", property);
        }

}

void parsed_sound(const char *table /* NULL if not in table */,
                        const char *tablename /* NULL if not in table */,
                        const char *define, const char *filename,
                        char *extras /* NULL if none. Otherwise space seperated */)
{
        if(debuglevel >= 1) {
                printf("Sound");
                if(table)
                        printf(" table %s with name %s ", table, tablename);
                printf("defined %s, file %s\n", define, filename);
                if(extras)
                        printf("\textras %s\n", extras);
        }

        if(!add_sound(filename, define))
                yyerror("Failed to add sound");

        addvaliddef(strdup(define));
        /* Now add to table the tablename */
        if(table) {

                addtotable(table, tablename, strdup(define));
                if(extras) {
                        /* Go through getting each word out of an extra */
                        char *start = extras;
                        char *upto;
                        do {
                                upto = strchr(start, ' ');
                                if(upto)
                                        *upto = 0;
                                addtotable(table, strdup(start), strdup(define));
                                start = upto + 1;
                        } while(upto);
                }
        }

        if(lastsoundname)
                free((void*)lastsoundname);

        lastsoundname = define;

        free((void*)table);
        free((void*)extras);
        free((void*)filename);
}

void parsed_equals(const char *table, const char *tablename,
                        char *extras /* Space seperated */)
{

        if(debuglevel >= 1)
                printf("Equals table %s name %s extras %s\n", table, tablename, extras);

        addtotable(table, tablename, extras);

        free((void*)table);
}

/* Dump the lang lists */
void dumplanglists()
{
        int i;

        for(i = 0; i < numlangs; i++) {
                LANGTABLEENTRY *entry = langs[i].firstentry;

                printf("Printing lang %s\n", langs[i].lang);
                while(entry) {
                        printf("\tEntry %s def %s\n", entry->name, entry->define);
                        entry = entry->next;
                }
        }
}

/* Go through each language a write it to a file as a sorted table */
void writelanglist(LANGENTRY *lang)
{
        FILE *outfile;
        char filename[FILENAME_MAX] = FILE_PREFIX;
        LANGTABLEENTRY *entry;
        const char *lastname = 0;

        strcat(filename, lang->lang);
        strcat(filename, FILE_POSTFIX);

        outfile = fopen(filename, "w");

        if(!outfile) {
                yyerror("Unable to open output file %s\n");
                return;
        }

        fprintf(outfile,
                "/* This file is generated automatically by linuxtoavr\n"
                " * Do not modify this file - any modifications will be overwritten\n"
                " * This is for a including in an array defined as:\n"
                " * struct tableentry { const char *name, const char *defines }\n"
                " * Both defines and name are null terminated strings\n"
                " * The defines are made using sounds.h which should be included before this file\n"
                " * The table is sorted alphabectically\n"
                " *\n"
                " * To send an email to the maker of linuxtoavr telling him how much you like it please write to:\n"
                " * <jhuntnz@users.sf.net (Subject: I love linuxtoavr!)\n"
                " * Please include Visa card details so I can deduct US$20 - Thanks\n"
                " *\n"
                " * This file is generated for language %s\n"
                " */\n"	
		"\n"
                "#include \"soundcontrol.h\"\n"
                "\n"
                "/* Dummy headers for Dynamic C */\n"
                "/*** Beginheader sounds_%s_c */\n"
                "#ifdef TARGET_RABBIT\n"
                "void sounds_%s_c();\n"
                "\n"
                "#asm\n"
                "xxxsounds_%s_c: equ sounds_%s_c\n"
                "#endasm\n"
                "\n"
                "#endif /* TARGET_RABBIT */\n"
                "/*** endheader */\n"
                "\n"
                "#ifdef TARGET_RABBIT\n"
                "void sounds_%s_c() { }\n"
                "#endif /* TARGET_RABBIT */\n"
                "\n"
		 , lang->lang, lang->lang, lang->lang, lang->lang, lang->lang, lang->lang);

        /* First of all print all the entries if the table is not inclusive. */
        if(!lang->prop_inclusivetable) {
                entry = lang->firstentry;
                while(entry) {
                        fprintf(outfile, "%s_OUTSIDE_NAME_DEF(__name_%s%s) \"%s\";\n",
                                lang->lang, lang->lang, entry->name, entry->name);
                        fprintf(outfile, "%s_OUTSIDE_DEFINE_DEF(__def_%s%s) %s;\n",
                                lang->lang, lang->lang, entry->name, entry->define);
                        entry = entry->next;
                }
        }

        fprintf(outfile,
                "\n"
                "\n"
                "%s_TABLE_DECL\n",
                lang->lang);
        /* Now for each entry in table write to file.
         * Double check that table is sorted.
         */
        entry = lang->firstentry;
        while(entry) {
                LANGTABLEENTRY *next;

                if(lang->prop_inclusivetable)
                        fprintf(outfile, " \"%s\"              , %s                ,\n",
                                entry->name, entry->define);
                else
                        fprintf(outfile, " %s_NAME_CAST __name_%s%s, %s_DEF_CAST __def_%s%s ,\n",
                                lang->lang, lang->lang, entry->name, lang->lang, lang->lang,
                                entry->name);

                if(lastname) {
                        if(strcmp(lastname, entry->name) >= 0)
                                yyerror("Unsorted table");
                        free((void*)lastname);
                }

                /* Can now free memory used by entry */
                lastname = entry->name;
                free((void*)entry->define);
                next = entry->next;
                free((void*)entry);
                entry = next;
        }

        if(lastname)
                free((void*)lastname);
		
	fprintf(outfile, 
	    "\n"
	    "%s_TABLE_END"
	    "\n", lang->lang);

        fclose(outfile);
}

BOOL parse_input(FILE *input_file)
{
        int i;

        yyin = input_file;
        yydebug = (debuglevel > 3) ? debuglevel : 0;
        yyparse();

        cleanupdefs();

        if(debuglevel >= 2)
                dumplanglists();
        for(i = 0; i < numlangs; i++)
                writelanglist(&(langs[i]));

        if(numerrs > 0)
                return FALSE;

        return TRUE;
}
