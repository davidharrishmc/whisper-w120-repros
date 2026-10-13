// Write MODE to satp from M-mode, read it back. If the write took, enter S-mode
// (translated fetch) and come back with ecall. Exit code = MODE read back.
  .text
  .globl _start
_start:
  la t0, mtrap
  csrw mtvec, t0
  li t0, -1
  csrw pmpaddr0, t0
  li t0, 0x1f            // NAPOT, RWX
  csrw pmpcfg0, t0
  li t0, MODE
  slli t0, t0, 60
  csrw satp, t0
  csrr a0, satp
  srli a0, a0, 60
  beqz a0, exit
  li t0, 3 << 11
  csrc mstatus, t0
  li t0, 1 << 11         // MPP = S
  csrs mstatus, t0
  la t0, smode
  csrw mepc, t0
  mret
smode:
  ecall
mtrap:
exit:
  slli a1, a0, 1
  ori a1, a1, 1
  la t1, tohost
  sd a1, 0(t1)
1:j 1b
  .data
  .align 3
  .globl tohost
tohost: .dword 0
