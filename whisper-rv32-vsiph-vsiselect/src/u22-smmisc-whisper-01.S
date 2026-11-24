// verify-v11 u22-smmisc-whisper-01 (adopted from work/u22-smmisc-whisper/u22w-vsiph-vsiselect.S): vsiph/siph (RV32 AIA CSRs 0x254/0x154) caught by the Smcdeleg vsiselect 0x40-0x5F
// check because Hart::checkCsrAccess tests the CSR-number range VSIREG..VSIREG6 / SIREG..SIREG6 (0x251-0x257 /
// 0x151-0x157), which contains 0x254 / 0x154.
// Spec: smcdeleg.adoc:104-105 restrict only vsireg*/sireg* (not vsiph/siph) while vsiselect is 0x40-0x5F;
// smcsrind.adoc:63-66 / csrs.adoc: 0x154/0x254 are siph/vsiph, not indirect aliases.
// Expected (every legal outcome): none of the probed accesses traps; vsiselect has no bearing on vsiph/siph (an
// illegal-instruction for M/HS vsiph would need vsiph to be absent, which it is not on an RV32 H+Smaia/Ssaia hart).
##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'Sm', 'S', 'U', 'H', 'Smaia', 'Ssaia', 'Smstateen']
# MARCH: rv${XLEN}i_zicsr_zifencei
# NEEDS_SIGNATURE: false
##### END_TEST_CONFIG #####
#define SIGUPD_COUNT 0
#define BOOT_TO_MMODE
#include "riscv_arch_test.h"
#include "../common/sa.h"
#define SISELECT 0x150
#define SIREG    0x151
#define SIREG2   0x152
#define SIREG5   0x156
#define MHPMEVENT3  0x323
#define MHPMEVENT3H 0x723
#define MSTATEEN0  0x30c
#define MSTATEEN0H 0x31c
#define HSTATEEN0  0x60c
#define HSTATEEN0H 0x61c
#define R REGWIDTH
#define MCLR LA(x9, mrec); SREG x0, 0(x9); LI(x7, -1); SREG x7, R(x9)
#define MGET(_R, _W) LA(x9, mrec); LREG _R, (_W)*R(x9)
#define SETMPP(_PP) LI(x9, 0x1800); csrc mstatus, x9; LI(x9, (_PP) << 11); csrs mstatus, x9
#ifdef H_SUPPORTED
  #if __riscv_xlen == 64
    #define SETMPV LI(x9, 1 << 39); csrs mstatus, x9
    #define CLRMPV LI(x9, 1 << 39); csrc mstatus, x9
  #else
    #define SETMPV li x9, 0x80; csrs mstatush, x9
    #define CLRMPV li x9, 0x80; csrc mstatush, x9
  #endif
#else
  #define CLRMPV
#endif
#define ENTER(_PP) CLRMPV; SETMPP(_PP); LA(x9, 71f); csrw mepc, x9; mret; 71:
#define ENTERV(_PP) SETMPV; SETMPP(_PP); LA(x9, 71f); csrw mepc, x9; mret; 71:
#define EXIT LA(x13, 72f); ebreak; 72:
// x15 = mcause of the trap taken by the instructions (-1 = none). The handler skips a trapping instruction.
#define IN_M(...)  MCLR; __VA_ARGS__; MGET(x15, 1)
#define IN_S(...)  MCLR; ENTER(1); __VA_ARGS__; EXIT; MGET(x15, 1)
#define IN_VS(...) MCLR; ENTERV(1); __VA_ARGS__; EXIT; MGET(x15, 1)
#define IN_VU(...) MCLR; ENTERV(0); __VA_ARGS__; EXIT; MGET(x15, 1)
#define CHK(_EXP, _MSG) SA_SOFT(x15, _EXP, _MSG)
#if __riscv_xlen == 64
  #define CDE_ON  LI(x9, (1 << 60)); csrs menvcfg, x9
  #define CDE_RD(_R) csrr _R, menvcfg; srli _R, _R, 60; andi _R, _R, 1
  #define CSRIND_M_ON  LI(x9, (1 << 60)); csrs MSTATEEN0, x9
  #define CSRIND_M_OFF LI(x9, (1 << 60)); csrc MSTATEEN0, x9
  #define CSRIND_H_ON  LI(x9, (1 << 60)); csrs HSTATEEN0, x9
#else
  #define CDE_ON  LI(x9, (1 << 28)); csrs menvcfgh, x9
  #define CDE_RD(_R) csrr _R, menvcfgh; srli _R, _R, 28; andi _R, _R, 1
  #define CSRIND_M_ON  LI(x9, (1 << 28)); csrs MSTATEEN0H, x9
  #define CSRIND_M_OFF LI(x9, (1 << 28)); csrc MSTATEEN0H, x9
  #define CSRIND_H_ON  LI(x9, (1 << 28)); csrs HSTATEEN0H, x9
#endif

RVTEST_BEGIN
#if __riscv_xlen == 32
  li x13, 0
  csrw mie, x0
  csrci mstatus, 8
  csrw medeleg, x0
  csrw mideleg, x0
  csrr x7, mtvec
  LA(x9, fwvec)
  SREG x7, 0(x9)
  LA(x7, mtrap)
  csrw mtvec, x7
  csrw hgatp, x0
  csrw vsatp, x0
  LI(x9, 0x9C000000)
  csrs MSTATEEN0H, x9
  csrs HSTATEEN0H, x9
  LI(x9, 0x30)
  csrw 0x250, x9
  IN_S(csrr x6, 0x254)
  CHK(-1, "control: vsiselect=0x30: HS csrr vsiph -> no trap")
  IN_VS(csrr x6, 0x154)
  CHK(-1, "control: vsiselect=0x30: VS csrr siph (vsiph) -> no trap")
  LI(x9, 0x40)
  csrw 0x250, x9
  csrr x6, 0x250
  SA_SOFT(x6, 0x40, "control: vsiselect holds 0x40")
  IN_S(csrr x6, 0x254)
  CHK(-1, "vsiselect=0x40: HS csrr vsiph (0x254) -> no trap (vsiph is not a vsireg alias)")
  IN_VS(csrr x6, 0x154)
  CHK(-1, "vsiselect=0x40: VS csrr siph (0x154 -> vsiph) -> no trap")
  IN_M(csrr x6, 0x254)
  CHK(-1, "vsiselect=0x40: M csrr vsiph -> no trap")
  IN_S(csrr x6, 0x214)
  CHK(-1, "control: vsiselect=0x40: HS csrr vsieh (0x214) -> no trap")
  LA(x9, fwvec)
  LREG x7, 0(x9)
  csrw mtvec, x7
#endif
  SA_SOFT_END
  j test_end

// ---------------------------------------------------------------- own M trap handler
  .option push
  .option norvc
  .balign 64
mtrap:
  bnez x13, mexit
  la x15, mrec
  LREG x14, 0(x15)
  addi x14, x14, 1
  SREG x14, 0(x15)
  csrr x14, mcause
  SREG x14, 1*R(x15)
  csrr x14, mepc
  addi x14, x14, 4
  csrw mepc, x14
  mret
mexit:
  csrw mepc, x13
  li x13, 0
  li x15, 0x1800
  csrs mstatus, x15
  li x15, 0x80
  csrc mstatus, x15
#ifdef H_SUPPORTED
  #if __riscv_xlen == 64
  li x15, 1
  slli x15, x15, 39
  csrc mstatus, x15
  #else
  li x15, 0x80
  csrc mstatush, x15
  #endif
#endif
  mret
  .option pop
test_end:
RVTEST_CODE_END

RVTEST_DATA_BEGIN
  .balign 8
fwvec: .dword 0
mrec:  .fill 8, 8, 0
RVTEST_DATA_END
RVTEST_SIG_SETUP
