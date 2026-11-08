// Pass/fail: x31 = 0 pass, else a bitmask of the failed checks.
// Spike, Sail, Whisper (HTIF): tohost = (x31 << 1) | 1.
// QEMU virt (-DQEMU): print "x31=<hex>" on the UART at 0x10000000, then exit through the sifive test finisher at
// 0x100000 (store 0x5555 pass, (x31 << 16) | 0x3333 fail; QEMU's exit status is then the low 8 bits of x31).
#if defined(QEMU)
#define EXIT \
  li t0, 0x10000000; li t1, 'x'; sb t1, 0(t0); li t1, '3'; sb t1, 0(t0); li t1, '1'; sb t1, 0(t0); \
  li t1, '='; sb t1, 0(t0); li t2, 28; \
8: srl t1, x31, t2; andi t1, t1, 15; addi t1, t1, '0'; li t3, '9' + 1; blt t1, t3, 7f; addi t1, t1, 'a' - '9' - 1; \
7: sb t1, 0(t0); addi t2, t2, -4; bgez t2, 8b; li t1, '\n'; sb t1, 0(t0); \
  li t0, 0x100000; beqz x31, 1f; slli t1, x31, 16; li t2, 0x3333; or t1, t1, t2; sw t1, 0(t0); j .; 1: li t1, 0x5555; sw t1, 0(t0); j .
#else
#define EXIT  slli t0, x31, 1; ori t0, t0, 1; la t1, tohost; sw t0, 0(t1); sw zero, 4(t1); j .
#endif
// CHECKC: record a failed check n in bit n of x31 and keep going.
#define CHECKC(n, reg, val) li t4, val; beq reg, t4, 9f; li t5, 1 << (n); or x31, x31, t5; 9:
