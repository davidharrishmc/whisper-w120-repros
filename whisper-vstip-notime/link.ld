OUTPUT_ARCH("riscv")
ENTRY(_start)
SECTIONS
{
  . = 0x80000000;
  .text.init : { *(.text.init) }
  .text : { *(.text) }
  . = ALIGN(0x1000);
  .rodata : { *(.rodata) }
  .data : { *(.data) }
  /* the tile matches tohost by the 64-byte write-buffer word address */
  . = ALIGN(64);
  .tohost : { *(.tohost) }
}
