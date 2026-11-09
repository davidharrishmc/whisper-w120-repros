# Whisper: mstatus.MXR and mstatus.TVM are writable when satp is Bare-only

On a hart with S-mode whose `satp.MODE` is read-only zero (only Bare translation), the ISA manual's main branch
makes MXR and TVM read-only zero, as it does SUM (machine.adoc norm:mstatus_mxr_rdonly0_no_smode,
norm:mstatus_tvm_acc, added by riscv/riscv-isa-manual#2978; norm:mstatus_sum_rdonly0). Whisper makes only SUM
read-only zero, so MXR and TVM can be set, and TVM = 1 then makes S-mode accesses to `satp` illegal.

`whisper-sbare-mxr-tvm.S` (RV64) first checks that `satp.MODE` is read-only zero (otherwise it checks nothing), then:

- sets MXR with `csrs mstatus` and checks that it reads 0;
- sets TVM with `csrs mstatus` and checks that it reads 0;
- with TVM written 1, goes to S-mode and executes `csrr satp` then `ecall`, and checks that the first trap is the
  ecall (mcause 9) and not an illegal-instruction exception on `csrr satp` (mcause 2).

Each failed check prints an `SA-MISMATCH` line; the test passes when all three hold.

Run: `./run.sh path/to/whisper` (exit status 0 = pass). `whisper-rv64.json` is riscv-arch-test's
`config/whisper/whisper-rv64-max/whisper.json` with h, svadu, svinval, svnapot, svpbmt, svvptc, ssnpm, smdbltrp and
smrnmi removed from the isa string, `"address_translation_modes": ["bare"]` and `"address_translation_pmms": ["off"]`.

Whisper master fa18e475:

```
FAIL whisper-sbare-mxr-tvm-rv64.elf
  SA-MISMATCH: mstatus.MXR after csrs (read-only 0 with a Bare-only satp) expect=0x0000000000000000 got=0x0000000000000001
  SA-MISMATCH: mstatus.TVM after csrs (read-only 0 with a Bare-only satp) expect=0x0000000000000000 got=0x0000000000000001
  SA-MISMATCH: first trap after S-mode csrr satp with TVM written 1 (9 = the ecall; 2 = csrr satp was illegal) expect=0x0000000000000009 got=0x0000000000000002
  RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
```

With the fix, it passes.

The ELF was built with the riscv-arch-test act4 framework (riscv/riscv-arch-test#3162, commit 205129dbd8, for an
RV64 S-mode configuration with Bare-only translation); `sa.h` has the `SA_SOFT` check macros. Rebuilding needs
that framework.

Other simulators (Spike c20813c, Sail master 81184531, stock Imperas Y-2026.09), with the same test built for each: Sail (S-mode with only Svbare in `sail.json`) and Imperas (`Sv_modes=1`) fail the same three checks. Spike makes MXR, SUM and TVM read-only zero when there is no MMU (`has_page` in riscv/csrs.cc), but running it Bare-only needs a device tree with `mmu-type = "riscv,sbare"`, so it was not run; on the configurations with Sv modes the test checks nothing and passes on all three.
