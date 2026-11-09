// Reproducer (TLB-hit variant): an M-mode ssamoswap with mstatus.MPRV=1 (MPP=S) and menvcfg.SSE=0 makes
// Whisper abort on an internal assertion instead of raising a store/AMO access fault.
// Spec: src/unpriv/cfi.adoc ssamoswap listing: "if privilege_mode != M && menvcfg.SSE == 0 raise
//   illegal-instruction exception ... else temp = mem[X(rs1)] ..." -- in M-mode the instruction executes
//   whatever menvcfg.SSE is. src/priv/cfi.adoc norm:ssmp_menvcfg_sse: with menvcfg.SSE=0 the SS page encoding
//   stays reserved; norm:ssmp_ss_page_illegal_access: "Should a shadow stack instruction access a page that is
//   not designated as a shadow stack page and is not marked as read-only (pte.xwr=0b001), a store/AMO
//   access-fault exception will be invoked." With MPRV=1 and MPP=S the access is translated as S-mode, so a
//   RW page gives cause 7.
// Whisper: virtual_memory/VirtMem.cpp pageTableWalk does `if (ssMode_) { assert(ssEnabled_);` (ssEnabled_ =
//   menvcfg.SSE); the TLB-hit path in VirtMem::translate has the same assert.
// This variant runs only the control and case 2 (translation cached by an earlier MPRV load), so the access
//   takes the TLB-hit path.
// Expected (spec): control and case 2 raise cause 7. Whisper: control 7, case 2: "Assertion `ssEnabled_'
//   failed" in VirtMem::translate (TLB hit) and the simulator stops.

##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'Sm', 'S', 'Zicfiss']
# MARCH: rv${XLEN}i_zicsr_zifencei
# NEEDS_SIGNATURE: false
##### END_TEST_CONFIG #####

#define SIGUPD_COUNT 0
#define BOOT_TO_MMODE
#include "riscv_arch_test.h"
#include "../common/sa.h"

#define MPRV_MPP_S ((1 << 17) | (1 << 11))

RVTEST_BEGIN
#if __riscv_xlen == 64
  csrw mie, x0
  // Sv39: identity gigapages for the image (RWX, A, D, U=0), gigapage 0 (MMIO) RW,
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
  csrw satp, x6
  sfence.vma

  LI(x6, 0x40000800)
  LI(x9, 0x55)
  LI(x10, MPRV_MPP_S)
  LI(x11, 3 << 11)

  // control: menvcfg.SSE = 1
  csrsi menvcfg, 8
  SA_TRY(1)
  csrc mstatus, x11
  csrs mstatus, x10           // MPRV=1, MPP=S: data accesses translated as S-mode
  .word 0x4893342f            // ssamoswap.d x8, x9, (x6)
  csrc mstatus, x10           // MPRV=0 (the handler's mret left MPP=U, MPRV=1)
  AI_OUTCOME
  mv x12, x14
  SA_CHECK(x12, 7, "control: M-mode ssamoswap.d, MPRV=1 MPP=S, menvcfg.SSE=1, RW page: xcause")

  csrci menvcfg, 8
  // case 2: menvcfg.SSE = 0, translation cached by an ordinary load through MPRV
  sfence.vma
  SA_TRY(1)
  csrc mstatus, x11
  csrs mstatus, x10
  ld x8, 0(x6)                // fills the TLB
  .word 0x4893342f            // ssamoswap.d x8, x9, (x6)
  csrc mstatus, x10
  AI_OUTCOME
  mv x12, x14
  SA_CHECK(x12, 7, "case 2: ssamoswap.d, menvcfg.SSE=0, after an MPRV ld from the page: xcause")

  csrw satp, x0
  sfence.vma
#endif
RVTEST_CODE_END

RVTEST_DATA_BEGIN
  .p2align 12
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
