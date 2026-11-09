// Whisper: SFENCE.VMA with rs1 != x0, executed while satp.MODE = Bare, invalidates nothing.
// Spec: priv/supervisor.adoc [norm:sfence_vma_va_all_asid] "If rs1!=x0 and rs2=x0, the fence orders only reads
//   and writes made to leaf page table entries corresponding to the virtual address in rs1, for all address
//   spaces. The fence also invalidates all address-translation cache entries that contain leaf page table
//   entries corresponding to the virtual address in rs1, for all address spaces." Nothing makes the fence
//   depend on the satp.MODE in effect when it executes.
// Scenario (S-mode loads through MPRV=1, MPP=S): Sv39, VA 0x40051000 -> page A; a load caches the translation.
//   The leaf is changed to page B, satp is set to Bare, SFENCE.VMA 0x40051000, x0 runs, satp is set back to
//   the same Sv39 value, and the VA is loaded again.
// Expected: the second load reads page B (0x2222). Whisper master: it reads page A (0x1111) from the stale TLB
//   entry. (With the fence executed under Sv39 instead, Whisper reads page B.)

##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'Sm', 'S']
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
  // root[1] -> t2, t2[0] -> t3, t3[0x51] maps VA 0x40051000
  LA(x6, sa_t2)
  srli x6, x6, 12
  slli x6, x6, 10
  ori x6, x6, 1
  sd x6, 8(x8)
  LA(x8, sa_t2)
  LA(x6, sa_t3)
  srli x6, x6, 12
  slli x6, x6, 10
  ori x6, x6, 1
  sd x6, 0(x8)
  // leaf -> page A, D A W R V
  LA(x6, sa_pgA)
  srli x6, x6, 12
  slli x6, x6, 10
  ori x6, x6, 0xc7
  LA(x8, sa_t3)
  sd x6, 0x51*8(x8)
  // page contents
  LA(x8, sa_pgA)
  li x7, 0x1111
  sw x7, 0(x8)
  LA(x8, sa_pgB)
  li x7, 0x2222
  sw x7, 0(x8)
  // satp = Sv39, ASID 0
  LA(x10, sa_root)
  srli x10, x10, 12
  li x7, 0x8000000000000000
  or x10, x10, x7
  csrw satp, x10
  sfence.vma x0, x0
  li x6, 0x40051000
  li x11, 0x20800          // MPRV | MPP=S (MPP bit 11)
  li x7, 0x1800
  csrc mstatus, x7
  // 1. load through page A: caches the translation
  csrs mstatus, x11
  lw x9, 0(x6)
  csrc mstatus, x11
  SA_CHECK(x9, 0x1111, "first load reads page A")
  // 2. retarget the leaf to page B
  LA(x7, sa_pgB)
  srli x7, x7, 12
  slli x7, x7, 10
  ori x7, x7, 0xc7
  LA(x8, sa_t3)
  sd x7, 0x51*8(x8)
  // 3. satp = Bare, fence that VA, then back to the same Sv39 value
  csrw satp, x0
  sfence.vma x6, x0
  csrw satp, x10
  // 4. load again: must use the new leaf
  csrs mstatus, x11
  lw x9, 0(x6)
  csrc mstatus, x11
  SA_CHECK(x9, 0x2222, "load after SFENCE.VMA va (run under satp=Bare) reads page B")
RVTEST_CODE_END

RVTEST_DATA_BEGIN
  .p2align 12
sa_root: .fill 4096, 1, 0
sa_t2:   .fill 4096, 1, 0
sa_t3:   .fill 4096, 1, 0
sa_pgA:  .fill 4096, 1, 0
sa_pgB:  .fill 4096, 1, 0
RVTEST_DATA_END
RVTEST_SIG_SETUP
