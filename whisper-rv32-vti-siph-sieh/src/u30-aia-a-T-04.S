// verify v7a, u30-aia-a-T-04 (Whisper, RV32): with hvictl.VTI = 1, VS-mode access to siph / sieh must raise a virtual
// instruction exception.
// Spec (riscv-aia 9507866): VSLevel.adoc:385-387 "When bit VTI (Virtual Trap Interrupt control) = 1, attempts from
//   VS-mode to explicitly access CSRs sip and sie (or, for RV32 only, siph and sieh) cause a virtual instruction
//   exception."
// Setup: mstateen0/hstateen0 all ones (AIA = 1), hvictl = VTI | IID 9 | IPRIO 0 (no interrupt), medeleg = 0.
// RV32: VS csrr siph, csrr sieh, csrr sip, csrr sie -> 0x1316.  RV64 (control): VS csrr sip -> 0x1316; siph/sieh do
// not exist for XLEN > 32 (CSRs.adoc:435): 0x1302.

##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'Sm', 'S', 'U', 'H', 'Zicsr', 'Smaia', 'Ssaia']
# MARCH: rv${XLEN}i_zicsr_zifencei
# NEEDS_SIGNATURE: false
##### END_TEST_CONFIG #####

#define SIGUPD_COUNT 0
#define BOOT_TO_MMODE
#include "riscv_arch_test.h"
#include "../common/sa.h"

// ------------------------------------------------------------------ u30-aia-a common macros
#define XL __riscv_xlen
#if XL == 64
  #define SET_MPV  LI(x6, 1 << 39); csrs mstatus, x6
  #define CLR_MPV  LI(x6, 1 << 39); csrc mstatus, x6
  #define MPV_BIT  (1 << 39)
#else
  #define SET_MPV  li x6, 0x80; csrs 0x310, x6
  #define CLR_MPV  li x6, 0x80; csrc 0x310, x6
#endif
// mret to _LBL in nominal mode _MPP (0 U, 1 S) with V=_V; MIE=MPIE=0. a0 = 1 so a later ecall is T-SBI GOTO_MMODE.
#define GOTO(_LBL, _MPP, _V)                                \
    LA(x6, _LBL)                                           ;\
    csrw mepc, x6                                          ;\
    LI(x6, 0x1800)                                         ;\
    csrc mstatus, x6                                       ;\
    LI(x6, ((_MPP) << 11))                                 ;\
    csrs mstatus, x6                                       ;\
    CLR_MPV                                                ;\
    .if _V                                                 ;\
    SET_MPV                                                ;\
    .endif                                                 ;\
    li x6, 0x88                                            ;\
    csrc mstatus, x6                                       ;\
    li a0, 1                                               ;\
    mret
// set medeleg and the framework's shadow of medeleg[2] (configs with an invisible M-mode trap handler, e.g. Whisper
// rv64 time emulation, clear medeleg[2] in lower modes and restore it from the shadow on T-SBI GOTO_MMODE)
#define SETDELEG(_V) LI(x7, _V); csrw medeleg, x7; andi x7, x7, 4; LA(x6, Mmedeleg_illegal_sv); SREG x7, 0(x6)
// back to M-mode from any mode (T-SBI GOTO_MMODE; ecall causes 8/9/10 must not be delegated, or are forwarded)
#define BACK_M   li a0, 1; ecall; auipc x0, 0; CLR_MPV
// close a window and store the outcome in res[_S] (see tp.py). Works in every mode (identity-mapped memory).
#define REC(_S)                                             \
    AI_OUTCOME                                             ;\
    li   x15, 0                                            ;\
    beqz x13, 81f                                          ;\
    LA(x6, res)                                            ;\
    LI(x5, (_S)*8*REGWIDTH)                                ;\
    add x6, x6, x5                                         ;\
    AI_LOG(x15, TRAPLOG_TVAL)                              ;\
    SREG x15, 1*REGWIDTH(x6)                               ;\
    LREG x15, TRAPLOG_STATUS*REGWIDTH(x4)                  ;\
    SREG x15, 3*REGWIDTH(x6)                               ;\
    LREG x15, TRAPLOG_STATUS2*REGWIDTH(x4)                 ;\
    SREG x15, 4*REGWIDTH(x6)                               ;\
    LREG x15, TRAPLOG_TVAL2*REGWIDTH(x4)                   ;\
    SREG x15, 5*REGWIDTH(x6)                               ;\
    LREG x15, TRAPLOG_TINST*REGWIDTH(x4)                   ;\
    SREG x15, 6*REGWIDTH(x6)                               ;\
    LREG x15, TRAPLOG_CAUSE*REGWIDTH(x4)                   ;\
    SREG x15, 7*REGWIDTH(x6)                               ;\
    AI_LOG(x15, TRAPLOG_VECT)                              ;\
    andi x15, x15, 3                                       ;\
    slli x15, x15, 8                                       ;\
    slli x13, x13, 12                                      ;\
    or   x15, x15, x13                                     ;\
81: andi x14, x14, 0xff                                    ;\
    or   x15, x15, x14                                     ;\
    LA(x4, res)                                            ;\
    LI(x5, (_S)*8*REGWIDTH)                                ;\
    add x4, x4, x5                                         ;\
    SREG x15, 0(x4)                                        ;\
    SREG x7, 2*REGWIDTH(x4)
// load res[_S] word _W into _R (M-mode)
#define RES(_R, _S, _W) LA(x4, res); LI(x5, (_S)*8*REGWIDTH + (_W)*REGWIDTH); add x4, x4, x5; LREG _R, 0(x4)
// soft check with two legal values
#define SOFT2(_R, _E1, _E2, _MSG) LI(x4, _E1); beq x4, _R, 93f; SA_SOFT(_R, _E2, _MSG); 93:
#define SOFT3(_R, _E1, _E2, _E3, _MSG) LI(x4, _E1); beq x4, _R, 94f; LI(x4, _E2); beq x4, _R, 94f; SA_SOFT(_R, _E3, _MSG); 94:
// informational print that is not counted as a failure
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

// ---- u30: catch handlers (own mtvec/stvec/vstvec). Each handler records into its area of u30rec
// (M at 0, S/HS at 8, VS at 16 REGWIDTH words): [0] xcause [1] xepc [2] xtopi read in the handler [3] count
// [4] mstatus/sstatus. The M handler then resumes at the address in u30rec[24] (in M-mode); the S and VS handlers
// ecall to M (cause 9/10 into the M handler), which resumes there. Handlers use x16-x19 only.
#define CATCH_ON(_RES)                                      \
    LA(x16, u30rec)                                        ;\
    li x17, -1                                             ;\
    SREG x17, 0(x16)                                       ;\
    SREG x17, 8*REGWIDTH(x16)                              ;\
    SREG x17, 16*REGWIDTH(x16)                             ;\
    SREG x0, 3*REGWIDTH(x16)                               ;\
    SREG x0, 11*REGWIDTH(x16)                              ;\
    SREG x0, 19*REGWIDTH(x16)                              ;\
    LA(x17, _RES)                                          ;\
    SREG x17, 24*REGWIDTH(x16)                             ;\
    csrr x17, mtvec                                        ;\
    SREG x17, 25*REGWIDTH(x16)                             ;\
    csrr x17, stvec                                        ;\
    SREG x17, 26*REGWIDTH(x16)                             ;\
    LA(x17, u30_mh)                                        ;\
    csrw mtvec, x17                                        ;\
    LA(x17, u30_sh)                                        ;\
    csrw stvec, x17                                        ;\
    CATCH_ON_VS
#define CATCH_OFF                                           \
    CLR_MDT                                                ;\
    LI(x17, 1 << 24)                                       ;\
    csrc mstatus, x17                                      ;\
    CLR_VSDT                                               ;\
    LA(x16, u30rec)                                        ;\
    LREG x17, 25*REGWIDTH(x16)                             ;\
    csrw mtvec, x17                                        ;\
    LREG x17, 26*REGWIDTH(x16)                             ;\
    csrw stvec, x17                                        ;\
    CATCH_OFF_VS                                           ;\
    CLR_MPV
// Smdbltrp/Ssdbltrp: a trap sets mstatus.MDT / sstatus.SDT / vsstatus.SDT; the handlers do not return with xret, so clear
// them (a later trap with the bit set would be a double trap)
#if __riscv_xlen == 64
  #define CLR_MDT LI(x18, 1 << 42); csrc mstatus, x18
#else
  #define CLR_MDT LI(x18, 1 << 10); csrc 0x310, x18
#endif
#ifdef H_SUPPORTED
  #define CLR_VSDT LI(x18, 1 << 24); csrc 0x200, x18
#else
  #define CLR_VSDT
#endif
#ifdef H_SUPPORTED
  #define CATCH_ON_VS  csrr x17, 0x205; SREG x17, 27*REGWIDTH(x16); LA(x17, u30_vsh); csrw 0x205, x17
  #define CATCH_OFF_VS LREG x17, 27*REGWIDTH(x16); csrw 0x205, x17
#else
  #define CATCH_ON_VS
  #define CATCH_OFF_VS
#endif
// rec word _W of area _A (0 M, 8 S, 16 VS) into _R
#define REC_LD(_R, _A, _W) LA(x4, u30rec); LREG _R, ((_A)+(_W))*REGWIDTH(x4)
#define U30_HANDLERS                                        \
    j u30_hend                                             ;\
    .p2align 2                                             ;\
u30_mh:                                                    ;\
    LA(x16, u30rec)                                        ;\
    csrr x17, mcause                                       ;\
    SREG x17, 0(x16)                                       ;\
    csrr x17, mepc                                         ;\
    SREG x17, 1*REGWIDTH(x16)                              ;\
    csrr x17, 0xFB0                                        ;\
    SREG x17, 2*REGWIDTH(x16)                              ;\
    LREG x17, 3*REGWIDTH(x16)                              ;\
    addi x17, x17, 1                                       ;\
    SREG x17, 3*REGWIDTH(x16)                              ;\
    csrr x17, mstatus                                      ;\
    SREG x17, 4*REGWIDTH(x16)                              ;\
    CLR_MDT                                                ;\
    LREG x17, 24*REGWIDTH(x16)                             ;\
    jr x17                                                 ;\
    .p2align 2                                             ;\
u30_sh:                                                    ;\
    LA(x16, u30rec)                                        ;\
    csrr x17, scause                                       ;\
    SREG x17, 8*REGWIDTH(x16)                              ;\
    csrr x17, sepc                                         ;\
    SREG x17, 9*REGWIDTH(x16)                              ;\
    csrr x17, 0xDB0                                        ;\
    SREG x17, 10*REGWIDTH(x16)                             ;\
    LREG x17, 11*REGWIDTH(x16)                             ;\
    addi x17, x17, 1                                       ;\
    SREG x17, 11*REGWIDTH(x16)                             ;\
    csrr x17, sstatus                                      ;\
    SREG x17, 12*REGWIDTH(x16)                             ;\
    ecall                                                  ;\
    .p2align 2                                             ;\
u30_vsh:                                                   ;\
    LA(x16, u30rec)                                        ;\
    csrr x17, scause                                       ;\
    SREG x17, 16*REGWIDTH(x16)                             ;\
    csrr x17, sepc                                         ;\
    SREG x17, 17*REGWIDTH(x16)                             ;\
    csrr x17, 0xDB0                                        ;\
    SREG x17, 18*REGWIDTH(x16)                             ;\
    LREG x17, 19*REGWIDTH(x16)                             ;\
    addi x17, x17, 1                                       ;\
    SREG x17, 19*REGWIDTH(x16)                             ;\
    csrr x17, sstatus                                      ;\
    SREG x17, 20*REGWIDTH(x16)                             ;\
    ecall                                                  ;\
u30_hend:
// mret to _LBL in mode (_MPP, _V) keeping the interrupt-enable bits the caller set (MPIE := _MPIE)
#define GOTOI(_LBL, _MPP, _V, _MPIE)                        \
    LA(x6, _LBL)                                           ;\
    csrw mepc, x6                                          ;\
    LI(x6, 0x1880)                                         ;\
    csrc mstatus, x6                                       ;\
    LI(x6, ((_MPP) << 11) | ((_MPIE) << 7))                ;\
    csrs mstatus, x6                                       ;\
    CLR_MPV                                                ;\
    .if _V                                                 ;\
    SET_MPV                                                ;\
    .endif                                                 ;\
    mret

RVTEST_BEGIN
  U30_HANDLERS
  // gate: M-mode csrr miselect must not trap on a config with Smaia (else CONFIG, rest skipped)
  li x7, 0
  AI_ALLOW(1)
  .word 0x350023f3
  REC(0)
  RES(x6, 0, 0)
  SA_SOFT(x6, 0xff, "CONFIG: M-mode csrr miselect (0x350) must not trap (Smaia claimed); rest skipped")
  RES(x6, 0, 0)
  li x7, 0xff
  bne x6, x7, u30_skip
  SETDELEG(0)
  csrw mideleg, x0
  csrw mie, x0
#ifdef SMSTATEEN_SUPPORTED
  li x7, -1
  csrw 0x30c, x7
#if __riscv_xlen == 32
  csrw 0x31c, x7
#endif
#endif
#ifdef SSSTATEEN_SUPPORTED
  li x7, -1
  csrw 0x60c, x7
#if __riscv_xlen == 32
  csrw 0x61c, x7
#endif
#endif
  LI(x7, (1 << 30) | (9 << 16))
  csrw 0x609, x7            // hvictl: VTI = 1, IID = 9, IPRIO = 0
  GOTO(t04_vs, 1, 1)
t04_vs:
  li x7, 0
  AI_ALLOW(1)
  .word 0x154023f3          // csrr x7, siph
  REC(1)
  li x7, 0
  AI_ALLOW(1)
  .word 0x114023f3          // csrr x7, sieh
  REC(2)
  li x7, 0
  AI_ALLOW(1)
  .word 0x144023f3          // csrr x7, sip
  REC(3)
  li x7, 0
  AI_ALLOW(1)
  .word 0x104023f3          // csrr x7, sie
  REC(4)
  BACK_M
  csrw 0x609, x0
#if __riscv_xlen == 32
  RES(x6, 1, 0)
  SA_SOFT(x6, 0x1316, "T-04: RV32 VS csrr siph with hvictl.VTI=1: virtual instruction (VSLevel.adoc:385-387)")
  RES(x6, 2, 0)
  SA_SOFT(x6, 0x1316, "T-04: RV32 VS csrr sieh with hvictl.VTI=1: virtual instruction (VSLevel.adoc:385-387)")
#else
  RES(x6, 1, 0)
  SA_SOFT(x6, 0x1302, "T-04 control: RV64 VS csrr siph: illegal (no siph for XLEN > 32)")
  RES(x6, 2, 0)
  SA_SOFT(x6, 0x1302, "T-04 control: RV64 VS csrr sieh: illegal (no sieh for XLEN > 32)")
#endif
  RES(x6, 3, 0)
  SA_SOFT(x6, 0x1316, "T-04 control: VS csrr sip with hvictl.VTI=1: virtual instruction")
  RES(x6, 4, 0)
  SA_SOFT(x6, 0x1316, "T-04 control: VS csrr sie with hvictl.VTI=1: virtual instruction")
u30_skip:
  SA_SOFT_END
RVTEST_CODE_END

RVTEST_DATA_BEGIN
  .p2align 4
res: .fill 2176, 1, 0
u30rec: .fill 32*8, 1, 0
.p2align 3
u30flags: .dword 0
.p2align 3
u30save: .fill 8*8, 1, 0
RVTEST_DATA_END
RVTEST_SIG_SETUP
