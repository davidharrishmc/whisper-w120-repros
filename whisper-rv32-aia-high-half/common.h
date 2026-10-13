// Minimal bare-metal harness: tohost = 1 on pass, (n << 1) | 1 on failure of check n.
#if __riscv_xlen == 64
#define SREG sd
#else
#define SREG sw
#endif
#define FAIL_IF_NEZ(n, r) li gp, n; bnez r, fail
#define FAIL_IF_EQZ(n, r) li gp, n; beqz r, fail

// Clear mstatus.MDT (Smdbltrp resets it to 1) and set mnstatus.NMIE (Smrnmi resets it
// to 0) so that M-mode traps are ordinary traps. Harts without Smrnmi trap on the
// mnstatus access; init_skip steps over it.
#if __riscv_xlen == 64
#define CLEAR_MDT li t0, 1; slli t0, t0, 42; csrc mstatus, t0
#else
#define CLEAR_MDT li t0, 0x400; csrc mstatush, t0
#endif
#define HARNESS_INIT                    \
  CLEAR_MDT;                            \
  la t0, init_skip;                     \
  csrw mtvec, t0;                       \
  csrsi 0x744, 8;                       \
  j init_done;                          \
  .align 2;                             \
init_skip:                              \
  csrr t0, mepc;                        \
  addi t0, t0, 4;                       \
  csrw mepc, t0;                        \
  mret;                                 \
init_done:

#define HARNESS_END                     \
pass:                                   \
  li t0, 1;                             \
  la t1, tohost;                        \
1: SREG t0, 0(t1);                      \
  j 1b;                                 \
fail:                                   \
  slli gp, gp, 1;                       \
  ori gp, gp, 1;                        \
  la t1, tohost;                        \
2: SREG gp, 0(t1);                      \
  j 2b;                                 \
  .section .tohost, "aw", @progbits;    \
  .align 6; .global tohost; tohost: .dword 0; \
  .align 6; .global fromhost; fromhost: .dword 0;
