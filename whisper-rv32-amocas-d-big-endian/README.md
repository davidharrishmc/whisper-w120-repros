# Whisper (RV32): big-endian amocas.d compares the register pair in one order and stores it in the other

unpriv/zacas.adoc:42-47, norm:Zacas_rv32_amocas-d_op: "For RV32, amocas.d atomically loads 64-bits of a data value
from address in rs1, compares the loaded value to a 64-bit value held in a register pair consisting of rd and
rd+1, and if the comparison is bitwise equal, then stores the 64-bit value held in the register pair rs2 and rs2+1
to the original address in rs1. The value loaded from memory is placed into the register pair rd and rd+1." The
listing that follows maps both pairs to memory by address: `temp0 = mem[X(rs1)+0]`, `temp1 = mem[X(rs1)+4]`,
`mem[X(rs1)+0] = swap0`, `mem[X(rs1)+4] = swap1`, `X(rd) = temp0`, `X(rd+1) = temp1`. Whatever pairing applies under
big-endian, the load, the compare and the store must use the same one.

`whisper-rv32-amocas-d-big-endian.S` (RV32, M-mode) sets mstatush.MBE = 1 (skipped if MBE is read-only 0), stores
A = 0x11112222 at +0 and B = 0x33334444 at +4 with `sw`, and does three `amocas.d`: one with rd = rs2 = 0 that
fails and returns the memory pair R, one with rd = R and rs2 = {C = 0x55556666, D = 0x77778888} that must succeed,
and one with rd = rs2 = 0 that must return {C, D}. R is {A, B} if the pairs map to memory by address (the listing)
or {B, A} if by value (rd = low-order word); the store of {C, D} must use the same pairing (checked with `lw`). The
same sequence then runs with MBE = 0 as a control. It fails with a bitmask of failed checks; `run.sh` decodes it.

Run: `./run.sh path/to/whisper`. `whisper.json` is the riscv-arch-test whisper-rv32-max configuration. The ELF was
built with the riscv-arch-test (ACT4) framework (`tests_ai` self-checking harness, Sail as the reference model);
the `.S` file is the source.

Whisper master fa18e475 (`master.out`): with MBE = 1 the first `amocas.d` returns (x6, x7) = (B, A): it reads the
doubleword as one big-endian value and puts its low-order word (the one at +4) in rd. The successful `amocas.d`
then stores C at +0 and D at +4, and the third returns (D, C). Little-endian passes. With the loaded doubleword
split by address (`fixed.out`), the first returns (A, B), the third (C, D), and the test passes.

Other simulators: Spike c20813c and Sail master 81184531 keep mstatush.MBE read-only 0, so the test skips the
check. Stock Imperas Y-2026.09 (rv32gck) passes: it pairs the registers by value (rd = low-order word) for both
the read and the store, so the first amocas.d returns (B, A) and the third (C, D).
