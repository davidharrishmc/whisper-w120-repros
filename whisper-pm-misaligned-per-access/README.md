# Whisper: pointer masking is applied once to a misaligned access instead of to each part

zpm.adoc, norm:pm_misaligned_equivalence: "The behavior is identical to applying the pointer masking
transformation to every constituent aligned memory access." Whisper transforms the start address only and derives
the second part's address from it, so an access that crosses bit XLEN-PMLEN-1 uses an untransformed address for
its second part.

`pm-misaligned-per-access.S`: Sv48, S-mode accesses through MPRV=1/MPP=S, `menvcfg.PMM` = 11 (PMLEN = 16, the
transformation sign-extends bit 47). Page A is at VA 0x00007ffffffff000 and page B at VA 0xffff800000000000;
aligned loads from both work. An `ld` and an `sd` at 0x00007ffffffffffc must access A[0xffc..0xfff] and B[0..3]
(bytes 0x0000800000000000-3 transform to 0xffff800000000000-3); an address-misaligned exception or an access fault
is also accepted, a page fault is not.

Run: `./run.sh [path/to/whisper]` (prints PASS or FAIL and the failed checks; exit status 0 = pass). The ELF runs as
`whisper --maxinst 100000000:f --config whisper.json pm-misaligned-per-access.elf`; `whisper.json` is the
riscv-arch-test whisper-rv64-max configuration.

Whisper master fa18e475 (`master.out`): the `ld` takes a load page fault and the `sd` a store page fault, both with
`mtval` = 0x0000800000000000 (the untransformed, non-canonical address of the second part). With each part
transformed separately (`fixed.out`), both complete with the expected bytes.

Built with the riscv-arch-test act4 framework (`tests/env`, tree at 205129dbd8) and the check macros in
`include/sa.h` and `include/ai_macros.h` (the `.S` files include them as `../common/sa.h`): each `.S` was put in
a `<testdir>/ai/<Suite>/` directory and built with
`act config/whisper/whisper-rv64-max/test_config.yaml --test-dir <testdir> --extensions <Suite>`.

Other simulators (Spike c20813c, Sail master 81184531, stock Imperas Y-2026.09): Spike passes; Sail and Imperas fail the same way as Whisper.
