// verify-v2 repro for u21-mother-whisper-06 (part B of work/u21-mother-whisper/u21w-clint-wide-misal.S).
// u21-mother walk (Whisper) probe: (A, RV32 only) an fsd to mtimecmp that completes must store all 64 bits;
// (B) a misaligned store that crosses a 4 KiB boundary inside the CLINT must either trap or complete.
// Spec: machine.adoc:2519 mtimecmp is a 64-bit register; machine.adoc:2575/2580 only 32-bit (RV32) and 64-bit (RV64)
//   aligned accesses are guaranteed; other widths and misaligned accesses are platform-defined (access fault allowed).
//   machine.adoc:3103 (pma_mag_ldst) a misaligned load/store either raises an exception or completes.
// Whisper (A): Hart.cpp:2536-2539 deviceWrite copies the store value into a URV (32 bits on RV32) before
//   processClintWrite and writes the truncated value back to memory, so the high word of an fsd is lost.
// Whisper (B): Hart.cpp:2883-2886 writeForStore asserts pa1 == pa2 for device addresses; an untranslated misaligned
//   store that crosses a page boundary has pa2 = next page (Hart.cpp:14582-14600) -> assertion abort.
##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'Sm']
# MARCH: rv${XLEN}i_zicsr_zifencei
# NEEDS_SIGNATURE: false
##### END_TEST_CONFIG #####
#define SIGUPD_COUNT 0
#define BOOT_TO_MMODE
#include "riscv_arch_test.h"
#include "../common/sa.h"

RVTEST_BEGIN
  csrw mie, x0
  csrci mstatus, 8
  // (B) misaligned store across the 4 KiB boundary at CLINT+0x5000 (inside the mtimecmp array of other harts)
  LI(x9, RVMODEL_MTIMECMP_ADDRESS + 0x0ffc)
  SA_TRY(1)
#if __riscv_xlen == 64
  sd x0, 0(x9)
#else
  sw x0, 2(x9)
#endif
  AI_OUTCOME
  li x6, 1
  SA_SOFT(x6, 1, "(B) reached the instruction after a page-crossing misaligned CLINT store")
  SA_SOFT_END
RVTEST_CODE_END

RVTEST_DATA_BEGIN
.align 3
RVTEST_DATA_END
RVTEST_SIG_SETUP
