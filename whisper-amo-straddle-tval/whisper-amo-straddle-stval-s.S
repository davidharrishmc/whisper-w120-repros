// Whisper reproducer (single-stage companion of whisper-amo-straddle-htval.S): a misaligned AMO / LR / SC in
// S-mode whose second page is invalid in satp.
// Setup: S boot, satp = Sv39 identity-mapping the 1 GiB regions 2 and 3 (0x80000000-0xffffffff); VA
//   0x100000000 is invalid. In S-mode, amoadd.w, lr.w and sc.w at 0xfffffffe straddle into it.
// Allowed outcomes: a misaligned or access fault, or a page fault with stval = 0 or the address of the
//   faulting portion, 0x100000000.
// Spec: machine.adoc norm:mtval_vaddr_wr_misaligned_addr ("If mtval is written with a nonzero value when a
//   misaligned load or store causes an access-fault or page-fault exception, then mtval will contain the
//   virtual address of the portion of the access that caused the fault"); stval likewise (supervisor.adoc).
// Result: the test fails with "Bad Value" = bitmask of failed checks (expected 0). For instruction i
//   (0 amoadd.w, 1 lr.w, 2 sc.w), bit 4i+0: not exactly one trap or an unexpected cause; bit 4i+1: page fault
//   with stval not 0 or 0x100000000.

##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'S', 'Zaamo', 'Zalrsc']
# MARCH: rv${XLEN}i_zicsr_zifencei
# NEEDS_SIGNATURE: false
##### END_TEST_CONFIG #####

#define SIGUPD_COUNT 0
#define BOOT_TO_SMODE
#include "riscv_arch_test.h"
#include "../common/sa.h"

// Set bit _B of the failure mask (clobbers x4, x5, x10).
#define SETFAIL(_B)                                         \
  LA(x4, sa_failmask)                                      ;\
  LREG x5, 0(x4)                                           ;\
  LI(x10, (1 << (_B)))                                     ;\
  or x5, x5, x10                                           ;\
  SREG x5, 0(x4)

#define S_STRADDLE(_I, _ENC, _PF, _MIS, _ACC)               \
  LI(x6, 0xfffffffe)                                       ;\
  li x9, 1                                                 ;\
  SA_TRY(1)                                                ;\
  .word _ENC                                               ;\
  AI_OUTCOME                                               ;\
  li x8, 1                                                 ;\
  bne x13, x8, 84f                                         ;\
  li x8, _MIS                                              ;\
  beq x14, x8, 89f                                         ;\
  li x8, _ACC                                              ;\
  beq x14, x8, 89f                                         ;\
  li x8, _PF                                               ;\
  bne x14, x8, 84f                                         ;\
  AI_LOG(x7, TRAPLOG_TVAL)                                 ;\
  beqz x7, 89f                                             ;\
  LI(x8, 0x100000000)                                      ;\
  beq x7, x8, 89f                                          ;\
  SETFAIL(4*(_I)+1)                                        ;\
  j 89f                                                    ;\
84: SETFAIL(4*(_I))                                        ;\
89:

RVTEST_BEGIN
  csrw satp, x0
  LA(x6, rvtest_entry_point)
  srli x6, x6, 30
  SA_CHECK(x6, 2, "test image lies in 1 GiB region 2")
  LA(x8, sa_s_root)
  LI(x7, 0xcf)                          // [0]: VA 0 -> PA 0 (console/IO for the failure reporter)
  sd x7, 0(x8)
  LI(x7, (0x80000000 >> 2) | 0xcf)      // [2]: VA 0x80000000 -> PA 0x80000000 DA-XWRV
  sd x7, 16(x8)
  LI(x7, (0xc0000000 >> 2) | 0xcf)      // [3]
  sd x7, 24(x8)
  srli x7, x8, 12
  LI(x10, 0x8000000000000000)           // MODE = Sv39
  or x7, x7, x10
  csrw satp, x7
  .word 0x12000073          // sfence.vma
  S_STRADDLE(0, 0x009323af, 15, 6, 7)   // amoadd.w x7, x9, (x6)
  S_STRADDLE(1, 0x100323af, 13, 4, 5)   // lr.w x7, (x6)
  S_STRADDLE(2, 0x189323af, 15, 6, 7)   // sc.w x7, x9, (x6)
  csrw satp, x0
  .word 0x12000073
  LA(x4, sa_failmask)
  LREG x6, 0(x4)
  SA_CHECK(x6, 0, "bitmask of failed checks (bit 4i+0 trap/cause, +1 stval; i = 0 amoadd.w, 1 lr.w, 2 sc.w)")
RVTEST_CODE_END

RVTEST_DATA_BEGIN
  .p2align 3
sa_failmask:
  .dword 0
  .p2align 12
sa_s_root:
  .fill 4096, 1, 0
RVTEST_DATA_END
RVTEST_SIG_SETUP
