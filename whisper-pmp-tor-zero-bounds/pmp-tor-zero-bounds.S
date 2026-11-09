// Whisper: a TOR PMP entry whose bounds are both 0 matches physical addresses 0-3 instead of nothing.
// Spec: priv/machine.adoc [norm:pmp_a_field_tor] "If PMP entry i's A field is set to TOR, the entry matches
//   any address y such that pmpaddr_(i-1) <= y < pmpaddr_i (irrespective of the value of pmpcfg_(i-1)). If
//   PMP entry 0's A field is set to TOR, zero is used for the lower bound, and so it matches any address
//   y < pmpaddr_0." and the note that follows: "If pmpaddr_(i-1) >= pmpaddr_i and pmpcfg_i.A=TOR, then PMP
//   entry i matches no addresses."
// Needs memory at physical address 0 (whisper.json here is whisper-rv64-max with the no-access PMA region
//   0-1023 made readable and writable); the test does nothing if an M-mode load from address 0 traps.
// Case 1: entry 0 TOR, pmpaddr0 = 0, RWX; entry 1 NAPOT [0, 4 KiB), no permissions; entry 15 NAPOT, all
//   addresses, RWX. A U-mode lw from address 0 must take a load access fault: entry 0 matches nothing, so
//   entry 1 decides.
// Case 2: entry 0 OFF, pmpaddr0 = 0; entry 1 TOR, pmpaddr1 = 0, RWX; entry 2 NAPOT [0, 4 KiB), no
//   permissions; entry 15 as above. Same expected result (entry 1 matches nothing).
// Whisper master: the U-mode load completes in both cases (the TOR entry matches 0-3 and grants RWX).

##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'Sm', 'U']
# MARCH: rv${XLEN}i_zicsr_zifencei
# NEEDS_SIGNATURE: false
##### END_TEST_CONFIG #####

#define SIGUPD_COUNT 0
#define BOOT_TO_MMODE
#include "riscv_arch_test.h"
#include "../common/sa.h"

// U-mode lw from address 0; x16 = mcause of the trap (-1 = no trap)
#define U_LOAD_0                       \
  RVTEST_TSBI_GOTO_UMODE              ;\
  SA_TRY(1)                           ;\
  lw x7, 0(x0)                        ;\
  AI_OUTCOME                          ;\
  mv x16, x14                         ;\
  RVTEST_TSBI_GOTO_MMODE

RVTEST_BEGIN
  csrw medeleg, x0
  SA_TRY(1)
  lw x7, 0(x0)
  AI_OUTCOME
  bnez x13, tz_skip                   // no memory at PA 0: nothing to test
  li x7, -1
  csrw pmpaddr15, x7
  LI(x7, 0x1f << 56)
  csrw pmpcfg2, x7                    // entry 15 NAPOT RWX

  // Case 1: entry 0 TOR [0, 0) RWX, entry 1 NAPOT [0, 4 KiB) no permissions
  csrw pmpaddr0, x0
  li x7, 0x1ff
  csrw pmpaddr1, x7
  li x7, 0x180f
  csrw pmpcfg0, x7
  sfence.vma x0, x0
  U_LOAD_0
  SA_SOFT(x16, 5, "case 1: entry 0 TOR with pmpaddr0 = 0 matches nothing: U-mode lw from 0: mcause (-1 = none)")

  // Case 2: entry 0 OFF, entry 1 TOR [0, 0) RWX, entry 2 NAPOT [0, 4 KiB) no permissions
  csrw pmpcfg0, x0
  csrw pmpaddr0, x0
  csrw pmpaddr1, x0
  li x7, 0x1ff
  csrw pmpaddr2, x7
  LI(x7, 0x180f00)
  csrw pmpcfg0, x7
  sfence.vma x0, x0
  U_LOAD_0
  SA_SOFT(x16, 5, "case 2: entry 1 TOR with pmpaddr0 = pmpaddr1 = 0 matches nothing: U-mode lw from 0: mcause (-1 = none)")
tz_skip:
  SA_SOFT_END
RVTEST_CODE_END

RVTEST_DATA_BEGIN
RVTEST_DATA_END
RVTEST_SIG_SETUP
