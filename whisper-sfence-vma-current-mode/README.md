# Whisper: SFENCE.VMA with rs1 != x0 sizes TLB entries with the current satp.MODE

`sfence.vma rs1, rs2` with rs1 != x0 must invalidate the cached leaf translations for the virtual address in rs1
whatever `satp.MODE` is when it executes (priv/supervisor.adoc, norm:sfence_vma_va_all_asid and
norm:sfence_vma_va_asid), and writing `satp` does not invalidate the TLB (norm:satp_op_sfence_vma). Whisper sizes
each TLB entry with the TLB's current mode instead of the mode the entry was made in: under Bare the fence
invalidates nothing, and after a switch from Sv48 to Sv39 a 512 GiB entry hits an assertion.

- `sfence-vma-bare.S`: Sv39, S-mode loads through MPRV=1/MPP=S. VA 0x40051000 maps page A and a load caches it.
  The leaf is changed to page B, `satp` is set to Bare, `sfence.vma 0x40051000, x0` runs, `satp` is set back to
  the same Sv39 value, and the VA is loaded again. Expected: 0x2222 (page B).
- `sfence-vma-mode-change-abort.S`: Sv48 with a 512 GiB leaf (root[0], identity); an S-mode load caches it.
  `satp` is set to Sv39 and `sfence.vma va, x0` runs. Expected: the fence completes.

Run: `./run.sh [path/to/whisper]` (prints PASS or FAIL per ELF and the failed check; exit status 0 = all pass).
Each ELF runs as `whisper --maxinst 100000000:f --config whisper.json <elf>`; `whisper.json` is the
riscv-arch-test whisper-rv64-max configuration.

Whisper master fa18e475 (`master.out`): the first test reads page A (0x1111) after the fence; the second stops
with `Tlb.hpp:420: static uint64_t WdRiscv::Tlb::sizeIn4kBytes(Mode, unsigned int): Assertion '0 && "Error:
Assertion failed"' failed.` With each TLB entry sized by the mode it was made in (`fixed.out`), both pass.

Built with the riscv-arch-test (ACT4) framework at 205129dbd8 (`tests/env`) and the check macros in
`include/sa.h` and `include/ai_macros.h` (the `.S` files include them as `../common/sa.h`): each `.S` was put in
a `<testdir>/ai/<Suite>/` directory and built with
`act config/whisper/whisper-rv64-max/test_config.yaml --test-dir <testdir> --extensions <Suite>`.

Other simulators (Spike c20813c, Sail master 81184531, stock Imperas Y-2026.09): Spike, Sail and Imperas pass both tests.
