// mtime-mtip: mip.MTIP must follow the unsigned comparison mtime >= mtimecmp when the result changes because mtime
// changes: by a store to mtime (T1) or by mtime wrapping past 2^64 (T2).
// Spec (riscv-isa-manual, src/priv/machine.adoc, "Machine Timer (mtime and mtimecmp) Registers"):
//   norm:mtime_acc "Platforms provide a real-time counter, exposed as a memory-mapped machine-mode read-write
//     register, mtime."   norm:mtime_wrap "The mtime register will wrap around if the count overflows."
//   norm:mtime_intr_pending "A machine timer interrupt becomes pending whenever mtime contains a value greater than
//     or equal to mtimecmp, treating the values as unsigned integers. The interrupt remains posted until mtimecmp
//     becomes greater than mtime (typically as a result of writing mtimecmp)."
//   norm:mtime_intr_mtip_visibility "If the result of the comparison between mtime and mtimecmp changes, it is
//     guaranteed to be reflected in MTIP eventually, but not necessarily immediately."
// "Eventually" is tested as 100,000 reads of mip (csrr only: the polling loop writes no CSR and stores to no device).
// Interrupts stay disabled (mstatus.MIE = 0, mie = 0); only the pending bit is observed.
##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'Sm']
# MARCH: rv${XLEN}i_zicsr_zifencei
# NEEDS_SIGNATURE: false
##### END_TEST_CONFIG #####
#define SIGUPD_COUNT 0
#define BOOT_TO_MMODE
#include "riscv_arch_test.h"
#include "../common/sa.h"

#define LIM 100000
// x6 = mip.MTIP (0 or 0x80) after polling up to LIM times for it to become _V
#define POLL_MTIP(_V)              \
  LI(x12, LIM)                    ;\
1: csrr x6, mip                   ;\
  andi x6, x6, 0x80               ;\
  li x5, _V                       ;\
  beq x6, x5, 2f                  ;\
  addi x12, x12, -1               ;\
  bnez x12, 1b                    ;\
2:
// 32-bit halves work on RV32 and RV64. mtime: low = 0, high, low. mtimecmp: the spec's sequence (-1, high, low).
#define WR_MTIME(_H, _L)  sw x0, 0(x8) ; LI(x7, _H) ; sw x7, 4(x8) ; LI(x7, _L) ; sw x7, 0(x8)
#define WR_CMP(_H, _L)    li x7, -1 ; sw x7, 0(x9) ; LI(x7, _H) ; sw x7, 4(x9) ; LI(x7, _L) ; sw x7, 0(x9)

RVTEST_BEGIN
  csrw mie, x0
  csrci mstatus, 8
  LI(x8, RVMODEL_MTIME_ADDRESS)
  LI(x9, RVMODEL_MTIMECMP_ADDRESS)
  // ---- controls: MTIP follows the comparison when mtime rises past mtimecmp and when mtimecmp is written
  WR_CMP(0x00000100, 0)
  WR_MTIME(0x000000ff, 0xff000000)
  POLL_MTIP(0)
  SA_SOFT(x6, 0, "C1 control: MTIP = 0 with mtime = mtimecmp - 2^24")
  WR_MTIME(0x00000100, 0x10)
  POLL_MTIP(0x80)
  SA_SOFT(x6, 0x80, "C2 control: MTIP = 1 after mtime is written to mtimecmp + 0x10")
  WR_CMP(0x00000200, 0)
  POLL_MTIP(0)
  SA_SOFT(x6, 0, "C3 control: MTIP = 0 after mtimecmp is written above mtime")
  WR_CMP(0x00000100, 0)
  POLL_MTIP(0x80)
  SA_SOFT(x6, 0x80, "C4 control: MTIP = 1 after mtimecmp is written back below mtime")
  // ---- T1: a store to mtime takes it below mtimecmp
  WR_MTIME(0, 0)
  lw x10, 4(x8)
  POLL_MTIP(0)
  mv x15, x6
  lw x11, 4(x8)
  SA_SOFT(x10, 0, "T1 mtime high half reads back 0 after mtime is written to 0 (mtime < mtimecmp = 2^40)")
  SA_SOFT(x15, 0, "T1 MTIP = 0 after mtime is written back below mtimecmp (polled 100000 times)")
  SA_SOFT(x11, 0, "T1 mtime high half is still 0 after the polling")
  // an unrelated CSR write: not required for MTIP to fall, shown because it is what makes Whisper re-evaluate
  csrr x7, mscratch
  csrw mscratch, x7
  POLL_MTIP(0)
  SA_SOFT(x6, 0, "T1 MTIP = 0 after an unrelated CSR write (csrw mscratch)")
  // ---- T2: mtime wraps past 2^64 to below mtimecmp, no store to mtime or mtimecmp after MTIP = 1
  WR_CMP(0xffffffff, 0xffffff80)
  WR_MTIME(0xffffffff, 0xffffff00)
  POLL_MTIP(0x80)
  SA_SOFT(x6, 0x80, "T2 control: MTIP = 1 once mtime reaches mtimecmp = 2^64 - 0x80")
  LI(x13, LIM)
9: lw x6, 4(x8)
  beqz x6, 10f
  addi x13, x13, -1
  bnez x13, 9b
10: SA_SOFT(x6, 0, "T2 control: mtime wraps from 2^64 - 1 to 0 (high half reads 0)")
  POLL_MTIP(0)
  lw x10, 4(x8)
  lw x11, 4(x9)
  SA_SOFT(x6, 0, "T2 MTIP = 0 after mtime wraps below mtimecmp (polled 100000 times)")
  SA_SOFT(x10, 0, "T2 mtime high half is still 0 (mtime < mtimecmp)")
  SA_SOFT(x11, -1, "T2 mtimecmp high half is still 0xffffffff")
  WR_CMP(0xffffffff, 0xffffffff)
  SA_SOFT_END
RVTEST_CODE_END

RVTEST_DATA_BEGIN
RVTEST_DATA_END
RVTEST_SIG_SETUP
