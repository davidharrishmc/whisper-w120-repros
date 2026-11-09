// Reproducer: an M-mode ssamoswap with mstatus.MPRV=1, MPV=1, MPP=S and menvcfg.SSE=0 does not fault on an
// invalid G-stage PTE: the G-stage walk treats it as valid.
// Spec: src/priv/supervisor.adoc (Virtual Address Translation Process) step 3: "If pte.v=0, or if pte.r=0 and
//   pte.w=1, or if any bits or encodings that are reserved for future standard use are set within pte, stop
//   and raise a page-fault exception corresponding to the original access type." src/priv/hypervisor.adoc
//   (guest-page faults): a G-stage translation failure raises a guest-page fault; src/priv/cfi.adoc
//   norm:ss_fault_exception_code: for a shadow stack instruction it is a store/AMO guest-page fault (23).
//   src/priv/cfi.adoc: "The G-stage address translation and protections remain unaffected by the Zicfiss
//   extension." In M-mode, ssamoswap executes whatever menvcfg.SSE is (src/unpriv/cfi.adoc listing).
// Whisper: virtual_memory/VirtMem.cpp stage2PageTableWalk step 3 is
//   `if (not isValidPte(pte)) if (not ssMode_ or (ssEnabled_ and not isSsPte(pte))) fault`, which never
//   faults for a shadow-stack access when menvcfg.SSE=0.
// Scenario: vsatp = Sv39 (tables in the image gigapage), hgatp = Sv39x4 whose leaf for the image gigapage has
//   V=0 (R, W, X, U, A, D set). The VS-stage walk's first PTE read therefore takes a guest-page fault.
// Expected (spec): control (ordinary sd through MPRV/MPV): 23; control (ssamoswap.d, menvcfg.SSE=1): 23;
//   case (ssamoswap.d, menvcfg.SSE=0): 23. Whisper: case: "Assertion `vsSsEnabled_' failed" (the walk goes
//   through the invalid PTE and reaches the VS-stage leaf).

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

  // G-stage leaf for the image gigapage: V=0, R W X U A D = 1
  LA(x6, rvtest_entry_point)
  srli x6, x6, 30
  slli x7, x6, 28
  ori x7, x7, 0xde
  LA(x8, sa_gpt_root)
  slli x9, x6, 3
  add x9, x8, x9
  SREG x7, 0(x9)
  .word 0x62000073            // hfence.gvma x0, x0
  .word 0x22000073            // hfence.vvma x0, x0

  LI(x6, 0x40000800)
  LI(x9, 0x55)
  LI(x10, MPRV_MPP_S)
  LI(x11, 3 << 11)
  LI(x15, MPV)

  // control 1: ordinary store through MPRV/MPV
  SA_TRY(1)
  csrc mstatus, x11
  csrs mstatus, x15
  csrs mstatus, x10
  sd x9, 0(x6)
  csrc mstatus, x10
  csrc mstatus, x15
  AI_OUTCOME
  mv x20, x14

  // control 2: ssamoswap.d with menvcfg.SSE = 1
  csrsi menvcfg, 8
  SA_TRY(1)
  csrc mstatus, x11
  csrs mstatus, x15
  csrs mstatus, x10
  .word 0x4893342f            // ssamoswap.d x8, x9, (x6)
  csrc mstatus, x10
  csrc mstatus, x15
  AI_OUTCOME
  mv x21, x14
  SA_CHECK(x20, 23, "control 1: sd through MPRV/MPV, invalid G-stage PTE: xcause")
  SA_CHECK(x21, 23, "control 2: ssamoswap.d, menvcfg.SSE=1, invalid G-stage PTE: xcause")

  // case: ssamoswap.d with menvcfg.SSE = 0
  csrci menvcfg, 8
  SA_TRY(1)
  csrc mstatus, x11
  csrs mstatus, x15
  csrs mstatus, x10
  .word 0x4893342f            // ssamoswap.d x8, x9, (x6)
  csrc mstatus, x10
  csrc mstatus, x15
  AI_OUTCOME
  mv x22, x14
  SA_CHECK(x22, 23, "case: ssamoswap.d, menvcfg.SSE=0, invalid G-stage PTE: xcause")

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
