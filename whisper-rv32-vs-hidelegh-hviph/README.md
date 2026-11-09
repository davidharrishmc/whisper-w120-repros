# Whisper, RV32: VS-mode can read and write hidelegh and hviph

`hidelegh` (0x613) and `hviph` (0x655) are the high halves of the hypervisor CSRs `hideleg` and `hvip`
(Smaia/Ssaia). On RV32, a VS-mode access to a high-half hypervisor CSR whose low half HS-mode can access in the
same way raises a virtual-instruction exception (hypervisor.adoc, norm:H_virtinst_vu_vs32_high_allowedhs_tvm0).
Whisper lets VS-mode read and write both.

`rv32-vs-hidelegh-hviph.S`: for each CSR, checks that an HS-mode read works (skips the CSR otherwise), then that a
VS-mode read (`csrrs x7, csr, x0`) and a VS-mode write-form access (`csrrs x7, csr, x20`, x20 = 0) each raise
mcause 22.

Run: `./run.sh [path/to/whisper]` (prints PASS or FAIL and the failed checks; exit status 0 = pass). The ELF runs as
`whisper --maxinst 100000000:f --config whisper.json rv32-vs-hidelegh-hviph.elf`; `whisper.json` is the
riscv-arch-test whisper-rv32-max configuration.

Whisper master fa18e475 (`master.out`): none of the four VS-mode accesses traps. With both CSRs marked as hypervisor
CSRs (`fixed.out`), the test passes.

Built with the riscv-arch-test act4 framework (`tests/env`, tree at 205129dbd8) and the check macros in
`include/sa.h` and `include/ai_macros.h` (the `.S` files include them as `../common/sa.h`): each `.S` was put in
a `<testdir>/ai/<Suite>/` directory and built with
`act config/whisper/whisper-rv32-max/test_config.yaml --test-dir <testdir> --extensions <Suite>`.

Other simulators (Spike c20813c, Sail master 81184531, stock Imperas Y-2026.09): Spike passes (all four accesses raise mcause 22). Sail has no AIA, so the test does nothing there; Imperas has no RV32 configuration with H.
