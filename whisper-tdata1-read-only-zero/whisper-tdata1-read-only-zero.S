// Reproducer: read-only-zero fields of each tdata1 layout keep the ones written to them.
// Write all data bits (except action and chain, and pending for icount) for each trigger type; the bits that
// riscv-debug-spec xml/hwbp_registers.xml lists as field "0" (access R, reset 0) must read 0:
//   RV64: mcontrol  (type 2): 52:23 and 5        mcontrol6 (type 6, tinfo.version 1): 58:27 and 20:19
//         icount    (type 3): 58:27              itrigger  (type 4): 57:13 and 8
//         etrigger  (type 5): 57:13, 10 and 8      tmexttrigger (type 7): 57:23
//   RV32: mcontrol: 5; mcontrol6: 20:19; itrigger: 25:13 and 8; etrigger: 25:13, 10 and 8; tmexttrigger: 25:23
// A type that does not stick (not supported) is skipped. Every mismatch is printed (SA-MISMATCH) and the
// test fails at the end if there was one.
// Spec: Sdtrig.adoc norm:Sdtrig_tdata_warl ("All tdata registers follow write-any-read-legal semantics");
//   norm:Sdtrig_tinfo_version_1 (version 1 = the ratified 1.0 layouts; version 0 had the mcontrol6 timing
//   bit and a 4-bit size in bits 20:19).
// mstatus.MIE = 0 so the M-enabled configurations cannot fire; each write is undone at once.

##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'Sm', 'Sdtrig']
# MARCH: rv${XLEN}i_zicsr_zifencei
# NEEDS_SIGNATURE: false
##### END_TEST_CONFIG #####

#define SIGUPD_COUNT 0
#define BOOT_TO_MMODE
#include "riscv_arch_test.h"
#include "../common/sa.h"

#define TT(n)   ((n) << (__riscv_xlen - 4))

// _T type, _BITS data bits written, _RSV reserved mask; skip when the type does not stick
#define RSV(_T, _BITS, _RSV, _MSG)                           \
  csrw tdata1, x0                                          ;\
  csrw tdata2, x0                                          ;\
  LI(x7, TT(_T) | (_BITS))                                 ;\
  csrw tdata1, x7                                          ;\
  csrr x8, tdata1                                          ;\
  csrw tdata1, x0                                          ;\
  srli x9, x8, __riscv_xlen - 4                            ;\
  li x10, _T                                               ;\
  bne x9, x10, 1f                                          ;\
  LI(x9, _RSV)                                             ;\
  and x8, x8, x9                                           ;\
  SA_SOFT(x8, 0, _MSG)                                     ;\
1:

RVTEST_BEGIN
  csrw mie, x0
  csrci mstatus, 8              // MIE = 0: no M-mode action-0 trigger can fire (option 1)
  csrw tselect, x0

  // data bits: everything below dmode except action (15:12 / 5:0), chain (11), pending (8, icount)
#if __riscv_xlen == 64
  RSV(2, 0x7ffffffff9c007f, 0x1fffffff800020, "mcontrol: bits 52:23 and 5 read 0")
  RSV(6, 0x7fffffffff8007f, 0x7fffffff8180000, "mcontrol6 (v1): bits 58:27 and 20:19 read 0")
  RSV(6, (3 << 19) | 9, (3 << 19), "mcontrol6 (v1): bits 20:19 alone read 0")
  RSV(6, (1 << 58) | (1 << 30) | 9, 0x7fffffff8000000, "mcontrol6 (v1): bits 58 and 30 alone read 0")
  RSV(3, 0x7fffffffffffec0, 0x7fffffff8000000, "icount: bits 58:27 read 0")
  RSV(4, 0x3ffffffffffffc0, 0x3ffffffffffe100, "itrigger: bits 57:13 and 8 read 0")
  RSV(5, 0x3ffffffffffffc0, 0x3ffffffffffe500, "etrigger: bits 57:13, 10 and 8 read 0")
  RSV(4, (1 << 20) | (1 << 6), 0x3ffffffffffe100, "itrigger: bit 20 alone reads 0")
  RSV(5, (1 << 20) | (1 << 10) | (1 << 6), 0x3ffffffffffe500, "etrigger: bits 20 and 10 alone read 0")
  RSV(3, (1 << 58) | (1 << 10) | (1 << 6), 0x7fffffff8000000, "icount: bit 58 alone reads 0")
  RSV(7, 0x3ffffffffffffc0, 0x3ffffffff800000, "tmexttrigger: bits 57:23 read 0")
#else
  RSV(2, 0x07ff07ff, 0x20, "mcontrol: bit 5 reads 0")
  RSV(6, 0x07ff07ff, 0x180000, "mcontrol6 (v1): bits 20:19 read 0")
  RSV(6, (3 << 19) | 9, (3 << 19), "mcontrol6 (v1): bits 20:19 alone read 0")
  RSV(4, 0x07ffffc0, 0x03ffe100, "itrigger: bits 25:13 and 8 read 0")
  RSV(5, 0x07ffffc0, 0x03ffe500, "etrigger: bits 25:13, 10 and 8 read 0")
  RSV(4, (1 << 20) | (1 << 6), 0x03ffe100, "itrigger: bit 20 alone reads 0")
  RSV(5, (1 << 20) | (1 << 10) | (1 << 6), 0x03ffe500, "etrigger: bits 20 and 10 alone read 0")
  RSV(7, 0x03ffffc0, 0x03800000, "tmexttrigger: bits 25:23 read 0")
#endif

  csrw tdata1, x0
  SA_SOFT_END
RVTEST_CODE_END

RVTEST_DATA_BEGIN
RVTEST_DATA_END
RVTEST_SIG_SETUP
