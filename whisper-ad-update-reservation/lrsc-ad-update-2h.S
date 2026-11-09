// Two-hart LR/SC test: a hardware A/D-bit update (Svadu, menvcfg.ADUE = 1) by another hart's page-table walk must
// invalidate this hart's reservation on the PTE.
// Hart 1 sets up Sv39: VA 0x40000000 -> page D through the leaf PTE pt_l0[0], with A = 0 (VARIANT 4) or A = 1,
// D = 0 (VARIANT 5). Hart 0 does lr.d on that PTE. Hart 1 then loads (VARIANT 4) or stores (VARIANT 5) through
// the VA with MPRV = 1, MPP = S, so its page-table walk sets A (or D) in the PTE, and checks that it did. Hart 0
// then does sc.d of the value its LR read, which would clear the A (D) bit again. VARIANT 1 (control): hart 1
// writes the PTE with an ordinary sd that sets A.
// Spec: unpriv/zalrsc.adoc norm:sc_other_hart_store_fail "The SC must fail if a store to the reservation set from
//   another hart can be observed to occur between the LR and SC."; priv/supervisor.adoc (Svadu): the A/D update
//   is a write of the PTE that "must be atomic with respect to other accesses to the PTE".
// tohost: 1 = pass (SC failed), 3 = FAIL (SC succeeded after the other hart's A/D update), 5 = setup problem.
// Build: riscv64-unknown-elf-gcc -march=rv64gc -mabi=lp64 -nostdlib -nostartfiles -T link.ld -DVARIANT=4 [-DWHISPER]
//   [-DIMPERAS] lrsc-ad-update-2h.S -o lrsc-ad-update-2h.elf   (WHISPER sets mnstatus.NMIE, else Smrnmi ignores MPRV)
#define PTE_V 1
#define PTE_R 2
#define PTE_W 4
#define PTE_A 0x40
#define PTE_D 0x80
  .section .text.init, "ax"
  .globl _start
_start:
  csrr t0, mhartid
  la s1, F1
  la s2, F2
  bnez t0, hart1
hart0:
  la s0, pt_l0             // the leaf PTE for VA 0x40000000 is pt_l0[0]
0: lw t1, 0(s1)            // wait for hart 1 to be ready (it has set up the page tables)
  li t2, 1
  bne t1, t2, 0b
  lr.d t2, (s0)
  li t1, 2
  sw t1, 0(s1)             // F1 = 2: LR done
1: lw t1, 0(s2)            // wait for hart 1's A/D update
  beqz t1, 1b
  mv t3, t2                // write back the value read by the LR (loses the A/D bit)
  sc.d t4, t3, (s0)
  li t6, 1
  bnez t4, finish          // SC failed: pass
  li t6, 3
  j finish

hart1:
#ifdef WHISPER
  csrsi 0x744, 8           // mnstatus.NMIE = 1 (Smrnmi: MPRV has no effect while NMIE = 0)
#endif
  // PMP entry 0: NAPOT over all memory, RWX (S-mode accesses and the page-table walk need a matching entry)
  li t1, -1
  csrw pmpaddr0, t1
  li t1, 0x1f
  csrw pmpcfg0, t1
  // Sv39: root[1] -> pt_l1, pt_l1[0] -> pt_l0, pt_l0[0] = leaf for VA 0x40000000 -> page D
  la t1, pt_l1
  srli t1, t1, 12
  slli t1, t1, 10
  ori t1, t1, PTE_V
  la t2, pt_root
  sd t1, 8(t2)
  la t1, pt_l0
  srli t1, t1, 12
  slli t1, t1, 10
  ori t1, t1, PTE_V
  la t2, pt_l1
  sd t1, 0(t2)
  la t1, D
  srli t1, t1, 12
  slli t1, t1, 10
#if VARIANT == 5
  ori t1, t1, PTE_V|PTE_R|PTE_W|PTE_A
#else
  ori t1, t1, PTE_V|PTE_R|PTE_W
#endif
  la t2, pt_l0
  sd t1, 0(t2)
  la t1, pt_root
  srli t1, t1, 12
  li t2, 8
  slli t2, t2, 60
  or t1, t1, t2
  csrw satp, t1
  sfence.vma
  // menvcfg.ADUE = 1 (bit 61): hardware A/D updates
  li t1, 1
  slli t1, t1, 61
  csrs menvcfg, t1
  csrr t2, menvcfg
  and t2, t2, t1
  bnez t2, 3f
  li t6, 5
  j finish
3:
  li t1, 1
  sw t1, 0(s1)             // F1 = 1: ready
0: lw t1, 0(s1)
  li t2, 2
  bne t1, t2, 0b
#if VARIANT == 1
  la t2, pt_l0             // control: an ordinary store sets A
  ld t1, 0(t2)
  ori t1, t1, PTE_A
  sd t1, 0(t2)
#else
  // M-mode, MPRV = 1, MPP = S: a load (V4) or store (V5) through VA 0x40000000 makes the walk set A (or D)
  li t1, (3 << 11)
  csrc mstatus, t1         // MPP = 0
  li t1, (1 << 17) | (1 << 11)
  csrs mstatus, t1         // MPRV = 1, MPP = S
  li t3, 0x40000000
#if VARIANT == 4
  ld t2, 0(t3)
#else
  sd x0, 0(t3)
#endif
  li t1, (1 << 17)
  csrc mstatus, t1
#endif
  // check that A (V1, V4) or A and D (V5) are now set
  la t2, pt_l0
  ld t2, 0(t2)
  andi t2, t2, PTE_A|PTE_D
#if VARIANT == 5
  li t1, PTE_A|PTE_D
#else
  li t1, PTE_A
#endif
  beq t2, t1, 4f
  li t6, 5
  j finish
4: li t1, 1
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
  .p2align 12
pt_root: .fill 512, 8, 0
pt_l1:   .fill 512, 8, 0
pt_l0:   .fill 512, 8, 0
D:       .fill 4096, 1, 0x44
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
