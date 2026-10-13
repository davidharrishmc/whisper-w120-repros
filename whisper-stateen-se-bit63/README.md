# whisper: bit 63 of mstateen1-3 / hstateen1-3 is read-only zero with H

tenstorrent/whisper#120 item 28. smstateen.adoc: "Bit 63 of each `mstateen` CSR may be
read-only zero only if the hypervisor extension is not implemented and the matching
supervisor-level `sstateen` CSR is all read-only zeros." and "Bit 63 of each `hstateen`
CSR is always writable (not read-only)." Whisper defines mstateen1-3 and hstateen1-3
(and the RV32 high halves) with write mask 0 (`CsRegs.cpp:6129-6149` at f069895c), so on
a hart with H, bit 63 cannot be set and S-mode can never access sstateen1-3.

`stateen-se.S` (bare metal, HTIF tohost) runs in M-mode on a hart with H and Smstateen:

- checks 1-3: set bit 63 of mstateen1/2/3 (mstateen1h-3h bit 31 on RV32), read it back as 1;
- checks 4-6: the same for hstateen1/2/3;
- check 7: with mstateen1.SE = 1, an S-mode `csrr sstateen1` must not trap.

The test writes 1 to tohost on success and (n << 1) | 1 when check n fails.

Files: `stateen-se-rv64.elf`, `stateen-se-rv32.elf` (one ELF per XLEN, the same for all
simulators; build with `riscv64-unknown-elf-gcc -march=rv64gch_zicsr_smstateen_smaia_ssaia -mabi=lp64
-nostdlib -nostartfiles -T link.ld stateen-se.S`), `whisper-rv{64,32}.json` (the
riscv-arch-test derived configurations whisper-rv{64,32}-max-base), `sail-rv{64,32}.json`
(their sail.json), `spike-args-rv{64,32}.txt`.

    ./run.sh [whisper] [spike] [sail_riscv_sim]

| | whisper f069895c | whisper + fix | Spike d6cfe9e | Sail 0.15 |
|---|---|---|---|---|
| rv64 | FAIL (check 1) | PASS | PASS | FAIL (check 1) |
| rv32 | FAIL (check 1) | PASS | PASS | FAIL (check 1) |

Sail 0.15 has the same problem (`legalize_mstateen1..3` return the old value, so
mstateen1-3 are read-only zero and hstateen1-3 are masked by them; still so on sail-riscv
master), so this is a Spike-only reference. riscv-arch-test cannot check it until Sail is
fixed.
