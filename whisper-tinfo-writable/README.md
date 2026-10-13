# whisper: tinfo is writable unless the configuration sets its mask

tenstorrent/whisper#120 item 35. Debug spec (Sdtrig, `xml/hwbp_registers.xml`): every
field of tinfo has access "R". Whisper's per-trigger tinfo write mask defaults to all ones
(`Triggers.hpp:942` at f069895c); only a `triggers` entry in the configuration with a
fourth (tinfo) element changes it. With no `triggers` section, or with entries that list
only tdata1-3, CSR writes to tinfo change it (and the info field then decides which
tdata1 types are accepted, `Triggers.cpp:195`).

`W120Tinfo_ro-00.S` (riscv-arch-test) selects trigger 0, writes the complement of tinfo
and records the XOR of the values read before and after (expected 0). `whisper.json` is
the ACT derived configuration RVI20U64-sdtrig with its `triggers` section removed;
`whisper-stock.json` is the unmodified configuration (tinfo mask 0).

Files: `W120Tinfo_ro-00-{whisper,spike,sail}.elf`, `whisper.json`, `whisper-stock.json`,
`spike-args.txt`, `sail.json`.

    ./run.sh [whisper] [spike] [sail_riscv_sim]

| | whisper f069895c | whisper + fix |
|---|---|---|
| whisper-stock.json | PASS | PASS |
| whisper.json (no `triggers` section) | FAIL (tinfo 0 -> 0xffffffffffffffff) | PASS |

Spike d6cfe9e and Sail 0.15 (both ignore tinfo writes): PASS. Same result on RVI20U32-sdtrig.
