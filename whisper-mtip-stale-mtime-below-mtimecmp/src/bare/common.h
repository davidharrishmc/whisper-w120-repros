// Bare-metal HTIF harness. Pass: tohost = 1. Failure n: print "FAIL n" on the HTIF console,
// then tohost = (n << 1) | 1.
#if __riscv_xlen == 64
#define SREG sd
#define LREG ld
#else
#define SREG sw
#define LREG lw
#endif
#define TEST_PASS   li a0, 0; j report
#define TEST_FAIL(n) li a0, n; j report
#define TEST_END \
report: beqz a0, 9f; \
  la a1, failmsg; \
2: lbu a2, 0(a1); beqz a2, 3f; call putch; addi a1, a1, 1; j 2b; \
3: addi a2, a0, '0'; call putch; li a2, '\n'; call putch; \
  slli a0, a0, 1; \
9: ori a0, a0, 1; la t0, tohost; SREG a0, 0(t0); 1: j 1b; \
putch: /* a2 = char; HTIF device 1 (console), command 1 (putchar) */ \
  li t1, 0x0101; slli t1, t1, 48; or t1, t1, a2; \
  la t0, tohost; \
4: LREG t2, 0(t0); bnez t2, 4b; \
  SREG t1, 0(t0); \
5: la t2, fromhost; LREG t3, 0(t2); SREG zero, 0(t2); \
  LREG t2, 0(t0); bnez t2, 5b; ret; \
failmsg: .asciz "FAIL "; .balign 4; \
  .section .tohost, "aw", @progbits; .balign 64; .globl tohost; .type tohost, @object; .size tohost, 8; tohost: .dword 0; \
  .balign 64; .globl fromhost; .type fromhost, @object; .size fromhost, 8; fromhost: .dword 0
