// Whisper reproducer: a misaligned AMO / LR / SC in VS-mode whose second page is unmapped at the G-stage.
// Setup: HS boot, vsatp = Bare, hgatp = Sv39x4 identity-mapping GPA 0x80000000-0xffffffff; GPA 0x100000000
//   is unmapped. In VS-mode, amoadd.w, lr.w and sc.w at 0xfffffffe straddle into the unmapped page.
// Allowed outcomes: a misaligned or access fault (a misaligned AMO/LR/SC may raise either), or a guest-page
//   fault for the second page. For the guest-page fault, stval is 0 or the address of the faulting portion
//   (0x100000000); htval is 0 or the GPA of the address in stval, shifted right by 2 (vsatp = Bare, so
//   GPA = stval); and htinst is 0 or the transformed instruction whose Addr. Offset field (bits 19:15) is
//   stval - 0xfffffffe.
// Spec: priv/hypervisor.adoc norm:mtval2_htval_virtaddr ("a nonzero guest physical address written to
//   mtval2/htval shall correspond to the exact virtual address written to mtval/stval"), norm:H_straddle,
//   machine.adoc norm:mtval_vaddr_wr_misaligned_addr ("the virtual address of the portion of the access
//   that caused the fault").
// Result: the test fails with "Bad Value" = bitmask of failed checks (expected 0). For instruction i
//   (0 amoadd.w, 1 lr.w, 2 sc.w), bit 4i+0: not exactly one trap or an unexpected cause;
//   bit 4i+1: guest-page fault with stval not 0 or 0x100000000; bit 4i+2: htval not 0 or stval >> 2;
//   bit 4i+3: htinst not 0 or the transformed instruction with Addr. Offset stval - 0xfffffffe.

##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'S', 'H', 'Zaamo', 'Zalrsc']
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

// Run one instruction word in VS-mode with x6 = 0xfffffffe and record the failed checks (bits 4*_I+0..3).
// _TINST0 = the transformed instruction with Addr. Offset 0.
#define VS_STRADDLE(_I, _ENC, _TINST0, _GPF, _MIS, _ACC)    \
  LI(x6, 0xfffffffe)                                       ;\
  li x9, 1                                                 ;\
  SA_TRY(1)                                                ;\
  LA(x14, 81f)                                             ;\
  csrw sepc, x14                                           ;\
  LI(x14, 0x100)                                           ;\
  csrs sstatus, x14                                        ;\
  LI(x14, 0x80)                                            ;\
  csrs 0x600, x14                                          ;\
  sret                                                     ;\
81: .word _ENC                                             ;\
  RVTEST_TSBI_GOTO_SMODE                                   ;\
  AI_OUTCOME                                               ;\
  li x8, 1                                                 ;\
  bne x13, x8, 84f                                         ;\
  li x8, _MIS                                              ;\
  beq x14, x8, 89f                                         ;\
  li x8, _ACC                                              ;\
  beq x14, x8, 89f                                         ;\
  li x8, _GPF                                              ;\
  bne x14, x8, 84f                                         ;\
  AI_LOG(x7, TRAPLOG_TVAL)                                 ;\
  AI_LOG(x11, TRAPLOG_TVAL2)                               ;\
  AI_LOG(x12, TRAPLOG_TINST)                               ;\
  /* stval: 0 or the faulting portion */                   ;\
  beqz x7, 82f                                             ;\
  LI(x8, 0x100000000)                                      ;\
  beq x7, x8, 82f                                          ;\
  SETFAIL(4*(_I)+1)                                        ;\
  /* htval: 0 or GPA(stval) >> 2 (vsatp = Bare: GPA = stval) */ ;\
82: beqz x11, 83f                                          ;\
  srli x8, x7, 2                                           ;\
  beq x11, x8, 83f                                         ;\
  SETFAIL(4*(_I)+2)                                        ;\
  /* htinst: 0 or the transformed instruction, Addr. Offset = stval - 0xfffffffe */ ;\
83: beqz x12, 89f                                          ;\
  beqz x7, 89f                                             ;\
  LI(x8, 0xfffffffe)                                       ;\
  sub x8, x7, x8                                           ;\
  slli x8, x8, 15                                          ;\
  LI(x10, _TINST0)                                         ;\
  or x8, x8, x10                                           ;\
  beq x12, x8, 89f                                         ;\
  SETFAIL(4*(_I)+3)                                        ;\
  j 89f                                                    ;\
84: SETFAIL(4*(_I))                                        ;\
89:

RVTEST_BEGIN
  csrw 0x680, x0            // hgatp = Bare while building tables
  csrw 0x280, x0            // vsatp = Bare: GPA = GVA
  // G-stage Sv39x4: identity map the two 1 GiB regions holding the test image (perms DA-UXWRV)
  LA(x6, rvtest_entry_point)
  srli x6, x6, 30
  slli x7, x6, 28
  li x9, 0xdf
  or x7, x7, x9
  LA(x8, sa_g_root)
  slli x10, x6, 3
  add x10, x8, x10
  sd x7, 0(x10)
  addi x6, x6, 1
  slli x7, x6, 28
  or x7, x7, x9
  slli x10, x6, 3
  add x10, x8, x10
  sd x7, 0(x10)
  srli x6, x8, 12
  li x7, 0x8000000000000000  // MODE = Sv39x4
  or x6, x6, x7
  csrw 0x680, x6
  .word 0x62000073          // hfence.gvma x0, x0
  .word 0x22000073          // hfence.vvma x0, x0
  LA(x6, rvtest_entry_point)
  srli x6, x6, 30
  SA_CHECK(x6, 2, "test image lies in 1 GiB region 2 (so GPA 0xc0000000-0xffffffff is mapped, 0x100000000 is not)")

  VS_STRADDLE(0, 0x009323af, 0x009023af, 23, 6, 7)    // amoadd.w x7, x9, (x6)
  VS_STRADDLE(1, 0x100323af, 0x100023af, 21, 4, 5)    // lr.w x7, (x6)
  VS_STRADDLE(2, 0x189323af, 0x189023af, 23, 6, 7)    // sc.w x7, x9, (x6)

  LA(x4, sa_failmask)
  LREG x6, 0(x4)
  SA_CHECK(x6, 0, "bitmask of failed checks (bit 4i+0 trap/cause, +1 stval, +2 htval, +3 htinst; i = 0 amoadd.w, 1 lr.w, 2 sc.w)")
RVTEST_CODE_END

RVTEST_DATA_BEGIN
  .p2align 3
sa_failmask:
  .dword 0
  .p2align 14
sa_g_root:
  .fill 16384, 1, 0
RVTEST_DATA_END
RVTEST_SIG_SETUP
