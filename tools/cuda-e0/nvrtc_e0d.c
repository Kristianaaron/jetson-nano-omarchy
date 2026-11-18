#include <nvrtc.h>
#include <stdio.h>
#include <stdlib.h>
static const char *src = "extern \"C\" __global__ void axpy(float a, const float *x, float *y, int n) {"
  " int i = blockIdx.x * blockDim.x + threadIdx.x; if (i < n) y[i] = a * x[i] + y[i]; }";
static int dump(const char *arch, int cubin, const char *out) {
  nvrtcProgram p; nvrtcCreateProgram(&p, src, "k.cu", 0, NULL, NULL);
  const char *opts[] = { arch };
  nvrtcResult r = nvrtcCompileProgram(p, 1, opts);
  size_t n = 0; nvrtcGetProgramLogSize(p, &n); char *log = malloc(n + 1); nvrtcGetProgramLog(p, log);
  printf("%s %s: %s %s\n", arch, cubin ? "cubin" : "ptx", nvrtcGetErrorString(r), n > 1 ? log : "");
  if (r != NVRTC_SUCCESS) return 1;
  char *buf; size_t sz;
  if (cubin) { nvrtcGetCUBINSize(p, &sz); buf = malloc(sz); nvrtcGetCUBIN(p, buf); }
  else { nvrtcGetPTXSize(p, &sz); buf = malloc(sz); nvrtcGetPTX(p, buf); sz--; }
  FILE *f = fopen(out, "wb"); fwrite(buf, 1, sz, f); fclose(f); printf("  wrote %s (%zu bytes)\n", out, sz);
  return 0;
}
int main(void) { int v1, v2; nvrtcVersion(&v1, &v2); printf("NVRTC %d.%d\n", v1, v2);
  return dump("--gpu-architecture=compute_53", 0, "k12.ptx") | dump("--gpu-architecture=sm_53", 1, "k12.cubin"); }
