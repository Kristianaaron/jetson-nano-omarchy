// Minimal CUDA SM 5.3 smoke test for the Jetson Nano's GM20B.
// Three independent operators, each checked against a CPU reference:
//   1. vector add
//   2. 1-D convolution (5-tap)
//   3. FP16 dot product (GM20B has native half arithmetic)
// Build: nvcc -arch=sm_53 -O2 -o sm53_smoke minimal_sm53.cu
// A pass here proves kernels launched; it does not prove model or library support.

#include <cstdio>
#include <cstdlib>
#include <cmath>
#include <cuda_fp16.h>
#include <cuda_runtime.h>

#define CHECK(call)                                                            \
  do {                                                                         \
    cudaError_t e = (call);                                                    \
    if (e != cudaSuccess) {                                                    \
      fprintf(stderr, "CUDA error %s at %s:%d\n", cudaGetErrorString(e),       \
              __FILE__, __LINE__);                                             \
      exit(1);                                                                 \
    }                                                                          \
  } while (0)

__global__ void vec_add(const float *a, const float *b, float *c, int n) {
  int i = blockIdx.x * blockDim.x + threadIdx.x;
  if (i < n) c[i] = a[i] + b[i];
}

__global__ void conv1d(const float *x, const float *k, float *y, int n) {
  int i = blockIdx.x * blockDim.x + threadIdx.x;
  if (i >= n) return;
  float acc = 0.f;
  for (int t = 0; t < 5; ++t) {
    int j = i + t;
    if (j < n) acc += x[j] * k[t];
  }
  y[i] = acc;
}

__global__ void dot_half(const __half *a, const __half *b, float *out, int n) {
  int i = blockIdx.x * blockDim.x + threadIdx.x;
  if (i >= n) return;
  float v = __half2float(a[i]) * __half2float(b[i]);
  atomicAdd(out, v);
}

static int gpu_launches = 0;

int main() {
  int dev = 0;
  CHECK(cudaGetDevice(&dev));
  cudaDeviceProp p{};
  CHECK(cudaGetDeviceProperties(&p, dev));
  int major = p.major, minor = p.minor;
  printf("device: %s, compute capability %d.%d, driver %d.%d\n", p.name, major,
         minor, p.driverVersion / 1000, (p.driverVersion % 1000) / 10);
  if (major != 5 || minor != 3)
    printf("note: this build targets sm_53; device reports %d.%d\n", major, minor);

  const int n = 1 << 20, threads = 256, blocks = (n + threads - 1) / threads;
  float *a, *b, *c, *k, *y;
  __half *ha, *hb;
  float *d_sum;
  CHECK(cudaMallocManaged(&a, n * sizeof(float)));
  CHECK(cudaMallocManaged(&b, n * sizeof(float)));
  CHECK(cudaMallocManaged(&c, n * sizeof(float)));
  CHECK(cudaMallocManaged(&k, 5 * sizeof(float)));
  CHECK(cudaMallocManaged(&y, n * sizeof(float)));
  CHECK(cudaMallocManaged(&ha, n * sizeof(__half)));
  CHECK(cudaMallocManaged(&hb, n * sizeof(__half)));
  CHECK(cudaMallocManaged(&d_sum, sizeof(float)));

  for (int i = 0; i < n; ++i) {
    a[i] = sinf(i * 0.001f);
    b[i] = cosf(i * 0.002f);
    ha[i] = __float2half(a[i]);
    hb[i] = __float2half(b[i]);
  }
  for (int t = 0; t < 5; ++t) k[t] = 0.1f * (t + 1);
  *d_sum = 0.f;

  int fails = 0;

  vec_add<<<blocks, threads>>>(a, b, c, n);
  ++gpu_launches;
  CHECK(cudaDeviceSynchronize());
  double worst = 0;
  for (int i = 0; i < n; ++i) worst = fmax(worst, fabs(c[i] - (a[i] + b[i])));
  printf("%s vec_add worst_abs_err=%.3e tol=1e-6\n", worst < 1e-6 ? "PASS" : "FAIL", worst);
  fails += worst >= 1e-6;

  conv1d<<<blocks, threads>>>(a, k, y, n);
  ++gpu_launches;
  CHECK(cudaDeviceSynchronize());
  worst = 0;
  for (int i = 0; i < n; ++i) {
    float acc = 0.f;
    for (int t = 0; t < 5; ++t)
      if (i + t < n) acc += a[i + t] * k[t];
    worst = fmax(worst, fabs(y[i] - acc));
  }
  printf("%s conv1d worst_abs_err=%.3e tol=1e-5\n", worst < 1e-5 ? "PASS" : "FAIL", worst);
  fails += worst >= 1e-5;

  dot_half<<<blocks, threads>>>(ha, hb, d_sum, n);
  ++gpu_launches;
  CHECK(cudaDeviceSynchronize());
  float ref = 0.f;
  for (int i = 0; i < n; ++i) ref += __half2float(ha[i]) * __half2float(hb[i]);
  double rel = fabs(*d_sum - ref) / fmax(fabs(ref), 1e-6);
  printf("%s dot_half gpu=%.6f cpu=%.6f rel_err=%.3e tol=1e-2\n",
         rel < 1e-2 ? "PASS" : "FAIL", *d_sum, ref, rel);
  fails += rel >= 1e-2;

  printf("launches=%d fails=%d\n", gpu_launches, fails);
  return fails == 0 ? 0 : 2;
}
