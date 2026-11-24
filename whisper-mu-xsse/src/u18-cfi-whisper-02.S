// verify v5 repro (adopted from the u18 walk probe w18-nos-xsse.S). Needs a non-ACT M+U config with Zicfiss.
// u18-cfi Whisper walk probe: Zicfiss on an M+U hart (no S-mode) with menvcfg.SSE writable.
// Spec: priv/cfi.adoc:168-169 norm:Zicfiss_smode_xsse "When S-mode is not implemented, then xSSE is 0."
//   unpriv/cfi.adoc:353-359 (u18-cfi-0028): with xSSE=0, sspush/sspopchk/ssrdp/c.* revert to Zimop/Zcmop: no memory
//   access, ssp unchanged, ssrdp writes 0. (isa#2646 ruling.)
// Whisper a5554a17: Hart.hpp:705-710 isShadowStackEnabled(User, V=0) returns menvcfg.SSE when S is absent
//   ("return isRvs() ? (menv and senv) : menv;"), and Hart.hpp:676-680 sets uSsEnabled_ = menvcfg.SSE on M+U.
// Not an ACT configuration (whisper-rv64-mu claims Zicfilp only). The earlier p2-cfi-01 nos probe passed
// vacuously because its scratch whisper.json made menvcfg.SSE read-only zero (mask 0xf5).
// Expected: U-mode sspush x5 and ssrdp are MOPs: ssp unchanged, buffer unchanged, ssrdp writes 0, no trap.

##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'Sm', 'U']
# MARCH: rv${XLEN}i_zicsr_zifencei
# NEEDS_SIGNATURE: false
##### END_TEST_CONFIG #####

#define SIGUPD_COUNT 0
#define BOOT_TO_MMODE
#include "riscv_arch_test.h"
#include "../common/sa.h"
#define SA_INFO(_R, _MSG)                                   \
    .option push                                           ;\
    .option norvc                                          ;\
    LA(x5, sa_soft_args)                                   ;\
    SREG x0, 0(x5)                                         ;\
    SREG _R, REGWIDTH(x5)                                  ;\
    LA(x4, 97f)                                            ;\
    SREG x4, 2*REGWIDTH(x5)                                ;\
    jal  x5, sa_soft_report                                ;\
    LA(x4, sa_soft_count)                                  ;\
    LREG x5, 0(x4)                                         ;\
    addi x5, x5, -1                                        ;\
    SREG x5, 0(x4)                                         ;\
    .pushsection .data                                     ;\
97: .string "INFO " _MSG                                   ;\
    .popsection                                            ;\
    .option pop

#define SSE_B 0x8
#define SSPUSH_X5 .word 0xCE504073
#define SSRDP_X9  .word 0xCDC044F3
#define SETPP(_PP) LI(x9, 0x1800); csrc mstatus, x9; LI(x9, (_PP) << 11); csrs mstatus, x9
#define RUN_U(_N, ...) SETPP(0); LA(x9, 71f); csrw mepc, x9; AI_ALLOW(_N); \
  mret; 71: __VA_ARGS__; RVTEST_TSBI_GOTO_MMODE; AI_OUTCOME

RVTEST_BEGIN
  .option norvc
  LI(x6, SSE_B)
  csrs menvcfg, x6
  csrr x7, menvcfg
  andi x7, x7, SSE_B
  bnez x7, 2f
  SA_INFO(x7, "menvcfg.SSE is read-only 0 here (legal); test vacuous")
  j nos_end
2:
  LA(x6, ssbuf_top)
  csrw ssp, x6
  li x5, 0x55
  li x8, 1
  RUN_U(0, SSPUSH_X5; li x9, 1; SSRDP_X9; mv x8, x9)
  SA_SOFT(x14, -1, "U sspush/ssrdp without S: xcause (-1 none)")
  SA_SOFT(x8, 0, "U ssrdp without S writes 0")
  csrr x7, ssp
  LA(x6, ssbuf_top)
  sub x7, x7, x6
  SA_SOFT(x7, 0, "U sspush without S: ssp unchanged")
  LA(x6, ssbuf_top)
  LREG x7, -REGWIDTH(x6)
  SA_SOFT(x7, 0, "U sspush without S: memory below ssp unchanged")
nos_end:
  SA_SOFT_END
RVTEST_CODE_END

RVTEST_DATA_BEGIN
  .p2align 4
ssbuf: .fill 64, 1, 0
ssbuf_top: .fill 64, 1, 0
RVTEST_DATA_END
RVTEST_SIG_SETUP
