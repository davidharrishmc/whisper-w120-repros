  .align 2
trap:
  csrr t5, mcause
  li t6, (99 << 1) | 1
write_tohost:
  li t0, 1 << 17; csrc mstatus, t0
#ifdef QEMU
  // QEMU virt: sifive test finisher; 0x5555 = pass, (n << 16) | 0x3333 = exit status n.
  li t0, 0x100000; srli t1, t6, 1; bnez t1, 2f
  li t1, 0x5555; sw t1, 0(t0)
1: j 1b
2: slli t1, t1, 16; li t2, 0x3333; or t1, t1, t2; sw t1, 0(t0)
1: j 1b
#else
  la t0, tohost
  sd t6, 0(t0)
1: j 1b
#endif
  .section .tohost, "aw"
  .align 3
  .globl tohost
tohost: .dword 0
  .globl fromhost
fromhost: .dword 0
