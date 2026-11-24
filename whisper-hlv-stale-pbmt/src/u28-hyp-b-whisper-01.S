// verify v5 repro (adopted from the u28 walk probe u28w-hlv-stale-pbmt.S; C0/C1 also accept a load-address-misaligned trap).
// u28-hyp-b Whisper walk probe (RV64): HLV/HSV with hgatp = Bare must not take the memory type of
// the HS-mode code page.
// Spec (riscv-isa-manual 3142f66f) priv/svpbmt.adoc:123-137: "if hgatp.MODE is not equal to zero,
//   non-zero G-stage PTE PBMT bits override the attributes in the PMA to produce an intermediate set of
//   attributes. Otherwise, the PMAs serve as the intermediate attributes. ... if vsatp.MODE is not equal
//   to zero, non-zero VS-stage PTE PBMT bits override the intermediate attributes ... For accesses that
//   are not subject to the first stage of address translation, e.g. VS-stage page-table accesses, the
//   intermediate attributes apply instead."  The satp (HS-level) PBMT of the page the HLV is fetched
//   from plays no part.
// Whisper a5554a17: VirtMem::stage2Translate (virtual_memory/VirtMem.cpp:474-489) returns for
//   hgatp=Bare without setting pbmt_, so pbmt_ keeps the value the HS fetch translation left
//   (single-stage walk / TLB hit). lastEffectivePbmt (VirtMem.hpp:513-525) then returns it for the
//   HLV data access, and the VS A/D-update callbacks (Hart.cpp:396-399, 463-484) use lastPbmt() and
//   refuse NC/IO.
// Cases (HS-mode, satp Sv39 identity gigapage over the image, menvcfg.PBMTE=1, hgatp = Bare):
//   C0/C1: vsatp = Bare, misaligned HLV.W (offset 2 in a dword) with code-page PBMT 0 / IO.
//   C2/C3/C4: vsatp = Sv39, VS leaf A=0 (Svadu, henvcfg.ADUE=1), HLV.D, code-page PBMT 0 / NC / IO;
//     expect the load to succeed and the VS leaf A bit to be set.

##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'Sm', 'S', 'H', 'Svpbmt', 'Svadu']
# MARCH: rv${XLEN}i_zicsr_zifencei
# NEEDS_SIGNATURE: false
##### END_TEST_CONFIG #####

#define SIGUPD_COUNT 0
#define BOOT_TO_MMODE
#include "riscv_arch_test.h"
#include "../common/sa.h"

#define HLV_W_X9_X8      .word 0x680444f3  // hlv.w x9, (x8)
#define HLV_D_X9_X8      .word 0x6c0444f3  // hlv.d x9, (x8)
#define HFENCE_GVMA_00   .word 0x62000073
#define HFENCE_VVMA_00   .word 0x22000073
#define SFENCE_VMA_00    .word 0x12000073

// Set satp root[2] (identity gigapage 0x80000000, DA-XWRV, S-level) with PBMT _PB, sfence.
#define SET_CODE_PBMT(_PB)                                 \
  LA(x15, sa_sroot)                                        ;\
  LI(x7, ((0x80000000 >> 2) | 0xcf) | ((_PB) << 61))      ;\
  sd x7, 16(x15)                                           ;\
  SFENCE_VMA_00

#define HS_HLV(_INST, _MSG)                                \
  AI_ALLOW(1)                                              ;\
  li x9, 0                                                 ;\
  RVTEST_TSBI_GOTO_SMODE                                   ;\
  _INST                                                    ;\
  RVTEST_TSBI_GOTO_MMODE                                   ;\
  AI_OUTCOME                                               ;\
  SA_SOFT(x14, -1, _MSG ": no trap (xcause, -1 = none)")


// C0/C1: a misaligned HLV.W may complete or raise load-address-misaligned (4); the value is checked when it completes.
#define HS_HLV_MIS(_INST, _MSG, _VAL)                      \
  AI_ALLOW(1)                                              ;\
  li x9, 0                                                 ;\
  RVTEST_TSBI_GOTO_SMODE                                   ;\
  _INST                                                    ;\
  RVTEST_TSBI_GOTO_MMODE                                   ;\
  AI_OUTCOME                                               ;\
  li x7, 4                                                 ;\
  beq x14, x7, 88f                                         ;\
  SA_SOFT(x14, -1, _MSG ": no trap or misaligned (xcause, -1 = none)") ;\
  SA_SOFT(x9, _VAL, _MSG ": value")                        ;\
88:

RVTEST_BEGIN
  LA(x7, rvtest_entry_point)
  srli x7, x7, 30
  SA_CHECK(x7, 2, "test image lies in 1 GiB region 2")
  csrw medeleg, x0
  csrw 0x602, x0                      // hedeleg
  LI(x7, 0x6000000000000000)          // menvcfg.PBMTE | ADUE
  csrs 0x30a, x7
  LI(x7, 0x2000000000000000)          // henvcfg.ADUE
  csrs 0x60a, x7
  csrr x8, 0x30a
  srli x8, x8, 61
  SA_CHECK(x8, 3, "menvcfg.PBMTE and ADUE set")
  csrw 0x680, x0                      // hgatp = Bare
  csrw 0x280, x0                      // vsatp = Bare
  LI(x7, 0x100)
  csrs 0x600, x7                      // hstatus.SPVP = 1
  // satp = Sv39 root sa_sroot
  LA(x15, sa_sroot)
  srli x7, x15, 12
  LI(x9, 0x8000000000000000)
  or x7, x7, x9
  csrw satp, x7
  HFENCE_GVMA_00
  HFENCE_VVMA_00

  // ---- C0/C1: misaligned HLV.W, vsatp = Bare, hgatp = Bare
  LA(x8, sa_data)
  addi x8, x8, 2
  SET_CODE_PBMT(0)
  HS_HLV_MIS(HLV_W_X9_X8, "C0 code PBMT=0, misaligned hlv.w", 0x33445566)
  SET_CODE_PBMT(2)
  HS_HLV_MIS(HLV_W_X9_X8, "C1 code PBMT=IO, misaligned hlv.w", 0x33445566)

  // ---- C2-C4: vsatp = Sv39, VS leaf A=0, hgatp = Bare
  LA(x6, sa_vsroot)
  srli x7, x6, 12
  LI(x9, 0x8000000000000000)
  or x7, x7, x9
  csrw 0x280, x7                      // vsatp
  LA(x8, sa_data)
  LI(x7, 0x40000000)
  sub x8, x8, x7                      // VA = PA - 1 GiB (VS root[1] -> GPA 0x80000000)

#define AD_CASE(_PB, _MSG)                                 \
  LA(x6, sa_vsroot)                                        ;\
  LI(x7, (0x80000000 >> 2) | 0x0f)                         ;\
  sd x7, 8(x6)                        /* XWRV, A=D=0 */    ;\
  HFENCE_VVMA_00                                           ;\
  SET_CODE_PBMT(_PB)                                       ;\
  HS_HLV(HLV_D_X9_X8, _MSG ": hlv.d needing a VS A-bit update") ;\
  SA_SOFT(x9, 0x1122334455667788, _MSG ": value")          ;\
  LA(x6, sa_vsroot)                                        ;\
  ld x7, 8(x6)                                             ;\
  srli x7, x7, 6                                           ;\
  andi x7, x7, 1                                           ;\
  SA_SOFT(x7, 1, _MSG ": VS leaf A bit set")

  AD_CASE(0, "C2 code PBMT=0")
  AD_CASE(1, "C3 code PBMT=NC")
  AD_CASE(2, "C4 code PBMT=IO")

  csrw satp, x0
  csrw 0x280, x0
  SFENCE_VMA_00
  HFENCE_VVMA_00
  SA_SOFT_END
RVTEST_CODE_END

RVTEST_DATA_BEGIN
  .p2align 12
sa_sroot:
  .fill 512, 8, 0
sa_vsroot:
  .fill 512, 8, 0
sa_data:
  .dword 0x1122334455667788
  .dword 0
RVTEST_DATA_END
RVTEST_SIG_SETUP
