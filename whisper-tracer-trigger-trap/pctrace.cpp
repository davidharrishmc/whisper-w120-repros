// Minimal Whisper tracer extension: writes "<pc> RET" or "<pc> TRAP" for every record it
// receives to the file named after the colon in --tracerlib pctrace.so:<file>.
#include <cstdio>
#include <string>
#include "Hart.hpp"
#include "Trace.hpp"

extern "C" {
  extern std::string tracerExtensionArgs;
}

static FILE* out = nullptr;

extern "C" {
  void tracerExtensionInit64() { out = fopen(tracerExtensionArgs.c_str(), "w"); }
  void tracerExtension64(void* data)
  {
    auto& tr = *static_cast<WdRiscv::TraceRecord<uint64_t>*>(data);
    uint64_t cause = 0;
    fprintf(out, "%016llx %s\n", (unsigned long long) tr.virtPc(), tr.hasTrap(cause) ? "TRAP" : "RET");
    fflush(out);
  }
}
