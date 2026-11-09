// Vector segment stores must store each field of each segment once.
// Two segment stores with vl = 4 and nf = 2 send field 0 of every segment to the console device (field 1 goes
// to the next byte): a strided one with x[rs2] = 0 and an ordered-indexed one with all indices 0.
// Expected console output: "ABCD" twice. Whisper master fa18e475 (partial_segment_update = false, its default)
// prints "AABABCABCD" twice: after each segment it stores again every earlier segment.
// Console device: Whisper "consoleio" (the riscv-arch-test whisper.json sets it to 0x10000000); Spike's
// ns16550 transmit register is at the same address.
#if __riscv_xlen == 64
#define SREG sd
#else
#define SREG sw
#endif
#define CONSOLE 0x10000000

  .section .text.init
  .globl _start
_start:
  li t0, (1<<9)|(1<<13)        // mstatus.VS = FS = Initial
  csrs mstatus, t0
  la t0, msg
  vsetivli x0, 4, e8, m1, tu, mu
  vlseg2e8.v v8, (t0)          // v8 = 'A','B','C','D'   v9 = 'a','b','c','d'
  li t1, CONSOLE

  li t2, 0                     // stride 0 with rs2 != x0: one access per active element
  vssseg2e8.v v8, (t1), t2     // field 0 of each segment -> console, field 1 -> console + 1
  li t0, '\n'
  sb t0, 0(t1)

  vmv.v.i v4, 0                // all indices 0
  vsoxseg2ei8.v v8, (t1), v4   // same, ordered indexed
  li t0, '\n'
  sb t0, 0(t1)

  li t0, 1
  la t1, tohost
  SREG t0, 0(t1)
1: j 1b

  .data
  .align 6
  .globl tohost
tohost: .dword 0
  .globl fromhost
fromhost: .dword 0
msg: .byte 'A','a','B','b','C','c','D','d'
