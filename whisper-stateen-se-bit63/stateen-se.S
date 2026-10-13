// tenstorrent/whisper#120 item 28: with the hypervisor extension, bit 63 (SE) of
// mstateen1-3 must be writable and bit 63 of hstateen1-3 is always writable
// (smstateen.adoc). Check 1/2/3: mstateen1/2/3 bit 63 writable. Check 4/5/6:
// hstateen1/2/3 bit 63 writable. Check 7: with mstateen1.SE=1, an S-mode read of
// sstateen1 does not trap.
#include "common.h"
  .section .text.init
  .global _start
_start:
  HARNESS_INIT
  la t0, trap
  csrw mtvec, t0
#if __riscv_xlen == 64
  li t1, 1
  slli t1, t1, 63
#define M1 mstateen1
#define M2 mstateen2
#define M3 mstateen3
#define H1 hstateen1
#define H2 hstateen2
#define H3 hstateen3
#else
  li t1, 0x80000000
#define M1 mstateen1h
#define M2 mstateen2h
#define M3 mstateen3h
#define H1 hstateen1h
#define H2 hstateen2h
#define H3 hstateen3h
#endif
  csrs M1, t1; csrr t2, M1; and t2, t2, t1; FAIL_IF_EQZ(1, t2)
  csrs M2, t1; csrr t2, M2; and t2, t2, t1; FAIL_IF_EQZ(2, t2)
  csrs M3, t1; csrr t2, M3; and t2, t2, t1; FAIL_IF_EQZ(3, t2)
  csrs H1, t1; csrr t2, H1; and t2, t2, t1; FAIL_IF_EQZ(4, t2)
  csrs H2, t1; csrr t2, H2; and t2, t2, t1; FAIL_IF_EQZ(5, t2)
  csrs H3, t1; csrr t2, H3; and t2, t2, t1; FAIL_IF_EQZ(6, t2)
  li gp, 7
  li t0, -1                     // PMP entry 0: NAPOT over all memory, RWX
  csrw pmpaddr0, t0
  li t0, 0x1f
  csrw pmpcfg0, t0
  li t0, 0x1800                 // mstatus.MPP = S
  csrc mstatus, t0
  li t0, 0x0800
  csrs mstatus, t0
  la t0, smode
  csrw mepc, t0
  mret
smode:
  csrr t2, sstateen1            // must not trap
  ecall
  .align 2
trap:
  csrr t0, mcause
  li t1, 9                      // environment call from S-mode
  bne t0, t1, fail
  j pass
HARNESS_END
