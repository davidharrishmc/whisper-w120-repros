// Whisper: on RV32, VS-mode can read and write the hypervisor CSRs hidelegh (0x613) and hviph (0x655).
// Spec: priv/hypervisor.adoc [norm:H_virtinst_vu_vs32_high_allowedhs_tvm0]: a virtual-instruction exception
//   is raised "in VS-mode or VU-mode, if XLEN=32, attempts to access an implemented high-half hypervisor CSR
//   or high-half VS CSR when the same access (read/write) to the CSR's low-half partner would be allowed in
//   HS-mode, assuming mstatus.TVM=0". hidelegh and hviph are the high halves of hideleg and hvip (Smaia/Ssaia).
// For each CSR the test first reads it in HS-mode and skips it if that traps (not implemented). Then, in
//   VS-mode, it reads it (csrrs rd, csr, x0) and does a write-form access (csrrs rd, csr, rs1 with rs1 != x0,
//   rs1 = 0, so the value cannot change). Each of the four VS-mode accesses must raise a virtual-instruction
//   exception (mcause 22). Whisper master: no trap.

##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'Sm', 'S', 'H']
# MARCH: rv${XLEN}i_zicsr_zifencei
# NEEDS_SIGNATURE: false
##### END_TEST_CONFIG #####

#define SIGUPD_COUNT 0
#define BOOT_TO_MMODE
#include "riscv_arch_test.h"
#include "../common/sa.h"

// VS_ACCESS(csr, "name"): skip if the HS-mode read traps, else check the VS-mode read and write forms.
#define VS_ACCESS(_CSR, _NAME)                                                   \
  RVTEST_TSBI_GOTO_SMODE                                                        ;\
  AI_ALLOW(1)                                                                   ;\
  csrr x7, _CSR                                                                 ;\
  AI_OUTCOME                                                                    ;\
  mv x21, x13                                                                   ;\
  RVTEST_TSBI_GOTO_MMODE                                                        ;\
  bnez x21, 89f                                                                 ;\
  li x20, 0                                                                     ;\
  RVTEST_TSBI_GOTO_VSMODE                                                       ;\
  SA_TRY(1)                                                                     ;\
  csrrs x7, _CSR, x0                                                            ;\
  AI_OUTCOME                                                                    ;\
  mv x16, x13                                                                   ;\
  mv x17, x14                                                                   ;\
  SA_TRY(1)                                                                     ;\
  csrrs x7, _CSR, x20                                                           ;\
  AI_OUTCOME                                                                    ;\
  mv x18, x13                                                                   ;\
  mv x19, x14                                                                   ;\
  RVTEST_TSBI_GOTO_MMODE                                                        ;\
  SA_SOFT(x16, 1, "VS-mode read of " _NAME ": number of traps")                 ;\
  SA_SOFT(x17, 22, "VS-mode read of " _NAME ": mcause (-1 = none)")             ;\
  SA_SOFT(x18, 1, "VS-mode write of " _NAME ": number of traps")                ;\
  SA_SOFT(x19, 22, "VS-mode write of " _NAME ": mcause (-1 = none)")            ;\
89:

RVTEST_BEGIN
#if __riscv_xlen == 32
  VS_ACCESS(0x613, "hidelegh")
  VS_ACCESS(0x655, "hviph")
#endif
  SA_SOFT_END
RVTEST_CODE_END

RVTEST_DATA_BEGIN
RVTEST_DATA_END
RVTEST_SIG_SETUP
