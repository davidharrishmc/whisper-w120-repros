// A Whisper snapshot must restore every CSR, including one that is 0 at the snapshot while reset leaves it
// non-zero. mstatus.MDT (Smdbltrp) resets to 1; on RV32 it is mstatush[10], and mstatush is otherwise 0.
// The test clears MDT and sets mnstatus.NMIE (so a trap into M-mode is an ordinary trap), runs a nop sled
// (run.sh saves a snapshot there and restarts from it), then
//   check 1: mstatush (RV32) / mstatus (RV64) shows MDT = 0
//   check 2: ecall from M-mode reaches the M-mode trap handler with mcause 11
//   check 3: mstatus.MIE = 1 (set before the snapshot, with mie = 0 so that no interrupt is taken)
//   check 2 is skipped if check 1 fails: with MDT = 1 the ecall is a double trap, which Whisper reports as
//   "Core entered critical-error state due to an unexpected trap".
// x31 = bitmask of failed checks. tohost = (x31 << 1) | 1.
#include "exit.h"
#if __riscv_xlen == 64
#define MDT_CLR     li t0, 1; slli t0, t0, 42; csrc mstatus, t0
#define MDT_GET(r)  csrr r, mstatus; srli r, r, 42; andi r, r, 1
#else
#define MDT_CLR     li t0, 1 << 10; csrc mstatush, t0
#define MDT_GET(r)  csrr r, mstatush; srli r, r, 10; andi r, r, 1
#endif

  .option norelax
  .section .text.init
  .globl _start
_start:
  li x31, 0
  la t0, mtrap; csrw mtvec, t0
  MDT_CLR                              // mstatus.MDT = 0
  li t0, 8; csrs 0x744, t0             // mnstatus.NMIE = 1
  csrw mie, zero; csrsi mstatus, 8     // mstatus.MIE = 1, no interrupt enabled
  .rept 64                             // run.sh saves the snapshot in this sled
  nop
  .endr
  .globl check
check:
  MDT_GET(t0); CHECKC(1, t0, 0)
  csrr t0, mstatus; andi t0, t0, 8; CHECKC(3, t0, 8)
  andi t0, x31, 2; bnez t0, done       // with MDT = 1 the ecall would be a double trap
  li s1, 0
  ecall
  bnez s1, done
  li t0, 1 << 4; or x31, x31, t0      // handler not reached
  j done
  .align 2
mtrap:
  li s1, 1
  csrr t0, mcause; CHECKC(2, t0, 11)
done:
  EXIT

  .section .tohost, "aw"
  .align 3
  .globl tohost
tohost: .dword 0
  .globl fromhost
fromhost: .dword 0
