// verify-v8 repro for u22-smmisc-T-B4 (Whisper master a5554a17): MNRET to VU-mode (MNPP = U, MNPV = 1) with
// mstatus.MDT = 1, sstatus.SDT = 1 and vsstatus.SDT = 1 clears vsstatus.SDT but leaves MDT = 1 and sstatus.SDT = 1, so
// the next trap from VU is an unexpected trap (RNMI handler). Case C is a control (vsstatus.SDT = 0: Whisper skips the
// vsstatus block and clears MDT/SDT). Case D applies the same question to MRET to VU (execMret has the same code shape).
// Reduced from tests/u22-smmisc/u22-smmisc-rnmi-mnret.S (S-042, VU row).
// Spec (riscv-isa-manual 3142f66f) priv/machine.adoc:
//   517 (norm:mstatus_mdt_clr_mnret) "When the smdbltrp extension is implemented, the mnret instruction ... sets the
//     mdt bit to 0 if the new privilege mode is not M."
//   518 (norm:sstatus_sdt_clr_mnret) "If the ssdbltrp extension is also implemented, and the new privilege mode is U,
//     VS, or VU, then sstatus.sdt is also set to 0."  519 "Additionally, if it is VU, then vsstatus.sdt is also set to 0."
//   511-515: the same three rules for MRET (and SRET in M); 469-470: a trap into M with MDT = 1 is unexpected.
// Observation: the VU ecall's trap-log mstatus (SDT) and whether the RNMI handler (installed at 0x8F000000, the w-u22
// nmi_vec; stock Whisper has nmi_vec = 0 and stops in the critical-error state instead) was entered.
##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'Sm', 'S', 'U', 'H', 'Smrnmi', 'Smdbltrp', 'Ssdbltrp']
# MARCH: rv${XLEN}i_zicsr_zifencei
# NEEDS_SIGNATURE: false
##### END_TEST_CONFIG #####
#define SIGUPD_COUNT 0
#define BOOT_TO_MMODE
#include "riscv_arch_test.h"
#include "../common/sa.h"
#define RNMI_INT_VEC 0x8F000000
#define RNMI_EXC_VEC 0x8F000100
#define MNRET_W .word 0x70200073
#define R REGWIDTH
#define R_HIT     0
#define R_EHIT    1
#define R_RESUME  2
#define R_MNEPC   3
#define R_MNCAUSE 4
#define R_MNSTAT  5
#define R_MSTAT   6
#define R_MSTATH  7
#define R_MEPC    8
#define R_MCAUSE  9
#define R_MTVAL   10
#define R_MTVAL2  11
#define FLD(_R, _SRC, _SH, _MASK)  srli _R, _SRC, _SH ; andi _R, _R, _MASK
#if __riscv_xlen == 64
  #define SET_MDT  LI(x7, (1 << 42)) ; csrs mstatus, x7
  #define CLR_MDT  LI(x7, (1 << 42)) ; csrc mstatus, x7
  #define RD_MDT(_R)  csrr _R, mstatus ; FLD(_R, _R, 42, 1)
  #define REC_MDT(_R) LA(x8, rnmi_rec) ; LREG _R, R_MSTAT*R(x8) ; FLD(_R, _R, 42, 1)
  #define DTE_ON   LI(x7, (1 << 59)) ; csrs menvcfg, x7
  #define HDTE_ON  LI(x7, (1 << 59)) ; csrs henvcfg, x7
  #define SET_MPV  LI(x7, (1 << 39)) ; csrs mstatus, x7
#else
  #define SET_MDT  li x7, 0x400 ; csrs mstatush, x7
  #define CLR_MDT  li x7, 0x400 ; csrc mstatush, x7
  #define RD_MDT(_R)  csrr _R, mstatush ; FLD(_R, _R, 10, 1)
  #define REC_MDT(_R) LA(x8, rnmi_rec) ; LREG _R, R_MSTATH*R(x8) ; FLD(_R, _R, 10, 1)
  #define DTE_ON   LI(x7, (1 << 27)) ; csrs menvcfgh, x7
  #define HDTE_ON  LI(x7, (1 << 27)) ; csrs henvcfgh, x7
  #define SET_MPV  li x7, 0x80 ; csrs mstatush, x7
#endif
#define RD_NMIE(_R) csrr _R, 0x744 ; FLD(_R, _R, 3, 1)
#define REC(_R, _W) LA(x8, rnmi_rec) ; LREG _R, (_W)*R(x8)
#define REC_CLR LA(x8, rnmi_rec) ; SREG x0, R_HIT*R(x8) ; SREG x0, R_EHIT*R(x8) ; SREG x0, R_MSTAT*R(x8) ; SREG x0, R_MSTATH*R(x8)
#define RESUME_AT(_L) LA(x7, _L) ; LA(x8, rnmi_rec) ; SREG x7, R_RESUME*R(x8)
// leave the NMIE = 0 state: MNRET (MNPP = M, MNPV = 0) to the next instruction
#define MNRET_HERE(_L) LA(x7, _L) ; csrw 0x741, x7 ; LI(x7, 0x1800) ; csrs 0x744, x7 ; li x7, 0x80 ; csrc 0x744, x7 ; MNRET_W ; _L:
#define SENTINELS LA(x7, sent_pc) ; csrw mepc, x7 ; li x7, 5 ; csrw mcause, x7 ; li x7, 0x66 ; csrw mtval, x7
#define B_SDT (1 << 24)
// mnstatus = MNPP | MNPV | NMIE
#define SET_MNST(_MNPP, _MNPV) LI(x7, ((_MNPP) << 11) | ((_MNPV) << 7) | 8) ; csrw 0x744, x7
// after a VU case: checks; if the RNMI handler was entered, leave NMIE = 0 with MNRET
#define VU_CHECKS(_MSG, _BACK) \
  REC(x6, R_HIT) ; SA_SOFT(x6, 0, _MSG ": ecall from VU is not an unexpected trap (RNMI handler not entered)") ;\
  REC_MDT(x6) ; SA_SOFT(x6, 0, _MSG ": [if the RNMI handler was entered] mstatus.MDT recorded there") ;\
  REC(x6, R_MSTAT) ; FLD(x6, x6, 24, 1) ; SA_SOFT(x6, 0, _MSG ": [if the RNMI handler was entered] sstatus.SDT recorded there") ;\
  REC(x6, R_HIT) ; beqz x6, 1f ; MNRET_HERE(_BACK) ; j 2f ;\
1: SA_SOFT(x14, 8, _MSG ": ecall from VU taken normally (cause 8)") ;\
  AI_LOG(x6, TRAPLOG_STATUS) ; FLD(x6, x6, 24, 1) ; SA_SOFT(x6, 0, _MSG ": sstatus.SDT = 0 (trap-log mstatus at the VU ecall)") ;\
2: csrr x6, vsstatus ; FLD(x6, x6, 24, 1) ; SA_SOFT(x6, 0, _MSG ": vsstatus.SDT = 0") ;\
  CLR_MDT ; LI(x7, B_SDT) ; csrc mstatus, x7 ; csrc vsstatus, x7

RVTEST_BEGIN
  csrw medeleg, x0
  csrw mideleg, x0
  csrw mie, x0
  LI(x8, RNMI_INT_VEC)
  LA(x9, rnmi_int_h)
  jal x1, put_tramp
  LI(x8, RNMI_EXC_VEC)
  LA(x9, rnmi_exc_h)
  jal x1, put_tramp
  fence.i
  CLR_MDT
  RD_NMIE(x6)
  SA_SOFT(x6, 1, "setup: mnstatus.NMIE = 1 (framework sets it at boot)")
  csrw hgatp, x0
  csrw vsatp, x0
  DTE_ON
  HDTE_ON
  // ================= A: MNRET to VU, MDT = 1, sstatus.SDT = 1, vsstatus.SDT = 1
  REC_CLR
  LA(x7, b4_a)
  csrw 0x741, x7
  SET_MNST(0, 1)
  SET_MDT
  LI(x7, B_SDT)
  csrs mstatus, x7
  csrs vsstatus, x7
  RESUME_AT(b4_a_out)
  SA_TRY(1)
  MNRET_W
b4_a:
  li a0, 0x73
  ecall
  RVTEST_TSBI_GOTO_MMODE
b4_a_out:
  AI_OUTCOME
  VU_CHECKS("T-B4 A MNRET to VU (vsstatus.SDT = 1)", b4_a_back)
  // ================= C (control): MNRET to VU with vsstatus.SDT = 0
  REC_CLR
  LA(x7, b4_c)
  csrw 0x741, x7
  SET_MNST(0, 1)
  SET_MDT
  LI(x7, B_SDT)
  csrs mstatus, x7
  RESUME_AT(b4_c_out)
  SA_TRY(1)
  MNRET_W
b4_c:
  li a0, 0x73
  ecall
  RVTEST_TSBI_GOTO_MMODE
b4_c_out:
  AI_OUTCOME
  VU_CHECKS("T-B4 C control: MNRET to VU (vsstatus.SDT = 0)", b4_c_back)
  // ================= D: MRET to VU, MDT = 1, sstatus.SDT = 1, vsstatus.SDT = 1, MPIE = 1
  REC_CLR
  LI(x7, 0x1800)
  csrc mstatus, x7                    // MPP = U
  SET_MPV
  li x7, 0x80
  csrs mstatus, x7                    // MPIE = 1
  LA(x7, b4_d)
  csrw mepc, x7
  SET_MDT
  LI(x7, B_SDT)
  csrs mstatus, x7
  csrs vsstatus, x7
  RESUME_AT(b4_d_out)
  SA_TRY(1)
  mret
b4_d:
  li a0, 0x73
  ecall
  RVTEST_TSBI_GOTO_MMODE
b4_d_out:
  AI_OUTCOME
  REC(x6, R_HIT)
  bnez x6, 3f
  AI_LOG(x6, TRAPLOG_STATUS)
  FLD(x6, x6, 7, 1)
  SA_SOFT(x6, 1, "T-B4 D MRET to VU: MIE was set from MPIE = 1 (trap-log MPIE at the VU ecall)")
3:
  VU_CHECKS("T-B4 D MRET to VU (vsstatus.SDT = 1)", b4_d_back)
  SA_SOFT_END
  j test_end

// ---- trampoline: copy 4 code words to x8, handler address (x9) at x8 + 16
put_tramp:
  LA(x7, tramp_code)
  lw x6, 0(x7)
  sw x6, 0(x8)
  lw x6, 4(x7)
  sw x6, 4(x8)
  lw x6, 8(x7)
  sw x6, 8(x8)
  lw x6, 12(x7)
  sw x6, 12(x8)
  SREG x9, 16(x8)
  ret
  .option push
  .option norvc
  .p2align 2
tramp_code:
  csrrw x31, 0x740, x31               // mnscratch <-> x31
  auipc x31, 0
  LREG x31, 12(x31)                   // the handler address at trampoline + 16
  jr x31
  .option pop

  .p2align 2
#define RNMI_HANDLER(_HITW) \
  LA(x31, rnmi_rec) ;\
  csrr x30, 0x741 ; SREG x30, R_MNEPC*R(x31) ;\
  csrr x30, 0x742 ; SREG x30, R_MNCAUSE*R(x31) ;\
  csrr x30, 0x744 ; SREG x30, R_MNSTAT*R(x31) ;\
  csrr x30, mstatus ; SREG x30, R_MSTAT*R(x31) ;\
  csrr x30, mepc ; SREG x30, R_MEPC*R(x31) ;\
  csrr x30, mcause ; SREG x30, R_MCAUSE*R(x31) ;\
  csrr x30, mtval ; SREG x30, R_MTVAL*R(x31) ;\
  LREG x30, (_HITW)*R(x31) ; addi x30, x30, 1 ; SREG x30, (_HITW)*R(x31)
rnmi_int_h:
  RNMI_HANDLER(R_HIT)
  j rnmi_tail
rnmi_exc_h:
  RNMI_HANDLER(R_EHIT)
rnmi_tail:
#if __riscv_xlen == 32
  csrr x30, mstatush
  SREG x30, R_MSTATH*R(x31)
#endif
  LREG x30, R_RESUME*R(x31)
  jr x30
sent_pc:
  nop
test_end:
RVTEST_CODE_END

RVTEST_DATA_BEGIN
  .p2align 3
rnmi_rec: .fill 16, REGWIDTH, 0
RVTEST_DATA_END
RVTEST_SIG_SETUP
