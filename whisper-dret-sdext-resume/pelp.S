// DRET must restore ELP from dcsr.pelp and then clear dcsr.pelp (Sdext.adoc, Resume):
//   "If the Zicfilp extension is enabled at the new privilege mode, the current ELP state is changed to that
//    specified by dcsr.pelp else it is set to NO_LP_EXPECTED. dcsr.pelp is set to NO_LP_EXPECTED."
// The test enables Zicfilp in M (mseccfg.MLPE = 1), enters Debug Mode with ebreak, sets dcsr.prv = M and
// dcsr.pelp = LP_EXPECTED, and resumes with dret at no_lpad, which is not an lpad: the hart must take a
// software-check exception (mcause 18, mtval 2) there. Software cannot read dcsr outside Debug Mode, and the
// next entry into Debug Mode rewrites dcsr.pelp, so run.sh checks dcsr.pelp after the dret with a
// debugger-style peek (Whisper interactive mode: until no_lpad, peek c dcsr).
// x31 = bitmask of failed checks: 1 dcsr.pelp not writable (config), 2 no software-check exception,
// 3 mcause != 18, 4 mtval != 2, 5 mepc != no_lpad. tohost = (x31 << 1) | 1.
#include "exit.h"
#define DCSR 0x7b0
#define DPC  0x7b1
#define DRET .word 0x7b200073
#define PELP (1 << 18)
#if __riscv_xlen == 64
#define MDT_CLR  li t0, 1; slli t0, t0, 42; csrc mstatus, t0
#else
#define MDT_CLR  li t0, 1 << 10; csrc mstatush, t0
#endif

  .option norelax
  .section .text.init
  .globl _start
_start:
  li x31, 0
  li t0, -1; csrw pmpaddr0, t0; li t0, 0x0f; csrw pmpcfg0, t0
  la t0, mhandler; csrw mtvec, t0
  MDT_CLR                              // mstatus.MDT = 0 (Smdbltrp) and
  li t0, 8; csrs 0x744, t0             // mnstatus.NMIE = 1 (Smrnmi), so the expected trap is not a double trap
  li t0, 1 << 10; csrs mseccfg, t0     // mseccfg.MLPE = 1: Zicfilp enabled in M
  la s0, debug_start
  ebreak                               // dcsr.ebreakm = 1: enter Debug Mode at park
  li t0, 1 << 30; or x31, x31, t0     // not reached
  j done

  .align 2
debug_start:                           // in Debug Mode (reached by jr from park: MLPE = 1, so land on an lpad)
  lpad 0
  csrr t0, DCSR; andi t0, t0, ~0x23; ori t0, t0, 3; li t1, PELP; or t0, t0, t1; csrw DCSR, t0  // prv = M, v = 0, pelp = 1
  csrr t1, DCSR; srli t1, t1, 18; andi t1, t1, 1; CHECKC(1, t1, 1)
  la t0, no_lpad; csrw DPC, t0
  DRET
  .globl no_lpad
no_lpad:                               // ELP = LP_EXPECTED, not an lpad: software-check exception
  nop
  li t0, 1 << 2; or x31, x31, t0
  j done

  .align 2
mhandler:
  csrr t0, mcause; CHECKC(3, t0, 18)
  csrr t0, mtval;  CHECKC(4, t0, 2)
  csrr t0, mepc; la t1, no_lpad; beq t0, t1, 1f; li t5, 1 << 5; or x31, x31, t5; 1:
done:
  EXIT

  .org 0x800
park:                                  // Debug Mode entry (debug_park_loop)
  jr s0
  .org 0x900
debug_trap:                            // exception in Debug Mode (debug_trap_address)
  li t0, 1 << 27; or x31, x31, t0
  j done

  .section .tohost, "aw"
  .align 3
  .globl tohost
tohost: .dword 0
  .globl fromhost
fromhost: .dword 0
