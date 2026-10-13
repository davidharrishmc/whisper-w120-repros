# whisper-geilen-imsic-guests (item 36 of whisper#120)

Whisper-only configuration reproducer. All three configurations are whisper-rv64-max-VLEN-512
(RV64 + H + AIA, IMSIC) with `guest_interrupt_count` removed or changed:

- `whisper-guests-only.json`: `imsic.guests = 5`, no `guest_interrupt_count`. GEILEN becomes 5
  (System.cpp sets it from `imsic.guests`), so bits 5:1 of hgeie must be writable (hypervisor.adoc
  norm:geilen). f069895c: hgeie reads 0 after writing all ones, because the hgeie/hgeip masks were
  computed by `setDefaultMasks` (during `configIsa`) before the IMSIC set GEILEN; IMSIC guest
  interrupts are also masked out of hgeip. Patched: 0x3e.
- `whisper-count-mismatch.json`: `guest_interrupt_count = 3`, `imsic.guests = 5`. The AIA IMSIC chapter
  says the number of guest interrupt files is exactly GEILEN. f069895c accepts it (hgeie 0xe, guest
  files 4 and 5 can never interrupt). Patched: configuration error.
- `whisper-guests-64.json`: `imsic.guests = 64` on RV64. GEILEN is at most XLEN-1; f069895c silently
  clamps the masks to 63 and `URV(1) << guest` (Hart.hpp:2840) is undefined for guest 64. Patched:
  configuration error.

`./run.sh path/to/whisper` runs `cmds.txt` (poke all ones into hgeie, peek it) in interactive mode.
