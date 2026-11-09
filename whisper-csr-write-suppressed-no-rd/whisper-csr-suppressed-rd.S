// A CSR instruction whose CSR write is suppressed or has no effect still reads the CSR and writes the old value
// to rd.
//   zicsr.adoc norm:csrrw_op "The CSRRW (Atomic Read/Write CSR) instruction atomically swaps values in the CSRs
//     and integer registers. CSRRW reads the old value of the CSR, zero-extends the value to XLEN bits, then
//     writes it to integer register rd." (CSRRS/CSRRC likewise.)
//   machine.adoc norm:misa_inc_ialign "If an instruction that would write misa increases IALIGN, and the
//     subsequent instruction's address is not IALIGN-bit aligned, the write to misa is suppressed, leaving misa
//     unchanged."
//   supervisor.adoc norm:satp_mode_op_unsupported "if satp is written with an unsupported MODE, the entire write
//     has no effect; no fields in satp are modified."
// Checks:
//   1. csrrw x7, misa, (misa without C) at an address = 2 mod 4: misa unchanged, x7 = old misa (the misa write is
//      suppressed if misa.C is writable and ignored if it is not; rd gets the old misa either way)
//   2. csrrw x7, satp, (MODE = 1, reserved on RV64): satp unchanged (0), x7 = 0 (RV64 only)
//   3. csrrs x7, satp, (MODE = 1): x7 = 0 (RV64 only)
// x7 is preset to 0x5555 before each instruction.

##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'Sm', 'S', 'C']
# MARCH: rv${XLEN}ic_zicsr_zifencei
# NEEDS_SIGNATURE: false
##### END_TEST_CONFIG #####

#define SIGUPD_COUNT 0
#define BOOT_TO_MMODE
#include "riscv_arch_test.h"
#include "../common/sa.h"

RVTEST_BEGIN
  // 1. misa
  csrr x9, misa                  // old misa
  andi x8, x9, 4
  beqz x8, 1f                    // C not set
  xori x8, x9, 4                 // misa with C cleared
  li x7, 0x5555
  .option push
  .option rvc
  .p2align 2
  c.nop                          // the csrrw below starts at an address = 2 mod 4
  csrrw x7, misa, x8             // would clear C; next pc = 2 mod 4 -> misa write suppressed
  c.nop
  .option pop
  csrr x11, misa
  sub x12, x11, x9
  SA_SOFT(x12, 0, "1: misa after the suppressed write (new - old)")
  sub x12, x7, x9
  SA_SOFT(x12, 0, "1: csrrw rd when the misa write is suppressed (rd - old misa)")
1:
#if __riscv_xlen == 64
  // 2./3. satp with a reserved MODE
  csrw satp, x0                  // Bare
  LI(x8, (1 << 60) | 0x123)      // MODE = 1 (reserved on RV64)
  li x7, 0x5555
  csrrw x7, satp, x8
  csrr x9, satp
  SA_SOFT(x9, 0, "2: satp after a write with a reserved MODE")
  SA_SOFT(x7, 0, "2: csrrw rd when the satp write has a reserved MODE (old satp = 0)")
  li x7, 0x5555
  csrrs x7, satp, x8
  SA_SOFT(x7, 0, "3: csrrs rd when the satp write has a reserved MODE (old satp = 0)")
#endif
  SA_SOFT_END
RVTEST_CODE_END

RVTEST_DATA_BEGIN
RVTEST_DATA_END
RVTEST_SIG_SETUP
