/* u32-debug-a bare tests: Debug Mode entry (debug_address) at 0x80000800, Debug Mode exception (dexc_address) at
   0x80000900, as in act/config/imperas/rr-u32-debug-a-imp{64,32}/imperas.ic. */
OUTPUT_ARCH("riscv")
ENTRY(_start)
SECTIONS
{
  . = 0x80000000;
  .text.init : { *(.text.init) }
  . = 0x80000800;
  .dmentry : { *(.dmentry) }
  . = 0x80000900;
  .dmexc : { *(.dmexc) }
  . = 0x80001000;
  .text : { *(.text) }
  . = ALIGN(0x1000);
  .tohost : { *(.tohost) }
  . = ALIGN(0x1000);
  .rodata : { *(.rodata) *(.rodata.*) }
  .data : { *(.data) *(.sdata) }
  .bss : { *(.bss) *(.sbss) }
  . = ALIGN(0x1000);
  _end = .;
}
