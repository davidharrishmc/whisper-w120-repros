// Reproducer: an mcontrol6 store-data trigger never matches the value stored by sspush.
// Spec: riscv-debug-spec xml/hwbp_registers.xml mcontrol6.store (norm:Sdtrig_mcontrol6_store): "When set, the
//   trigger fires on the virtual address or data of any store." riscv-isa-manual src/unpriv/cfi.adoc
//   (norm:sspush_c-sspush_instr): "The sspush and c.sspush instructions perform a store identically to the
//   existing store instructions, with the difference that the base is implicitly ssp and the width is
//   implicitly XLEN." Sdtrig.adoc tab:priority puts "store data before" with the address breakpoints.
// Whisper: ssAccessAllowed (shadow-stack.cpp) checks only the address triggers; execSspush then calls
//   writeForStore, which checks no triggers. Hart::store, used by ordinary stores, calls ldStDataTriggerHit
//   on the store value.
// Scenario: S-mode, Sv39, menvcfg.SSE=1, VA 0x40000000 is a shadow-stack page; mcontrol6 select=1 store=1 s=1,
//   tdata2 = x1; sstatus.SIE=1 (breakpoints are delegated to S).
// Expected (spec): both `sd x1` (control) and `sspush x1` take a breakpoint (cause 3) before the store; ssp is
//   unchanged. Whisper: control 3, sspush no trap.

##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'S', 'Zicfiss', 'Sdtrig']
# MARCH: rv${XLEN}i_zicsr_zifencei
# NEEDS_SIGNATURE: false
##### END_TEST_CONFIG #####

#define SIGUPD_COUNT 0
#define BOOT_TO_SMODE
#include "riscv_arch_test.h"
#include "../common/sa.h"

#define MC6 (6 << (__riscv_xlen - 4))
// mcontrol6: select=1 (data), size=0, match=0, s=1, store=1
#define TD1 (MC6 | (1 << 21) | (1 << 4) | 2)
#define SSVAL 0x0123456789abcdef

RVTEST_BEGIN
#if __riscv_xlen == 64
  // menvcfg.SSE = 1 (T-SBI)
  LI(a1, 8)
  RVTEST_TSBI_CSR_ACCESS TSBI_CSR_SET(CSR_MENVCFG)

  // Sv39: identity map the test image gigapages (RWX, A, D), gigapage 0 (MMIO, RW),
  // and VA 0x40000000 -> sa_pg_ss as a shadow-stack page (xwr=010, A, D)
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
  LA(x6, sa_pt_t1)          // root[1] -> t1
  srli x6, x6, 12
  slli x6, x6, 10
  ori x6, x6, 1
  SREG x6, 8(x8)
  LA(x6, sa_pt_t2)          // t1[0] -> t2
  srli x6, x6, 12
  slli x6, x6, 10
  ori x6, x6, 1
  LA(x9, sa_pt_t1)
  SREG x6, 0(x9)
  LA(x6, sa_pg_ss)          // t2[0] -> SS page
  srli x6, x6, 12
  slli x6, x6, 10
  ori x6, x6, 0xc5
  LA(x9, sa_pt_t2)
  SREG x6, 0(x9)
  srli x6, x8, 12
  li x7, 0x8000000000000000
  or x6, x6, x7
  csrw satp, x6
  sfence.vma

  // trigger 0 (T-SBI, M-mode CSRs): store data == SSVAL in S-mode
  LI(a1, 0)
  RVTEST_TSBI_CSR_ACCESS TSBI_CSR_WRITE(CSR_TSELECT)
  LI(a1, 0)
  RVTEST_TSBI_CSR_ACCESS TSBI_CSR_WRITE(CSR_TDATA1)
  LI(a1, SSVAL)
  RVTEST_TSBI_CSR_ACCESS TSBI_CSR_WRITE(CSR_TDATA2)
  LI(a1, TD1)
  RVTEST_TSBI_CSR_ACCESS TSBI_CSR_WRITE(CSR_TDATA1)
  RVTEST_TSBI_CSR_ACCESS TSBI_CSR_READ(CSR_TDATA1)
  mv x8, a0
  SA_CHECK(x8, TD1, "tdata1 = mcontrol6 select=1 s=1 store=1")

  // S-mode triggers with action=0 match only while sstatus.SIE=1 when breakpoints are delegated
  csrw sie, x0
  csrsi sstatus, 2

  LI(x1, SSVAL)

  // control: an ordinary store of SSVAL fires the trigger
  LA(x9, sa_scratch)
  SA_TRY(1)
  sd x1, 0(x9)
  AI_OUTCOME
  mv x8, x14

  // sspush x1 stores SSVAL to the shadow stack
  LI(x6, 0x40000808)
  csrw 0x11, x6               // ssp
  SA_TRY(1)
  .word 0xce104073            // sspush x1
  AI_OUTCOME
  mv x9, x14
  csrr x12, 0x11              // ssp after

  csrci sstatus, 2
  LI(a1, 0)
  RVTEST_TSBI_CSR_ACCESS TSBI_CSR_WRITE(CSR_TDATA1)
  SA_CHECK(x8, 3, "control: sd of the tdata2 value: xcause (3 = store-data breakpoint)")
  SA_CHECK(x9, 3, "sspush of the tdata2 value: xcause (3 = store-data breakpoint)")
  SA_CHECK(x12, 0x40000808, "sspush with a store-data breakpoint before: ssp unchanged")

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
sa_pt_t2:
  .fill 4096, 1, 0
sa_pg_ss:
  .fill 4096, 1, 0
sa_scratch:
  .dword 0
RVTEST_DATA_END
RVTEST_SIG_SETUP
