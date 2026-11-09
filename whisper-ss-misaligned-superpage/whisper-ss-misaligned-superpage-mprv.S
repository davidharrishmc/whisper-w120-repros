// Reproducer: a store to a misaligned shadow-stack superpage raises a store access fault instead of the store
// page fault required by the translation algorithm's step order (M-mode accesses through MPRV).
// Spec: riscv-isa-manual src/priv/supervisor.adoc (Virtual Address Translation Process): step 5 "A leaf PTE has
//   been reached. If i>0 and pte.ppn[i-1:0] != 0, this is a misaligned superpage; stop and raise a page-fault
//   exception corresponding to the original access type." comes before step 7 "Determine if the requested
//   memory access is allowed by the pte.r, pte.w, and pte.x bits, given the Shadow Stack Memory Protection
//   rules. If not, stop and raise an access-fault exception."
// Whisper: virtual_memory/VirtMem.cpp pageTableWalk applies the Zicfiss rule (non-SS store to an SS page ->
//   access fault) before its misaligned-superpage check.
// Scenario: Sv39, menvcfg.SSE=1, S-mode accesses via MPRV=1/MPP=S. VA 0x40000000 is a 2 MiB leaf with
//   xwr=010 (shadow-stack page), A=D=1, whose PPN is only 4 KiB aligned (ppn[0] != 0).
// Expected (spec): lw -> load page fault (13); sw -> store page fault (15). Whisper: lw 13, sw 7.

##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'Sm', 'S', 'Zicfiss']
# MARCH: rv${XLEN}i_zicsr_zifencei
# NEEDS_SIGNATURE: false
##### END_TEST_CONFIG #####

#define SIGUPD_COUNT 0
#define BOOT_TO_MMODE
#include "riscv_arch_test.h"
#include "../common/sa.h"

RVTEST_BEGIN
  // identity-map the image: root[2], root[3] = 1 GiB leaves, D A X W R V
  LA(x8, sa_root)
  li x7, (0x80000000 >> 12) << 10 | 0xcf
  sd x7, 16(x8)
  li x7, (0xC0000000 >> 12) << 10 | 0xcf
  sd x7, 24(x8)
  // root[1] -> t2; t2[0] = 2 MiB SS leaf (D A W V = 0xc5) at a 4 KiB-aligned PPN
  LA(x6, sa_t2)
  srli x6, x6, 12
  slli x6, x6, 10
  ori x6, x6, 1
  sd x6, 8(x8)
  LA(x6, sa_pg)
  srli x6, x6, 12
  andi x7, x6, 0x1ff
  // ppn[0] of sa_pg is nonzero: the image starts at 0x80000000 and sa_pg is not at a 2 MiB boundary
  beqz x7, sa_bad_align
  slli x6, x6, 10
  ori x6, x6, 0xc5
  LA(x8, sa_t2)
  sd x6, 0(x8)
  // satp = Sv39
  LA(x6, sa_root)
  srli x6, x6, 12
  li x7, 0x8000000000000000
  or x6, x6, x7
  csrw satp, x6
  sfence.vma x0, x0
  // menvcfg.SSE = 1
  csrsi menvcfg, 8
  csrr x9, menvcfg
  andi x9, x9, 8
  SA_CHECK(x9, 8, "menvcfg.SSE holds 1")
  li x11, 0x20800          // MPRV | MPP=S
  li x7, 0x1800
  csrc mstatus, x7
  li x6, 0x40000000
  // load: page fault on every reading (SS pages are readable; misaligned superpage)
  SA_TRY(1)
  csrs mstatus, x11
  lw x9, 0(x6)
  csrc mstatus, x11
  SA_TRAPS(1, 13, "lw from misaligned SS superpage")
  // store: step 5 (misaligned superpage, page fault) precedes step 7 (SS rule, access fault)
  SA_TRY(1)
  csrs mstatus, x11
  sw x9, 0(x6)
  csrc mstatus, x11
  SA_TRAPS(1, 15, "sw to misaligned SS superpage")
  csrc mstatus, x11
  csrci menvcfg, 8
  j sa_done
sa_bad_align:
  li x9, 1
  SA_CHECK(x9, 0, "sa_pg happens to be 2 MiB aligned; move it")
sa_done:
RVTEST_CODE_END

RVTEST_DATA_BEGIN
  .p2align 12
sa_root: .fill 4096, 1, 0
sa_t2:   .fill 4096, 1, 0
sa_pg:   .fill 4096, 1, 0
RVTEST_DATA_END
RVTEST_SIG_SETUP
