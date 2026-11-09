// Whisper, RV32: a single-stage Sv32 or G-stage Sv32x4 non-leaf PTE that points to a next-level table at a
// physical address at or above 4 GiB is truncated to 32 bits.
// Spec: priv/supervisor.adoc (Sv32: 34-bit physical addresses, 22-bit PPN; Virtual Address Translation
//   Process step 4: "Otherwise, this PTE is a pointer to the next level of the page table. Let i = i-1 ...
//   let a = pte.ppn x PAGESIZE"); priv/hypervisor.adoc: G-stage Sv32x4 uses the Sv32 PTE format and algorithm.
// Needs RAM at physical address 0x1_0000_0000-0x1_0000_1fff (whisper-rv32-max has RAM up to 0x3_ffff_ffff); the
//   test does nothing if a store there traps.
// Setup (M boot, RV32): Sv32 root: root[0x200] = 4 MiB leaf VA 0x80000000 -> PA 0x80000000; root[0x300] = 4 MiB
//   leaf VA 0xc0000000 -> PA 0x1_0000_0000 (used to write the high tables). Two level-0 tables are placed at
//   PA 0x1_0000_0000 (for the Sv32 walk) and PA 0x1_0000_1000 (for the G-stage walk); each maps page 0 of its
//   4 MiB region to sa_data's page.
//   Case 1 (Sv32): root[0x100] = non-leaf PTE with PPN 0x100000 (table at PA 0x1_0000_0000); lw from VA
//     0x40000000 + offset (MPRV=1, MPP=S).
//   Case 2 (G-stage Sv32x4, vsatp = Bare): G-stage root[0x100] = non-leaf PTE with PPN 0x100001 (table at PA
//     0x1_0000_1000); hlv.w (SPVP=1) from M-mode of GPA 0x40000000 + offset.
// Expected: both read 0x5a5a1234 without a trap. Whisper master: the table address is truncated to PA 0x0 /
//   0x1000, case 1 raises a load access fault and case 2 a load guest-page fault.

##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'Sm', 'S', 'H']
# MARCH: rv${XLEN}i_zicsr_zifencei
# NEEDS_SIGNATURE: false
##### END_TEST_CONFIG #####

#define SIGUPD_COUNT 0
#define BOOT_TO_MMODE
#include "riscv_arch_test.h"
#include "../common/sa.h"

// *(root + 4*_IDX) = _R
#define PUT(_ROOT, _IDX, _R)  LI(x10, (_IDX)*4); add x10, x10, _ROOT; sw _R, 0(x10)

RVTEST_BEGIN
#if __riscv_xlen == 32
  LA(x6, rvtest_entry_point)
  srli x6, x6, 22
  SA_CHECK(x6, 0x200, "image lies in 0x80000000-0x803fffff")
  csrw medeleg, x0
  // Sv32 root
  LA(x8, sa_root)
  LI(x7, (0x80000000 >> 2) | 0xcf)      // [0x200]: 4 MiB leaf, identity, DA-XWRV
  PUT(x8, 0x200, x7)
  LI(x7, 0x40000000 | 0xcf)             // [0x300]: 4 MiB leaf VA 0xc0000000 -> PA 0x1_0000_0000 (PPN 0x100000)
  PUT(x8, 0x300, x7)
  LI(x7, 0x40000000 | 0x01)             // [0x100]: non-leaf, PPN 0x100000 (table at PA 0x1_0000_0000)
  PUT(x8, 0x100, x7)
  srli x7, x8, 12
  LI(x9, 0x80000000)                    // MODE = Sv32
  or x7, x7, x9
  csrw satp, x7
  sfence.vma x0, x0
  // leaf PTE for sa_data's page: Sv32 (DA-XWRV) and G-stage (DAU-XWRV)
  LA(x12, sa_data)
  srli x12, x12, 12
  slli x12, x12, 10
  ori x17, x12, 0xcf
  ori x12, x12, 0xdf
  LI(x11, 0x20800)                      // mstatus.MPRV | MPP = S
  LI(x7, 0x1800)
  csrc mstatus, x7
  // write the two high level-0 tables through VA 0xc0000000 (entry 0 of each)
  LI(x6, 0xc0000000)
  LI(x18, 0xc0001000)
  SA_TRY(2)
  csrs mstatus, x11
  sw x17, 0(x6)                         // PA 0x1_0000_0000: Sv32 level-0 table [0]
  sw x12, 0(x18)                        // PA 0x1_0000_1000: G-stage level-0 table [0]
  csrc mstatus, x11
  AI_OUTCOME
  csrc mstatus, x11
  bnez x13, sa_skip                     // no RAM at PA 0x1_0000_0000: nothing to test
  // VA / GPA 0x40000000 + page offset of sa_data
  LA(x6, sa_data)
  slli x6, x6, 20
  srli x6, x6, 20
  LI(x7, 0x40000000)
  or x6, x6, x7

  // Case 1: Sv32 walk through the table at PA 0x1_0000_0000
  li x7, 0
  SA_TRY(1)
  csrs mstatus, x11
  lw x7, 0(x6)
  csrc mstatus, x11
  AI_OUTCOME
  csrc mstatus, x11
  mv x16, x7
  SA_SOFT(x13, 0, "case 1: Sv32 non-leaf PTE -> table at PA 0x1_0000_0000: lw: number of traps")
  SA_SOFT(x16, 0x5a5a1234, "case 1: Sv32 non-leaf PTE -> table at PA 0x1_0000_0000: lw value")
  csrw satp, x0
  sfence.vma x0, x0

  // Case 2: G-stage Sv32x4 walk through the table at PA 0x1_0000_1000, vsatp = Bare
  csrw 0x280, x0                        // vsatp = Bare
  LA(x8, sa_g_root)
  LI(x7, 0x40000400 | 0x01)             // [0x100]: non-leaf, PPN 0x100001 (table at PA 0x1_0000_1000)
  PUT(x8, 0x100, x7)
  srli x7, x8, 12
  LI(x9, 0x80000000)                    // MODE = Sv32x4
  or x7, x7, x9
  csrw 0x680, x7
  li x7, 0x100
  csrs 0x600, x7                        // hstatus.SPVP = 1
  .word 0x62000073                      // hfence.gvma x0, x0
  li x7, 0
  SA_TRY(1)
  .word 0x680343f3                      // hlv.w x7, (x6)
  AI_OUTCOME
  mv x16, x7
  SA_SOFT(x13, 0, "case 2: G-stage non-leaf PTE -> table at PA 0x1_0000_1000: hlv.w: number of traps")
  SA_SOFT(x16, 0x5a5a1234, "case 2: G-stage non-leaf PTE -> table at PA 0x1_0000_1000: hlv.w value")
  csrw 0x680, x0
sa_skip:
#endif
  SA_SOFT_END
RVTEST_CODE_END

RVTEST_DATA_BEGIN
  .p2align 14
sa_g_root:
  .fill 16384, 1, 0
  .p2align 12
sa_root:
  .fill 4096, 1, 0
sa_data:
  .word 0x5a5a1234
RVTEST_DATA_END
RVTEST_SIG_SETUP
