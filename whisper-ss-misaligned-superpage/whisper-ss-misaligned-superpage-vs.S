// Reproducer: in the VS-stage walk, a store to a misaligned shadow-stack superpage and an ssamoswap to a
// misaligned RW superpage raise a store/AMO access fault instead of the store/AMO page fault required by
// the translation algorithm's step order.
// Spec: src/priv/supervisor.adoc (Virtual Address Translation Process): step 5 "A leaf PTE has been reached.
//   If i>0 and pte.ppn[i-1:0] != 0, this is a misaligned superpage; stop and raise a page-fault exception
//   corresponding to the original access type." comes before step 7 "Determine if the requested memory
//   access is allowed by the pte.r, pte.w, and pte.x bits, given the Shadow Stack Memory Protection
//   rules. If not, stop and raise an access-fault exception." The VS-stage walk follows the same steps.
// Scenario: M-mode with mstatus.MPRV=1, MPV=1, MPP=S (accesses translated as VS-mode), menvcfg.SSE=1,
//   henvcfg.SSE=1. vsatp = Sv39 with 2 MiB leaves at VA 0x40000000 (SS, misaligned), 0x40200000 (RW,
//   misaligned), 0x40400000 (SS, aligned), 0x40600000 (RW, aligned); hgatp = Sv39x4 identity gigapages.
// Expected (spec): sd to the misaligned SS megapage and ssamoswap.d to the misaligned RW megapage: store/AMO
//   page fault (15); the same accesses to the aligned megapages: store/AMO access fault (7).

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

// One access with MPRV=1, MPV=1, MPP=S; x14 = xcause (-1 = none) after AI_OUTCOME
#define VS_ACCESS(...)            \
  SA_TRY(1)                      ;\
  csrc mstatus, x11              ;\
  csrs mstatus, x15              ;\
  csrs mstatus, x10              ;\
  __VA_ARGS__                    ;\
  csrc mstatus, x10              ;\
  csrc mstatus, x15              ;\
  AI_OUTCOME

RVTEST_BEGIN
  .option norvc
#if __riscv_xlen == 64
  csrw mie, x0
  // VS-stage Sv39 (vsatp): identity gigapages for the image (RWX, A, D), gigapage 0 (MMIO) RW,
  // root[1] -> t1 (VA 0x40000000.. as megapages)
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
  LA(x9, sa_pt_t1)
  LI(x6, (0x80001 << 10) | 0xc5)   // t1[0]: SS megapage (xwr=010, A, D), ppn[0]=1: misaligned
  SREG x6, 0(x9)
  LI(x6, (0x80001 << 10) | 0xc7)   // t1[1]: RW megapage, misaligned
  SREG x6, 8(x9)
  LI(x6, (0x80000 << 10) | 0xc5)   // t1[2]: SS megapage, aligned (control)
  SREG x6, 16(x9)
  LI(x6, (0x80000 << 10) | 0xc7)   // t1[3]: RW megapage, aligned (control)
  SREG x6, 24(x9)
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

  csrsi menvcfg, 8            // menvcfg.SSE = 1
  csrsi 0x60a, 8              // henvcfg.SSE = 1
  LI(x10, MPRV_MPP_S)
  LI(x11, 3 << 11)
  LI(x15, MPV)
  LI(x9, 0x55)

  // case 1: ordinary store to a misaligned SS megapage
  LI(x6, 0x40000800)
  VS_ACCESS(sd x0, 0(x6))
  mv x20, x14
  // case 2: ssamoswap.d to a misaligned RW megapage
  LI(x6, 0x40200800)
  VS_ACCESS(.word 0x4893342f)  // ssamoswap.d x8, x9, (x6)
  mv x21, x14
  // control 3: ordinary store to an aligned SS megapage
  LI(x6, 0x40400800)
  VS_ACCESS(sd x0, 0(x6))
  mv x22, x14
  // control 4: ssamoswap.d to an aligned RW megapage
  LI(x6, 0x40600800)
  VS_ACCESS(.word 0x4893342f)  // ssamoswap.d x8, x9, (x6)
  mv x23, x14

  csrci 0x60a, 8
  csrci menvcfg, 8
  csrw vsatp, x0
  csrw hgatp, x0
  .word 0x62000073            // hfence.gvma x0, x0

  SA_CHECK(x22, 7, "control 3: VS sd to an aligned SS megapage: cause")
  SA_CHECK(x23, 7, "control 4: VS ssamoswap.d to an aligned RW megapage: cause")
  SA_CHECK(x20, 15, "case 1: VS sd to a misaligned SS megapage: cause (misaligned superpage: 15)")
  SA_CHECK(x21, 15, "case 2: VS ssamoswap.d to a misaligned RW megapage: cause (misaligned superpage: 15)")
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
RVTEST_DATA_END
RVTEST_SIG_SETUP
