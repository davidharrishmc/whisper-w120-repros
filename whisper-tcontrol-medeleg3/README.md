# whisper-tcontrol-medeleg3

With `trigger_use_tcontrol` (Sdtrig reentrancy option 2), Whisper keeps `medeleg` bit 3
(breakpoint) writable, so breakpoints can be delegated to S-mode.

Spec (riscv-debug-spec afd3901), Sdtrig.adoc:192: option 2 implements `tcontrol.mte` and
`tcontrol.mpte`, and "`medeleg` [3] is hard-wired to 0".

`medeleg3.S` is bare-metal and self-checking. It runs both checks and writes 1 to `tohost` when
both pass, or `(failmask << 1) | 1` otherwise (bit N-1 of failmask = check N):

1. After writing all ones to `medeleg`, bit 3 reads back as 0.
2. With that value in place, `ebreak` in S-mode traps into M-mode, not S-mode.

Hart: Whisper's riscv-arch-test `whisper-rv64-max` configuration with `"trigger_use_tcontrol":
true` and without Smrnmi. Sail 0.15 uses the matching `sail.json` (`breakpoint_reentrancy:
Use_tcontrol`; Sail rejects a configuration that also makes `medeleg` bit 3 delegatable).
Spike is not run: it uses the MIE/SIE option whenever S-mode exists.

Run `./run.sh [whisper] [sail_riscv_sim]`. Whisper master c35cf562:

```
whisper  FAIL (failmask 3)
sail     PASS
```

With the fix Whisper passes. `trigger_use_tcontrol` defaults to true in Whisper, so this also
applies to configurations with Sdtrig that omit the key.

Build: `riscv64-unknown-elf-gcc -march=rv64i_zicsr -mabi=lp64 -nostdlib -nostartfiles -static
-T link.ld -I. medeleg3.S -o medeleg3.elf`.
