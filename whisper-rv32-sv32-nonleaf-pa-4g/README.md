# Whisper, RV32: a non-leaf Sv32 PTE that points to a page table at or above 4 GiB is truncated to 32 bits

An Sv32 PTE has a 22-bit PPN, so the next-level page table of a non-leaf PTE is at a 34-bit (guest) physical
address (supervisor.adoc, translation process step 4: "let a=pte.ppn×PAGESIZE"; hypervisor.adoc: Sv32x4 "is
defined to support a 34-bit guest physical address"). Whisper computes the table address in 32 bits.

- `rv32-vs-nonleaf-gpa-4g.S` (HS boot, no memory above 4 GiB needed): `hgatp` = Sv32x4 with 4 MiB pages maps GPA
  0x80000000-0x80ffffff to itself and an alias GPA 0x100000000-0x100ffffff to the same PAs. `vsatp` = Sv32. VS
  root[0x100] points to the level-0 table through its identity GPA (case 1) and through its alias GPA, at or above
  4 GiB (case 2). `hlv.w` (SPVP = 1) of VA 0x40000000 must read 0x5a5a1234 in both cases.
- `rv32-sv32-nonleaf-pa-4g.S` (M boot; needs RAM at 0x1_0000_0000, as whisper-rv32-max has; does nothing
  otherwise): an Sv32 root[0x100] non-leaf PTE with PPN 0x100000 (table at PA 0x1_0000_0000) for an MPRV S-mode
  `lw` (case 1), and a G-stage (Sv32x4, `vsatp` = Bare) root[0x100] non-leaf PTE with PPN 0x100001 (table at PA
  0x1_0000_1000) for an M-mode `hlv.w` (case 2). Both must read 0x5a5a1234.

Run: `./run.sh [path/to/whisper]` (prints PASS or FAIL per ELF and the failed checks; exit status 0 = all pass).
Each ELF runs as `whisper --maxinst 100000000:f --config whisper.json <elf>`; `whisper.json` is the
riscv-arch-test whisper-rv32-max configuration.

Whisper master fa18e475 (`master.out`): the VS-stage case 2 takes a load guest-page fault; the Sv32 case takes a
load access fault (the table is read at PA 0) and the G-stage case a load guest-page fault (table read at PA
0x1000). With the PPN widened to 64 bits (`fixed.out`), both tests pass.

Built with the riscv-arch-test act4 framework (`tests/env`, tree at 205129dbd8) and the check macros in
`include/sa.h` and `include/ai_macros.h` (the `.S` files include them as `../common/sa.h`): each `.S` was put in
a `<testdir>/ai/<Suite>/` directory and built with
`act config/whisper/whisper-rv32-max/test_config.yaml --test-dir <testdir> --extensions <Suite>`.

Other simulators (Spike c20813c, Sail master 81184531, stock Imperas Y-2026.09): `rv32-vs-nonleaf-gpa-4g` passes on Spike and Sail. `rv32-sv32-nonleaf-pa-4g` passes on Spike and Sail with RAM added at 0x1_0000_0000-0x1_0000_1fff (their stock RV32 configurations have none, so the test does nothing there). Imperas has no RV32 configuration with H.
