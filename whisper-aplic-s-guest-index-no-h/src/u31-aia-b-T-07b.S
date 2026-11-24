// verify v15a, u31-aia-b-T-07b (Whisper, bare): APLIC S-domain target[i] Guest Index is read-only zero when the
// domain's harts do not implement H (harts with M, S and U but no H).
// Spec: AIA AdvPLIC.adoc:937-954 (active source, MSI delivery mode: bits 17:12 Guest Index) "If the interrupt domain is
//   at supervisor level and the domain's harts implement the H extension, then Guest Index is a WLRL field that must
//   be able to hold all integer values in the range 0 through GEILEN. ... Otherwise, field Guest Index is read-only
//   zero."
// Configs: act/config/whisper/rr-verify-v15a-w/whisper-rv<x>-noh.json (whisper-rv<x>-max without H: isa without h,
//   misa.H = 0, GEILEN 0) and, as a control, whisper-rv<x>-h.json (the -max config, H with GEILEN 63/31: Guest
//   Index 5 must be held).
// Steps: M domain delegates source 2 to the S domain (sourcecfg[2] = 0x400); S domain domaincfg = 0x80000004
//   (MSI mode; DM checked); S sourcecfg[2] = 4 (Edge1, active); S target[2] := 0x5003 (Hart Index 0, Guest Index 5,
//   EIID 3). Expected read-back: 0x3 without H, 0x5003 with H.
// Run: CFG=config/whisper/rr-verify-v15a-w/whisper-rv<x>-{noh,h}.json DEFS="-DHAS_S -DHAS_U [-DEXPECT_H]"
//   work/verify-v15a/wb.sh u31-aia-b-T-07b 64|32 [a5554a17|2646725] fast
// Source: tests/u31-aia-b/u31-aia-b-target.S (u31-aia-b-0099), there on the -m/-mu configs.
#include "dm.h"
#define MB 0x0C000000
#define SB 0x0D000000
#define WR(_A, _V) li t0, _A; li t1, _V; sw t1, 0(t0)
#define RD(_R, _A) li t0, _A; lw _R, 0(t0)
main:
  csrr s0, misa
  srli s0, s0, 7
  andi s0, s0, 1
#ifdef EXPECT_H
  CHK(s0, 1, "T07b control: misa.H = 1 (H config)")
#else
  CHK(s0, 0, "T07b control: misa.H = 0 (no-H config)")
#endif
  WR(MB+0x0008, 0x400)               // M sourcecfg[2]: delegate to child 0 (the S domain)
  WR(SB+0x0000, 0x80000004)          // S domaincfg: DM = 1 (MSI), IE = 0
  RD(s1, SB+0x0000)
  CHKM(s1, 4, 4, "T07b control: S domaincfg.DM = 1 (MSI mode supported)")
  WR(SB+0x0008, 4)                   // S sourcecfg[2] = Edge1 (active)
  RD(s1, SB+0x0008)
  CHK(s1, 4, "T07b control: S sourcecfg[2] = 4 (active)")
  WR(SB+0x3008, 0x5003)              // S target[2]: Hart Index 0, Guest Index 5, EIID 3
  RD(s2, SB+0x3008)
#ifdef EXPECT_H
  CHK(s2, 0x5003, "T07b control: harts with H (GEILEN >= 5): S target[2] holds Guest Index 5")
#else
  CHK(s2, 0x3, "T07b: harts without H: S target[2] Guest Index read-only zero (AdvPLIC.adoc:948-951)")
#endif
  TEST_END
  .section .rodata
s_name: .asciz "u31-aia-b-T-07b"
