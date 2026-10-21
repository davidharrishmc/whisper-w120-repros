# Reproducer: with menvcfg.STCE = henvcfg.STCE = 1 and vstimecmp = 0, hip.VSTIP must be 1, because
# time + htimedelta >= 0 always holds (Hypervisor spec, vstimecmp: "A virtual supervisor timer interrupt
# becomes pending, as reflected in the VSTIP bit in the hip register, whenever (time + htimedelta),
# truncated to 64 bits, contains a value greater than or equal to vstimecmp").
# Everything runs in M-mode.  Each case waits up to 64 iterations for the bit, then records it.
#   A: stimecmp = 0             -> mip.STIP  (control: the S-level timer)
#   B: vstimecmp = 0            -> hip.VSTIP
#   C: hvip.VSTIP = 1 then 0, with vstimecmp = 0 -> hip.VSTIP (hvip clear must not hide the timer)
#   D: vstimecmp = 0             -> mip.VSTIP (the same bit through mip)
#   E: vstimecmp = 0, hie.VSTIE = 1, mstatus.MPRV = 0, mret to HS-mode with sstatus.SIE = 1 and
#      hideleg = 0: VSTI must be taken in HS-mode (scause = 0x8000000000000006)
# Exit code: bit 0 = A wrong, bit 1 = B wrong, bit 2 = C wrong, bit 3 = D wrong, bit 4 = E wrong.

#define MIP_STIP  (1 << 5)
#define MIP_VSTIP (1 << 6)

  .section .text.init
  .globl _start
_start:
  li    s1, 0
  li    t0, -1
  csrw  mcounteren, t0
  li    t0, 1
  slli  t0, t0, 63
  csrs  menvcfg, t0        # menvcfg.STCE = 1
  csrs  henvcfg, t0        # henvcfg.STCE = 1
  csrw  htimedelta, zero
  csrw  hvip, zero
  li    t0, -1
  csrw  stimecmp, t0
  csrw  vstimecmp, t0

  # A: stimecmp = 0 -> STIP
  csrw  stimecmp, zero
  li    a1, MIP_STIP
  call  wait_mip
  bnez  a0, 1f
  ori   s1, s1, 1
1:
  # B: vstimecmp = 0 -> VSTIP
  csrw  vstimecmp, zero
  li    a1, MIP_VSTIP
  call  wait_hip
  bnez  a0, 1f
  ori   s1, s1, 2
1:
  # C: hvip.VSTIP set then cleared with vstimecmp still 0
  li    t0, MIP_VSTIP
  csrs  hvip, t0
  csrc  hvip, t0
  li    a1, MIP_VSTIP
  call  wait_hip
  bnez  a0, 1f
  ori   s1, s1, 4
1:
  # D: mip.VSTIP
  li    a1, MIP_VSTIP
  call  wait_mip
  bnez  a0, 1f
  ori   s1, s1, 8
1:
  # E: take VSTI in HS-mode
  la    t0, strap
  csrw  stvec, t0
  la    t0, mtrap
  csrw  mtvec, t0
  li    t0, -1
  csrw  mideleg, t0          # delegate S-level (VS-level are read-only one) to HS
  csrw  hideleg, zero
  li    t0, MIP_VSTIP
  csrw  hie, t0
  csrsi sstatus, 2           # SIE = 1
  li    t0, 0x1800
  csrc  mstatus, t0
  li    t0, 0x0800
  csrs  mstatus, t0          # MPP = S
  la    t0, in_hs
  csrw  mepc, t0
  mret
in_hs:
  li    t2, 64
3: addi t2, t2, -1
  bnez  t2, 3b
  ori   s1, s1, 16           # not taken
  ecall                      # back to M-mode
strap:                       # VSTI taken: check scause, return to M
  csrr  t0, scause
  li    t1, 0x8000000000000006
  beq   t0, t1, 4f
  ori   s1, s1, 16
4: csrw hie, zero
  ecall
mtrap:
  slli  t0, s1, 1
  ori   t0, t0, 1
  la    t1, tohost
  sd    t0, 0(t1)
2: j 2b

# wait_mip(a1 = mask): a0 = mip & mask, polling up to 64 times
wait_mip:
  li    t2, 64
1: csrr a0, mip
  and   a0, a0, a1
  bnez  a0, 2f
  addi  t2, t2, -1
  bnez  t2, 1b
2: ret
# wait_hip(a1 = mask): a0 = hip & mask, polling up to 64 times
wait_hip:
  li    t2, 64
1: csrr a0, hip
  and   a0, a0, a1
  bnez  a0, 2f
  addi  t2, t2, -1
  bnez  t2, 1b
2: ret

  .section .tohost, "aw", @progbits
  .balign 64; .globl tohost;   tohost:   .dword 0
  .balign 64; .globl fromhost; fromhost: .dword 0
