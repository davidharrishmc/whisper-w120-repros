// vsetvl with vtype.vsew = 4 (SEW = 128, reserved). Exit code 0 if vill is set
// (the expected result), 1 if the vtype was accepted.
  .text
  .globl _start
_start:
  li t0, 1 << 9          // mstatus.VS = Initial
  csrs mstatus, t0
  li t1, 4 << 3          // vsew = 4, vlmul = 1
  li t2, 4
  vsetvl t3, t2, t1
  csrr a0, vtype
  srli a0, a0, 63        // vill
  xori a0, a0, 1
  slli a1, a0, 1
  ori a1, a1, 1
  la t1, tohost
  sd a1, 0(t1)
1:j 1b
  .data
  .align 3
  .globl tohost
tohost: .dword 0
