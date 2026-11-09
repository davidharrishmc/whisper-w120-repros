// Whisper: a VS-stage A-bit update whose PTE is mapped read-only at the G-stage and whose physical page
// is read-only in PMP raises an access fault instead of the guest-page fault from the G-stage.
// Spec: priv/hypervisor.adoc [norm:H_vm_gstagetrans] "When V=1, memory accesses that would normally bypass
//   address translation are subject to G-stage address translation alone. This includes memory accesses
//   made in support of VS-stage address translation, such as reads and writes of VS-level page tables."
//   [norm:H_pmp] "Machine-level physical memory protection applies to supervisor physical addresses".
//   [norm:H_vm_gpapriv] "For a memory access made to support VS-stage address translation (such as to
//   read/write a VS-level page table), permissions and the need to set A and/or D bits at the G-stage level
//   are checked as though for an implicit load or store, not for the original access type. However, any
//   exception is always reported for the original access type".
//   So the store that sets the A bit is first G-stage translated (the G-stage denies W: guest-page fault);
//   only a successful translation gives a supervisor physical address for PMP to check.
// Setup (M boot): menvcfg.ADUE = henvcfg.ADUE = 1. G-stage Sv39x4 identity-maps the image (1 GiB, DAU-XWRV)
//   and maps the alias GPA 0x140000000 -> PA 0x80000000 read-only (A U R V). vsatp = Sv39 with its root at
//   the alias GPA (so the G-stage maps the VS root read-only). VS root[1] maps VA 0x40000000 -> GPA
//   0x80000000 with A=0. A VS-mode lw from VA 0x40000000 needs a VS A-bit update (implicit store to the
//   VS root).
//   Case 1 (control): PMP lets S/U write everything -> load guest-page fault (21).
//   Case 2: PMP entry 0 makes the VS root's physical page read-only for S/U -> still 21.
//   Case 3 (control): as case 2, but vsatp points at the VS root's identity GPA (G-stage writable)
//     -> load access fault (5) from the PMP check.
// Expected: cases 1 and 2: mcause 21, mtval2 = 0 or GPA(VS PTE) >> 2, mtinst = 0x3020 (write
//   pseudoinstruction) when mtval2 != 0. Case 3: mcause 5. Whisper master: case 2 gives mcause 5.

##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'Sm', 'S', 'H', 'Svadu']
# MARCH: rv${XLEN}i_zicsr_zifencei
# NEEDS_SIGNATURE: false
##### END_TEST_CONFIG #####

#define SIGUPD_COUNT 0
#define BOOT_TO_MMODE
#include "riscv_arch_test.h"
#include "../common/sa.h"

#define VS_LOAD_CASE(_MSG)                                 \
  RVTEST_TSBI_GOTO_VSMODE                                  ;\
  LI(x6, 0x40000000)                                       ;\
  SA_TRY(1)                                                ;\
  lw x7, 0(x6)                                             ;\
  RVTEST_TSBI_GOTO_MMODE                                   ;\
  SA_TRAPS(1, 21, _MSG ": load guest-page fault (G-stage denies the implicit A-bit store)") ;\
  AI_LOG(x7, TRAPLOG_TVAL)                                 ;\
  SA_CHECK2(x7, 0, 0x40000000, _MSG ": mtval = 0 or the VA")   ;\
  AI_LOG(x7, TRAPLOG_TVAL2)                                ;\
  mv x9, x7                                                ;\
  beqz x9, 84f                                             ;\
  LA(x10, sa_vs_root)                                      ;\
  LI(x11, 0xc0000000 + 8)                                  ;\
  add x10, x10, x11                                        ;\
  srli x10, x10, 2                                         ;\
  sub x11, x9, x10                                         ;\
  SA_CHECK(x11, 0, _MSG ": mtval2 = 0 or GPA(VS PTE) >> 2 (difference)") ;\
  AI_LOG(x7, TRAPLOG_TINST)                                ;\
  SA_CHECK(x7, 0x3020, _MSG ": mtinst = write pseudoinstruction") ;\
84:

RVTEST_BEGIN
  LA(x6, rvtest_entry_point)
  srli x6, x6, 30
  SA_CHECK(x6, 2, "test image lies in 1 GiB region 2")
  // keep address-translation faults in M-mode
  LI(x7, 0xb0a0a0)
  csrc medeleg, x7
  csrw 0x602, x0            // hedeleg = 0
  // Svadu at both stages
  LI(x7, 0x2000000000000000)
  csrs 0x30a, x7            // menvcfg.ADUE
  csrs 0x60a, x7            // henvcfg.ADUE
  csrr x8, 0x60a
  and x8, x8, x7
  SA_CHECK(x8, 0x2000000000000000, "henvcfg.ADUE = 1")
  csrw 0x680, x0
  csrw 0x280, x0
  // G-stage root
  LA(x8, sa_g_root)
  LI(x7, (0x80000000 >> 2) | 0xdf)      // [2]: GPA 0x80000000 -> PA 0x80000000 DAU-XWRV
  sd x7, 16(x8)
  LI(x7, (0xc0000000 >> 2) | 0xdf)      // [3]: GPA 0xc0000000 -> PA 0xc0000000
  sd x7, 24(x8)
  LI(x7, (0x80000000 >> 2) | 0x53)      // [5]: GPA 0x140000000 -> PA 0x80000000, A U R V (read-only)
  sd x7, 40(x8)
  // VS root (Sv39)
  LA(x9, sa_vs_root)
  LI(x7, (0x80000000 >> 2) | 0xcf)      // [2]: VA 0x80000000 -> GPA 0x80000000 DA-XWRV
  sd x7, 16(x9)
  LI(x7, (0xc0000000 >> 2) | 0xcf)      // [3]
  sd x7, 24(x9)
  LI(x7, (0x80000000 >> 2) | 0x0f)      // [1]: VA 0x40000000 -> GPA 0x80000000, XWRV, A=D=0
  sd x7, 8(x9)
  // hgatp = Sv39x4, vsatp = Sv39 with root GPA = PA + 0xc0000000
  srli x7, x8, 12
  LI(x10, 0x8000000000000000)
  or x7, x7, x10
  csrw 0x680, x7
  LI(x7, 0xc0000000)
  add x7, x9, x7
  srli x7, x7, 12
  or x7, x7, x10
  csrw 0x280, x7
  .word 0x62000073          // hfence.gvma x0, x0
  .word 0x22000073          // hfence.vvma x0, x0

  // Case 1: PMP lets S/U do everything (as set up by the framework)
  VS_LOAD_CASE("case 1 (PMP RWX)")

  // Case 2: PMP entry 0 = the VS root page, read-only; entry 1 = everything RWX
  LA(x9, sa_vs_root)
  srli x7, x9, 2
  ori x7, x7, 0x1ff         // NAPOT 4 KiB
  csrw pmpaddr0, x7
  LI(x7, -1)
  csrw pmpaddr1, x7
  LI(x7, 0x1f19)            // entry 1 NAPOT RWX, entry 0 NAPOT R
  csrw pmpcfg0, x7
  .word 0x12000073          // sfence.vma
  .word 0x62000073          // hfence.gvma x0, x0
  .word 0x22000073          // hfence.vvma x0, x0
  csrr x7, pmpcfg0
  andi x7, x7, 0xff
  SA_CHECK(x7, 0x19, "pmp0cfg = NAPOT R")
  VS_LOAD_CASE("case 2 (PMP: VS root page read-only)")

  // Case 3: vsatp root at the identity GPA (G-stage writable), PMP still read-only -> PMP access fault
  LA(x9, sa_vs_root)
  srli x7, x9, 12
  LI(x10, 0x8000000000000000)
  or x7, x7, x10
  csrw 0x280, x7
  .word 0x62000073          // hfence.gvma x0, x0
  .word 0x22000073          // hfence.vvma x0, x0
  RVTEST_TSBI_GOTO_VSMODE
  LI(x6, 0x40000000)
  SA_TRY(1)
  lw x7, 0(x6)
  RVTEST_TSBI_GOTO_MMODE
  SA_TRAPS(1, 5, "case 3 (G-stage writable, PMP read-only): load access fault from the PMP check")
RVTEST_CODE_END

RVTEST_DATA_BEGIN
  .p2align 14
sa_g_root:
  .fill 16384, 1, 0
  .p2align 12
sa_vs_root:
  .fill 4096, 1, 0
RVTEST_DATA_END
RVTEST_SIG_SETUP
