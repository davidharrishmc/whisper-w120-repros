# hip.VSTIP ignores vstimecmp when the time CSR is not implemented

With `menvcfg.STCE = henvcfg.STCE = 1`, `htimedelta = 0` and `vstimecmp = 0`, `time + htimedelta >= vstimecmp`
always holds, so `hip.VSTIP` must read 1. When the hart's `time` CSR is not implemented (`"time": { "exists": "false" }`,
as in riscv-arch-test's whisper-rv64-max, which does it to exercise M-mode emulation of `time` reads), Whisper reads
`hip.VSTIP` as 0, although `mip.VSTIP` is 1 and the VS-level timer interrupt is delivered.

vstip.S runs in M-mode:

| Case | Setup | Checks |
|---|---|---|
| A | `stimecmp = 0` | `mip.STIP` = 1 (control: the S-level timer) |
| B | `vstimecmp = 0` | `hip.VSTIP` = 1 |
| C | `hvip.VSTIP` set, then cleared, with `vstimecmp = 0` | `hip.VSTIP` = 1 |
| D | `vstimecmp = 0` | `mip.VSTIP` = 1 |
| E | `vstimecmp = 0`, `hie.VSTIE = 1`, `hideleg = 0`, `mret` to HS-mode with `sstatus.SIE = 1` | VSTI taken in HS-mode (`scause = 0x8000000000000006`) |

Each case polls up to 64 times. tohost is written with `(bitmask of wrong cases << 1) | 1`.

| File | |
|---|---|
| vstip.S, link.ld, Makefile | source; `make` rebuilds vstip.elf with riscv64-unknown-elf-gcc |
| vstip.elf | prebuilt ELF |
| notime.json | riscv-arch-test's whisper-rv64-max whisper.json (`time` not implemented) |
| time.json | the same with `"time": { "exists": "true" }` |
| run.sh | runs both configs on `whisper` from PATH |
| whisper.log | run.sh output on whisper 283b0d11 |
| notime.trace, time.trace | whisper --log traces |

Result on whisper 283b0d11 (master on 2026-10-21): with notime.json, tohost = 0xd (cases B and C wrong, A, D and E
correct); every `csrr hip` returns 0. With time.json, tohost = 1 (all correct).
