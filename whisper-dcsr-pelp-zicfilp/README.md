# Whisper: dcsr.pelp is read-only zero with Zicfilp, so a halt loses ELP

Sdext.adoc says that, with Zicfilp, a halt saves ELP in `dcsr.pelp` and sets ELP to NO_LP_EXPECTED, and a
resume restores ELP from `dcsr.pelp`. Whisper's default `dcsr` masks (write mask 0x8e04, poke mask 0x8fef)
do not include `pelp` (bit 18), so the poke in `enterDebugMode_` that saves ELP in `dcsr.pelp` is dropped,
and a resume always restores NO_LP_EXPECTED.

`pelp.S` uses Whisper's default `dcsr` masks (`whisper-rv*.json` sets only the `dcsr` reset value, for
`ebreakm` = 1, plus `debug_park_loop`). It enables Zicfilp in M-mode (`mseccfg.MLPE` = 1), enters Debug
Mode with `ebreak`, sets an mcontrol6 execute trigger with action 1 (enter Debug Mode) on `no_lpad`, and
resumes at a `jr` to `no_lpad`, which sets ELP = LP_EXPECTED. The trigger halts the hart before `no_lpad`
executes. Back in Debug Mode the test checks `dcsr`, disables the trigger, and resumes at `no_lpad`, which
is not an `lpad`, so the restored ELP must raise a software-check exception (mcause 18, mtval 2).

x31 = bitmask of failed checks: 1 `dcsr.pelp` = 0 after the halt, 2 `dcsr.cause` != 2 (trigger),
3 mcause != 18, 4 mtval != 2, 5 mepc != `no_lpad`, 6 no software-check exception at `no_lpad`,
7 unexpected path. tohost = (x31 << 1) | 1.

Expected: x31 = 0 (`dcsr` = 0x40048083 after the halt).

Whisper master 6b8cce1a (`master.out`): x31 = 0x42 on RV64 and RV32: `dcsr` = 0x40008083 after the halt
(pelp = 0), and `no_lpad` executes without an exception:

```
rv64: x31 = 0x42
  FAIL check 1: dcsr.pelp = 0 after the trigger halt (ELP not saved)
  FAIL check 6: no software-check exception at no_lpad after the dret (ELP not restored)
rv32: x31 = 0x42
  FAIL check 1: dcsr.pelp = 0 after the trigger halt (ELP not saved)
  FAIL check 6: no software-check exception at no_lpad after the dret (ELP not restored)
```

With `dcsr.pelp` pokeable when Zicfilp is enabled (`fixed.out`), both pass.

Run: `./run.sh [path/to/whisper]` (prints the failed checks; exit status 0 = pass). Rebuild: `./build.sh`
(needs a toolchain with Zicfilp, for `lpad`).

Other simulators: Spike, Sail and QEMU have no Debug Mode that a bare-metal program can enter, so the test
cannot run on them. Imperas (stock ImperasDV Y-2026.09 library,
`IMPERAS_VLNV=/cad/imperas/IMPERAS_DV/lib/Linux64/ImperasLib`; `debug_mode=vector`, `debug_address=0x80000800`, `dexc_address=0x80000900`,
`dcsr_ebreak_mask=0x3f`, `rnmi_version=0.4` for Smrnmi) passes on RV64: it sets `dcsr.pelp` at the halt
(0x4007b083) and takes the software-check exception after the resume.
