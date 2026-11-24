// verify-v2 u21-mother-whisper-05: EBREAK in VS-mode / VU-mode with dcsr.ebreaks = ebreaku = 1 and
// dcsr.ebreakvs = ebreakvu = 0 must raise a breakpoint exception (cause 3), not enter Debug Mode.
// Spec: ISA debug-trace/registers/core_registers.adoc:187-209 (dcsr.ebreakvs/ebreakvu = 0: "ebreak instructions in
// VS-mode [VU-mode] behave as described in the Privileged Spec"), :221-232 (ebreaks/ebreaku: S-mode / U-mode);
// priv/machine.adoc:2622 (EBREAK raises a breakpoint exception unless overridden by an external debug environment).
// dcsr is only writable in Debug Mode, so the dcsr value is set by the simulator configuration (Whisper: "csr":
// {"dcsr": {"reset": ...}} in work/verify-v2/ebreak/whisper-rv*-ebreaks.json). With the stock configuration
// (dcsr.ebreak* = 0) the test is a control: both EBREAKs must trap.
// x1: 1 = both EBREAKs trapped to M with cause 3 and MPV = 1;  3 = the VS EBREAK did not trap;
//     5 = a trap with another cause / MPV;  7 = the VU EBREAK did not trap.
#include "common.h"
  .option norvc
  .section .text.init
  .globl _start
_start:
  la t0, handler
  csrw mtvec, t0
#if __riscv_xlen == 64
  li t0, 1
  slli t0, t0, 42
  csrc mstatus, t0          // MDT = 0
#else
  li t0, 0x400
  csrc 0x310, t0
#endif
  la s11, 1f
  csrsi 0x744, 8            // mnstatus.NMIE = 1 (traps harmlessly without Smrnmi)
1:
  li s0, 0                  // stage
  li t0, -1
  csrw pmpaddr0, t0
  li t0, 0x1f               // pmp0: NAPOT RWX over everything (VS/VU accesses need a PMP match)
  csrw pmpcfg0, t0
  csrw medeleg, x0
  csrw 0x680, x0            // hgatp = Bare
  csrw 0x280, x0            // vsatp = Bare
  li a0, 0x800              // MPP = S
  la a1, vs_code
  j enter_virtual
vs_code:
  li s0, 1
  ebreak
  li x1, 3                  // VS ebreak did not trap
  j done
vu_code:
  li s0, 2
  ebreak
  li x1, 7
  j done

// enter V=1 with mstatus.MPP = a0 at address a1
enter_virtual:
  li t0, 0x1800
  csrc mstatus, t0
  csrs mstatus, a0
#if __riscv_xlen == 64
  li t0, 1
  slli t0, t0, 39
  csrs mstatus, t0          // MPV = 1
#else
  li t0, 0x80
  csrs 0x310, t0
#endif
  csrw mepc, a1
  mret

  .align 2
handler:
  beqz s0, skip             // setup trap (mnstatus absent)
  csrr t0, mcause
  li t1, 3
  bne t0, t1, bad
#if __riscv_xlen == 64
  csrr t0, mstatus
  srli t0, t0, 39
#else
  csrr t0, 0x310
  srli t0, t0, 7
#endif
  andi t0, t0, 1
  beqz t0, bad
  li t1, 1
  bne s0, t1, 2f
  li a0, 0                  // stage 1 passed: go to VU
  la a1, vu_code
  j enter_virtual
2:
  li x1, 1                  // stage 2 passed
  j done_m
bad:
  li x1, 5
  j done_m
skip:
  li t0, 0x1800
  csrs mstatus, t0          // MPP = M
  csrw mepc, s11
  mret
done_m:
#if __riscv_xlen == 64
  li t0, 1
  slli t0, t0, 39
  csrc mstatus, t0
#else
  li t0, 0x80
  csrc 0x310, t0
#endif
  j done
EPILOGUE
