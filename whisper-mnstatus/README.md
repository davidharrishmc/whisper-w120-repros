# whisper-mnstatus

tenstorrent/whisper#120 item 27: with Zicfilp, Whisper's mnstatus (Smrnmi) cannot hold MNPELP
and MNRET never restores ELP from it, and MNPP accepts the reserved value 2. `mnstatus.S` is a
bare-metal self-checking test (not riscv-arch-test: Sail 0.15 does not implement Smrnmi, so ACT
cannot generate the expected values). It runs every check and writes 1 to `tohost` when all
pass, or `(failmask << 1) | 1` otherwise (bit N-1 of failmask = check N):

1. MNPELP (bit 9) is writable with Zicfilp (smrnmi.adoc:94-95: "If the Zicfilp extension is
   implemented, mnstatus also holds the MNPELP field"). Whisper: bit 9 is not in the write
   mask (RNMI entry does save ELP into it, but software cannot write it).
2. MNRET to M-mode with mseccfg.MLPE=1 and MNPELP=1 sets ELP, so the non-lpad instruction at
   mnepc raises a software-check exception, mcause 18 (smrnmi.adoc:147-148: "MNRET sets ELP to
   the logical AND of yLPE and mnstatus.MNPELP"). Whisper: MNRET never touches ELP. This check
   sets MNPELP with a CSR write, so it needs check 1.
3. MNPP never holds the reserved value 2 (smrnmi.adoc:86-88: MNPP is "encoded in the same
   manner as mstatus.MPP"; machine.adoc:430: xPP fields are WARL and "can hold only privilege
   mode x and any implemented privilege mode lower than x"). Whisper: stores 2; MNRET then
   enters `PrivilegeMode::Reserved`.

Hart: RV64I with M, S and U, Zicfilp and Smrnmi, no H (`whisper.json`, Spike
`spike-args.txt`). One ELF serves both simulators (both use `tohost`).

Run `./run.sh [whisper] [spike]`. Spike d6cfe9e passes. Whisper master f069895c:

```
whisper  FAIL (failmask 7)
spike    PASS
sail     not run (Sail 0.15 has no Smrnmi)
```

With the fix Whisper passes.

Build: `riscv64-unknown-elf-gcc -march=rv64i_zicsr -mabi=lp64 -nostdlib -nostartfiles -static
-T link.ld mnstatus.S -o mnstatus.elf`.
