// Two-hart LR/SC test: a cbo.zero by another hart must invalidate this hart's reservation.
// Hart 0: lr.d on A, then waits for hart 1; hart 1 writes A (VARIANT 1: sw, the control; VARIANT 2: cbo.zero on
// A's cache block), then sets F2; hart 0 then does sc.d on A, writing back the value its LR read (so a wrong
// success is a lost update of hart 1's write).
// Spec: unpriv/zalrsc.adoc norm:sc_other_hart_store_fail "The SC must fail if a store to the reservation set from
//   another hart can be observed to occur between the LR and SC."; unpriv/cmo.adoc norm:cbo-zero_op "A cbo.zero
//   instruction performs stores of zeros to the full set of bytes corresponding to the cache block".
// tohost: 1 = pass (SC failed), 3 = FAIL (SC succeeded after the other hart's write), 5 = setup problem.
// Build: riscv64-unknown-elf-gcc -march=rv64gc_zicboz -mabi=lp64 -nostdlib -nostartfiles -T link.ld -DVARIANT=2
//   [-DIMPERAS] lrsc-cbo-zero-2h.S -o lrsc-cbo-zero-2h.elf
  .section .text.init, "ax"
  .globl _start
_start:
  csrr t0, mhartid
  la s1, F1
  la s2, F2
  bnez t0, hart1
hart0:
  la s0, A
0: lw t1, 0(s1)            // wait for hart 1 to be ready
  li t2, 1
  bne t1, t2, 0b
  lr.d t2, (s0)
  li t1, 2
  sw t1, 0(s1)             // F1 = 2: LR done
1: lw t1, 0(s2)            // wait for hart 1's write
  beqz t1, 1b
  mv t3, t2                // write back the value read by the LR
  sc.d t4, t3, (s0)
  li t6, 1
  bnez t4, finish          // SC failed: pass
  // SC succeeded: check that hart 1's write really happened first (it is lost now)
  li t6, 3
  j finish

hart1:
  li t1, 1
  sw t1, 0(s1)             // F1 = 1: ready
0: lw t1, 0(s1)
  li t2, 2
  bne t1, t2, 0b
  la s0, A
#if VARIANT == 1
  li t1, 0x55
  sw t1, 0(s0)
#elif VARIANT == 2
  cbo.zero (s0)
#endif
  ld t2, 0(s0)             // the write must have changed A
  li t1, 0x1111111111111111
  bne t2, t1, 2f
  li t6, 5
  j finish
2: li t1, 1
  sw t1, 0(s2)             // F2 = 1
5: j 5b

// t6 = result: 1 pass, 3 fail, 5 setup problem
finish:
#ifdef IMPERAS
  la t0, msg_pass
  li t1, 1
  beq t6, t1, 6f
  la t0, msg_fail
  li t1, 3
  beq t6, t1, 6f
  la t0, msg_setup
6: lbu t1, 0(t0)
  beqz t1, 7f
  li t2, 0x10010000
  sw t1, 0(t2)
  addi t0, t0, 1
  j 6b
7:
#endif
  la t5, tohost
  .globl _test_exit
_test_exit:
  sd t6, 0(t5)
  j _test_exit

  .data
  .p2align 6
A:  .dword 0x1111111111111111
  .p2align 6
F1: .word 0
  .p2align 6
F2: .word 0
msg_pass: .string "MH-RESULT: PASS (SC failed)\n"
msg_fail: .string "MH-RESULT: FAIL (SC succeeded after the other hart wrote the reservation set)\n"
msg_setup: .string "MH-RESULT: SETUP PROBLEM\n"
  .section .tohost, "aw"
  .p2align 6
  .globl tohost
tohost: .dword 0
  .globl fromhost
fromhost: .dword 0
