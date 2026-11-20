// GPU load and DVFS check: run a compute-bound FMA kernel for SECONDS (default 20), print the
// achieved GFLOP/s once a second (it follows the GPC clock: GM20B peak is 128 cores x 2 x f), and
// compare every result with the CPU at the end. Driver API plus NVRTC, like cuda_smoke.c.
// Build: gcc -O2 gpu_load.c -I$CUDA/include -I$NVRTC/include -L$LIBCUDA -L$NVRTC/lib -lcuda -lnvrtc -lm
#include <cuda.h>
#include <nvrtc.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

#define N (128 * 1024)
#define ITERS 4096  // FMA pairs per element per launch

static const char *kSrc =
    "extern \"C\" __global__ void fma_loop(float *x, int iters) {\n"
    "  int i = blockIdx.x * blockDim.x + threadIdx.x;\n"
    "  float a = x[i], b = 1.0001f, c = 0.9999f;\n"
    "  for (int k = 0; k < iters; k++) { a = a * b + c; a = a * c - b; }\n"
    "  x[i] = a;\n"
    "}\n";

static int ok(CUresult r, const char *what)
{
  if (r == CUDA_SUCCESS) return 1;
  const char *s = NULL;
  cuGetErrorString(r, &s);
  printf("FAIL %s: %s\n", what, s ? s : "?");
  return 0;
}
#define CU(call) do { if (!ok((call), #call)) return 1; } while (0)

static double now(void)
{
  struct timespec t;
  clock_gettime(CLOCK_MONOTONIC, &t);
  return t.tv_sec + t.tv_nsec * 1e-9;
}

static float cpu_ref(float a, int launches)
{
  const float b = 1.0001f, c = 0.9999f;
  for (int l = 0; l < launches; l++)
    for (int k = 0; k < ITERS; k++) { a = fmaf(a, b, c); a = fmaf(a, c, -b); }
  return a;
}

int main(void)
{
  double seconds = getenv("SECONDS") ? atof(getenv("SECONDS")) : 20.0;
  CUdevice dev;
  CUcontext ctx;
  CUmodule mod;
  CUfunction fn;
  CUdeviceptr dx;
  nvrtcProgram prog;
  const char *opts[] = {"--gpu-architecture=compute_53", "--fmad=true"};
  size_t size;
  static float x[N], y[N];
  int iters = ITERS, launches = 0;

  if (nvrtcCreateProgram(&prog, kSrc, "fma.cu", 0, NULL, NULL) != NVRTC_SUCCESS ||
      nvrtcCompileProgram(prog, 2, opts) != NVRTC_SUCCESS) {
    printf("FAIL nvrtc\n");
    return 1;
  }
  nvrtcGetPTXSize(prog, &size);
  char *ptx = malloc(size);
  nvrtcGetPTX(prog, ptx);
  nvrtcDestroyProgram(&prog);

  CU(cuInit(0));
  CU(cuDeviceGet(&dev, 0));
  CU(cuCtxCreate(&ctx, 0, dev));
  CU(cuModuleLoadData(&mod, ptx));
  CU(cuModuleGetFunction(&fn, mod, "fma_loop"));
  for (int i = 0; i < N; i++) x[i] = (float)(i % 97) * 0.01f;
  CU(cuMemAlloc(&dx, sizeof(x)));
  CU(cuMemcpyHtoD(dx, x, sizeof(x)));

  void *args[] = {&dx, &iters};
  double t0 = now(), tlast = t0;
  int last = 0;
  while (now() - t0 < seconds) {
    CU(cuLaunchKernel(fn, N / 256, 1, 1, 256, 1, 1, 0, 0, args, NULL));
    CU(cuCtxSynchronize());
    launches++;
    double t = now();
    if (t - tlast >= 1.0) {
      // 2 FMAs (4 flops) per inner iteration per element.
      printf("t=%4.1fs %6.1f GFLOP/s\n", t - t0, (launches - last) * (double)N * ITERS * 4 / (t - tlast) / 1e9);
      fflush(stdout);
      tlast = t;
      last = launches;
    }
  }
  CU(cuMemcpyDtoH(y, dx, sizeof(y)));
  long bad = 0;
  for (int i = 0; i < N; i += 101) {  // a sample covering every input value (101 and 97 coprime)
    float r = cpu_ref(x[i], launches);
    if (fabsf(y[i] - r) > 1e-3f * fabsf(r) + 1e-3f) bad++;
  }
  printf("%d launches, %ld wrong of %d checked: %s\n", launches, bad, (N + 100) / 101, bad ? "FAIL" : "PASS");
  return bad != 0;
}
