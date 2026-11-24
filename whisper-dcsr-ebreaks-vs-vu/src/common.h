// Bare (no ACT framework) probe helpers. Result code in x1: 1 = pass (spec-consistent), 3/5/7 = fail codes.
// Ends with the store loop at _test_exit (Imperas customControl stops there; HTIF sims stop on tohost).
#define FINISH(code) li x1, code; j done
#define EPILOGUE \
done: la t0, tohost; \
_test_exit: sw x1, 0(t0); sw x0, 4(t0); j _test_exit; \
  .section .tohost,"aw",@progbits; .align 6; .globl tohost; tohost: .dword 0; .globl fromhost; fromhost: .dword 0
