// A whole-register vector load (vl1re32.v) whose first element matches an mcontrol6 load-data trigger.
// Expected: a breakpoint exception (mcause 3), with vstart = 0 (the trigger fires before element 0 is loaded)
// or 1 (it fires right after element 0), and mtval = 0 or the address of element 0.
// Whisper master fa18e475 aborts instead: "VecLdStInfo.hpp:125: void WdRiscv::VecLdStInfo::removeLastElem():
// Assertion `not elems_.empty()' failed" (vectorLoadWholeReg removes an ldStInfo record it has not added yet).
// Built with the riscv-arch-test framework (tests_ai, sa.h self-checks); M-mode only, RV32 and RV64.

##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'Sm', 'V', 'Sdtrig']
# MARCH: rv${XLEN}iv_zicsr_zifencei
# NEEDS_SIGNATURE: false
##### END_TEST_CONFIG #####

#define SIGUPD_COUNT 0
#define BOOT_TO_MMODE
#include "riscv_arch_test.h"
#include "../common/sa.h"

#define MC6 (6 << (__riscv_xlen - 4))
#define TD1 (MC6 | (1 << 21) | (1 << 6) | 1)   // mcontrol6: select=1 (data), size=0, match=0 (equal), m=1, load=1

RVTEST_BEGIN
  // trigger 0: load-data trigger on the value 0x12345678, action 0 (breakpoint exception)
  csrw tselect, x0
  csrw tdata1, x0
  LI(x7, 0x12345678)
  csrw tdata2, x7
  LI(x7, TD1)
  csrw tdata1, x7
  csrr x8, tdata1
  SA_CHECK(x8, TD1, "tdata1 = mcontrol6 select=1 m=1 load=1")

  // M-mode triggers with action 0 match only while mstatus.MIE = 1 (mie = 0: no interrupts)
  csrw mie, x0
  csrw vstart, x0
  csrsi mstatus, 8

  // vl1re32.v: element 0 (the first element accessed) is 0x12345678, the tdata2 value
  LA(x6, sa_data)
  SA_TRY(1)
  vl1re32.v v1, (x6)
  nop
  nop
  csrci mstatus, 8
  csrr x10, vstart
  csrw vstart, x0
  csrw tdata1, x0
  SA_TRAPS(1, 3, "vl1re32.v with element 0 matching a load-data trigger: breakpoint")
  SA_CHECK2(x10, 0, 1, "vstart = 0 (trap before element 0) or 1 (trap right after element 0)")
  AI_LOG(x7, TRAPLOG_TVAL)
  LA(x6, sa_data)
  beqz x7, 1f
  sub x7, x7, x6
1:
  SA_CHECK(x7, 0, "mtval = 0 or the address of element 0")
RVTEST_CODE_END

RVTEST_DATA_BEGIN
.align 6
sa_data: .word 0x12345678, 0x11111111, 0x22222222, 0x33333333, 0x44444444, 0x55555555, 0x66666666, 0x77777777
         .word 0x88888888, 0x99999999, 0xaaaaaaaa, 0xbbbbbbbb, 0xcccccccc, 0xdddddddd, 0xeeeeeeee, 0xffffffff
         .fill 112, 4, 0x01020304
RVTEST_DATA_END
RVTEST_SIG_SETUP
