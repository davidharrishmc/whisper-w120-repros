// Reproducer: a VS-mode sspopchk through a G-stage leaf that is readable but not writable completes without a
// fault when an earlier ordinary load has put the G-stage translation in the TLB.
// Spec: riscv-isa-manual src/priv/cfi.adoc (norm:active_g_stage_pte) "When G-stage page tables are active, the
//   shadow stack instructions that access memory require the G-stage page table to have read-write permission
//   for the accessed memory; else a store/AMO guest-page-fault exception is raised." The requirement holds
//   for sspopchk, which only reads, and does not depend on TLB contents.
// Whisper: virtual_memory/VirtMem.cpp stage2PageTableWalk checks R and W when ssMode_ is set, but the G-stage
//   TLB-hit path in stage2Translate checks only the permission of the access type (read for sspopchk).
// Expected (spec): control (G-stage RW leaf) no trap; case 1 (no earlier access) and case 2 (after an ld from
//   the same page) both raise a store/AMO guest-page fault (cause 23). Whisper: case 1 23, case 2 no trap.

##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'S', 'H', 'Zicfiss']
# MARCH: rv${XLEN}i_zicsr_zifencei
# NEEDS_SIGNATURE: false
##### END_TEST_CONFIG #####

#define SIGUPD_COUNT 0
#define BOOT_TO_SMODE
#include "riscv_arch_test.h"
#include "../common/sa.h"

// enter VS-mode at label _L (from HS)
#define TO_VS(_L)               \
  LA(x14, _L)                  ;\
  csrw sepc, x14               ;\
  LI(x14, 256)                 ;\
  csrs sstatus, x14            ;\
  LI(x14, HSTATUS_SPV)         ;\
  csrs CSR_HSTATUS, x14        ;\
  sret

// G-stage leaf for GPA 0x140000000 + _I*4K -> _PG with perms _P (U=1 required)
#define G_LEAF(_I, _PG, _P)     \
  LA(x6, _PG)                  ;\
  srli x6, x6, 12              ;\
  slli x6, x6, 10              ;\
  LI(x7, _P)                   ;\
  or x6, x6, x7                ;\
  LA(x8, sa_g_t2)              ;\
  SREG x6, ((_I)*8)(x8)

// VS-stage leaf for VA 0x40000000 + _I*4K -> GPA 0x140000000 + _I*4K, SS page (xwr=010, A, D)
#define VS_LEAF(_I)             \
  LI(x6, ((0x140000 + (_I)) << 10) | 0xc5) ;\
  LA(x8, sa_vs_t2)             ;\
  SREG x6, ((_I)*8)(x8)

RVTEST_BEGIN
  .option norvc
#if __riscv_xlen == 64
  LI(a1, MENVCFG_SSE)
  RVTEST_TSBI_CSR_ACCESS TSBI_CSR_SET(CSR_MENVCFG)
  LI(x5, HENVCFG_SSE)
  csrs CSR_HENVCFG, x5
  csrr x7, CSR_HENVCFG
  and x7, x7, x5
  beqz x7, sa_skip            // henvcfg.SSE not writable

  // G-stage (Sv39x4): identity gigapages for the image (0xdf), root[5] -> t1 -> t2
  LA(x6, rvtest_entry_point)
  srli x6, x6, 30
  slli x7, x6, 28
  ori x7, x7, 0xdf
  LA(x8, sa_g_root)
  slli x9, x6, 3
  add x9, x8, x9
  SREG x7, 0(x9)
  addi x6, x6, 1
  slli x7, x6, 28
  ori x7, x7, 0xdf
  slli x9, x6, 3
  add x9, x8, x9
  SREG x7, 0(x9)
  LA(x6, sa_g_t1)
  srli x6, x6, 12
  slli x6, x6, 10
  ori x6, x6, 1
  SREG x6, 40(x8)             // root[5]: GPA 0x140000000
  LA(x6, sa_g_t2)
  srli x6, x6, 12
  slli x6, x6, 10
  ori x6, x6, 1
  LA(x9, sa_g_t1)
  SREG x6, 0(x9)
  G_LEAF(0, sa_pg0, 0xd3)     // V R U A D, W=0: read-only at G-stage
  G_LEAF(1, sa_pg1, 0xd3)
  G_LEAF(2, sa_pg2, 0xd7)     // control: V R W U A D
  // VS-stage (Sv39): identity gigapages (0xcf), root[1] -> t1 -> t2
  LA(x6, rvtest_entry_point)
  srli x6, x6, 30
  slli x7, x6, 28
  ori x7, x7, 0xcf
  LA(x8, sa_vs_root)
  slli x9, x6, 3
  add x9, x8, x9
  SREG x7, 0(x9)
  addi x6, x6, 1
  slli x7, x6, 28
  ori x7, x7, 0xcf
  slli x9, x6, 3
  add x9, x8, x9
  SREG x7, 0(x9)
  LA(x6, sa_vs_t1)
  srli x6, x6, 12
  slli x6, x6, 10
  ori x6, x6, 1
  SREG x6, 8(x8)              // root[1]: VA 0x40000000
  LA(x6, sa_vs_t2)
  srli x6, x6, 12
  slli x6, x6, 10
  ori x6, x6, 1
  LA(x9, sa_vs_t1)
  SREG x6, 0(x9)
  VS_LEAF(0)
  VS_LEAF(1)
  VS_LEAF(2)
  LA(x6, sa_g_root)
  srli x6, x6, 12
  li x7, 0x8000000000000000
  or x6, x6, x7
  csrw 0x680, x6              // hgatp
  .word 0x62000073            // hfence.gvma
  LA(x6, sa_vs_root)
  srli x6, x6, 12
  li x7, 0x8000000000000000
  or x6, x6, x7
  csrw 0x280, x6              // vsatp
  .word 0x22000073            // hfence.vvma
  csrr x7, 0x680
  beqz x7, sa_skip

  li x1, 0                    // equals the shadow-stack word (0), so no software check

  // control: sspopchk through a G-stage RW leaf completes
  LI(x6, 0x40002800)
  csrw 0x11, x6
  SA_TRY(1)
  TO_VS(sa_vs0)
sa_vs0:
  .word 0xcdc0c073            // sspopchk x1
  RVTEST_TSBI_GOTO_SMODE
  SA_TRAPS(0, -1, "control: VS sspopchk, G-stage RW")

  // case 1: sspopchk through a G-stage read-only leaf, no earlier access to the page
  LI(x6, 0x40001800)
  csrw 0x11, x6
  SA_TRY(1)
  TO_VS(sa_vs1)
sa_vs1:
  .word 0xcdc0c073            // sspopchk x1
  RVTEST_TSBI_GOTO_SMODE
  SA_TRAPS(1, 23, "case 1: VS sspopchk, G-stage R only (cold)")

  // case 2: an ordinary load from the page first (legal: loads may read SS pages), then sspopchk
  LI(x6, 0x40000800)
  csrw 0x11, x6
  SA_TRY(1)
  TO_VS(sa_vs2)
sa_vs2:
  LI(x9, 0x40000800)
  ld x10, 0(x9)               // loads G-stage-readable data: no fault
  .word 0xcdc0c073            // sspopchk x1
  RVTEST_TSBI_GOTO_SMODE
  SA_TRAPS(1, 23, "case 2: VS sspopchk, G-stage R only, after ld from the same page")

sa_skip:
  csrw 0x680, x0
  csrw 0x280, x0
  .word 0x62000073
  LI(a1, MENVCFG_SSE)
  RVTEST_TSBI_CSR_ACCESS TSBI_CSR_CLEAR(CSR_MENVCFG)
#endif
RVTEST_CODE_END

RVTEST_DATA_BEGIN
  .p2align 14
sa_g_root:
  .fill 16384, 1, 0
  .p2align 12
sa_g_t1:
  .fill 4096, 1, 0
sa_g_t2:
  .fill 4096, 1, 0
sa_vs_root:
  .fill 4096, 1, 0
sa_vs_t1:
  .fill 4096, 1, 0
sa_vs_t2:
  .fill 4096, 1, 0
sa_pg0:
  .fill 4096, 1, 0
sa_pg1:
  .fill 4096, 1, 0
sa_pg2:
  .fill 4096, 1, 0
RVTEST_DATA_END
RVTEST_SIG_SETUP
