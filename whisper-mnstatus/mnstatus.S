// mnstatus.S: tenstorrent/whisper#120 item 27 (Smrnmi mnstatus MNPELP and MNPP).
// Hart: RV64 M/S/U, Zicfilp, Smrnmi, no H. Self-checking: runs every check and writes 1 to
// tohost when all pass, or (failmask << 1) | 1 otherwise (bit N-1 of failmask = check N).
//   check 1: mnstatus.MNPELP (bit 9) is writable with Zicfilp (smrnmi.adoc:94-95: "If the
//            Zicfilp extension is implemented, mnstatus also holds the MNPELP field").
//   check 2: MNRET to M-mode with mseccfg.MLPE=1 and MNPELP=1 sets ELP, so the instruction
//            at mnepc (not an lpad) raises a software-check exception (mcause 18)
//            (smrnmi.adoc:147-148: "MNRET sets ELP to the logical AND of yLPE and
//            mnstatus.MNPELP"). Needs check 1 (MNPELP is set by a CSR write).
//   check 3: mnstatus.MNPP never holds the reserved value 2 (smrnmi.adoc:86-88: MNPP is
//            "encoded in the same manner as mstatus.MPP"; machine.adoc:430: xPP "can hold
//            only privilege mode x and any implemented privilege mode lower than x").

#define MNEPC    0x741
#define MNSTATUS 0x744
#define MSECCFG  0x747
#define NMIE     (1 << 3)
#define MNPELP   (1 << 9)
#define MNPP_M   (3 << 11)
#define MNPP_RES (2 << 11)
#define MLPE     (1 << 10)

  .section .text.init, "ax"
  .globl _start
_start:
  la t0, trap
  csrw mtvec, t0
  li s0, 0                  // failure mask

check1:
  li t1, MNPELP | MNPP_M | NMIE
  csrw MNSTATUS, t1
  csrr t2, MNSTATUS
  li t4, MNPELP
  and t3, t2, t4
  bnez t3, check2
  ori s0, s0, 1

check2:
  la s1, check3             // trap handler resumes here
  li t1, MLPE
  csrs MSECCFG, t1
  la t1, target
  csrw MNEPC, t1
  li t1, MNPELP | MNPP_M | NMIE
  csrw MNSTATUS, t1
  .word 0x70200073          // mnret
target:
  nop                       // ELP=1 here: software-check exception expected
  li t1, MLPE               // no trap: check 2 failed
  csrc MSECCFG, t1
  ori s0, s0, 2

check3:
  li t1, MNPP_RES | NMIE
  csrw MNSTATUS, t1
  csrr t2, MNSTATUS
  srli t3, t2, 11
  andi t3, t3, 3
  li t4, 2
  bne t3, t4, done
  ori s0, s0, 4

done:
  slli a0, s0, 1
  ori a0, a0, 1
  la t0, tohost
  sd a0, 0(t0)
1: j 1b

  .p2align 2
trap:                       // expected only in check 2
  li t1, MLPE
  csrc MSECCFG, t1
  csrr t5, mcause
  li t6, 18                 // software check
  bne t5, t6, 1f
  csrr t5, mepc
  la t6, target
  beq t5, t6, 2f
1:ori s0, s0, 2
2:jr s1

  .section .tohost, "aw", @progbits
  .p2align 6
  .globl tohost
tohost: .dword 0
  .p2align 6
  .globl fromhost
fromhost: .dword 0
