# whisper-napot-n-without-svnapot

Whisper ignores PTE.N (bit 63) on a hart without Svnapot. supervisor.adoc reserves bits 63-54 of an
Sv39/Sv48/Sv57 PTE when the extensions that define them are not implemented: "If any of these bits are
set, a page-fault exception is raised." Whisper (`virtual_memory/VirtMem.hpp` `napotCheck`) returns
"no fault" when Svnapot is off and uses the PTE as an ordinary 4 KiB leaf.

`Sv_sv39_svnapot_not_supported_Smode-00.S` is the riscv-arch-test (act4) test of that name. The hart is
RV64I + Zicsr + S + U + Sv39, no Svnapot. In S-mode it maps a data page with a level-0 leaf PTE that has
N=1 (and PPN[3:0] = 1000, a 64 KiB NAPOT encoding), then stores, loads and jumps through it. Each access
must take a page fault (store/AMO page fault, load page fault, instruction page fault).

The ELFs are self-checking: expected values come from Sail. There is one ELF per simulator because the
ACT model macros (halt, console) differ.

Expected (Sail, Spike `--isa=rv64i_zicsr`): `RVCP-SUMMARY: TEST PASSED`.
Whisper master f069895c: the store and load complete, so the test fails at

    RVCP: Test Info: "test: 302; cg: Sv; cp: cp_sv39_svnapot_not_supported_Smode; bin: test1_load"
    RVCP: Register: x13
    RVCP: Bad Value:      0x0000000000000810
    RVCP: Expected Value: 0xdbeadfeedbeadfee

## Run

    ./run.sh [path/to/whisper] [path/to/spike] [path/to/sail_riscv_sim]

prints PASS/FAIL per simulator. On whisper f069895c:

    whisper: FAIL
    spike:   PASS
    sail:    PASS

With the fix (fault in `napotCheck` when PTE.N is set and Svnapot is off), whisper prints PASS.
The Sv48 and Sv57 variants of the test (same cover point) behave the same way.

Files: `whisper.json` (whisper configuration), `spike_args.txt` (spike options), `sail.json` (Sail
0.15 configuration), and the three ELFs built from the .S for each simulator by the act4 framework.
