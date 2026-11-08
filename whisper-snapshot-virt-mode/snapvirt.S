// Whisper snapshot restore must put the hart back in virtual mode the way a mode change does.
// The test enters VS-mode with mret and runs a nop sled there (run.sh saves a snapshot in the sled and
// restarts from it). After the sled, still in VS-mode, it checks that S-level CSR accesses reach the VS
// copies and that Smcntrpmf filters instret by the VS inhibit bit:
//   check 1: csrr sscratch reads vsscratch (0x1234), not sscratch (0x5a5a)
//   check 2: csrr sstatus reads vsstatus (SUM = 1), not mstatus (SUM = 0)
//   check 3: instret counts in VS-mode (minstretcfg.VSINH = 0; SINH = 1 would stop it in HS-mode)
//   check 4: csrw sscratch from VS-mode writes vsscratch
//   check 5: ... and leaves the HS sscratch (0x5a5a) unchanged
//   check 6: ecall from VS-mode traps to HS-mode (medeleg[10] = 1) with scause 10
//   check 7: an unexpected trap into M-mode, or the ecall came before VS-mode was reached
// The checks run in the HS-mode handler, so that no trap into M-mode is needed (on RV32, mstatush.MDT = 0 is
// not saved in the snapshot, so a trap into M-mode after the restore would be a double trap).
// x31 = bitmask of failed checks. tohost = (x31 << 1) | 1.
#include "exit.h"
#define VSSCRATCH 0x240
#define MSTATUS_SUM (1 << 18)
#if __riscv_xlen == 64
#define MDT_CLR     li t0, 1; slli t0, t0, 42; csrc mstatus, t0
#define MPV_SET     li t0, 1; slli t0, t0, 39; csrs mstatus, t0
#define INSTRET_CFG li t0, 1; slli t0, t0, 61; csrw 0x322, t0          /* minstretcfg: SINH = 1, VSINH = 0 */
#else
#define MDT_CLR     li t0, 1 << 10; csrc mstatush, t0
#define MPV_SET     li t0, 1 << 7; csrs mstatush, t0
#define INSTRET_CFG csrw 0x322, zero; li t0, 1 << 29; csrw 0x722, t0  /* minstretcfgh: SINH = 1, VSINH = 0 */
#endif

  .option norelax
  .section .text.init
  .globl _start
_start:
  li x31, 0
  li t0, -1; csrw pmpaddr0, t0; li t0, 0x0f; csrw pmpcfg0, t0
  la t0, mhandler; csrw mtvec, t0
  la t0, shandler; csrw stvec, t0
  li t0, 1 << 10; csrs medeleg, t0     // ecall from VS-mode traps to HS-mode
  MDT_CLR                              // mstatus.MDT = 0 (Smdbltrp) and
  li t0, 8; csrs 0x744, t0             // mnstatus.NMIE = 1 (Smrnmi): traps into M are expected traps
  csrw satp, zero; csrw vsatp, zero; csrw hgatp, zero
  li t0, 0x5a5a; csrw sscratch, t0
  li t0, 0x1234; csrw VSSCRATCH, t0
  li t0, MSTATUS_SUM; csrc mstatus, t0; csrs vsstatus, t0
  li t0, 4; csrs mcounteren, t0; csrs hcounteren, t0   // IR: instret readable in VS-mode
  INSTRET_CFG
  li t0, 0x1800; csrc mstatus, t0; li t0, 0x0800; csrs mstatus, t0   // MPP = S
  MPV_SET                                                            // MPV = 1
  la t0, vs_code; csrw mepc, t0
  li s1, 0                             // s1 = 1 once in VS-mode
  mret

vs_code:                               // VS-mode
  li s1, 1
  .rept 64                             // run.sh saves the snapshot in this sled
  nop
  .endr
  .globl vs_check
vs_check:
  csrr a0, sscratch
  csrr a1, sstatus
  rdinstret a2
  nop
  nop
  rdinstret a3
  li t0, 0x777; csrw sscratch, t0
  ecall

  .align 2
shandler:                              // HS-mode
  csrr t0, scause; CHECKC(6, t0, 10)
  beqz s1, unexpected
  CHECKC(1, a0, 0x1234)
  li t0, MSTATUS_SUM; and t1, a1, t0; CHECKC(2, t1, MSTATUS_SUM)
  sub t1, a3, a2; bnez t1, 1f; li t5, 1 << 3; or x31, x31, t5; 1:
  csrr t1, VSSCRATCH; CHECKC(4, t1, 0x777)
  csrr t1, sscratch;  CHECKC(5, t1, 0x5a5a)
  j done
  .align 2
mhandler:                              // no trap into M-mode is expected
unexpected:
  li t0, 1 << 7; or x31, x31, t0
done:
  EXIT

  .section .tohost, "aw"
  .align 3
  .globl tohost
tohost: .dword 0
  .globl fromhost
fromhost: .dword 0
