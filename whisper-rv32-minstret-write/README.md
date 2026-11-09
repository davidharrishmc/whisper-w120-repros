# Whisper (RV32): an instruction that writes minstret or minstreth is still counted in minstret

- unpriv/zicsr.adoc:173-180: "Some CSRs, such as the instructions-retired counter, instret, may be modified as side
  effects of instruction execution. In these cases, if a CSR access instruction reads a CSR, it reads the value
  prior to the execution of the instruction. If a CSR access instruction writes such a CSR, the explicit write is
  done instead of the update from the side effect. In particular, a value written to instret by one instruction
  will be the value read by the following instruction."
- priv/machine.adoc:1552-1553, norm:mcycleh_minstreth_mhpmh_op: on RV32, "reads of the mcycleh, minstreth,
  mhpmcounternh, and mhpmeventnh CSRs return bits 63-32 of the corresponding register, and writes change only bits
  63-32."
- riscv/riscv-isa-manual#1255: minstret is one 64-bit counter and a write of minstreth is a write of it, so the
  write replaces the instruction's increment of the whole counter. riscv-tests `isa/rv32mi/instret_overflow`
  (test cases 3 and 4) checks this.

`whisper-rv32-minstret-write.S` (RV32, M-mode, mcountinhibit = 0) writes one half right after the other, with no
instruction in between, and reads the other half with the next instruction. It fails with a bitmask of failed
checks; `run.sh` decodes it. On RV64 it does nothing (passes).

Run: `./run.sh path/to/whisper`. `whisper.json` is the riscv-arch-test whisper-rv32-max configuration. The ELF was
built with the riscv-arch-test (ACT4) framework (`tests_ai` self-checking harness, Sail as the reference model);
the `.S` file is the source.

Whisper master fa18e475 (`master.out`) fails all five checks:

```
minstret = 0x10;              csrw minstreth, 5:  next csrr minstret = 0x11        (expected 0x10)
minstret = 0xffffffff;        csrw minstreth, 7:  next csrr minstret = 0           (expected 0xffffffff)
minstret = 0x0_ffffffff;      csrw minstret, 5:   next csrr minstreth = 1          (expected 0)
csrw minstret, -1; csrw minstreth, -1; nop:       csrr minstret = 1, minstreth = 0xffffffff (expected 0, 0)
```

Whisper increments the 64-bit counter before the write and then overwrites only the half that was written. With
the increment dropped for writes of minstret and minstreth (`fixed.out`), it passes.

Other simulators: Spike c20813c, Sail master 81184531 (RV32 configuration) and stock Imperas Y-2026.09 (rv32gck)
pass.
