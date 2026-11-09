// MRET with mstatus.MPP = M and mstatus.MPV = 1 returns to M-mode (MPV is ignored when MPP = 3), so it must not
// clear sstatus.SDT: MRET clears SDT only when the new privilege mode is U, VS or VU.
//   machine.adoc norm:sstatus_sdt_clr_mret_sret "If the Ssdbltrp extension is also implemented, and the new
//     privilege mode is U, VS, or VU, then sstatus.SDT is also set to 0."
//   hypervisor.adoc norm:mstatus_mpv_op: MRET sets V to MPV "unless MPP=3, in which case V remains 0".
// Setup in M-mode: menvcfg.DTE = 1 (menvcfgh on RV32), mstatus.SDT = 1, MPP = M, MPV = 1 (mstatush on RV32); mret.
// Expected: mstatus.SDT = 1 after the MRET. Without Ssdbltrp (SDT not writable) the test checks nothing.

##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'Sm', 'S', 'H']
# MARCH: rv${XLEN}i_zicsr_zifencei
# NEEDS_SIGNATURE: false
##### END_TEST_CONFIG #####

#define SIGUPD_COUNT 0
#define BOOT_TO_MMODE
#include "riscv_arch_test.h"
#include "../common/sa.h"

RVTEST_BEGIN
  csrw mideleg, x0
  csrw mie, x0
  // menvcfg.DTE = 1
#if __riscv_xlen == 64
  li x7, 1
  slli x7, x7, 59
  csrs menvcfg, x7
#else
  li x7, 1
  slli x7, x7, 27
  csrs 0x31A, x7                 // menvcfgh
#endif
  LI(x6, 0x01000000)             // SDT (bit 24)
  csrs mstatus, x6
  csrr x8, mstatus
  and x8, x8, x6
  beqz x8, t_skip               // no Ssdbltrp: nothing to test
  li x7, 0x1800                  // MPP = M
  csrs mstatus, x7
#if __riscv_xlen == 64
  li x7, 1
  slli x7, x7, 39                // MPV = 1
  csrs mstatus, x7
  csrr x8, mstatus
  srli x8, x8, 39
#else
  li x7, 0x80                    // mstatush.MPV (bit 7)
  csrs 0x310, x7
  csrr x8, 0x310
  srli x8, x8, 7
#endif
  andi x8, x8, 1
  SA_CHECK(x8, 1, "setup: mstatus.MPV = 1 with MPP = M")
  LA(x7, t_after)
  csrw mepc, x7
  mret                           // MPP = M: stays in M-mode, MPV ignored
t_after:
  csrr x9, mstatus
  csrc mstatus, x6               // SDT = 0 again
  srli x9, x9, 24
  andi x9, x9, 1
  SA_CHECK(x9, 1, "mstatus.SDT after MRET with MPP=M, MPV=1 (new mode M: SDT unchanged)")
t_skip:
RVTEST_CODE_END

RVTEST_DATA_BEGIN
RVTEST_DATA_END
RVTEST_SIG_SETUP
