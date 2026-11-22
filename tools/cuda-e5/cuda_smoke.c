// E5: first CUDA 12 work on GM20B (Jetson Nano) through the R36 driver stack on mainline Linux.
// Driver API only (libcuda from L4T R36.4) plus NVRTC 12.6, so no CUDA runtime or nvcc is needed.
// Steps: init, device query, then the same kernel twice: as an sm_53 cubin and as compute_53 PTX
// (the second path exercises the driver's PTX JIT). Every output element is checked on the CPU.
// Exit 0 only if every step passes.
#include <cuda.h>
#include <nvrtc.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>

#define N (1 << 20)

static const char *kSrc =
    "extern \"C\" __global__ void axpb(const float *a, const float *b, float *c, int n)\n"
    "{\n"
    "  int i = blockIdx.x * blockDim.x + threadIdx.x;\n"
    "  if (i < n) c[i] = a[i] * 2.0f + b[i];\n"
    "}\n";

static int check_cu(CUresult r, const char *what)
{
  const char *name = NULL;
  if (r == CUDA_SUCCESS) {
    printf("ok   %s\n", what);
    return 0;
  }
  cuGetErrorName(r, &name);
  printf("FAIL %s: %s (%d)\n", what, name ? name : "?", (int)r);
  return 1;
}

#define CU(call)                         \
  do {                                   \
    if (check_cu((call), #call)) goto out; \
  } while (0)

// Compile kSrc for one target; returns a malloc'd image (cubin or PTX) or NULL.
static char *compile(const char *arch_opt, int want_cubin)
{
  nvrtcProgram prog;
  const char *opts[] = {arch_opt};
  size_t size = 0;
  char *image = NULL;
  nvrtcResult r = nvrtcCreateProgram(&prog, kSrc, "axpb.cu", 0, NULL, NULL);
  if (r != NVRTC_SUCCESS) {
    printf("FAIL nvrtcCreateProgram: %s\n", nvrtcGetErrorString(r));
    return NULL;
  }
  r = nvrtcCompileProgram(prog, 1, opts);
  if (r != NVRTC_SUCCESS) {
    size_t log_size = 0;
    nvrtcGetProgramLogSize(prog, &log_size);
    char *log = malloc(log_size + 1);
    nvrtcGetProgramLog(prog, log);
    printf("FAIL nvrtcCompileProgram %s: %s\n%s\n", arch_opt, nvrtcGetErrorString(r), log);
    free(log);
    nvrtcDestroyProgram(&prog);
    return NULL;
  }
  if (want_cubin) {
    nvrtcGetCUBINSize(prog, &size);
    image = malloc(size);
    nvrtcGetCUBIN(prog, image);
  } else {
    nvrtcGetPTXSize(prog, &size);
    image = malloc(size);
    nvrtcGetPTX(prog, image);
  }
  printf("ok   nvrtc %s -> %s, %zu bytes\n", arch_opt, want_cubin ? "cubin" : "PTX", size);
  nvrtcDestroyProgram(&prog);
  return image;
}

// Load one image, run it on a, b and compare with the CPU result. Returns the number of
// wrong elements, or -1 on an API failure.
static long run_image(const char *label, const void *image, CUdeviceptr da, CUdeviceptr db,
                      CUdeviceptr dc, const float *a, const float *b, float *c)
{
  CUmodule mod = NULL;
  CUfunction fn;
  CUevent t0 = NULL, t1 = NULL;
  float ms = 0;
  int n = N;
  void *args[] = {&da, &db, &dc, &n};
  long bad = -1;

  printf("--- %s\n", label);
  CU(cuModuleLoadData(&mod, image));
  CU(cuModuleGetFunction(&fn, mod, "axpb"));
  CU(cuMemsetD32(dc, 0, N));
  CU(cuEventCreate(&t0, CU_EVENT_DEFAULT));
  CU(cuEventCreate(&t1, CU_EVENT_DEFAULT));
  CU(cuEventRecord(t0, 0));
  CU(cuLaunchKernel(fn, N / 256, 1, 1, 256, 1, 1, 0, 0, args, NULL));
  CU(cuEventRecord(t1, 0));
  CU(cuCtxSynchronize());
  CU(cuEventElapsedTime(&ms, t0, t1));
  CU(cuMemcpyDtoH(c, dc, N * sizeof(float)));
  bad = 0;
  for (int i = 0; i < N; i++)
    if (fabsf(c[i] - (a[i] * 2.0f + b[i])) > 1e-6f * fabsf(a[i] * 2.0f + b[i]) + 1e-6f)
      bad++;
  // 3 floats of 4 bytes move per element.
  printf("%s: %ld wrong of %d, kernel %.3f ms, %.2f GB/s\n", label, bad, N, ms,
         ms > 0 ? (3.0 * 4 * N) / (ms * 1e6) : 0.0);
out:
  if (t0) cuEventDestroy(t0);
  if (t1) cuEventDestroy(t1);
  if (mod) cuModuleUnload(mod);
  return bad;
}

int main(void)
{
  CUdevice dev;
  CUcontext ctx = NULL;
  CUdeviceptr da = 0, db = 0, dc = 0;
  char name[128];
  int major = 0, minor = 0, sms = 0, clk = 0, drv = 0;
  size_t total = 0;
  int rc = 1;
  float *a = malloc(N * sizeof(float)), *b = malloc(N * sizeof(float)), *c = malloc(N * sizeof(float));
  char *cubin = NULL, *ptx = NULL;

  for (int i = 0; i < N; i++) {
    a[i] = (float)(i % 1000) * 0.5f;
    b[i] = (float)(i % 777) - 300.0f;
  }

  CU(cuInit(0));
  CU(cuDriverGetVersion(&drv));
  CU(cuDeviceGet(&dev, 0));
  CU(cuDeviceGetName(name, sizeof name, dev));
  CU(cuDeviceGetAttribute(&major, CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MAJOR, dev));
  CU(cuDeviceGetAttribute(&minor, CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MINOR, dev));
  CU(cuDeviceGetAttribute(&sms, CU_DEVICE_ATTRIBUTE_MULTIPROCESSOR_COUNT, dev));
  CU(cuDeviceGetAttribute(&clk, CU_DEVICE_ATTRIBUTE_CLOCK_RATE, dev));
  CU(cuDeviceTotalMem(&total, dev));
  printf("device: %s, compute %d.%d, %d SM, %d MHz, %zu MiB, driver API %d\n", name, major, minor,
         sms, clk / 1000, total >> 20, drv);

  CU(cuCtxCreate(&ctx, 0, dev));
  CU(cuMemAlloc(&da, N * sizeof(float)));
  CU(cuMemAlloc(&db, N * sizeof(float)));
  CU(cuMemAlloc(&dc, N * sizeof(float)));
  CU(cuMemcpyHtoD(da, a, N * sizeof(float)));
  CU(cuMemcpyHtoD(db, b, N * sizeof(float)));

  cubin = compile("--gpu-architecture=sm_53", 1);
  ptx = compile("--gpu-architecture=compute_53", 0);
  if (!cubin || !ptx)
    goto out;
  if (run_image("sm_53 cubin", cubin, da, db, dc, a, b, c) != 0)
    goto out;
  /* The driver can JIT PTX only from a compiler no newer than itself (R36.4: CUDA 12.6);
   * a newer nvrtc (cuda-nano: 12.9) emits a PTX ISA it rejects, so that case is skipped. */
  {
    int rtc_major = 0, rtc_minor = 0;
    nvrtcVersion(&rtc_major, &rtc_minor);
    if (rtc_major * 1000 + rtc_minor * 10 > drv) {
      printf("compute_53 PTX (driver JIT): skipped, nvrtc %d.%d is newer than the driver (%d)\n",
             rtc_major, rtc_minor, drv);
    } else if (run_image("compute_53 PTX (driver JIT)", ptx, da, db, dc, a, b, c) != 0) {
      goto out;
    }
  }
  rc = 0;
  printf("E5 PASS\n");
out:
  if (rc)
    printf("E5 FAIL\n");
  if (da) cuMemFree(da);
  if (db) cuMemFree(db);
  if (dc) cuMemFree(dc);
  if (ctx) cuCtxDestroy(ctx);
  free(cubin);
  free(ptx);
  free(a);
  free(b);
  free(c);
  return rc;
}
