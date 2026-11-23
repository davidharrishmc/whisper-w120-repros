// Illegal-instruction mtval on a hart without C/Zca (IALIGN = 32).
//
// riscv-isa-manual#3549 (src/unpriv/intro.adoc): "Instructions are always a multiple of IALIGN bits in length."
// With IALIGN = 32 there are no 16-bit instructions, so a word whose low two bits are 00, 01 or 10 is a 32-bit
// (illegal) instruction and a nonzero mtval must hold all 32 bits of it (riscv-isa-manual#3547).
//
// M-mode only, built without C (-march=rv64i_zicsr / rv32i_zicsr). Ends through HTIF tohost:
// tohost = (code << 1) | 1, so tohost = 1 means pass.
//   code bits [1:0], [3:2], [5:4]: probe 0xABCD0004, 0xABCD6101, 0xABCD4002
//        0 = mtval is the 32-bit word (correct)   1 = mtval is the low 16-bit parcel   2 = other cause or mtval
//   code bit 6: misa.C reads 1             code bit 7: jalr to pc+2 did not raise cause 0 (IALIGN is not 32)
// The observed mcause/mtval of each probe are stored in `observed` (3 x {mcause, mtval}, XLEN-sized).

#if __riscv_xlen == 64
#define SREG sd
#define REGBYTES 8
#define ZEXT32(d, s) slli d, s, 32; srli d, d, 32
#else
#define SREG sw
#define REGBYTES 4
#define ZEXT32(d, s) mv d, s
#endif

  .option norvc
  .section .text.init
  .globl _start
_start:
  la t0, handler
  csrw mtvec, t0
  li s10, 0                 // result code
  la s9, observed

  // misa.C must read 0
  csrr t1, misa
  andi t1, t1, 4
  beqz t1, 1f
  ori s10, s10, 64
1:
  // IALIGN probe: jalr to a 2-byte-aligned target must raise instruction-address-misaligned (cause 0)
  la s11, ia_resume
  li a6, -1
  la t1, ia_target
  addi t1, t1, 2
  jalr x0, 0(t1)
  .align 2
ia_target:
  .word 0x00000013          // nop
  .word 0x00000013
ia_resume:
  beqz a6, 1f
  ori s10, s10, 128
1:

// PROBE(word, shift): execute `word`, classify mcause/mtval, record them
#define PROBE(w, sh, lbl)        \
  la s11, lbl;                   \
  li a6, -1;                     \
  li a7, -1;                     \
  .word w;                       \
lbl:                             \
  SREG a6, 0(s9);                \
  SREG a7, REGBYTES(s9);         \
  addi s9, s9, 2*REGBYTES;       \
  li t2, 2;                      \
  bne a6, t2, 9f;                \
  li t2, w;                      \
  ZEXT32(t2, t2);                \
  beq a7, t2, 8f;                \
  li t2, (w) & 0xffff;           \
  beq a7, t2, 7f;                \
9: li t2, 2 << (sh); or s10, s10, t2; j 8f; \
7: li t2, 1 << (sh); or s10, s10, t2;       \
8:

  PROBE(0xABCD0004, 0, p0)  // low half: c.addi4spn with nzuimm = 0 (reserved)
  PROBE(0xABCD6101, 2, p1)  // low half: c.addi16sp with nzimm = 0 (reserved)
  PROBE(0xABCD4002, 4, p2)  // low half: c.lwsp with rd = x0 (reserved)

  slli t0, s10, 1
  ori t0, t0, 1
  la t1, tohost
  .globl _test_exit
_test_exit:               // Imperas customControl stops here
  sw t0, 0(t1)
  sw x0, 4(t1)
  j _test_exit

  .align 2
handler:                    // record mcause/mtval, resume at s11
  csrr a6, mcause
  csrr a7, mtval
  csrw mepc, s11
  mret

  .data
  .align 3
observed:
  .fill 6, REGBYTES, 0

  .section .tohost, "aw", @progbits
  .align 6
  .globl tohost
tohost: .dword 0
  .size tohost, 8
  .align 6
  .globl fromhost
fromhost: .dword 0
  .size fromhost, 8
