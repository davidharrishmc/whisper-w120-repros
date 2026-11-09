// Whisper, RV32: a VS-stage Sv32 non-leaf PTE that points to a next-level table at a guest physical address
// at or above 4 GiB is truncated to 32 bits.
// Spec: priv/hypervisor.adoc [norm:hgatp_mode_sv32x4] "Sv32x4 ... is defined to support a 34-bit guest physical
//   address"; the VS-stage is the Sv32 algorithm (priv/supervisor.adoc, Virtual Address Translation Process
//   step 4: "Otherwise, this PTE is a pointer to the next level of the page table. Let i = i-1 ... let
//   a = pte.ppn x PAGESIZE"), and pte.ppn has 22 bits, so a is a 34-bit guest physical address.
// Setup (HS boot): hgatp = Sv32x4 with 4 MiB megapages: GPA 0x80000000-0x80ffffff -> same PA (identity) and an
//   alias GPA 0x100000000-0x100ffffff -> PA 0x80000000-0x80ffffff. vsatp = Sv32 (root at its identity GPA).
//   VS root[0x100] (VA 0x40000000) points to the level-0 table
//     case 1 (control): through the table's identity GPA (< 4 GiB);
//     case 2: through its alias GPA = PA + 0x80000000 (>= 4 GiB).
//   The level-0 leaf maps VA 0x40000000 -> the (identity) GPA of sa_data's page. HLV.W with SPVP=1 from HS
//   reads sa_data. No memory above 4 GiB is needed.
// Expected: both cases read 0x5a5a1234 without a trap. Whisper master: case 2 raises a load guest-page fault
//   (htval = the table GPA with bit 32 dropped, >> 2).

##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'S', 'H']
# MARCH: rv${XLEN}i_zicsr_zifencei
# NEEDS_SIGNATURE: false
##### END_TEST_CONFIG #####

#define SIGUPD_COUNT 0
#define BOOT_TO_SMODE
#include "riscv_arch_test.h"
#include "../common/sa.h"

// *(root + 4*_IDX) = _R
#define PUT(_ROOT, _IDX, _R)  LI(x10, (_IDX)*4); add x10, x10, _ROOT; sw _R, 0(x10)

RVTEST_BEGIN
#if __riscv_xlen == 32
  csrw 0x680, x0
  csrw 0x280, x0
  LA(x6, rvtest_entry_point)
  srli x6, x6, 24
  SA_CHECK(x6, 0x80, "image lies in 0x80000000-0x80ffffff")
  // G-stage root (Sv32x4, 4096 entries)
  LA(x8, sa_g_root)
  LI(x9, 0x400000 >> 2)                 // PTE increment for the next 4 MiB
  LI(x7, (0x80000000 >> 2) | 0xdf)      // DAU-XWRV
  PUT(x8, 0x200, x7)
  PUT(x8, 0x400, x7)
  add x7, x7, x9
  PUT(x8, 0x201, x7)
  PUT(x8, 0x401, x7)
  add x7, x7, x9
  PUT(x8, 0x202, x7)
  PUT(x8, 0x402, x7)
  add x7, x7, x9
  PUT(x8, 0x203, x7)
  PUT(x8, 0x403, x7)
  srli x7, x8, 12
  LI(x9, 0x80000000)                    // MODE = Sv32x4
  or x7, x7, x9
  csrw 0x680, x7
  // VS level-0 table: VA 0x40000000 -> GPA of sa_data's page (identity), DA-XWRV
  LA(x11, sa_vs_t0)
  LA(x7, sa_data)
  srli x7, x7, 12
  slli x7, x7, 10
  ori x7, x7, 0xcf
  sw x7, 0(x11)
  // vsatp = Sv32, root at its identity GPA
  LA(x12, sa_vs_root)
  srli x7, x12, 12
  LI(x9, 0x80000000)
  or x7, x7, x9
  csrw 0x280, x7
  li x7, 0x100
  csrs 0x600, x7                        // hstatus.SPVP = 1
  // VA for HLV: 0x40000000 + page offset of sa_data
  LA(x6, sa_data)
  slli x6, x6, 20
  srli x6, x6, 20
  LI(x7, 0x40000000)
  or x6, x6, x7

  // Case 1: VS root[0x100] -> level-0 table through its identity GPA
  srli x7, x11, 12
  slli x7, x7, 10
  ori x7, x7, 1
  PUT(x12, 0x100, x7)
  .word 0x62000073          // hfence.gvma x0, x0
  .word 0x22000073          // hfence.vvma x0, x0
  SA_TRY(1)
  .word 0x680343f3          // hlv.w x7, (x6)
  SA_TRAPS(0, -1, "case 1: table GPA < 4 GiB: hlv.w")
  SA_CHECK(x7, 0x5a5a1234, "case 1: hlv.w value")

  // Case 2: VS root[0x100] -> level-0 table through its alias GPA = PA + 0x80000000 (PPN + 0x80000)
  srli x7, x11, 12
  LI(x9, 0x80000)
  add x7, x7, x9
  slli x7, x7, 10
  ori x7, x7, 1
  PUT(x12, 0x100, x7)
  .word 0x62000073          // hfence.gvma x0, x0
  .word 0x22000073          // hfence.vvma x0, x0
  li x7, 0
  SA_TRY(1)
  .word 0x680343f3          // hlv.w x7, (x6)
  SA_TRAPS(0, -1, "case 2: table GPA >= 4 GiB: hlv.w")
  SA_CHECK(x7, 0x5a5a1234, "case 2: hlv.w value")
  csrw 0x280, x0
  csrw 0x680, x0
#endif
RVTEST_CODE_END

RVTEST_DATA_BEGIN
  .p2align 14
sa_g_root:
  .fill 16384, 1, 0
  .p2align 12
sa_vs_root:
  .fill 4096, 1, 0
sa_vs_t0:
  .fill 4096, 1, 0
sa_data:
  .word 0x5a5a1234
RVTEST_DATA_END
RVTEST_SIG_SETUP
