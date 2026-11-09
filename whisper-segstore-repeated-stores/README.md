# Whisper: segment stores repeat the stores of every earlier segment

With `partial_segment_store` false (Whisper's default; the riscv-arch-test whisper configurations set
`partial_segment_update`, which covers it, false), each vector segment store stores the fields of every
earlier segment again after finishing a segment, so segment i is written vl - i times (with vstart = 0).
Memory ends with the right values, but a device, or another hart, sees the repeated stores.

`segstore.S` (bare metal, M-mode) loads 'A'..'D' (field 0) and 'a'..'d' (field 1) with `vlseg2e8.v` at vl = 4,
then sends field 0 of every segment to Whisper's console device at 0x10000000 (field 1 goes to the next byte)
with:

1. `vssseg2e8.v v8, (t1), t2` with t2 = 0 (strided, stride 0);
2. `vsoxseg2ei8.v v8, (t1), v4` with all indices 0 (ordered indexed).

Expected console output: `ABCD`, a newline, `ABCD`. Whisper master fa18e475 (`master.out`) prints `AABABCABCD`
for each store, on RV64 and RV32. With the fix (`fixed.out`) both print `ABCD`.

Spec: vector-common.adoc (strided): "When `rs2!=x0` and the value of `x[rs2]=0`, the implementation must perform
one memory access for each active element (but these accesses will not be ordered)", and the NOTE that
follows: "For non-idempotent memory regions, where by definition each access can be observed by a device, the
optimization would not be possible." norm:vector_ls_indexed_ordered_rvwmo: "Vector indexed-ordered loads and
stores read and write elements from/to memory in element order respectively, obeying RVWMO at the element
level." Whether a trap part-way through a segment leaves some of its fields stored is implementation-defined
(norm:vector_ls_seg_partial_access), so deferring a segment's stores until all its fields are checked is
legal; storing earlier segments again is not.

## Files

- `segstore.S`, `link.ld`, `build.sh`: the test and how to rebuild it (`riscv64-unknown-elf-gcc`).
- `segstore_rv64.elf`, `segstore_rv32.elf`: the built test.
- `whisper-rv64.json`, `whisper-rv32.json`: riscv-arch-test's `whisper-rv64-max` and `whisper-rv32-max` Whisper
  configurations (console at 0x10000000, `partial_segment_update` false).
- `master.out`, `fixed.out`, `spike.out`: output for Whisper master fa18e475, the fix, and Spike c20813c.

## Run

    ./run.sh path/to/whisper     # prints the console output and PASS or FAIL for each ELF; exit status 0 = pass

Each run is `whisper --config whisper-rv64.json segstore_rv64.elf` (and the same for RV32).

## Other simulators

Spike c20813c (`spike --isa=rv64gcv segstore_rv64.elf`, and RV32), whose ns16550 transmit register is at the
same address, prints `ABCD` twice (`spike.out`). Sail, and Imperas as riscv-arch-test runs it, have no
device at that address that shows each store, so the test cannot count the stores on them.
