// SPDX-License-Identifier: MIT
// cublas_check: SGEMM on the GPU through cuBLAS (CUDA runtime API), checked against the CPU.
// Proves the cuBLAS API runs on GM20B. NVIDIA's cuBLAS cannot (no sm_53 code, and the Tegra driver
// runs only exact-architecture code); nanoblas (packaging/nanoblas) provides libcublas.so.12.
// Build: gcc -O2 -o cublas_check cublas_check.c -I/opt/cuda/include -L/opt/cuda/lib64 -lcublas -lcudart
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <cuda_runtime.h>
#include <cublas_v2.h>

#define N 1024

int main(void)
{
	float *a = malloc(sizeof(float) * N * N), *b = malloc(sizeof(float) * N * N);
	float *c = malloc(sizeof(float) * N * N), *da, *db, *dc;
	float one = 1.0f, zero = 0.0f;
	struct cudaDeviceProp p;
	cublasHandle_t h;
	cudaEvent_t t0, t1;
	float ms;
	int bad = 0, reps = 10;

	srand(1);
	for (int i = 0; i < N * N; i++) {
		a[i] = (float)rand() / RAND_MAX - 0.5f;
		b[i] = (float)rand() / RAND_MAX - 0.5f;
	}
	if (cudaGetDeviceProperties(&p, 0) != cudaSuccess) {
		printf("no CUDA device\n");
		return 1;
	}
	cudaMalloc((void **)&da, sizeof(float) * N * N);
	cudaMalloc((void **)&db, sizeof(float) * N * N);
	cudaMalloc((void **)&dc, sizeof(float) * N * N);
	cudaMemcpy(da, a, sizeof(float) * N * N, cudaMemcpyHostToDevice);
	cudaMemcpy(db, b, sizeof(float) * N * N, cudaMemcpyHostToDevice);
	if (cublasCreate(&h) != CUBLAS_STATUS_SUCCESS) {
		printf("cublasCreate failed\n");
		return 1;
	}
	/* warm-up, then timed runs */
	cublasSgemm(h, CUBLAS_OP_N, CUBLAS_OP_N, N, N, N, &one, da, N, db, N, &zero, dc, N);
	cudaEventCreate(&t0);
	cudaEventCreate(&t1);
	cudaEventRecord(t0, 0);
	for (int r = 0; r < reps; r++)
		cublasSgemm(h, CUBLAS_OP_N, CUBLAS_OP_N, N, N, N, &one, da, N, db, N, &zero, dc, N);
	cudaEventRecord(t1, 0);
	cudaEventSynchronize(t1);
	cudaEventElapsedTime(&ms, t0, t1);
	cudaMemcpy(c, dc, sizeof(float) * N * N, cudaMemcpyDeviceToHost);

	/* column-major: c[i + j*N] = sum_k a[i + k*N] * b[k + j*N]; check 4096 sampled entries */
	for (int s = 0; s < 4096; s++) {
		int i = (s * 7919) % N, j = (s * 104729) % N;
		double ref = 0;
		for (int k = 0; k < N; k++)
			ref += (double)a[i + k * N] * b[k + j * N];
		if (fabs(ref - c[i + j * N]) > 1e-3 * (1 + fabs(ref)))
			bad++;
	}
	printf("%s sm_%d%d: cuBLAS SGEMM %dx%d, %.1f GFLOP/s, %d wrong of 4096 checked\n", p.name,
	       p.major, p.minor, N, N, 2.0 * N * N * N * reps / (ms * 1e6), bad);
	printf("%s\n", bad ? "CUBLAS FAIL" : "CUBLAS PASS");
	cublasDestroy(h);
	return bad != 0;
}
