# whisper-tcontrol-trap-into-m

With `trigger_use_tcontrol` (Sdtrig reentrancy option 2), Whisper fires an etrigger or itrigger
on an exception or interrupt raised in S-mode and taken into M-mode, although taking the trap
into M-mode has just cleared `tcontrol.mte`.

Spec (riscv-debug-spec afd3901):
- Sdtrig.adoc:192: option 2 implements `tcontrol.mte` and `tcontrol.mpte`; Sdtrig.adoc:210-211:
  "Both options prevent etrigger and itrigger from having any effect on exceptions and
  interrupts that are handled in M-mode."
- `norm:Sdtrig_tcontrol_mte`: "When any trap into M-mode is taken, mte is set to 0";
  `norm:Sdtrig_tcontrol_mte_disabled`: with mte=0, "Triggers with action=0 do not match/fire
  while the hart is in M-mode".
- `norm:Sdtrig_etrigger_timing` / `norm:Sdtrig_itrigger_timing`: the trigger "fires after the
  trap occurs, just before the first instruction of the trap handler", so here in M-mode.

Both tests are bare-metal and self-checking. Trigger 0 has action 0 (breakpoint) and s=1.
`medeleg` and `mideleg` are 0 and `tcontrol` is 0.
- `etrigger.S`: etrigger on cause 2. An illegal instruction in S-mode traps into M-mode.
- `itrigger.S`: itrigger on interrupt 3. A machine software interrupt (CLINT `msip`) is pending
  when `mret` enters S-mode, so it is taken into M-mode.

Each writes 1 to `tohost` when the M-mode handler sees the original cause, or
`(mcause << 1) | 1` otherwise.

Hart: Whisper's riscv-arch-test `whisper-rv64-max` configuration with `"trigger_use_tcontrol":
true` and without Smrnmi (`mnstatus.NMIE` resets to 0, which would keep the interrupt
pending). Sail 0.15 uses the matching `sail.json` (`breakpoint_reentrancy: Use_tcontrol`,
`medeleg` bit 3 not delegatable). Spike is not run: it uses the MIE/SIE option whenever S-mode
exists.

Run `./run.sh [whisper] [sail_riscv_sim]`. Whisper master c35cf562:

```
etrigger  whisper FAIL (critical-error state: the breakpoint trapped again inside the M-mode handler)
etrigger  sail    PASS
itrigger  whisper FAIL (critical-error state: the breakpoint trapped again inside the M-mode handler)
itrigger  sail    PASS
```

The configuration has Smdbltrp, so the breakpoint taken inside the M-mode handler (with
`mstatus.MDT` = 1) is a double trap. Without Smdbltrp, the handler sees mcause 3 instead
(`tohost` 7). With the fix Whisper passes both.

Build: `riscv64-unknown-elf-gcc -march=rv64i_zicsr -mabi=lp64 -nostdlib -nostartfiles -static
-T link.ld -I. etrigger.S -o etrigger.elf` (likewise `itrigger.S`).
