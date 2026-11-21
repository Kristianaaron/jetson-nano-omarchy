// SPDX-License-Identifier: MIT
// nanoblas tests: every GEMM type combination and transpose case on odd sizes, padded leading
// dimensions, beta, strided and pointer batches, against a double-precision CPU reference;
// batched TRSM; then GFLOP/s on a square problem and on llama.cpp-shaped problems.
// Exit status 0 only if every check passes.
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <vector>
#include <cuda_runtime.h>
#include <cuda_fp16.h>
#include <cuda_bf16.h>
#include <cublas_v2.h>

#define CK(x) do { cudaError_t e_ = (x); if (e_ != cudaSuccess) { printf("CUDA %s at %d\n", cudaGetErrorString(e_), __LINE__); exit(2); } } while (0)

static int failures;

template <typename T> T from_d(double x);
template <> float from_d<float>(double x) { return (float)x; }
template <> __half from_d<__half>(double x) { return __float2half((float)x); }
template <> __nv_bfloat16 from_d<__nv_bfloat16>(double x) { return __float2bfloat16((float)x); }
static double to_d(float x) { return x; }
static double to_d(__half x) { return __half2float(x); }
static double to_d(__nv_bfloat16 x) { return __bfloat162float(x); }

template <typename T> cudaDataType dtype();
template <> cudaDataType dtype<float>() { return CUDA_R_32F; }
template <> cudaDataType dtype<__half>() { return CUDA_R_16F; }
template <> cudaDataType dtype<__nv_bfloat16>() { return CUDA_R_16BF; }

static double rnd() { return (double)rand() / RAND_MAX - 0.5; }

// One GemmStridedBatchedEx (or pointer-array BatchedEx) call checked against the CPU.
template <typename TI, typename TO>
static void check(cublasHandle_t h, int m, int n, int k, int ta, int tb, double beta, int batch,
		  bool pointers, cublasComputeType_t ct, double tol)
{
	const int ar = ta ? k : m, ac = ta ? m : k, br = tb ? n : k, bc = tb ? k : n;
	const int lda = ar + 3, ldb = br + 1, ldc = m + 2;
	const long long sA = (long long)lda * ac, sB = (long long)ldb * bc, sC = (long long)ldc * n;
	std::vector<TI> A(sA * batch), B(sB * batch);
	std::vector<TO> C(sC * batch), R(sC * batch);
	std::vector<double> ref(sC * batch);
	for (auto &x : A) x = from_d<TI>(rnd());
	for (auto &x : B) x = from_d<TI>(rnd());
	for (auto &x : C) x = from_d<TO>(rnd());
	const double alpha = 0.75;
	for (int b = 0; b < batch; b++)
		for (int j = 0; j < n; j++)
			for (int i = 0; i < m; i++) {
				double s = 0;
				for (int p = 0; p < k; p++) {
					double a = to_d(A[b * sA + (ta ? p + (long long)i * lda : i + (long long)p * lda)]);
					double bb = to_d(B[b * sB + (tb ? j + (long long)p * ldb : p + (long long)j * ldb)]);
					s += a * bb;
				}
				ref[b * sC + i + (long long)j * ldc] = alpha * s + beta * to_d(C[b * sC + i + (long long)j * ldc]);
			}
	TI *dA, *dB;
	TO *dC;
	CK(cudaMalloc(&dA, A.size() * sizeof(TI)));
	CK(cudaMalloc(&dB, B.size() * sizeof(TI)));
	CK(cudaMalloc(&dC, C.size() * sizeof(TO)));
	CK(cudaMemcpy(dA, A.data(), A.size() * sizeof(TI), cudaMemcpyHostToDevice));
	CK(cudaMemcpy(dB, B.data(), B.size() * sizeof(TI), cudaMemcpyHostToDevice));
	CK(cudaMemcpy(dC, C.data(), C.size() * sizeof(TO), cudaMemcpyHostToDevice));
	const bool h16 = ct == CUBLAS_COMPUTE_16F;
	float af = (float)alpha, bf = (float)beta;
	__half ah = __float2half(af), bh = __float2half(bf);
	const void *pa = h16 ? (const void *)&ah : (const void *)&af;
	const void *pb = h16 ? (const void *)&bh : (const void *)&bf;
	cublasOperation_t oa = ta ? CUBLAS_OP_T : CUBLAS_OP_N, ob = tb ? CUBLAS_OP_T : CUBLAS_OP_N;
	cublasStatus_t s;
	void **ptrs = nullptr;
	if (pointers) {
		std::vector<void *> hp(3 * batch);
		for (int b = 0; b < batch; b++) {
			hp[b] = dA + b * sA;
			hp[batch + b] = dB + b * sB;
			hp[2 * batch + b] = dC + b * sC;
		}
		CK(cudaMalloc(&ptrs, hp.size() * sizeof(void *)));
		CK(cudaMemcpy(ptrs, hp.data(), hp.size() * sizeof(void *), cudaMemcpyHostToDevice));
		s = cublasGemmBatchedEx(h, oa, ob, m, n, k, pa, (const void *const *)ptrs, dtype<TI>(), lda,
					(const void *const *)(ptrs + batch), dtype<TI>(), ldb, pb,
					ptrs + 2 * batch, dtype<TO>(), ldc, batch, ct, CUBLAS_GEMM_DEFAULT);
	} else {
		s = cublasGemmStridedBatchedEx(h, oa, ob, m, n, k, pa, dA, dtype<TI>(), lda, sA, dB,
					       dtype<TI>(), ldb, sB, pb, dC, dtype<TO>(), ldc, sC, batch,
					       ct, CUBLAS_GEMM_DEFAULT);
	}
	CK(cudaDeviceSynchronize());
	CK(cudaMemcpy(R.data(), dC, R.size() * sizeof(TO), cudaMemcpyDeviceToHost));
	double worst = 0;
	long long bad = 0;
	for (int b = 0; b < batch; b++)
		for (int j = 0; j < n; j++)
			for (int i = 0; i < ldc; i++) {
				const long long idx = b * sC + i + (long long)j * ldc;
				if (i >= m) { // padding rows must be untouched
					if (to_d(R[idx]) != to_d(C[idx])) bad++;
					continue;
				}
				const double scale = sqrt((double)k) + fabs(ref[idx]);
				const double err = fabs(to_d(R[idx]) - ref[idx]) / scale;
				if (err > worst) worst = err;
				if (err > tol) bad++;
			}
	const bool ok = s == CUBLAS_STATUS_SUCCESS && bad == 0;
	if (!ok) failures++;
	printf("%s %-6s m=%4d n=%4d k=%4d %c%c beta=%.1f batch=%d %s: err %.2e%s\n", ok ? "ok  " : "FAIL",
	       h16 ? "c16f" : "c32f", m, n, k, ta ? 'T' : 'N', tb ? 'T' : 'N', beta, batch,
	       pointers ? "ptrs" : "strided", worst, s ? " (status)" : "");
	cudaFree(dA);
	cudaFree(dB);
	cudaFree(dC);
	cudaFree(ptrs);
}

static void check_trsm(cublasHandle_t h, cublasSideMode_t side, cublasFillMode_t uplo,
		       cublasOperation_t tr, cublasDiagType_t diag, int m, int n, int batch)
{
	const int an = side == CUBLAS_SIDE_LEFT ? m : n, lda = an + 1, ldb = m + 2;
	std::vector<float> A((size_t)lda * an * batch), B((size_t)ldb * n * batch), X;
	for (int b = 0; b < batch; b++)
		for (int j = 0; j < an; j++)
			for (int i = 0; i < an; i++) {
				const bool in = uplo == CUBLAS_FILL_MODE_UPPER ? i <= j : i >= j;
				A[(size_t)b * lda * an + i + (size_t)j * lda] = i == j ? 2.0f + (float)rnd() : in ? (float)rnd() * 0.5f : 99.0f;
			}
	for (auto &x : B) x = (float)rnd();
	float *dA, *dB;
	CK(cudaMalloc(&dA, A.size() * 4));
	CK(cudaMalloc(&dB, B.size() * 4));
	CK(cudaMemcpy(dA, A.data(), A.size() * 4, cudaMemcpyHostToDevice));
	CK(cudaMemcpy(dB, B.data(), B.size() * 4, cudaMemcpyHostToDevice));
	std::vector<float *> pa(batch), pb(batch);
	for (int b = 0; b < batch; b++) {
		pa[b] = dA + (size_t)b * lda * an;
		pb[b] = dB + (size_t)b * ldb * n;
	}
	float **dpa, **dpb;
	CK(cudaMalloc(&dpa, batch * sizeof(float *)));
	CK(cudaMalloc(&dpb, batch * sizeof(float *)));
	CK(cudaMemcpy(dpa, pa.data(), batch * sizeof(float *), cudaMemcpyHostToDevice));
	CK(cudaMemcpy(dpb, pb.data(), batch * sizeof(float *), cudaMemcpyHostToDevice));
	const float alpha = 1.5f;
	cublasStatus_t s = cublasStrsmBatched(h, side, uplo, tr, diag, m, n, &alpha,
					      (const float *const *)dpa, lda, dpb, ldb, batch);
	CK(cudaDeviceSynchronize());
	X.resize(B.size());
	CK(cudaMemcpy(X.data(), dB, X.size() * 4, cudaMemcpyDeviceToHost));
	double worst = 0;
	for (int b = 0; b < batch; b++) {
		const float *a = &A[(size_t)b * lda * an];
		auto opa = [&](int p, int q) -> double {
			const bool in = uplo == CUBLAS_FILL_MODE_UPPER ? (tr == CUBLAS_OP_N ? p <= q : q <= p)
								      : (tr == CUBLAS_OP_N ? p >= q : q >= p);
			if (!in) return 0.0;
			if (p == q && diag == CUBLAS_DIAG_UNIT) return 1.0;
			return tr == CUBLAS_OP_N ? a[p + (size_t)q * lda] : a[q + (size_t)p * lda];
		};
		for (int j = 0; j < n; j++)
			for (int i = 0; i < m; i++) {
				double s2 = 0;
				if (side == CUBLAS_SIDE_LEFT)
					for (int p = 0; p < m; p++) s2 += opa(i, p) * X[(size_t)b * ldb * n + p + (size_t)j * ldb];
				else
					for (int p = 0; p < n; p++) s2 += X[(size_t)b * ldb * n + i + (size_t)p * ldb] * opa(p, j);
				const double want = alpha * B[(size_t)b * ldb * n + i + (size_t)j * ldb];
				const double err = fabs(s2 - want) / (1 + fabs(want));
				if (err > worst) worst = err;
			}
	}
	const bool ok = s == CUBLAS_STATUS_SUCCESS && worst < 1e-4;
	if (!ok) failures++;
	printf("%s trsm %s %s %s %s m=%d n=%d batch=%d: err %.2e\n", ok ? "ok  " : "FAIL",
	       side == CUBLAS_SIDE_LEFT ? "L" : "R", uplo == CUBLAS_FILL_MODE_UPPER ? "U" : "L",
	       tr == CUBLAS_OP_N ? "N" : "T", diag == CUBLAS_DIAG_UNIT ? "unit" : "nonunit", m, n, batch,
	       worst);
	cudaFree(dA); cudaFree(dB); cudaFree(dpa); cudaFree(dpb);
}

template <typename TI, typename TO>
static double bench(cublasHandle_t h, int m, int n, int k, int ta, int tb, cublasComputeType_t ct)
{
	const int lda = ta ? k : m, ldb = tb ? n : k;
	TI *dA, *dB;
	TO *dC;
	CK(cudaMalloc(&dA, (size_t)m * k * sizeof(TI)));
	CK(cudaMalloc(&dB, (size_t)k * n * sizeof(TI)));
	CK(cudaMalloc(&dC, (size_t)m * n * sizeof(TO)));
	CK(cudaMemset(dA, 0, (size_t)m * k * sizeof(TI)));
	CK(cudaMemset(dB, 0, (size_t)k * n * sizeof(TI)));
	float a = 1, b = 0;
	__half ah = __float2half(1.f), bh = __float2half(0.f);
	const bool h16 = ct == CUBLAS_COMPUTE_16F;
	const void *pa = h16 ? (const void *)&ah : (const void *)&a, *pb = h16 ? (const void *)&bh : (const void *)&b;
	auto run = [&] {
		cublasGemmEx(h, ta ? CUBLAS_OP_T : CUBLAS_OP_N, tb ? CUBLAS_OP_T : CUBLAS_OP_N, m, n, k, pa, dA,
			     dtype<TI>(), lda, dB, dtype<TI>(), ldb, pb, dC, dtype<TO>(), m, ct, CUBLAS_GEMM_DEFAULT);
	};
	run();
	CK(cudaDeviceSynchronize());
	cudaEvent_t e0, e1;
	cudaEventCreate(&e0);
	cudaEventCreate(&e1);
	int reps = 0;
	float ms = 0;
	cudaEventRecord(e0);
	do {
		run();
		reps++;
		cudaEventRecord(e1);
		cudaEventSynchronize(e1);
		cudaEventElapsedTime(&ms, e0, e1);
	} while (ms < 1000 && reps < 1000);
	cudaFree(dA); cudaFree(dB); cudaFree(dC);
	return 2.0 * m * n * k * reps / (ms * 1e6);
}

int main(int argc, char **argv)
{
	cublasHandle_t h;
	cublasStatus_t s = cublasCreate(&h);
	if (s != CUBLAS_STATUS_SUCCESS) {
		printf("cublasCreate: %s\n", cublasGetStatusString(s));
		return 1;
	}
	srand(7);
	const int sizes[][3] = { { 1, 1, 1 }, { 7, 13, 5 }, { 64, 64, 16 }, { 129, 65, 33 },
				 { 300, 257, 129 }, { 520, 384, 70 } };
	for (auto &sz : sizes)
		for (int t = 0; t < 4; t++) {
			check<float, float>(h, sz[0], sz[1], sz[2], t & 1, t >> 1, t == 3 ? 0.5 : 0.0, 1, false, CUBLAS_COMPUTE_32F, 1e-5);
			check<__half, float>(h, sz[0], sz[1], sz[2], t & 1, t >> 1, t == 1 ? 0.5 : 0.0, 1, false, CUBLAS_COMPUTE_32F, 1e-5);
		}
	check<__half, __half>(h, 300, 257, 129, 1, 0, 0.0, 1, false, CUBLAS_COMPUTE_16F, 2e-3);
	check<__half, __half>(h, 129, 65, 33, 0, 1, 0.5, 1, false, CUBLAS_COMPUTE_32F, 2e-3);
	check<__nv_bfloat16, float>(h, 300, 257, 129, 1, 0, 0.0, 1, false, CUBLAS_COMPUTE_32F, 1e-5);
	check<__nv_bfloat16, __nv_bfloat16>(h, 129, 65, 33, 0, 0, 0.5, 1, false, CUBLAS_COMPUTE_32F, 1e-2);
	check<float, float>(h, 70, 90, 40, 1, 0, 0.0, 5, false, CUBLAS_COMPUTE_32F, 1e-5);
	check<__half, float>(h, 70, 90, 40, 0, 1, 0.5, 4, true, CUBLAS_COMPUTE_32F, 1e-5);
	check<__half, __half>(h, 33, 47, 64, 1, 0, 0.0, 6, true, CUBLAS_COMPUTE_16F, 2e-3);
	for (int side = 0; side < 2; side++)
		for (int up = 0; up < 2; up++)
			for (int tr = 0; tr < 2; tr++)
				check_trsm(h, side ? CUBLAS_SIDE_RIGHT : CUBLAS_SIDE_LEFT,
					   up ? CUBLAS_FILL_MODE_UPPER : CUBLAS_FILL_MODE_LOWER,
					   tr ? CUBLAS_OP_T : CUBLAS_OP_N, (side + up + tr) % 2 ? CUBLAS_DIAG_UNIT : CUBLAS_DIAG_NON_UNIT,
					   37, 29, 3);
	printf("%s: %d failure(s)\n", failures ? "TESTS FAIL" : "TESTS PASS", failures);
	if (argc > 1) {
		struct { int m, n, k, ta; const char *what; } shapes[] = {
			{ 1024, 1024, 1024, 0, "square" },
			{ 896, 512, 896, 1, "0.5B attn proj, 512 tokens" },
			{ 4864, 512, 896, 1, "0.5B ffn up, 512 tokens" },
			{ 896, 512, 4864, 1, "0.5B ffn down, 512 tokens" },
			{ 2048, 512, 2048, 1, "1.5B-class proj, 512 tokens" },
		};
		for (auto &sh : shapes)
			printf("bench %-30s m=%5d n=%4d k=%5d: FP32 %6.1f GFLOP/s, FP16-in/FP32-out %6.1f GFLOP/s\n", sh.what,
			       sh.m, sh.n, sh.k, bench<float, float>(h, sh.m, sh.n, sh.k, sh.ta, 0, CUBLAS_COMPUTE_32F),
			       bench<__half, float>(h, sh.m, sh.n, sh.k, sh.ta, 0, CUBLAS_COMPUTE_32F));
	}
	cublasDestroy(h);
	return failures ? 1 : 0;
}
