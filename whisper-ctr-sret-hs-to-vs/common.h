// Shared setup for the CTR reproducers. M-mode handler: an ecall (cause 8/9/10) returns to M-mode at a0;
// any other exception records mcause in s2 and resumes after the faulting instruction in the same mode.
#include "exit.h"
#define MCTRCTL 0x34e
#define SCTRCTL 0x14e
#define VSCTRCTL 0x24e
#define SCTRSTATUS 0x14f
#define SCTRDEPTH 0x15f
#define SISELECT 0x150
#define SIREG 0x151
#define SIREG2 0x152
#define SCTRCLR .word 0x10400073
#define SETUP \
  li x31, 0; li s2, 0; \
  li t0, -1; csrw pmpaddr0, t0; li t0, 0x0f; csrw pmpcfg0, t0; \
  la t0, mhandler; csrw mtvec, t0; csrw medeleg, zero; csrw mideleg, zero; \
  csrw satp, zero; csrw vsatp, zero; csrw hgatp, zero
// mret to mode (MPP = pp, MPV = v) at label lab; the code there ends with an ecall back to a0 in M-mode.
#if __riscv_xlen == 64
#define SET_MPV(v) li t0, 1; slli t0, t0, 39; .if v; csrs mstatus, t0; .else; csrc mstatus, t0; .endif
#else
#define SET_MPV(v) li t0, 0x80; .if v; csrs 0x310, t0; .else; csrc 0x310, t0; .endif
#endif
#define ENTER(pp, v, lab, ret) la a0, ret; la t0, lab; csrw mepc, t0; li t0, 0x1800; csrc mstatus, t0; \
  li t0, (pp) << 11; csrs mstatus, t0; SET_MPV(v); mret
#define HANDLER \
  .align 2; \
mhandler: \
  csrr t3, mcause; \
  addi t4, t3, -8; bltz t4, 1f; addi t4, t3, -11; bgez t4, 1f; \
  li t0, 0x1800; csrs mstatus, t0; SET_MPV(0); csrw mepc, a0; mret; \
1: mv s2, t3; csrr t4, mepc; addi t4, t4, 4; csrw mepc, t4; mret
