// Pass/fail: x31 = 0 pass, else the bitmask of failed checks.
// Whisper, Spike, Sail, Imperas: tohost = (x31 << 1) | 1.
// QEMU virt: prints "x31=0x<hex>" on the UART, then the SiFive test finisher at 0x100000 ends the run with exit
// status x31 & 0xff (bits above 7 are lost there, so read the printed line).
#if defined(QEMU)
#define EXIT  li t0, 0x10000000; li t1, 'x'; sb t1, 0(t0); li t1, '3'; sb t1, 0(t0); li t1, '1'; sb t1, 0(t0); \
  li t1, '='; sb t1, 0(t0); li t1, '0'; sb t1, 0(t0); li t1, 'x'; sb t1, 0(t0); li t2, 28; \
  1: srl t3, x31, t2; andi t3, t3, 0xf; li t4, 10; blt t3, t4, 2f; addi t3, t3, 'a' - '0' - 10; 2: addi t3, t3, '0'; \
  sb t3, 0(t0); addi t2, t2, -4; bgez t2, 1b; li t1, '\n'; sb t1, 0(t0); \
  li t0, 0x100000; beqz x31, 1f; slli t1, x31, 16; li t2, 0x3333; or t1, t1, t2; sw t1, 0(t0); j .; 1: li t1, 0x5555; sw t1, 0(t0); j .
#else
#define EXIT  slli t0, x31, 1; ori t0, t0, 1; la t1, tohost; sw t0, 0(t1); sw zero, 4(t1); j .
#endif
// CHECKC: record a failed check n in bit n of x31 and keep going.
#define CHECKC(n, reg, val) li t4, val; beq reg, t4, 9f; li t5, 1 << (n); or x31, x31, t5; 9:
