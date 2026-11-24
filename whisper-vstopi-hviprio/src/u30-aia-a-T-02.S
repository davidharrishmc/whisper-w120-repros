// verify v7a, u30-aia-a-T-02 (Whisper): vstopi ignores the priority numbers in hviprio1.
// Spec (riscv-aia 9507866): VSLevel.adoc:460-463 vstopi candidate "if hvictl.VTI = 0: the highest-priority
//   pending-and-enabled major interrupt indicated by vsip and vsie other than a supervisor external interrupt (code 9),
//   using the priority numbers assigned by hviprio1 and hviprio2"; :236-243 hviprio1 bits 15:8 = interrupt 1 (SSI),
//   bits 31:24 = interrupt 5 (STI); :265-270 each field is RO0 or WARL (a minimal implementation is all RO0);
//   :485-499 the usual S-level order (smaller number = higher priority; ties by default order), IPRIOM = 1: IPRIO = the
//   candidate's number when 1..255.
// Setup: hideleg/hvip VSSIP+VSTIP (vsip 1 and 5), vsie 1 and 5, VGEIN = 0, hvictl = IPRIOM only.
// Case A: hviprio1 int1 = 7, int5 = 3 -> vstopi = (5 << 16) | 3.  Case B: int1 = 3, int5 = 7 -> (1 << 16) | 3.
// Checked only when hviprio1 reads back the written fields (else the fields are RO0, which is legal: INFO).

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
  csrw 0x609, x0            // hvictl = 0
  csrw 0x645, x0            // hvip = 0
  LI(x7, 0x3f000)
  csrc 0x600, x7            // VGEIN = 0
  li x7, 0x44
  csrs 0x603, x7            // hideleg VSSI, VSTI
  csrw 0x645, x7            // hvip.VSSIP = hvip.VSTIP = 1
  li x7, 0x22
  csrw 0x204, x7            // vsie SSIE(1), STIE(5)
  LI(x7, 0x100)
  csrw 0x609, x7            // hvictl.IPRIOM = 1
  // case A
  LI(x8, (7 << 8) | (3 << 24))
  csrw 0x646, x8
  csrr x6, 0x646
  LI(x7, 0xff00ff00)
  and x6, x6, x7
  bne x6, x8, t02_ro
  csrr x6, 0xEB0
  SA_SOFT(x6, (5 << 16) | 3, "T-02 A: hviprio1 int1=7 int5=3: vstopi = IID 5, IPRIO 3 (VSLevel.adoc:460-463)")
  // case B
  LI(x8, (3 << 8) | (7 << 24))
  csrw 0x646, x8
  csrr x6, 0xEB0
  SA_SOFT(x6, (1 << 16) | 3, "T-02 B: hviprio1 int1=3 int5=7: vstopi = IID 1, IPRIO 3")
  j t02_end
t02_ro:
  SA_INFO(x6, "T-02: hviprio1 fields for interrupts 1/5 not settable (RO0, legal): checks skipped")
t02_end:
  csrw 0x646, x0
  csrw 0x645, x0
  csrw 0x204, x0
  csrw 0x609, x0
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
