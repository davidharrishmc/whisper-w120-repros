// Setting menvcfg.DTE makes sstatus.SDT writable again; that change is field modulation, not a write of sstatus,
// so it must not clear sstatus.SIE.
//   csrs.adoc norm:Zicsr_field_modulation: when a write to one CSR changes the legal values of a field of another,
//     that field "immediately gets an UNSPECIFIED value from among its new legal values".
//   csrs.adoc norm:Zicsr_field_modulation_no_side_effects "A change to the value of a CSR for this reason is not a
//     write to the affected CSR and thus does not trigger any side effects specified for that CSR."
//   supervisor.adoc norm:sstatus_sdt_sstatus_sie_overwrite "When the SDT bit is set to 1 by an explicit CSR write,
//     the SIE (Supervisor Interrupt Enable) bit is cleared to 0."
//   machine.adoc norm:menvcfg_dte_op / norm:menvcfg_dte_sdt_rdonly0: with menvcfg.DTE = 0, sstatus.SDT is
//     read-only zero.
// Sequence (M-mode): DTE=1; sstatus.SDT=1 (an explicit write: SIE cleared); DTE=0 (SDT reads 0); sstatus.SIE=1
// (allowed, SDT reads 0); DTE=1. Expected: SIE still 1 (SDT may read 0 or 1).

##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'Sm', 'S', 'Ssdbltrp']
# MARCH: rv${XLEN}i_zicsr_zifencei
# NEEDS_SIGNATURE: false
##### END_TEST_CONFIG #####

#define SIGUPD_COUNT 0
#define BOOT_TO_MMODE
#include "riscv_arch_test.h"
#include "../common/sa.h"

#if __riscv_xlen == 64
  #define DTE_SET(_R)   csrs menvcfg, _R
  #define DTE_CLR(_R)   csrc menvcfg, _R
  #define DTE_BIT       (1 << 59)
  #define ENVCFG        menvcfg
#else
  #define DTE_SET(_R)   csrs menvcfgh, _R
  #define DTE_CLR(_R)   csrc menvcfgh, _R
  #define DTE_BIT       (1 << 27)
  #define ENVCFG        menvcfgh
#endif

RVTEST_BEGIN
  csrci mstatus, 8             // MIE = 0
  csrw mie, x0
  csrr x12, ENVCFG             // restored at the end
  LI(x8, DTE_BIT)
  LI(x9, 0x1000000)            // sstatus.SDT (bit 24)
  DTE_SET(x8)
  csrs sstatus, x9             // explicit write: SDT = 1, SIE cleared
  csrr x7, sstatus
  and x7, x7, x9
  beqz x7, 1f                  // SDT not writable: nothing to check
  DTE_CLR(x8)                  // SDT now read-only zero
  csrr x7, sstatus
  and x7, x7, x9
  SA_CHECK(x7, 0, "sstatus.SDT with menvcfg.DTE = 0")
  csrsi sstatus, 2             // SIE = 1 (allowed: SDT reads 0)
  csrr x7, sstatus
  andi x7, x7, 2
  beqz x7, 1f                  // SIE not set: nothing further to check
  DTE_SET(x8)                  // DTE = 1: SDT writable again
  csrr x7, sstatus
  andi x7, x7, 2
  SA_CHECK(x7, 2, "sstatus.SIE after menvcfg.DTE 0 -> 1 (not a write of sstatus: SIE stays 1)")
1:
  csrc sstatus, x9
  csrci sstatus, 2
  csrw ENVCFG, x12
RVTEST_CODE_END

RVTEST_DATA_BEGIN
RVTEST_DATA_END
RVTEST_SIG_SETUP
