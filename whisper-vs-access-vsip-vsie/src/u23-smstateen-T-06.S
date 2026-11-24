// verify v9, u23-smstateen-T-06 (Whisper, RV32): VS-mode csrr of the high-half VS CSRs vsiph (0x254) and vsieh (0x214)
// must raise a virtual-instruction exception (22) whenever HS-mode could read them, independently of mstateen0.CSRIND.
// Spec (riscv-isa-manual 3142f66f) hypervisor.adoc:2380-2383 (norm:H_virtinst_vu_vs32_high_allowedhs_tvm0): a
//   virtual-instruction exception is raised "in VS-mode or VU-mode, if XLEN=32, attempts to access an implemented
//   high-half hypervisor CSR or high-half VS CSR when the same access (read/write) to the CSR's low-half partner would
//   be allowed in HS-mode, assuming mstatus.TVM=0"; hypervisor.adoc:2339-2346 (high-half rule).
//   riscv-aia VSLevel.adoc / CSRs.adoc:434-437: vsiph/vsieh are AIA state controlled by the AIA bit (59) of mstateen0;
//   the CSRIND bit (60) controls only siselect/sireg*/vsiselect/vsireg* (smstateen.adoc:279-283).
// Set-up: mstateen0/mstateen0h = all ones, hstateen0/hstateen0h = all ones, medeleg = hedeleg = 0.
//   A1/A2: VS csrr vsiph / vsieh                                         -> 22
//   B1/B2: same with mstateen0h.CSRIND (bit 28 = bit 60) cleared          -> 22  (CSRIND does not control vsiph/vsieh)
//   B3/B4: HS csrr vsiph / vsieh with mstateen0h.CSRIND = 0 (control)    -> no trap (-1)
// RV64: no checks (vsiph/vsieh do not exist). Skipped if vsiph does not exist in M-mode (no Ssaia).

##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'Sm', 'S', 'U', 'H', 'Smstateen', 'Zicsr']
# MARCH: rv${XLEN}i_zicsr_zifencei
# NEEDS_SIGNATURE: false
##### END_TEST_CONFIG #####

#define SIGUPD_COUNT 0
#define BOOT_TO_MMODE
#include "riscv_arch_test.h"
#include "../common/sa.h"

#define I_VSIPH csrr x9, 0x254
#define I_VSIEH csrr x9, 0x214
#define VS_TRY(_INSN, _EXP, _MSG)                                          \
  SA_TRY(1) ; RVTEST_TSBI_GOTO_VSMODE ; _INSN ; RVTEST_TSBI_GOTO_MMODE ; AI_OUTCOME ;\
  SA_SOFT(x14, _EXP, _MSG)
#define HS_TRY(_INSN, _EXP, _MSG)                                          \
  SA_TRY(1) ; RVTEST_TSBI_GOTO_SMODE ; _INSN ; RVTEST_TSBI_GOTO_MMODE ; AI_OUTCOME ;\
  SA_SOFT(x14, _EXP, _MSG)

RVTEST_BEGIN
#if __riscv_xlen == 32
  csrw medeleg, x0
  csrw 0x602, x0                      // hedeleg
  li x7, -1
  csrw 0x30C, x7                      // mstateen0
  csrw 0x31C, x7                      // mstateen0h
  csrw 0x60C, x7                      // hstateen0
  csrw 0x61C, x7                      // hstateen0h
  SA_TRY(1) ; csrr x9, 0x254 ; AI_OUTCOME
  li x7, -1
  bne x14, x7, skip

  VS_TRY(I_VSIPH, 22, "A1 VS csrr vsiph, mstateen0 = ~0: 22")
  VS_TRY(I_VSIEH, 22, "A2 VS csrr vsieh, mstateen0 = ~0: 22")
  LI(x7, 0x10000000)
  csrc 0x31C, x7                      // mstateen0h.CSRIND = 0
  csrr x9, 0x31C
  srli x9, x9, 27
  andi x9, x9, 3
  SA_CHECK(x9, 1, "mstateen0h read-back: AIA (bit 27) = 1, CSRIND (bit 28) = 0")
  VS_TRY(I_VSIPH, 22, "B1 VS csrr vsiph, mstateen0.CSRIND = 0, AIA = 1: 22")
  VS_TRY(I_VSIEH, 22, "B2 VS csrr vsieh, mstateen0.CSRIND = 0, AIA = 1: 22")
  HS_TRY(I_VSIPH, -1, "B3 HS csrr vsiph, mstateen0.CSRIND = 0 (control): no trap")
  HS_TRY(I_VSIEH, -1, "B4 HS csrr vsieh, mstateen0.CSRIND = 0 (control): no trap")
skip:
#endif
  SA_SOFT_END
RVTEST_CODE_END

RVTEST_DATA_BEGIN
  .word 0
RVTEST_DATA_END
RVTEST_SIG_SETUP
