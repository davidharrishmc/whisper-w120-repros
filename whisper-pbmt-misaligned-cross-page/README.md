# Whisper: a misaligned access that crosses a page uses the second page's PBMT for the first part

When a misaligned load or store crosses from a page with PBMT=PMA into a page with PBMT=IO, Whisper checks both
parts with PBMT=IO, so the first part (ordinary main memory) takes the access fault and `mtval` is the first
part's address. machine.adoc, norm:mtval_vaddr_wr_misaligned_addr: a nonzero `mtval` for a misaligned access fault
"will contain the virtual address of the portion of the access that caused the fault"; svpbmt.adoc: PBMT overrides
the PMAs "for the associated memory pages".

`pbmt-misaligned-cross-page.S`: Sv39, `menvcfg.PBMTE` = 1, S-mode accesses through MPRV=1/MPP=S. VA 0x40051000
maps page A (PBMT=0), VA 0x40052000 maps page B (PBMT=IO). It runs `ld` and `sd` at 0x40051ffc. Each may
complete, raise an address-misaligned exception, or raise an access fault with `mtval` = 0x40052000 (the part in
page B) or 0.

Run: `./run.sh [path/to/whisper]` (prints PASS or FAIL and the failed checks; exit status 0 = pass). The ELF runs
as `whisper --maxinst 100000000:f --config whisper.json pbmt-misaligned-cross-page.elf`; `whisper.json` is the
riscv-arch-test whisper-rv64-max configuration.

Whisper master fa18e475 (`master.out`): the `ld` takes a load access fault and the `sd` a store access fault,
both with `mtval` = 0x40051ffc. With each part checked against its own page's PBMT (`fixed.out`), both fault
with `mtval` = 0x40052000 and the test passes.

Built with the riscv-arch-test act4 framework (`tests/env`, tree at 205129dbd8) and the check macros in
`include/sa.h` and `include/ai_macros.h` (the `.S` files include them as `../common/sa.h`): each `.S` was put in
a `<testdir>/ai/<Suite>/` directory and built with
`act config/whisper/whisper-rv64-max/test_config.yaml --test-dir <testdir> --extensions <Suite>`.

Other simulators (Spike c20813c, Sail master 81184531, stock Imperas Y-2026.09): Spike, Sail and Imperas pass.
