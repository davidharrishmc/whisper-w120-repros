// mtime-stip: with Sstc, mip.STIP must follow the unsigned comparison time >= stimecmp when the result changes because
// mtime (the source of the time CSR) is written back below stimecmp.
// Spec (riscv-isa-manual, src/priv/supervisor.adoc, "Supervisor Timer (stimecmp) Register", norm:mip_sip_stip_op):
//   "A supervisor timer interrupt becomes pending, as reflected in the STIP bit in the mip and sip registers whenever
//   time contains a value greater than or equal to stimecmp, treating the values as unsigned integers. If the result
//   of this comparison changes, it is guaranteed to be reflected in STIP eventually, but not necessarily immediately.
//   The interrupt remains posted until stimecmp becomes greater than time, typically as a result of writing stimecmp."
// "Eventually" is tested as 100,000 reads of mip (csrr only). Interrupts stay disabled; mtimecmp = 2^64 - 1.
##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'Sm', 'S', 'Sstc']
# MARCH: rv${XLEN}i_zicsr_zifencei
# NEEDS_SIGNATURE: false
##### END_TEST_CONFIG #####
#define SIGUPD_COUNT 0
#define BOOT_TO_MMODE
#include "riscv_arch_test.h"
#include "../common/sa.h"

#define LIM 100000
// x6 = mip.STIP (0 or 0x20) after polling up to LIM times for it to become _V
#define POLL_STIP(_V)              \
  LI(x12, LIM)                    ;\
1: csrr x6, mip                   ;\
  andi x6, x6, 0x20               ;\
  li x5, _V                       ;\
  beq x6, x5, 2f                  ;\
  addi x12, x12, -1               ;\
  bnez x12, 1b                    ;\
2:
#define WR_MTIME(_H, _L)  sw x0, 0(x8) ; LI(x7, _H) ; sw x7, 4(x8) ; LI(x7, _L) ; sw x7, 0(x8)
#define WR_CMP(_H, _L)    li x7, -1 ; sw x7, 0(x9) ; LI(x7, _H) ; sw x7, 4(x9) ; LI(x7, _L) ; sw x7, 0(x9)

RVTEST_BEGIN
  csrw mie, x0
  csrci mstatus, 8
  LI(x8, RVMODEL_MTIME_ADDRESS)
  LI(x9, RVMODEL_MTIMECMP_ADDRESS)
  WR_CMP(0xffffffff, 0xffffffff)
  // menvcfg.STCE = 1, stimecmp = 2^40
#if __riscv_xlen == 64
  LI(x7, 0x8000000000000000)
  csrs menvcfg, x7
  LI(x7, 0x10000000000)
  csrw stimecmp, x7
#else
  LI(x7, 0x80000000)
  csrs 0x31A, x7        // menvcfgh
  csrw stimecmp, x0
  LI(x7, 0x100)
  csrw 0x15D, x7        // stimecmph
#endif
  WR_MTIME(0xff, 0xff000000)
  POLL_STIP(0)
  SA_SOFT(x6, 0, "C1 control: STIP = 0 with mtime = stimecmp - 2^24")
  WR_MTIME(0x100, 0x10)
  POLL_STIP(0x20)
  SA_SOFT(x6, 0x20, "C2 control: STIP = 1 after mtime is written to stimecmp + 0x10")
  WR_MTIME(0, 0)
  lw x10, 4(x8)
  POLL_STIP(0)
  SA_SOFT(x10, 0, "T1 mtime high half reads back 0 after mtime is written to 0 (time < stimecmp = 2^40)")
  SA_SOFT(x6, 0, "T1 STIP = 0 after mtime is written back below stimecmp (polled 100000 times)")
  // an unrelated CSR write: not required for STIP to fall, shown because it is what makes Whisper re-evaluate
  csrr x7, mscratch
  csrw mscratch, x7
  POLL_STIP(0)
  SA_SOFT(x6, 0, "T1 STIP = 0 after an unrelated CSR write (csrw mscratch)")
  SA_SOFT_END
RVTEST_CODE_END

RVTEST_DATA_BEGIN
RVTEST_DATA_END
RVTEST_SIG_SETUP
