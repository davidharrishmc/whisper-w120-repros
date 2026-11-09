// Reproducer: on a misaligned superpage, the shadow-stack access-fault rules are applied before the
// misaligned-superpage page fault (S-mode accesses).
// Spec: riscv-isa-manual src/priv/supervisor.adoc (Virtual Address Translation Process), in order: step 5 "A
//   leaf PTE has been reached. If i>0 and pte.ppn[i-1:0] != 0, this is a misaligned superpage; stop and raise
//   a page-fault exception corresponding to the original access type." step 7 "Determine if the requested
//   memory access is allowed by the pte.r, pte.w, and pte.x bits, given the Shadow Stack Memory Protection
//   rules. If not, stop and raise an access-fault exception." Step 5 comes first, so a store to a misaligned
//   SS megapage, and an sspush to a misaligned RW megapage, raise a store/AMO page fault (15)
//   (src/priv/cfi.adoc norm:ss_fault_exception_code: SS instructions report store/AMO faults).
// Whisper: virtual_memory/VirtMem.cpp pageTableWalk returns the SS access fault (non-SS store to an SS page;
//   SS instruction to a non-SS page) before its misaligned-superpage check.
// Scenario: S-mode, Sv39, menvcfg.SSE=1; 2 MiB leaves at VA 0x40000000 (SS, misaligned), 0x40200000 (RW,
//   misaligned), 0x40400000 (SS, aligned), 0x40600000 (RW, aligned).
// Expected (spec): cases 1 and 2 cause 15; controls on aligned megapages cause 7. Whisper: 7 for all four.

##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'S', 'Zicfiss']
# MARCH: rv${XLEN}i_zicsr_zifencei
# NEEDS_SIGNATURE: false
##### END_TEST_CONFIG #####

#define SIGUPD_COUNT 0
#define BOOT_TO_SMODE
#include "riscv_arch_test.h"
#include "../common/sa.h"

RVTEST_BEGIN
  .option norvc
#if __riscv_xlen == 64
  LI(a1, 8)                   // menvcfg.SSE = 1 (T-SBI)
  RVTEST_TSBI_CSR_ACCESS TSBI_CSR_SET(CSR_MENVCFG)

  // Sv39: identity gigapages for the image (RWX, A, D); root[1] -> t1 (VA 0x40000000.. as megapages)
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
  li x7, 0xc7                 // root[0]: gigapage 0 (MMIO, console) RW, so the failure reporter works
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
  csrw satp, x6
  sfence.vma

  LI(x1, 0x0123456789abcdef)

  // Each case records its trap cause (x14 after AI_OUTCOME, -1 = none); all are checked at the end.
  // case 1: ordinary store to a misaligned SS megapage
  LI(x9, 0x40000800)
  SA_TRY(1)
  sd x0, 0(x9)
  AI_OUTCOME
  mv x10, x14

  // case 2: sspush to a misaligned RW megapage
  LI(x6, 0x40200808)
  csrw 0x11, x6
  SA_TRY(1)
  .word 0xce104073            // sspush x1
  AI_OUTCOME
  mv x11, x14

  // control 3: ordinary store to an aligned SS megapage
  LI(x9, 0x40400800)
  SA_TRY(1)
  sd x0, 0(x9)
  AI_OUTCOME
  mv x12, x14

  // control 4: sspush to an aligned RW megapage
  LI(x6, 0x40600808)
  csrw 0x11, x6
  SA_TRY(1)
  .word 0xce104073            // sspush x1
  AI_OUTCOME
  mv x15, x14

  SA_CHECK(x12, 7, "control 3: sd to an aligned SS megapage: cause")
  SA_CHECK(x15, 7, "control 4: sspush to an aligned RW megapage: cause")
  SA_CHECK(x10, 15, "case 1: sd to a misaligned SS megapage: cause (misaligned superpage: 15)")
  SA_CHECK(x11, 15, "case 2: sspush to a misaligned RW megapage: cause (misaligned superpage: 15)")

  csrw satp, x0
  sfence.vma
  LI(a1, 8)
  RVTEST_TSBI_CSR_ACCESS TSBI_CSR_CLEAR(CSR_MENVCFG)
#endif
RVTEST_CODE_END

RVTEST_DATA_BEGIN
  .p2align 12
sa_pt_root:
  .fill 4096, 1, 0
sa_pt_t1:
  .fill 4096, 1, 0
RVTEST_DATA_END
RVTEST_SIG_SETUP
