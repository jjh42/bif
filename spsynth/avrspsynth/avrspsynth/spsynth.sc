MEMORY
{
  text   (rx)   : ORIGIN = 0,    LENGTH = 4K
  data   (rw!x) : ORIGIN = 0x800060, LENGTH = 128
  eeprom (rw!x) : ORIGIN = 0x810000, LENGTH = 256
}

SECTIONS
{
    /* Read-only sections, merged into text segment: */
  .hash        0 : { *(.hash)		}
  .dynsym      0 : { *(.dynsym)		}
  .dynstr      0 : { *(.dynstr)		}
  .gnu.version 0 : { *(.gnu.version)	}
  .gnu.version_d 0 : { *(.gnu.version_d)	}
  .gnu.version_r 0 : { *(.gnu.version_r)	}
  .rel.init    0 : { *(.rel.init)	}
  .rela.init   0 : { *(.rela.init)	}
  .rel.text    0 :
    {
      *(.rel.text)
    }
  .rela.text   0 :
    {
      *(.rela.text)
    }
  .rel.fini    0 : { *(.rel.fini)	}
  .rela.fini   0 : { *(.rela.fini)	}
  .rel.rodata  0 :
    {
      *(.rel.rodata)
    }
  .rela.rodata 0 :
    {
      *(.rela.rodata)
    }
  .rel.data    0 :
    {
      *(.rel.data)
    }
  .rela.data   0 :
    {
      *(.rela.data)
    }
  .rel.ctors   0 : { *(.rel.ctors)	}
  .rela.ctors  0 : { *(.rela.ctors)	}
  .rel.dtors   0 : { *(.rel.dtors)	}
  .rela.dtors  0 : { *(.rela.dtors)	}
  .rel.got     0 : { *(.rel.got)		}
  .rela.got    0 : { *(.rela.got)		}
  .rel.bss     0 : { *(.rel.bss)		}
  .rela.bss    0 : { *(.rela.bss)		}
  .rel.plt     0 : { *(.rel.plt)		}
  .rela.plt    0 : { *(.rela.plt)		}
  /* Internal text space or external memory */
  .text :
  {
    *(.init)
    *(.progmem.gcc*)
    *(.progmem*)
    *(.text)
    *(.text.*)
    *(.fini)
    FILL(0xff)
  } > text =0xff
  
  .eeprom :	
  {
    _eeprom_dummy = .;
    *(.eeprom*)
    FILL(0xff)
  } > eeprom =0xff
  
   .data	: /* AT ( ADDR (.eeprom) + SIZEOF(.eeprom) ) */
  {
    *(.data)
    *(.gnu.linkonce.d*)
    FILL(0xff)
  } > data AT > eeprom =0xff

  .bss  :
  {
    *(.bss)
    *(COMMON)
  } > data 
  
  /* Stabs debugging sections.  */

  .stab 0 : { *(.stab) }
  .stabstr 0 : { *(.stabstr) }
  .stab.excl 0 : { *(.stab.excl) }
  .stab.exclstr 0 : { *(.stab.exclstr) }
  .stab.index 0 : { *(.stab.index) }
  .stab.indexstr 0 : { *(.stab.indexstr) }
 
  .comment 0 : { *(.comment) }
  /* DWARF debug sections.
     Symbols in the DWARF debugging sections are relative to the beginning
     of the section so we begin them at 0.  */
  /* DWARF 1 */
  .debug          0 : { *(.debug) }
  .line           0 : { *(.line) }
  /* GNU DWARF 1 extensions */
  .debug_srcinfo  0 : { *(.debug_srcinfo) }
  .debug_sfnames  0 : { *(.debug_sfnames) }
  /* DWARF 1.1 and DWARF 2 */
  .debug_aranges  0 : { *(.debug_aranges) }
  .debug_pubnames 0 : { *(.debug_pubnames) }
  /* DWARF 2 */
  .debug_info     0 : { *(.debug_info) *(.gnu.linkonce.wi.*) }
  .debug_abbrev   0 : { *(.debug_abbrev) }
  .debug_line     0 : { *(.debug_line) }
  .debug_frame    0 : { *(.debug_frame) }
  .debug_str      0 : { *(.debug_str) }
  .debug_loc      0 : { *(.debug_loc) }
  .debug_macinfo  0 : { *(.debug_macinfo) }

}
