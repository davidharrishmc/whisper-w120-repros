// Whisper, RV32: loads, stores and instruction fetches that run past 0xFFFFFFFF use physical address
// 0x1_0000_0000 instead of wrapping to address 0.
// Spec: unpriv/intro.adoc (no norm tag): "The memory address space is circular, so that the byte at address
//   2^XLEN-1 is adjacent to the byte at address zero. Accordingly, memory address computations done by the
//   hardware ignore overflow and instead wrap around modulo 2^XLEN." priv/supervisor.adoc (Sv32 note): in
//   Bare mode on RV32 "the 32-bit virtual address is translated (unmodified) into a 32-bit physical address,
//   and then that physical address is zero-extended into a 34-bit machine-level physical address".
// In whisper-rv32-max (stock configuration), 0xFFFFFFFE-0xFFFFFFFF is RAM, addresses 0-1023 have no access, and
//   0x1_0000_0000 is RAM. (The test does nothing if address 0 is accessible or 0xFFFFFFFE is not writable.)
//   M-mode (Bare):
//   1. lw at 0xFFFFFFFE (bytes FFFFFFFE, FFFFFFFF, 0, 1) must trap (load access fault, or address-misaligned).
//   2. lhu at 0xFFFFFFFF (bytes FFFFFFFF, 0) must trap likewise.
//   3. sw at 0xFFFFFFFE must trap (store access fault, or address-misaligned).
//   4. A 32-bit instruction at 0xFFFFFFFE (its upper parcel at address 0) must raise an instruction access
//      fault with mepc = 0xFFFFFFFE, without executing.
//   5. As 1, in S-mode with satp = Bare.
// Whisper master: 1-3 and 5 complete (using bytes at 0x1_0000_0000), and 4 executes the instruction with its
//   upper parcel from 0x1_0000_0000 and then faults at 0x2 (mepc = 2).

##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'Sm', 'Zifencei']
# MARCH: rv${XLEN}i_zicsr_zifencei
# NEEDS_SIGNATURE: false
##### END_TEST_CONFIG #####

#define SIGUPD_COUNT 0
#define BOOT_TO_MMODE
#include "riscv_arch_test.h"
#include "../common/sa.h"

RVTEST_BEGIN
  .option push
  .option norvc
#if __riscv_xlen == 32
  SA_TRY(1)
  lbu x7, 0(x0)
  AI_OUTCOME
  bnez x13, 1f
  SA_SOFT(x13, 1, "precondition: address 0 has no memory in this configuration")
  j wrap_end
1:
  li x8, 0xaa
  SA_TRY(2)
  sb x8, -2(x0)
  li x8, 0xbb
  sb x8, -1(x0)
  AI_OUTCOME
  bnez x13, wrap_end                      // no memory at 0xFFFFFFFE: nothing to test
  // 1. lw at 0xFFFFFFFE
  li x7, 0x5a
  SA_TRY(1)
  lw x7, -2(x0)
  AI_OUTCOME
  mv x16, x14
  li x17, 4
  beq x16, x17, 2f
  SA_SOFT(x16, 5, "lw at 0xFFFFFFFE (bytes FFFFFFFE FFFFFFFF 0 1): mcause (-1 = no trap)")
2:
  // 2. lhu at 0xFFFFFFFF
  SA_TRY(1)
  lhu x7, -1(x0)
  AI_OUTCOME
  mv x16, x14
  li x17, 4
  beq x16, x17, 2f
  SA_SOFT(x16, 5, "lhu at 0xFFFFFFFF (bytes FFFFFFFF 0): mcause (-1 = no trap)")
2:
  // 3. sw at 0xFFFFFFFE
  LI(x8, 0x44332211)
  SA_TRY(1)
  sw x8, -2(x0)
  AI_OUTCOME
  mv x16, x14
  li x17, 6
  beq x16, x17, 2f
  SA_SOFT(x16, 7, "sw at 0xFFFFFFFE (bytes FFFFFFFE FFFFFFFF 0 1): mcause (-1 = no trap)")
2:
#ifdef ZCA_SUPPORTED
  // 4. lower parcel of addi x7, x0, 0x55 (0x05500393) at 0xFFFFFFFE; the upper parcel would be at 0
  li x8, 0x0393
  sh x8, -2(x0)
  fence.i
  li x7, 0x5a
  SA_TRY(1)
  jalr x1, -2(x0)                         // the trap handler resumes at x1 after a fetch fault
  AI_OUTCOME
  mv x16, x14
  mv x18, x7
  AI_LOG(x17, TRAPLOG_EPC)
  SA_SOFT(x16, 1, "fetch of a 32-bit instruction at 0xFFFFFFFE: mcause (-1 = no trap)")
  SA_SOFT(x17, 0xFFFFFFFE, "fetch of a 32-bit instruction at 0xFFFFFFFE: mepc")
  SA_SOFT(x18, 0x5a, "fetch of a 32-bit instruction at 0xFFFFFFFE: the instruction did not execute")
#endif
#ifdef S_SUPPORTED
  // 5. lw at 0xFFFFFFFE in S-mode with satp = Bare
  csrw satp, x0
  RVTEST_TSBI_GOTO_SMODE
  SA_TRY(1)
  lw x7, -2(x0)
  AI_OUTCOME
  mv x16, x14
  RVTEST_TSBI_GOTO_MMODE
  li x17, 4
  beq x16, x17, 2f
  SA_SOFT(x16, 5, "S-mode (satp = Bare) lw at 0xFFFFFFFE: mcause (-1 = no trap)")
2:
#endif
wrap_end:
#endif
  SA_SOFT_END
  .option pop
RVTEST_CODE_END

RVTEST_DATA_BEGIN
RVTEST_DATA_END
RVTEST_SIG_SETUP
