// verify-v2 X1: illegal-instruction xtval when IALIGN=32 (riscv-isa-manual#3547, fixed by #3549 on 2026-11-19).
// Spec: unpriv/intro.adoc:456-461 (IALIGN is 32 in the base ISA; "Instructions are always a multiple of IALIGN bits
// in length."), priv/machine.adoc:2037-2045 (nonzero mtval on illegal instruction = shortest of the actual faulting
// instruction, the first ILEN bits, the first MXLEN bits), priv/machine.adoc:189 (writing misa may increase IALIGN,
// e.g. by disabling C).
// Steps: clear misa.C (harmless where C is absent); probe IALIGN with a jalr to a 2-byte-aligned target (cause 0 =>
// IALIGN=32); execute three words whose low 2 bits are 00, 01, 10 and whose upper half is 0xABCD (each is a reserved
// compressed encoding in its low half, and not a 32-bit instruction): with IALIGN=32 a nonzero mtval must be the full
// 32-bit word.
// Exit code (tohost = code<<1 | 1; x1 = tohost value at _test_exit), OR of:
//   1: misa.C still 1 after csrc      2: IALIGN probe did not trap with cause 0 (IALIGN=16)
//   4: an illegal probe had mtval == low 16 bits only    8: an illegal probe had another cause/mtval
// Verdict: IALIGN=32 (bit 2 clear) and bit 4 set => non-conforming under current main.
#include "common.h"
  .option norvc
  .section .text.init
  .globl _start
_start:
  la t0, handler
  csrw mtvec, t0
  // Smdbltrp: mstatus.MDT resets to 1, and a trap taken in M-mode with MDT=1 is a double trap: clear it.
#if __riscv_xlen == 64
  li t0, 1
  slli t0, t0, 42
  csrc mstatus, t0
#else
  li t0, 0x400
  csrc 0x310, t0            // mstatush.MDT
#endif
  // Smrnmi: mnstatus.NMIE resets to 0; set it (an illegal-instruction trap here, without Smrnmi, is harmless).
  la s11, 1f
  csrsi 0x744, 8
1:
  li s10, 0                 // result code
  li t0, 4
  csrc misa, t0
  csrr t1, misa
  andi t1, t1, 4
  beqz t1, 1f
  ori s10, s10, 1
1:
  // IALIGN probe
  la s11, ia_resume
  li a6, -1
  li a7, -1
  la t1, ia_target
  addi t1, t1, 2
  jalr x0, 0(t1)
  .align 2
ia_target:
  .word 0x00000013          // nop; its upper half (0x0000) is the illegal 16-bit encoding
  .word 0x00000013
ia_resume:
  beqz a6, 2f               // cause 0: instruction address misaligned => IALIGN=32
  ori s10, s10, 2
2:
#if __riscv_xlen == 64
#define ZEXT32(d, s) slli d, s, 32; srli d, d, 32
#else
#define ZEXT32(d, s) mv d, s
#endif
#define PROBE(w, lbl)          \
  la s11, lbl;                 \
  li a6, -1;                   \
  li a7, -1;                   \
  .word w;                     \
lbl:                           \
  li t2, 2;                    \
  bne a6, t2, 9f;              \
  beqz a7, 8f;                 \
  li t2, w;                    \
  ZEXT32(t2, t2);              \
  ZEXT32(t3, a7);              \
  beq t3, t2, 8f;              \
  li t2, (w) & 0xffff;         \
  beq a7, t2, 7f;              \
9: ori s10, s10, 8; j 8f;      \
7: ori s10, s10, 4;            \
8:
  PROBE(0xABCD0004, p0)     // low half c.addi4spn nzuimm=0 (reserved)
  PROBE(0xABCD6101, p1)     // low half c.addi16sp nzimm=0 (reserved)
  PROBE(0xABCD4002, p2)     // low half c.lwsp rd=x0 (reserved)
  slli x1, s10, 1
  ori x1, x1, 1
  j done
  .align 2
handler:                    // record mcause/mtval, resume at s11 through mret (mret also clears MDT)
  csrr a6, mcause
  csrr a7, mtval
  csrw mepc, s11
  mret
EPILOGUE
