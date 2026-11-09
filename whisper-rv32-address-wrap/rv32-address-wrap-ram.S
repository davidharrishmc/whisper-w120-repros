// Whisper, RV32: the same accesses as rv32-address-wrap.S, on a configuration with RAM at both ends of the
// 32-bit address space (whisper-wrapmem.json: whisper-rv32-max with addresses 0-4095 made RAM), so the values
// show which bytes are accessed. M-mode (Bare).
// Expected: lw at 0xFFFFFFFE reads bytes FFFFFFFE, FFFFFFFF, 0, 1 (0x2211bbaa); lhu at 0xFFFFFFFF reads bytes
//   FFFFFFFF, 0 (0x11bb); sw at 0xFFFFFFFE writes bytes FFFFFFFE, FFFFFFFF, 0, 1; a 32-bit instruction at
//   0xFFFFFFFE takes its upper parcel from address 0 (addi x7, x0, 0x55) and the next instruction is at 0x2.
// Whisper master: lw reads 0x0000bbaa and lhu 0x00bb (the bytes from 0x1_0000_0000), sw leaves bytes 0 and 1
//   unchanged, and the instruction's upper parcel does not come from address 0.

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
  li x8, 0x11
  SA_TRY(4)
  sb x8, 0(x0)
  li x8, 0x22
  sb x8, 1(x0)
  li x8, 0xaa
  sb x8, -2(x0)
  li x8, 0xbb
  sb x8, -1(x0)
  AI_OUTCOME
  SA_SOFT(x13, 0, "setup: page 0 and page 0xFFFFF000 are writable RAM in this configuration")
  bnez x13, wm_end
  lbu x7, 0(x0)
  SA_SOFT(x7, 0x11, "setup: byte 0")
  lbu x7, -1(x0)
  SA_SOFT(x7, 0xbb, "setup: byte 0xFFFFFFFF")
  SA_TRY(1)
  lw x7, -2(x0)
  AI_OUTCOME
  SA_SOFT(x13, 0, "lw at 0xFFFFFFFE (RAM on both sides of the wrap): no trap")
  SA_SOFT(x7, 0x2211bbaa, "lw at 0xFFFFFFFE reads bytes FFFFFFFE FFFFFFFF 0 1")
  SA_TRY(1)
  lhu x7, -1(x0)
  AI_OUTCOME
  SA_SOFT(x7, 0x11bb, "lhu at 0xFFFFFFFF reads bytes FFFFFFFF 0")
  LI(x8, 0x44332211)
  SA_TRY(1)
  sw x8, -2(x0)
  AI_OUTCOME
  SA_SOFT(x13, 0, "sw at 0xFFFFFFFE: no trap")
  lbu x7, -2(x0)
  SA_SOFT(x7, 0x11, "sw at 0xFFFFFFFE: byte FFFFFFFE")
  lbu x7, -1(x0)
  SA_SOFT(x7, 0x22, "sw at 0xFFFFFFFE: byte FFFFFFFF")
  lbu x7, 0(x0)
  SA_SOFT(x7, 0x33, "sw at 0xFFFFFFFE: byte 0 (wrapped)")
  lbu x7, 1(x0)
  SA_SOFT(x7, 0x44, "sw at 0xFFFFFFFE: byte 1 (wrapped)")
#ifdef ZCA_SUPPORTED
  // fetch: addi x7, x0, 0x55 (0x05500393) at 0xFFFFFFFE (upper parcel at 0), jalr x0, 0(x1) at 0x2
  li x8, 0x0393
  sh x8, -2(x0)
  li x8, 0x0550
  sh x8, 0(x0)
  LI(x8, 0x8067)
  sh x8, 2(x0)
  sh x0, 4(x0)
  fence.i
  li x7, 0x5a
  SA_TRY(1)
  jalr x1, -2(x0)
  AI_OUTCOME
  SA_SOFT(x13, 0, "wrap fetch: instruction at 0xFFFFFFFE with its upper parcel at 0 executes without a trap")
  SA_SOFT(x7, 0x55, "wrap fetch: the instruction is addi x7, x0, 0x55 (upper parcel from address 0)")
#endif
wm_end:
#endif
  SA_SOFT_END
  .option pop
RVTEST_CODE_END
RVTEST_DATA_BEGIN
RVTEST_DATA_END
RVTEST_SIG_SETUP
