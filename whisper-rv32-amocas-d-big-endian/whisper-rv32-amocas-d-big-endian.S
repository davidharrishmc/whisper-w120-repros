// Whisper reproducer (RV32): amocas.d with big-endian M-mode data (mstatush.MBE = 1) must use the same pairing of
// the register pairs with the two memory words for the load, the compare and the store.
// Spec: unpriv/zacas.adoc norm:Zacas_rv32_amocas-d_op ("compares the loaded value to a 64-bit value held in a
//   register pair consisting of rd and rd+1, and if the comparison is bitwise equal, then stores the 64-bit value
//   held in the register pair rs2 and rs2+1 to the original address in rs1") and its listing (temp0 =
//   mem[X(rs1)+0]; ... mem[X(rs1)+0] = swap0; ... X(rd) = temp0). priv/machine.adoc norm:mstatus_mbe_op.
// Sequence, run with MBE = 1 and then (as a control) with MBE = 0: sw A to +0 and B to +4; amocas.d with
//   rd = rs2 = 0 fails and returns the memory pair R; amocas.d with rd = R and rs2 = {C, D} succeeds; amocas.d
//   with rd = rs2 = 0 fails and must return {C, D}. R is {A, B} if the pairs are matched to memory by address
//   (the listing) or {B, A} if by value (rd = low-order word); the store of {C, D} must use the same pairing.
// Skipped (passes) if MBE is read-only 0.
// Result: the test fails with "Bad Value" = bitmask of failed checks (expected 0); bits 0-3 with MBE = 1,
//   bits 4-7 the same checks with MBE = 0:
//   bit 0: the first amocas.d returns neither {A, B} nor {B, A}
//   bit 1: the second amocas.d (compare value R) does not succeed (rd != R)
//   bit 2: the second amocas.d stores {C, D} in the other order from the one in which the first read the pair
//          (lw +0 / lw +4 are not C / D for R = {A, B}, or not D / C for R = {B, A})
//   bit 3: the third amocas.d does not return {C, D} (round trip)
##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'Sm', 'Zaamo', 'Zacas']
# MARCH: rv32ia_zicsr_zifencei_zacas
# NEEDS_SIGNATURE: false
##### END_TEST_CONFIG #####
#define SIGUPD_COUNT 0
#define BOOT_TO_MMODE
#include "riscv_arch_test.h"
#include "../common/sa.h"

#define VA 0x11112222
#define VB 0x33334444
#define VC 0x55556666
#define VD 0x77778888

// Set bit _B of the failure mask x20 (clobbers x10).
#define SETFAIL(_B) LI(x10, (1 << (_B))); or x20, x20, x10

// _SET: 1 = big-endian (MBE = 1), 0 = little-endian. _BIT: first bit of this group.
#define ROUND_TRIP(_SET, _BIT)                              \
  li x5, 0x20                                              ;\
  csrc mstatush, x5                                        ;\
  .if _SET                                                 ;\
  csrs mstatush, x5                                        ;\
  .endif                                                   ;\
  LA(x12, bbuf)                                            ;\
  LI(x7, VA)                                               ;\
  sw x7, 0(x12)                                            ;\
  LI(x7, VB)                                               ;\
  sw x7, 4(x12)                                            ;\
  li x6, 0                                                 ;\
  li x7, 0                                                 ;\
  li x8, 0                                                 ;\
  li x9, 0                                                 ;\
  amocas.d x6, x8, (x12)    /* fails: (x6, x7) = R */      ;\
  mv x16, x6                                               ;\
  mv x17, x7                                               ;\
  li x18, 0                 /* 0: R = {A, B}, 1: {B, A} */ ;\
  LI(x10, VA)                                              ;\
  bne x16, x10, 61f                                        ;\
  LI(x10, VB)                                              ;\
  beq x17, x10, 62f                                        ;\
61: li x18, 1                                              ;\
  LI(x10, VB)                                              ;\
  bne x16, x10, 63f                                        ;\
  LI(x10, VA)                                              ;\
  beq x17, x10, 62f                                        ;\
63: SETFAIL(_BIT)                                          ;\
62: LI(x8, VC)                                             ;\
  LI(x9, VD)                                               ;\
  amocas.d x6, x8, (x12)    /* compare R: succeeds */      ;\
  bne x6, x16, 64f                                         ;\
  beq x7, x17, 65f                                         ;\
64: SETFAIL((_BIT) + 1)                                    ;\
65: lw x14, 0(x12)                                         ;\
  lw x15, 4(x12)                                           ;\
  LI(x10, VC)                                              ;\
  LI(x11, VD)                                              ;\
  beqz x18, 66f                                            ;\
  mv x13, x10                                              ;\
  mv x10, x11                                              ;\
  mv x11, x13                                              ;\
66: bne x14, x10, 67f                                      ;\
  beq x15, x11, 68f                                        ;\
67: SETFAIL((_BIT) + 2)                                    ;\
68: li x6, 0                                               ;\
  li x7, 0                                                 ;\
  li x8, 0                                                 ;\
  li x9, 0                                                 ;\
  amocas.d x6, x8, (x12)    /* fails: must return {C, D} */ ;\
  LI(x10, VC)                                              ;\
  bne x6, x10, 69f                                         ;\
  LI(x10, VD)                                              ;\
  beq x7, x10, 70f                                         ;\
69: SETFAIL((_BIT) + 3)                                    ;\
70: li x5, 0x20                                            ;\
  csrc mstatush, x5

RVTEST_BEGIN
  li x20, 0
  li x5, 0x20
  csrs mstatush, x5
  csrr x7, mstatush
  csrc mstatush, x5
  andi x7, x7, 0x20
  beqz x7, skip                    // MBE read-only 0: nothing to check
  ROUND_TRIP(1, 0)
  ROUND_TRIP(0, 4)
skip:
  SA_CHECK(x20, 0, "bitmask of failed amocas.d pairing checks (bits 0-3 MBE=1, 4-7 MBE=0; see the test header)")
RVTEST_CODE_END
RVTEST_DATA_BEGIN
.p2align 6
bbuf: .fill 4, 4, 0
RVTEST_DATA_END
RVTEST_SIG_SETUP
