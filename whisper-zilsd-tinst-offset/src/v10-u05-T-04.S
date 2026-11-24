// v10-u05-T-04: mtinst for a trapping Zilsd LD/SD must be 0 or the transformed instruction whose Addr. Offset
//  (bits 19:15) = mtval - EA.
// Spec: priv/hypervisor.adoc:2612-2624 (a nonzero value must be the transformation of the trapping instruction),
//  :2759-2768 (no transformation defined -> zero), :2770-2786 (LD/SD transformation), :2804-2808
//  (norm:H_tinst_addr_offset). If Zilsd LD/SD are not the listed "LD"/"SD", only 0 is legal; if they are, 0 or the
//  transformation with the correct offset. Either way a transformed value with the wrong offset is illegal.
// Shape: M-mode traps from S-mode, Bare. M1/M2: ld/sd x20,0(ppg1-4), second word PMP-denied (mtval = ppg1, offset 4,
//  or mtval = EA if done as one access, offset 0). M3: ld x20,1(ppg0+0x100) (EA%4 = 1): completion or a misaligned
//  trap with mtval = EA (offset 0).
##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'Sm', 'S', 'U', 'H', 'Zilsd']
# MARCH: rv${XLEN}i_zicsr_zifencei
# NEEDS_SIGNATURE: false
##### END_TEST_CONFIG #####
#define SIGUPD_COUNT 0
#define BOOT_TO_MMODE
#include "riscv_arch_test.h"
#include "../common/sa.h"
#define MPRV (1 << 17)
#define SETMPP(_PP) LI(x9, 0x1800); csrc mstatus, x9; LI(x9, (_PP) << 11); csrs mstatus, x9
#define MP(_PP, ...) SETMPP(_PP); AI_ALLOW(1); LI(x12, MPRV); csrs mstatus, x12; __VA_ARGS__; csrc mstatus, x12; AI_OUTCOME
#define S_DO(...) SETMPP(1); LA(x9, 71f); csrw mepc, x9; AI_ALLOW(1); mret; 71: __VA_ARGS__; RVTEST_TSBI_GOTO_MMODE; AI_OUTCOME
#define CAUSE(_C, _MSG) SA_SOFT(x14, _C, _MSG ": xcause (-1 none)")
#define SOFT2(_R, _E1, _E2, _MSG) LI(x4, _E1); beq x4, _R, 93f; SA_SOFT(_R, _E2, _MSG); 93:
#define SOFTR(_R, _E, _MSG) sub x15, _R, _E; SA_SOFT(x15, 0, _MSG " (difference)")
#define PMP_PAGE(_S, _C) LA(x9, _S); srli x9, x9, 2; ori x9, x9, 0x1ff; csrw pmpaddr0, x9; LI(x9, -1); \
  csrw pmpaddr1, x9; LI(x9, 0x1f00 | (_C)); csrw pmpcfg0, x9; sfence.vma x0, x0
#define PMP_RESTORE LI(x9, -1); csrw pmpaddr0, x9; li x9, 0x0f; csrw pmpcfg0, x9; sfence.vma x0, x0
#define LDP(_RD, _OFF, _RS1) .insn i 0x03, 3, _RD, _OFF(_RS1)
#define SDP(_RS2, _OFF, _RS1) .insn s 0x23, 3, _RS2, _OFF(_RS1)
#define SENT 0xC0DEC0DE
#define WA 0xAAAA0FFC
#define WB 0xBBBB0000
#define TI_LD20 0x00003a03
#define TI_SD20 0x01403023
// xtinst in {0, _BASE | ((xtval - EA) << 15)}, EA in register _EAR
#define TINST(_BASE, _EAR, _MSG) AI_LOG(x15, TRAPLOG_TVAL); sub x16, x15, _EAR; slli x16, x16, 15; \
  LI(x15, _BASE); or x16, x16, x15; AI_LOG(x15, TRAPLOG_TINST); beqz x15, 86f; \
  SOFTR(x15, x16, _MSG ": xtinst in {0, transformed (offset = xtval-EA)}"); 86:
RVTEST_BEGIN
#if __riscv_xlen == 32
  csrw medeleg, x0
  csrw satp, x0
  PMP_PAGE(ppg1, 0x18)
  LA(x25, ppg1)
  addi x25, x25, -4
  LI(x20, SENT)
  S_DO(LDP(x20, 0, x25))
  CAUSE(5, "M1 ld x20,0(ppg1-4), 2nd word denied")
  TINST(TI_LD20, x25, "M1 ld")
  LI(x20, 0x12345678)
  LI(x21, 0x9abcdef0)
  S_DO(SDP(x20, 0, x25))
  CAUSE(7, "M2 sd x20,0(ppg1-4), 2nd word denied")
  TINST(TI_SD20, x25, "M2 sd")
  LI(x9, WA)
  sw x9, 0(x25)
  PMP_RESTORE
  LA(x25, ppg0)
  addi x25, x25, 0x101
  LI(x20, SENT)
  S_DO(LDP(x20, 0, x25))
  li x9, -1
  beq x14, x9, 1f
  CAUSE(4, "M3 ld x20,0(ppg0+0x101): a trap must be load-misaligned")
  TINST(TI_LD20, x25, "M3 misaligned ld")
1:
#endif
  SA_SOFT_END
RVTEST_CODE_END
RVTEST_DATA_BEGIN
  .p2align 12
ppg0: .fill 4088, 1, 0x5a
  .word 0x08070605, WA
ppg1: .word WB, 0x0F0E0D0C
  .fill 4088, 1, 0x5a
RVTEST_DATA_END
RVTEST_SIG_SETUP
