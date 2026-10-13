///////////////////////////////////////////
// W120Xepc/W120Xepc_zca-00.S
//
// whisper#120 item 16: with Zca, IALIGN is 16, so mepc[1] is kept even when misa.C is 0
// (for example RV32 with F and Zca but no Zcf, where C is not implemented).
//
// SPDX-License-Identifier: Apache-2.0
///////////////////////////////////////////

##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'Sm', 'Zca']
# # # no param constraints
# MARCH: rv${XLEN}i_zca_zicsr
##### END_TEST_CONFIG #####

#define SIGUPD_COUNT 3

#define BOOT_TO_MMODE
#define TRAP_SIGUPD_COUNT 16

#include "riscv_arch_test.h"

RVTEST_BEGIN

main:

  LA(x8, w120_xepc_target)
// mret to a halfword-aligned target: returning 2 bytes early executes c.j into the failure path
  LI(x11, MSTATUS_MPP)
  csrs mstatus, x11           // MPP = M
  csrw mepc, x8
  LI(x12, 0)
  mret
  .balign 4
  c.j w120_xepc_wrong         // at 4n: reached only if mepc[1] was dropped
w120_xepc_target:             // at 4n+2
  c.li x12, 5
  j w120_xepc_done
w120_xepc_wrong:
  LI(x12, 0xbad)
w120_xepc_done:
W120Xepc_mret_target:
  RVTEST_SIGUPD(x2, x5, x4, x12, W120Xepc_mret_target, W120Xepc_mret_target_str)

// mepc keeps bit 1: write the address of a halfword-aligned instruction and read it back
W120Xepc_mepc_bit1:
  csrw mepc, x8
  csrr x9, mepc
  sub x9, x9, x8              // 0 when bit 1 is kept, -2 when it is dropped
  RVTEST_SIGUPD(x2, x5, x4, x9, W120Xepc_mepc_bit1, W120Xepc_mepc_bit1_str)

// misa.C must read 0 here (Zca without C)
  csrr x10, misa
  srli x10, x10, 2            // misa.C is bit 2
  andi x10, x10, 1
W120Xepc_misa_c:
  RVTEST_SIGUPD(x2, x5, x4, x10, W120Xepc_misa_c, W120Xepc_misa_c_str)

RVTEST_CODE_END

RVTEST_DATA_BEGIN
W120Xepc_mepc_bit1_str: .string "\"test: 2; cg: W120Xepc; cp: mepc_bit1; bin: mepc - target\""
W120Xepc_misa_c_str: .string "\"test: 3; cg: W120Xepc; cp: misa_c; bin: misa.C\""
W120Xepc_mret_target_str: .string "\"test: 1; cg: W120Xepc; cp: mret_target; bin: 5 if mret returned to 4n+2\""
RVTEST_DATA_END

RVTEST_SIG_SETUP
