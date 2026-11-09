// Whisper reproducer (RV32): an instruction that writes minstret or minstreth must not also increment the 64-bit
// instret counter, so the half that was not written keeps its value.
// Spec: unpriv/zicsr.adoc: "If a CSR access instruction writes such a CSR, the explicit write is done instead of the
//   update from the side effect. In particular, a value written to instret by one instruction will be the value
//   read by the following instruction." priv/machine.adoc norm:mcycleh_minstreth_mhpmh_op: minstreth "writes change
//   only bits 63-32". riscv/riscv-isa-manual#1255: minstret is one 64-bit CSR and a write of minstreth is a write of
//   it, so the write replaces the increment of all 64 bits. riscv-tests isa/rv32mi/instret_overflow checks the same.
// Result: the test fails with "Bad Value" = bitmask of failed checks (expected 0):
//   bit 0: minstret = 0x10, csrw minstreth, 5:            the next csrr minstret is not 0x10
//   bit 1: minstret = 0xffffffff, csrw minstreth, 7:      the next csrr minstret is not 0xffffffff
//   bit 2: minstreth = 0, minstret = 0xffffffff, csrw minstret, 5: the next csrr minstreth is not 0
//   bit 3: riscv-tests instret_overflow: csrw minstret, -1; csrw minstreth, -1; nop: csrr minstret is not 0
//   bit 4: ... and the following csrr minstreth is not 0

##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'Sm', 'Zicntr']
# MARCH: rv${XLEN}i_zicsr_zifencei
# NEEDS_SIGNATURE: false
##### END_TEST_CONFIG #####

#define SIGUPD_COUNT 0
#define BOOT_TO_MMODE
#include "riscv_arch_test.h"
#include "../common/sa.h"

// Set bit _B of the failure mask x20 (clobbers x10).
#define SETFAIL(_B) LI(x10, (1 << (_B))); or x20, x20, x10

RVTEST_BEGIN
  li x20, 0
#if __riscv_xlen == 32
  csrw mcountinhibit, x0       // count instret
  li x6, -1

  li x11, 0x10
  li x12, 5
  li x13, 7
  csrw minstreth, x0
  csrw minstret, x11           // minstret = 0x00000000_00000010
  csrw minstreth, x12          // writes bits 63:32 only, instead of this instruction's increment
  csrr x8, minstret
  beq x8, x11, 1f
  SETFAIL(0)
1:
  csrw minstret, x6            // minstret = 0x????????_ffffffff
  csrw minstreth, x13
  csrr x8, minstret
  beq x8, x6, 2f
  SETFAIL(1)
2:
  csrw minstreth, x0
  csrw minstret, x6            // minstret = 0x00000000_ffffffff
  csrw minstret, x12           // writes bits 31:0 only: no carry into minstreth
  csrr x8, minstreth
  beqz x8, 3f
  SETFAIL(2)
3:
  csrw minstret, x6            // riscv-tests isa/rv64mi/instret_overflow.S, TEST_CASE 3 and 4
  csrw minstreth, x6           // minstret = 0xffffffff_ffffffff
  nop                          // wraps to 0
  csrr x8, minstret
  csrr x9, minstreth
  beqz x8, 4f
  SETFAIL(3)
4:
  beqz x9, 5f
  SETFAIL(4)
5:
#endif
  SA_CHECK(x20, 0, "bitmask of failed minstret/minstreth write checks (see the test header)")
RVTEST_CODE_END

RVTEST_DATA_BEGIN
RVTEST_DATA_END
RVTEST_SIG_SETUP
