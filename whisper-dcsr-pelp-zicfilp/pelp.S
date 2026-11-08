// With Zicfilp, a halt must save ELP in dcsr.pelp and the resume must restore it (Sdext.adoc):
//   Halt:   "If the Zicfilp extension is implemented, dcsr.pelp is set to the current ELP state and ELP is set
//            to NO_LP_EXPECTED"
//   Resume: "If the Zicfilp extension is enabled at the new privilege mode, the current ELP state is changed to
//            that specified by dcsr.pelp else it is set to NO_LP_EXPECTED."
// whisper-rv*.json uses Whisper's default dcsr masks (only the reset value is set, for dcsr.ebreakm = 1).
// The test enables Zicfilp in M (mseccfg.MLPE = 1), enters Debug Mode with ebreak, sets an mcontrol6
// execute trigger with action = 1 (enter Debug Mode) on no_lpad, and resumes at a `jr t1` to no_lpad, which
// sets ELP = LP_EXPECTED. The trigger halts the hart before no_lpad executes; the halt must save ELP = 1 in
// dcsr.pelp. Back in Debug Mode the test checks dcsr, disables the trigger and resumes at no_lpad, which is
// not an lpad: the restored ELP = LP_EXPECTED must raise a software-check exception (mcause 18, mtval 2).
// x31 = bitmask of failed checks: 1 dcsr.pelp = 0 after the trigger halt, 2 dcsr.cause != trigger (2),
// 3 mcause != 18, 4 mtval != 2, 5 mepc != no_lpad, 6 no software-check exception at the jr target,
// 7 unexpected path. tohost = (x31 << 1) | 1.
#include "exit.h"
#define DCSR 0x7b0
#define DPC  0x7b1
#define DRET .word 0x7b200073
#define XLEN __riscv_xlen
// mcontrol6: type 6, dmode, action 1 (enter Debug Mode), m, execute, match equal, before.
#define MC6_DEBUG_EXEC li t0, 6; slli t0, t0, XLEN - 4; li t2, 1; slli t2, t2, XLEN - 5; or t0, t0, t2; \
                       li t2, 0x1044; or t0, t0, t2
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
  j unexpected

  .align 2
debug_start:                           // Debug Mode (reached by jr from park, so an lpad)
  lpad 0
  csrw tselect, zero
  la t0, no_lpad; csrw tdata2, t0
  MC6_DEBUG_EXEC; csrw tdata1, t0      // halt before no_lpad executes
  la t0, m_jr; csrw DPC, t0
  la t1, no_lpad                       // jr target
  la s0, after_halt
  DRET

m_jr:                                  // M-mode
  jr t1                                // sets ELP = LP_EXPECTED
  j unexpected

  .align 2
after_halt:                            // Debug Mode after the trigger halt
  lpad 0
  csrr t0, DCSR
  srli t2, t0, 18; andi t2, t2, 1; CHECKC(1, t2, 1)   // dcsr.pelp = ELP saved at the halt
  srli t2, t0, 6;  andi t2, t2, 7; CHECKC(2, t2, 2)   // dcsr.cause = trigger
  csrw tdata1, zero                    // disable the trigger
  DRET                                 // resume at dpc = no_lpad with ELP = dcsr.pelp

  .globl no_lpad
no_lpad:                               // not an lpad: software-check exception if ELP = LP_EXPECTED
  nop
  li t0, 1 << 6; or x31, x31, t0
  j done

  .align 2
mhandler:
  csrr t0, mcause; CHECKC(3, t0, 18)
  csrr t0, mtval;  CHECKC(4, t0, 2)
  csrr t0, mepc; la t1, no_lpad; beq t0, t1, 1f; li t5, 1 << 5; or x31, x31, t5; 1:
  j done
unexpected:
  li t0, 1 << 7; or x31, x31, t0
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
