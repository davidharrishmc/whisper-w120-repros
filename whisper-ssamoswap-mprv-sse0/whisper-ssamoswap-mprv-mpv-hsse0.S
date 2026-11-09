// Reproducer: an M-mode ssamoswap with mstatus.MPRV=1, MPV=1, MPP=S (effective mode VS) and henvcfg.SSE=0 makes
// Whisper abort on an internal assertion instead of raising a store/AMO access fault.
// Spec: src/unpriv/cfi.adoc ssamoswap listing: "if privilege_mode != M && menvcfg.SSE == 0 raise
//   illegal-instruction exception ... else temp = mem[X(rs1)] ..." -- in M-mode the instruction executes
//   whatever menvcfg.SSE and henvcfg.SSE are. src/priv/cfi.adoc norm:ssmp_henvcfg_sse: with V=1 and
//   henvcfg.SSE=0 the SS encoding stays reserved at VS level; norm:ssmp_ss_page_illegal_access: a shadow
//   stack instruction access to a page that is neither an SS page nor read-only raises a store/AMO access
//   fault. With MPRV=1, MPV=1 and MPP=S the access is translated as VS-mode, so a RW VS-stage page gives
//   cause 7.
// Whisper: virtual_memory/VirtMem.cpp stage1PageTableWalk does `if (ssMode_) { assert(vsSsEnabled_);`; the
//   VS-stage TLB-hit path in stage1Translate has the same assert.
// Expected (spec): control (henvcfg.SSE=1), case 1 (henvcfg.SSE=0, page-table walk) and case 2 (henvcfg.SSE=0,
//   translation cached by an earlier MPRV load) all raise cause 7. Whisper: control 7, case 1:
//   "Assertion `vsSsEnabled_' failed" and the simulator stops.

##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'Sm', 'S', 'H', 'Zicfiss']
# MARCH: rv${XLEN}i_zicsr_zifencei
# NEEDS_SIGNATURE: false
##### END_TEST_CONFIG #####

#define SIGUPD_COUNT 0
#define BOOT_TO_MMODE
#include "riscv_arch_test.h"
#include "../common/sa.h"

#define MPRV_MPP_S ((1 << 17) | (1 << 11))
#define MPV (1 << 39)

RVTEST_BEGIN
#if __riscv_xlen == 64
  csrw mie, x0
  // VS-stage Sv39 (vsatp): identity gigapages for the image (RWX, A, D, U=0), gigapage 0 (MMIO) RW,
  // VA 0x40000000 -> sa_pg (RW, A, D, U=0: an ordinary data page, not an SS page)
  LA(x6, rvtest_entry_point)
  srli x6, x6, 30
  slli x7, x6, 28
  ori x7, x7, 0xcf
  LA(x8, sa_pt_root)
  slli x9, x6, 3
  add x9, x8, x9
  SREG x7, 0(x9)
  addi x6, x6, 1
  slli x7, x6, 28
  ori x7, x7, 0xcf
  slli x9, x6, 3
  add x9, x8, x9
  SREG x7, 0(x9)
  li x7, 0xc7
  SREG x7, 0(x8)
  LA(x6, sa_pt_t1)
  srli x6, x6, 12
  slli x6, x6, 10
  ori x6, x6, 1
  SREG x6, 8(x8)
  LA(x6, sa_pt_t2)
  srli x6, x6, 12
  slli x6, x6, 10
  ori x6, x6, 1
  LA(x9, sa_pt_t1)
  SREG x6, 0(x9)
  LA(x6, sa_pg)
  srli x6, x6, 12
  slli x6, x6, 10
  ori x6, x6, 0xc7
  LA(x9, sa_pt_t2)
  SREG x6, 0(x9)
  srli x6, x8, 12
  li x7, 0x8000000000000000
  or x6, x6, x7
  csrw vsatp, x6

  // G-stage Sv39x4 (hgatp): identity gigapages for the image (RWX, U, A, D)
  LA(x6, rvtest_entry_point)
  srli x6, x6, 30
  slli x7, x6, 28
  ori x7, x7, 0xdf
  LA(x8, sa_gpt_root)
  slli x9, x6, 3
  add x9, x8, x9
  SREG x7, 0(x9)
  addi x6, x6, 1
  slli x7, x6, 28
  ori x7, x7, 0xdf
  slli x9, x6, 3
  add x9, x8, x9
  SREG x7, 0(x9)
  srli x6, x8, 12
  li x7, 0x8000000000000000
  or x6, x6, x7
  csrw hgatp, x6
  .word 0x62000073            // hfence.gvma x0, x0
  .word 0x22000073            // hfence.vvma x0, x0

  LI(x6, 0x40000800)
  LI(x9, 0x55)
  LI(x10, MPRV_MPP_S)
  LI(x11, 3 << 11)
  LI(x15, MPV)
  csrsi menvcfg, 8            // menvcfg.SSE = 1

  // control: henvcfg.SSE = 1
  csrsi 0x60a, 8              // henvcfg.SSE = 1
  SA_TRY(1)
  csrc mstatus, x11
  csrs mstatus, x15           // MPV=1
  csrs mstatus, x10           // MPRV=1, MPP=S: data accesses translated as VS-mode
  .word 0x4893342f            // ssamoswap.d x8, x9, (x6)
  csrc mstatus, x10           // MPRV=0
  csrc mstatus, x15           // MPV=0
  AI_OUTCOME
  mv x12, x14
  SA_CHECK(x12, 7, "control: M-mode ssamoswap.d, MPRV=1 MPV=1 MPP=S, henvcfg.SSE=1, RW page: xcause")

  // case 1: henvcfg.SSE = 0, page-table walk
  csrci 0x60a, 8              // henvcfg.SSE = 0
  SA_TRY(1)
  csrc mstatus, x11
  csrs mstatus, x15
  csrs mstatus, x10
  .word 0x4893342f            // ssamoswap.d x8, x9, (x6)
  csrc mstatus, x10
  csrc mstatus, x15
  AI_OUTCOME
  mv x12, x14
  SA_CHECK(x12, 7, "case 1: M-mode ssamoswap.d, MPRV=1 MPV=1 MPP=S, henvcfg.SSE=0, RW page: xcause")

  // case 2: henvcfg.SSE = 0, translation cached by an ordinary load through MPRV
  .word 0x22000073            // hfence.vvma x0, x0
  SA_TRY(1)
  csrc mstatus, x11
  csrs mstatus, x15
  csrs mstatus, x10
  ld x8, 0(x6)                // fills the TLBs
  .word 0x4893342f            // ssamoswap.d x8, x9, (x6)
  csrc mstatus, x10
  csrc mstatus, x15
  AI_OUTCOME
  mv x12, x14
  SA_CHECK(x12, 7, "case 2: as case 1 after an MPRV ld from the page: xcause")

  csrci menvcfg, 8
  csrw vsatp, x0
  csrw hgatp, x0
  .word 0x62000073            // hfence.gvma x0, x0
#endif
RVTEST_CODE_END

RVTEST_DATA_BEGIN
  .p2align 14
sa_gpt_root:
  .fill 16384, 1, 0
sa_pt_root:
  .fill 4096, 1, 0
sa_pt_t1:
  .fill 4096, 1, 0
sa_pt_t2:
  .fill 4096, 1, 0
sa_pg:
  .fill 4096, 1, 0
RVTEST_DATA_END
RVTEST_SIG_SETUP
