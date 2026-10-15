// common.h: shared setup for the tcontrol reproducers (RV64, M/S/U, Sdtrig).
#define TSELECT  0x7a0
#define TDATA1   0x7a1
#define TDATA2   0x7a2
#define TCONTROL 0x7a5

// M-mode setup: trap vector, a PMP entry that gives S/U access to all memory, no delegation,
// tcontrol.mte = tcontrol.mpte = 0.
.macro SETUP_M
  la t0, trap
  csrw mtvec, t0
  li t0, -1
  csrw pmpaddr0, t0
  li t0, 0x1f                 // NAPOT, RWX
  csrw pmpcfg0, t0
  csrw medeleg, zero
  csrw mideleg, zero
  csrw TCONTROL, zero
.endm

// mret to label in S-mode.
.macro GOTO_S label
  li t0, 3 << 11
  csrc mstatus, t0
  li t0, 1 << 11              // MPP = S
  csrs mstatus, t0
  la t0, \label
  csrw mepc, t0
  mret
.endm

// Write a0 to tohost and stop.
.macro EXIT
  la t1, tohost
  sd a0, 0(t1)
1:
  j 1b
.endm

.macro TOHOST
  .section .tohost, "aw"
  .align 3
  .globl tohost
tohost:
  .dword 0
  .globl fromhost
fromhost:
  .dword 0
.endm
