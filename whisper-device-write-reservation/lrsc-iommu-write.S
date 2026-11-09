// Whisper reproducer: a memory write by the IOMMU (a device other than a hart) to the bytes an LR read must make
// the SC fail.
// The hart (M-mode) sets up the IOMMU command queue and enqueues an IOFENCE.C command with AV = 1, which makes the
// IOMMU write DATA (32 bits) to ADDR. It then does lr.w on ADDR, rings the doorbell (cqt), checks that the IOMMU
// wrote ADDR, and does sc.w on ADDR with the value its LR read (a wrong success overwrites the device's data).
// Spec: unpriv/zalrsc.adoc norm:sc_other_device_write_fail "The SC must fail if a write from some other device to
//   the bytes accessed by the LR can be observed to occur between the LR and SC."; norm:sc_device_write_failure.
// IOMMU registers (RISC-V IOMMU spec): cqb 0x18, cqt 0x24, cqcsr 0x48. IOFENCE.C: opcode 2, func3 0, AV bit 10,
// DATA in bits 63:32 of the first doubleword, ADDR[63:2] in bits 61:0 of the second.
// tohost: 1 = pass (SC failed), 3 = FAIL (SC succeeded after the IOMMU wrote the bytes), 5 = setup problem.
// Build: riscv64-unknown-elf-gcc -march=rv64gc -mabi=lp64 -nostdlib -nostartfiles -T link.ld lrsc-iommu-write.S
//   -o lrsc-iommu-write.elf
#define IOMMU_BASE 0x30000000
#define DATA       0x5a5aa5a5
  .section .text.init, "ax"
  .globl _start
_start:
  csrr t0, mhartid
  bnez t0, .
  li s0, IOMMU_BASE
  // Command queue: 16 entries (LOG2SZ-1 = 3) at cq (4 KiB aligned)
  la t1, cq
  srli t1, t1, 12
  slli t1, t1, 10
  ori t1, t1, 3
  sd t1, 0x18(s0)          // cqb
  sw x0, 0x24(s0)          // cqt = 0
  li t1, 1
  sw t1, 0x48(s0)          // cqcsr.cqen = 1
  lw t1, 0x48(s0)
  li t2, 1 << 16           // cqcsr.cqon
  and t1, t1, t2
  bnez t1, 1f
  li t6, 5
  j finish
1:
  // cq[0] = IOFENCE.C AV=1, DATA, ADDR = X
  la t1, cq
  li t2, DATA
  slli t2, t2, 32
  ori t2, t2, (1 << 10) | 2
  sd t2, 0(t1)
  la t2, X
  srli t2, t2, 2           // ADDR[63:2]
  sd t2, 8(t1)
  fence
  la s1, X
  lr.w t3, (s1)            // t3 = 0x11111111
  li t1, 1
  sw t1, 0x24(s0)          // cqt = 1: the IOMMU executes the IOFENCE.C and writes DATA to X
  lw t4, 0(s1)
  li t2, DATA
  beq t4, t2, 2f
  li t6, 5                 // the IOMMU did not write X
  j finish
2:
  sc.w t5, t3, (s1)        // must fail: the IOMMU wrote the bytes the LR read
  li t6, 1
  bnez t5, finish
  li t6, 3
// t6 = result: 1 pass, 3 fail, 5 setup problem
finish:
  la t5, tohost
  .globl _test_exit
_test_exit:
  sd t6, 0(t5)
  j _test_exit

  .data
  .p2align 12
cq: .fill 256, 1, 0
  .p2align 6
X:  .word 0x11111111
  .section .tohost, "aw"
  .p2align 6
  .globl tohost
tohost: .dword 0
  .globl fromhost
fromhost: .dword 0
