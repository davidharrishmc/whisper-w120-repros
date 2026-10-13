// tenstorrent/whisper#120 item 31: on RV32 with Smaia/Ssaia and H, sieh/siph must be
// read-only zero in every bit whose midelegh and mvienh bits are both zero (AIA
// MSLevel.adoc:520-521, 543-546), and vsieh/vsiph in every bit whose hidelegh and hvienh
// bits are both zero (VSLevel.adoc:319-320, 332-338). The test clears midelegh, mvienh,
// hidelegh and hvienh, reads back what they hold (they may have read-only bits), writes
// all ones to sieh, siph, vsieh and vsiph, and checks that the bits not covered by the
// read-back delegation/enable bits read 0. It runs every check and writes 1 to tohost
// when all pass, or (failmask << 1) | 1 otherwise: bit 0 sieh, bit 1 siph, bit 2 vsieh,
// bit 3 vsiph, bit 4 an unexpected trap.
#include "common.h"
  .section .text.init
  .global _start
_start:
  HARNESS_INIT
  la t0, trap
  csrw mtvec, t0
  li s0, 0                      // failure mask

  csrw 0x313, zero              // midelegh
  csrw 0x318, zero              // mvienh
  csrw 0x613, zero              // hidelegh
  csrw 0x618, zero              // hvienh
  csrr t0, 0x313
  csrr t1, 0x318
  or t0, t0, t1
  not s2, t0                    // sieh/siph bits that must be read-only zero
  csrr t0, 0x613
  csrr t1, 0x618
  or t0, t0, t1
  not s3, t0                    // vsieh/vsiph bits that must be read-only zero

  li t1, -1
#define CHECK(bit, csr, roz) csrw csr, t1; csrr t2, csr; csrw csr, zero; \
  and t2, t2, roz; beqz t2, 1f; ori s0, s0, bit; 1:
  CHECK(1, 0x114, s2)           // sieh
  CHECK(2, 0x154, s2)           // siph
  CHECK(4, 0x214, s3)           // vsieh
  CHECK(8, 0x254, s3)           // vsiph

  beqz s0, pass
  mv gp, s0
  j fail
  .align 2
trap:                           // any trap (e.g. CSR not implemented) is a failure
  ori gp, s0, 16
  j fail
HARNESS_END
