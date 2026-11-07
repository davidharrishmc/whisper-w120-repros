// DRET must apply the Sdext resume rules (Sdext.adoc, Resume):
//   "If the new privilege mode is less privileged than M-mode, MPRV in mstatus is cleared."
//   "If the Smdbltrp extension is implemented and the new privilege mode is not M, then the MDT bit is set to 0."
//   "If the Ssdbltrp extension is implemented and the new privilege mode is U, VS, or VU, then sstatus.SDT is
//    set to 0. Additionally, if it is VU, then vsstatus.SDT is also set to 0."
// The test enters Debug Mode with ebreak (dcsr.ebreakm resets to 1 in whisper.json; debug_park_loop = park).
// For each new mode (M, S, U, VS, VU) it sets mstatus.MPRV = MDT = SDT = 1 and vsstatus.SDT = 1 in Debug Mode,
// resumes with dret into that mode, where an ebreak (dcsr.ebreak{s,u,vs,vu} = 1) re-enters Debug Mode at once,
// and checks mstatus.MPRV, mstatus.MDT, mstatus.SDT and vsstatus.SDT there.
// x31 = bitmask of failed checks; check 1 + 4*step + field, step M=0 S=1 U=2 VS=3 VU=4,
// field MPRV=0 MDT=1 SDT=2 vsstatus.SDT=3. tohost = (x31 << 1) | 1.
#include "exit.h"
#define DCSR 0x7b0
#define DPC  0x7b1
#define DRET .word 0x7b200073
#define EBREAK_ALL 0x3b000            // dcsr.ebreakvs | ebreakvu | ebreakm | ebreaks | ebreaku
#define MPRV_SH 17
#define SDT_SH  24
#if __riscv_xlen == 64
#define MDT_SET  li t0, 1; slli t0, t0, 42; csrs mstatus, t0
#define MPV_CLR  li t0, 1; slli t0, t0, 39; csrc mstatus, t0
#define MDT_GET(r) csrr r, mstatus; srli r, r, 42
#define DTE_ON   li t0, 1; slli t0, t0, 59; csrs menvcfg, t0; csrs henvcfg, t0
#else
#define MDT_SET  li t0, 1 << 10; csrs mstatush, t0
#define MPV_CLR  li t0, 1 << 7; csrc mstatush, t0
#define MDT_GET(r) csrr r, mstatush; srli r, r, 10
#define DTE_ON   li t0, 1 << 27; csrs menvcfgh, t0; csrs henvcfgh, t0
#endif

// Set the four bits, resume in mode (prv, v) at guest_ebreak, come back at after_<n>, check the bits.
#define STEP(n, prv, v, e_mprv, e_mdt, e_sdt, e_vsdt) \
  li t0, (1 << MPRV_SH) | (1 << SDT_SH) | 0x1800; csrs mstatus, t0;  /* MPP = M */ \
  MDT_SET; \
  MPV_CLR; \
  li t0, 1 << SDT_SH; csrs vsstatus, t0; \
  csrr t0, DCSR; andi t0, t0, ~0x23; ori t0, t0, (prv) | ((v) << 5); csrw DCSR, t0; \
  la t0, guest_ebreak; csrw DPC, t0; \
  la s0, after_##n; \
  DRET; \
after_##n: \
  csrr t1, mstatus; csrr t2, vsstatus; \
  srli t3, t1, MPRV_SH; andi t3, t3, 1; CHECKC(1 + 4*n + 0, t3, e_mprv); \
  MDT_GET(t3);          andi t3, t3, 1; CHECKC(1 + 4*n + 1, t3, e_mdt); \
  srli t3, t1, SDT_SH;  andi t3, t3, 1; CHECKC(1 + 4*n + 2, t3, e_sdt); \
  srli t3, t2, SDT_SH;  andi t3, t3, 1; CHECKC(1 + 4*n + 3, t3, e_vsdt)

  .option norelax
  .section .text.init
  .globl _start
_start:
  li x31, 0
  li t0, -1; csrw pmpaddr0, t0; li t0, 0x0f; csrw pmpcfg0, t0
  la t0, mhandler; csrw mtvec, t0
  DTE_ON                               // menvcfg.DTE = henvcfg.DTE = 1 (Ssdbltrp on for S and VS)
  csrw satp, zero; csrw vsatp, zero; csrw hgatp, zero
  la s0, debug_start
  ebreak                               // dcsr.ebreakm = 1: enter Debug Mode at park
  li t0, 1 << 30; or x31, x31, t0     // not reached
  j done

debug_start:                           // in Debug Mode
  csrr t0, DCSR; li t1, EBREAK_ALL; or t0, t0, t1; csrw DCSR, t0
  STEP(0, 3, 0, 1, 1, 1, 1)            // M:  nothing cleared
  STEP(1, 1, 0, 0, 0, 1, 1)            // S:  MPRV, MDT cleared
  STEP(2, 0, 0, 0, 0, 0, 1)            // U:  MPRV, MDT, SDT cleared
  STEP(3, 1, 1, 0, 0, 0, 1)            // VS: MPRV, MDT, SDT cleared
  STEP(4, 0, 1, 0, 0, 0, 0)            // VU: MPRV, MDT, SDT, vsstatus.SDT cleared
done:
  EXIT

guest_ebreak:                          // runs in the new mode; dcsr.ebreak<mode> = 1 re-enters Debug Mode
  ebreak
  li t0, 1 << 29; or x31, x31, t0     // not reached
  j done

  .align 2
mhandler:                              // no trap is expected
  li t0, 1 << 28; or x31, x31, t0
  j done

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
