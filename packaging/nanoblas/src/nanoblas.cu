// SPDX-License-Identifier: MIT
// nanoblas: cuBLAS API subset for the Jetson Nano's GM20B (sm_53); see include/cublas_api.h.
//
// GEMM: one register-tiled kernel family. A thread block computes a BM x BN tile of C in
// steps of BK along k: the A and B sub-tiles go to shared memory (converted to float, op(A) and
// op(B) applied while loading, out-of-range elements as zero), and each thread accumulates a
// TM x TN micro-tile in registers with FP32 FMA, reading shared memory four floats at a time so the
// FMA units, not shared-memory bandwidth, set the pace. Inputs FP32/FP16/BF16 are accumulated in
// FP32 (at least as accurate as cuBLAS's FP16 compute); C may be FP32/FP16/BF16. Batches run on
// gridDim.z. The next k step's global loads are issued before the current step's FMAs and land in
// a second shared buffer (one barrier per step), which hides memory latency on the single SM. Two tile shapes: 128x128 (8x8 per thread) for large problems, 64x64 (4x4) for small.
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cuda_runtime.h>
#include <cuda_fp16.h>
#include <cuda_bf16.h>
#include "cublas_v2.h"

struct cublasContext {
	cudaStream_t stream;
	cublasPointerMode_t pmode;
	cublasMath_t math;
};

namespace {

__device__ __forceinline__ float to_f(float x) { return x; }
__device__ __forceinline__ float to_f(__half x) { return __half2float(x); }
__device__ __forceinline__ float to_f(__nv_bfloat16 x) { return __bfloat162float(x); }

template <typename T> __device__ __forceinline__ T from_f(float x);
template <> __device__ __forceinline__ float from_f<float>(float x) { return x; }
template <> __device__ __forceinline__ __half from_f<__half>(float x) { return __float2half_rn(x); }
template <> __device__ __forceinline__ __nv_bfloat16 from_f<__nv_bfloat16>(float x)
{
	return __float2bfloat16_rn(x);
}

struct GemmArgs {
	int m, n, k, ta, tb, batch;
	float alpha, beta;
	const void *A, *B;
	void *C;
	long long lda, ldb, ldc, sA, sB, sC;
	const void *const *Ap, *const *Bp;
	void *const *Cp;
};

// op(A)[i, kq] is A[i + kq*lda] (N) or A[kq + i*lda] (T); op(B)[kq, j] is B[kq + j*ldb] (N) or
// B[j + kq*ldb] (T). The transposes are template parameters, so the loads have no branches.
template <int TR, int ROWS, int BK, int NT> struct TileIndex {
	// element e of the ROWS x BK tile: the memory-contiguous index runs fastest across threads
	static __device__ __forceinline__ void at(int e, int &row, int &kk)
	{
		if (!TR) {
			row = e % ROWS;
			kk = e / ROWS;
		} else {
			kk = e % BK;
			row = e / BK;
		}
	}
};

template <typename TA, typename TB, typename TC, int BM, int BN, int BK, int TM, int TN, int TRA,
	  int TRB>
__global__ void __launch_bounds__((BM / TM) * (BN / TN)) gemm_kernel(GemmArgs g)
{
	constexpr int NT = (BM / TM) * (BN / TN);
	constexpr int TX = BM / TM;
	constexpr int LA = (BM * BK) / NT, LB = (BK * BN) / NT;
	static_assert(TM % 4 == 0 && TN % 4 == 0, "micro-tile is read as float4");
	static_assert((BM * BK) % NT == 0 && (BK * BN) % NT == 0, "tile loads must divide");
	// two buffers: the next tile is stored while the current one is read
	__shared__ __align__(16) float As[2][BK][BM + 4];
	__shared__ __align__(16) float Bs[2][BK][BN + 4];

	const int tid = threadIdx.x, tx = tid % TX, ty = tid / TX;
	const int m0 = blockIdx.x * BM, n0 = blockIdx.y * BN;

	for (int b = blockIdx.z; b < g.batch; b += gridDim.z) {
		const TA *A = g.Ap ? (const TA *)g.Ap[b] : (const TA *)g.A + b * g.sA;
		const TB *B = g.Bp ? (const TB *)g.Bp[b] : (const TB *)g.B + b * g.sB;
		TC *C = g.Cp ? (TC *)g.Cp[b] : (TC *)g.C + b * g.sC;
		float acc[TM][TN];
#pragma unroll
		for (int r = 0; r < TM; r++)
#pragma unroll
			for (int c = 0; c < TN; c++)
				acc[r][c] = 0.f;

		float ra[LA], rb[LB];
		auto fetch = [&](int k0) {
#pragma unroll
			for (int l = 0; l < LA; l++) {
				int row, kk;
				TileIndex<TRA, BM, BK, NT>::at(tid + l * NT, row, kk);
				const int i = m0 + row, kq = k0 + kk;
				ra[l] = (i < g.m && kq < g.k)
						? to_f(TRA ? A[kq + (long long)i * g.lda] : A[i + (long long)kq * g.lda])
						: 0.f;
			}
#pragma unroll
			for (int l = 0; l < LB; l++) {
				int col, kk;
				TileIndex<!TRB, BN, BK, NT>::at(tid + l * NT, col, kk);
				const int j = n0 + col, kq = k0 + kk;
				rb[l] = (j < g.n && kq < g.k)
						? to_f(TRB ? B[j + (long long)kq * g.ldb] : B[kq + (long long)j * g.ldb])
						: 0.f;
			}
		};
		auto stash = [&](int buf) {
#pragma unroll
			for (int l = 0; l < LA; l++) {
				int row, kk;
				TileIndex<TRA, BM, BK, NT>::at(tid + l * NT, row, kk);
				As[buf][kk][row] = ra[l];
			}
#pragma unroll
			for (int l = 0; l < LB; l++) {
				int col, kk;
				TileIndex<!TRB, BN, BK, NT>::at(tid + l * NT, col, kk);
				Bs[buf][kk][col] = rb[l];
			}
		};

		fetch(0);
		stash(0);
		__syncthreads();
		int buf = 0;
		for (int k0 = 0; k0 < g.k; k0 += BK) {
			const bool more = k0 + BK < g.k;
			if (more)
				fetch(k0 + BK); // global loads in flight during the FMAs below
#pragma unroll
			for (int kk = 0; kk < BK; kk++) {
				float a[TM], bv[TN];
#pragma unroll
				for (int q = 0; q < TM / 4; q++) {
					const float4 t = *(const float4 *)&As[buf][kk][tx * TM + 4 * q];
					a[4 * q] = t.x;
					a[4 * q + 1] = t.y;
					a[4 * q + 2] = t.z;
					a[4 * q + 3] = t.w;
				}
#pragma unroll
				for (int q = 0; q < TN / 4; q++) {
					const float4 t = *(const float4 *)&Bs[buf][kk][ty * TN + 4 * q];
					bv[4 * q] = t.x;
					bv[4 * q + 1] = t.y;
					bv[4 * q + 2] = t.z;
					bv[4 * q + 3] = t.w;
				}
#pragma unroll
				for (int r = 0; r < TM; r++)
#pragma unroll
					for (int c = 0; c < TN; c++)
						acc[r][c] = fmaf(a[r], bv[c], acc[r][c]);
			}
			if (more)
				stash(buf ^ 1); // the other buffer: nobody reads it in this step
			__syncthreads();
			buf ^= 1;
		}
#pragma unroll
		for (int c = 0; c < TN; c++) {
			const int j = n0 + ty * TN + c;
			if (j >= g.n)
				continue;
#pragma unroll
			for (int r = 0; r < TM; r++) {
				const int i = m0 + tx * TM + r;
				if (i >= g.m)
					continue;
				const long long idx = i + (long long)j * g.ldc;
				float out = g.alpha * acc[r][c];
				if (g.beta != 0.f)
					out = fmaf(g.beta, to_f(C[idx]), out);
				C[idx] = from_f<TC>(out);
			}
		}
		__syncthreads(); // the next batch item reuses the shared buffers
	}
}

template <typename TA, typename TB, typename TC, int BM, int BN, int BK, int TM, int TN>
void launch_tiles(cudaStream_t stream, const GemmArgs &g, unsigned z)
{
	dim3 grid((g.m + BM - 1) / BM, (g.n + BN - 1) / BN, z);
	constexpr int NT = (BM / TM) * (BN / TN);
	if (!g.ta && !g.tb)
		gemm_kernel<TA, TB, TC, BM, BN, BK, TM, TN, 0, 0><<<grid, NT, 0, stream>>>(g);
	else if (g.ta && !g.tb)
		gemm_kernel<TA, TB, TC, BM, BN, BK, TM, TN, 1, 0><<<grid, NT, 0, stream>>>(g);
	else if (!g.ta && g.tb)
		gemm_kernel<TA, TB, TC, BM, BN, BK, TM, TN, 0, 1><<<grid, NT, 0, stream>>>(g);
	else
		gemm_kernel<TA, TB, TC, BM, BN, BK, TM, TN, 1, 1><<<grid, NT, 0, stream>>>(g);
}

template <typename TA, typename TB, typename TC>
cublasStatus_t launch_gemm(cudaStream_t stream, GemmArgs g)
{
	if (g.m < 0 || g.n < 0 || g.k < 0 || g.batch < 0)
		return CUBLAS_STATUS_INVALID_VALUE;
	if (g.m == 0 || g.n == 0 || g.batch == 0)
		return CUBLAS_STATUS_SUCCESS;
	const unsigned z = g.batch < 65535 ? g.batch : 65535;
	if ((long long)g.m * g.n >= 128LL * 128 * 4)
		launch_tiles<TA, TB, TC, 128, 128, 8, 8, 8>(stream, g, z);
	else
		launch_tiles<TA, TB, TC, 64, 64, 16, 4, 4>(stream, g, z);
	return cudaGetLastError() == cudaSuccess ? CUBLAS_STATUS_SUCCESS : CUBLAS_STATUS_EXECUTION_FAILED;
}

int op_of(cublasOperation_t op) { return op != CUBLAS_OP_N; }

bool compute_is_16f(cublasComputeType_t t)
{
	return t == CUBLAS_COMPUTE_16F || t == CUBLAS_COMPUTE_16F_PEDANTIC;
}

bool compute_is_32f(cublasComputeType_t t)
{
	return t == CUBLAS_COMPUTE_32F || t == CUBLAS_COMPUTE_32F_PEDANTIC ||
	       t == CUBLAS_COMPUTE_32F_FAST_16F || t == CUBLAS_COMPUTE_32F_FAST_16BF ||
	       t == CUBLAS_COMPUTE_32F_FAST_TF32;
}

// alpha/beta: float for FP32 compute, __half for FP16 compute; host or device pointers
cublasStatus_t read_scalar(cublasHandle_t h, const void *p, bool half, float *out)
{
	if (!p)
		return CUBLAS_STATUS_INVALID_VALUE;
	if (h->pmode == CUBLAS_POINTER_MODE_DEVICE) {
		unsigned char buf[4] = { 0 };
		if (cudaMemcpyAsync(buf, p, half ? 2 : 4, cudaMemcpyDeviceToHost, h->stream) != cudaSuccess ||
		    cudaStreamSynchronize(h->stream) != cudaSuccess)
			return CUBLAS_STATUS_EXECUTION_FAILED;
		p = buf;
		if (half) {
			__half_raw r;
			memcpy(&r.x, buf, 2);
			*out = __half2float(__half(r));
		} else {
			memcpy(out, buf, 4);
		}
		return CUBLAS_STATUS_SUCCESS;
	}
	if (half)
		*out = __half2float(*(const __half *)p);
	else
		*out = *(const float *)p;
	return CUBLAS_STATUS_SUCCESS;
}

cublasStatus_t gemm_ex(cublasHandle_t h, cublasOperation_t transa, cublasOperation_t transb, int m,
		       int n, int k, const void *alpha, cudaDataType at, cudaDataType bt,
		       const void *beta, cudaDataType ct, cublasComputeType_t compute, GemmArgs g)
{
	if (!h)
		return CUBLAS_STATUS_NOT_INITIALIZED;
	const bool half_scalars = compute_is_16f(compute);
	if (!half_scalars && !compute_is_32f(compute))
		return CUBLAS_STATUS_NOT_SUPPORTED;
	cublasStatus_t s = read_scalar(h, alpha, half_scalars, &g.alpha);
	if (s == CUBLAS_STATUS_SUCCESS)
		s = read_scalar(h, beta, half_scalars, &g.beta);
	if (s != CUBLAS_STATUS_SUCCESS)
		return s;
	g.m = m;
	g.n = n;
	g.k = k;
	g.ta = op_of(transa);
	g.tb = op_of(transb);
	if (at != bt)
		return CUBLAS_STATUS_NOT_SUPPORTED;
	switch (at) {
	case CUDA_R_32F:
		if (ct == CUDA_R_32F)
			return launch_gemm<float, float, float>(h->stream, g);
		break;
	case CUDA_R_16F:
		if (ct == CUDA_R_16F)
			return launch_gemm<__half, __half, __half>(h->stream, g);
		if (ct == CUDA_R_32F)
			return launch_gemm<__half, __half, float>(h->stream, g);
		break;
	case CUDA_R_16BF:
		if (ct == CUDA_R_16BF)
			return launch_gemm<__nv_bfloat16, __nv_bfloat16, __nv_bfloat16>(h->stream, g);
		if (ct == CUDA_R_32F)
			return launch_gemm<__nv_bfloat16, __nv_bfloat16, float>(h->stream, g);
		break;
	default:
		break;
	}
	return CUBLAS_STATUS_NOT_SUPPORTED;
}

GemmArgs args_strided(const void *A, long long lda, long long sA, const void *B, long long ldb,
		      long long sB, void *C, long long ldc, long long sC, int batch)
{
	GemmArgs g = {};
	g.A = A;
	g.B = B;
	g.C = C;
	g.lda = lda;
	g.ldb = ldb;
	g.ldc = ldc;
	g.sA = sA;
	g.sB = sB;
	g.sC = sC;
	g.batch = batch;
	return g;
}

GemmArgs args_pointers(const void *const *Ap, long long lda, const void *const *Bp, long long ldb,
		       void *const *Cp, long long ldc, int batch)
{
	GemmArgs g = {};
	g.Ap = Ap;
	g.Bp = Bp;
	g.Cp = Cp;
	g.lda = lda;
	g.ldb = ldb;
	g.ldc = ldc;
	g.batch = batch;
	return g;
}

// TRSM, batched: one thread per independent vector (a column of B for the left side, a row for
// the right side), solved in place by substitution. op(A) is upper when (uplo, trans) say so.
__global__ void trsm_kernel(int left, int upper, int trans, int unit, int m, int n, float alpha,
			    const float *const *Aa, int lda, float *const *Ba, int ldb, int batch)
{
	const int vecs = left ? n : m;
	const long long total = (long long)vecs * batch;
	for (long long t = blockIdx.x * (long long)blockDim.x + threadIdx.x; t < total;
	     t += (long long)gridDim.x * blockDim.x) {
		const int b = t / vecs, v = t % vecs;
		const float *a = Aa[b];
		float *x = Ba[b];
		auto opa = [&](int p, int q) {
			return trans ? a[q + (long long)p * lda] : a[p + (long long)q * lda];
		};
		if (left) { // op(A) X(:, v) = alpha B(:, v), op(A) is m x m
			auto X = [&](int i) -> float & { return x[i + (long long)v * ldb]; };
			if (upper) {
				for (int i = m - 1; i >= 0; i--) {
					float s = alpha * X(i);
					for (int j = i + 1; j < m; j++)
						s -= opa(i, j) * X(j);
					X(i) = unit ? s : s / opa(i, i);
				}
			} else {
				for (int i = 0; i < m; i++) {
					float s = alpha * X(i);
					for (int j = 0; j < i; j++)
						s -= opa(i, j) * X(j);
					X(i) = unit ? s : s / opa(i, i);
				}
			}
		} else { // X(v, :) op(A) = alpha B(v, :), op(A) is n x n
			auto X = [&](int j) -> float & { return x[v + (long long)j * ldb]; };
			if (upper) {
				for (int j = 0; j < n; j++) {
					float s = alpha * X(j);
					for (int i = 0; i < j; i++)
						s -= X(i) * opa(i, j);
					X(j) = unit ? s : s / opa(j, j);
				}
			} else {
				for (int j = n - 1; j >= 0; j--) {
					float s = alpha * X(j);
					for (int i = j + 1; i < n; i++)
						s -= X(i) * opa(i, j);
					X(j) = unit ? s : s / opa(j, j);
				}
			}
		}
	}
}

cublasLogCallback log_callback;

} // namespace

extern "C" {

cublasStatus_t cublasCreate_v2(cublasHandle_t *handle)
{
	int dev, major = 0, minor = 0;
	if (!handle)
		return CUBLAS_STATUS_INVALID_VALUE;
	if (cudaGetDevice(&dev) != cudaSuccess ||
	    cudaDeviceGetAttribute(&major, cudaDevAttrComputeCapabilityMajor, dev) != cudaSuccess ||
	    cudaDeviceGetAttribute(&minor, cudaDevAttrComputeCapabilityMinor, dev) != cudaSuccess)
		return CUBLAS_STATUS_NOT_INITIALIZED;
	if (major != 5 || minor != 3) // the kernels are built for sm_53 only
		return CUBLAS_STATUS_ARCH_MISMATCH;
	cublasContext *c = (cublasContext *)calloc(1, sizeof(*c));
	if (!c)
		return CUBLAS_STATUS_ALLOC_FAILED;
	c->stream = 0;
	c->pmode = CUBLAS_POINTER_MODE_HOST;
	c->math = CUBLAS_DEFAULT_MATH;
	*handle = c;
	return CUBLAS_STATUS_SUCCESS;
}

cublasStatus_t cublasDestroy_v2(cublasHandle_t handle)
{
	if (!handle)
		return CUBLAS_STATUS_NOT_INITIALIZED;
	free(handle);
	return CUBLAS_STATUS_SUCCESS;
}

cublasStatus_t cublasGetVersion_v2(cublasHandle_t handle, int *version)
{
	(void)handle;
	if (!version)
		return CUBLAS_STATUS_INVALID_VALUE;
	*version = CUBLAS_VERSION;
	return CUBLAS_STATUS_SUCCESS;
}

cublasStatus_t cublasGetProperty(libraryPropertyType type, int *value)
{
	if (!value)
		return CUBLAS_STATUS_INVALID_VALUE;
	switch (type) {
	case MAJOR_VERSION: *value = CUBLAS_VER_MAJOR; break;
	case MINOR_VERSION: *value = CUBLAS_VER_MINOR; break;
	case PATCH_LEVEL: *value = CUBLAS_VER_PATCH; break;
	default: return CUBLAS_STATUS_INVALID_VALUE;
	}
	return CUBLAS_STATUS_SUCCESS;
}

size_t cublasGetCudartVersion(void) { return CUDART_VERSION; }

cublasStatus_t cublasSetWorkspace_v2(cublasHandle_t handle, void *workspace, size_t size)
{
	(void)workspace;
	(void)size; // the kernels need no workspace
	return handle ? CUBLAS_STATUS_SUCCESS : CUBLAS_STATUS_NOT_INITIALIZED;
}

cublasStatus_t cublasSetStream_v2(cublasHandle_t handle, cudaStream_t stream)
{
	if (!handle)
		return CUBLAS_STATUS_NOT_INITIALIZED;
	handle->stream = stream;
	return CUBLAS_STATUS_SUCCESS;
}

cublasStatus_t cublasGetStream_v2(cublasHandle_t handle, cudaStream_t *stream)
{
	if (!handle)
		return CUBLAS_STATUS_NOT_INITIALIZED;
	if (!stream)
		return CUBLAS_STATUS_INVALID_VALUE;
	*stream = handle->stream;
	return CUBLAS_STATUS_SUCCESS;
}

cublasStatus_t cublasGetPointerMode_v2(cublasHandle_t handle, cublasPointerMode_t *mode)
{
	if (!handle)
		return CUBLAS_STATUS_NOT_INITIALIZED;
	if (!mode)
		return CUBLAS_STATUS_INVALID_VALUE;
	*mode = handle->pmode;
	return CUBLAS_STATUS_SUCCESS;
}

cublasStatus_t cublasSetPointerMode_v2(cublasHandle_t handle, cublasPointerMode_t mode)
{
	if (!handle)
		return CUBLAS_STATUS_NOT_INITIALIZED;
	if (mode != CUBLAS_POINTER_MODE_HOST && mode != CUBLAS_POINTER_MODE_DEVICE)
		return CUBLAS_STATUS_INVALID_VALUE;
	handle->pmode = mode;
	return CUBLAS_STATUS_SUCCESS;
}

cublasStatus_t cublasGetMathMode(cublasHandle_t handle, cublasMath_t *mode)
{
	if (!handle)
		return CUBLAS_STATUS_NOT_INITIALIZED;
	if (!mode)
		return CUBLAS_STATUS_INVALID_VALUE;
	*mode = handle->math;
	return CUBLAS_STATUS_SUCCESS;
}

cublasStatus_t cublasSetMathMode(cublasHandle_t handle, cublasMath_t mode)
{
	if (!handle)
		return CUBLAS_STATUS_NOT_INITIALIZED;
	handle->math = mode; // accumulation is FP32 in every mode
	return CUBLAS_STATUS_SUCCESS;
}

const char *cublasGetStatusName(cublasStatus_t s)
{
	switch (s) {
	case CUBLAS_STATUS_SUCCESS: return "CUBLAS_STATUS_SUCCESS";
	case CUBLAS_STATUS_NOT_INITIALIZED: return "CUBLAS_STATUS_NOT_INITIALIZED";
	case CUBLAS_STATUS_ALLOC_FAILED: return "CUBLAS_STATUS_ALLOC_FAILED";
	case CUBLAS_STATUS_INVALID_VALUE: return "CUBLAS_STATUS_INVALID_VALUE";
	case CUBLAS_STATUS_ARCH_MISMATCH: return "CUBLAS_STATUS_ARCH_MISMATCH";
	case CUBLAS_STATUS_MAPPING_ERROR: return "CUBLAS_STATUS_MAPPING_ERROR";
	case CUBLAS_STATUS_EXECUTION_FAILED: return "CUBLAS_STATUS_EXECUTION_FAILED";
	case CUBLAS_STATUS_INTERNAL_ERROR: return "CUBLAS_STATUS_INTERNAL_ERROR";
	case CUBLAS_STATUS_NOT_SUPPORTED: return "CUBLAS_STATUS_NOT_SUPPORTED";
	case CUBLAS_STATUS_LICENSE_ERROR: return "CUBLAS_STATUS_LICENSE_ERROR";
	}
	return "CUBLAS_STATUS_UNKNOWN";
}

const char *cublasGetStatusString(cublasStatus_t s)
{
	switch (s) {
	case CUBLAS_STATUS_SUCCESS: return "success";
	case CUBLAS_STATUS_NOT_INITIALIZED: return "the library was not initialized";
	case CUBLAS_STATUS_ALLOC_FAILED: return "the resource allocation failed";
	case CUBLAS_STATUS_INVALID_VALUE: return "an invalid numeric value was used as an argument";
	case CUBLAS_STATUS_ARCH_MISMATCH: return "nanoblas runs on compute capability 5.3 (GM20B) only";
	case CUBLAS_STATUS_MAPPING_ERROR: return "an access to GPU memory space failed";
	case CUBLAS_STATUS_EXECUTION_FAILED: return "the GPU program failed to execute";
	case CUBLAS_STATUS_INTERNAL_ERROR: return "an internal operation failed";
	case CUBLAS_STATUS_NOT_SUPPORTED: return "the functionality requested is not supported";
	case CUBLAS_STATUS_LICENSE_ERROR: return "license error";
	}
	return "unknown error";
}

cublasStatus_t cublasLoggerConfigure(int on, int out, int err, const char *file)
{
	(void)on;
	(void)out;
	(void)err;
	(void)file;
	return CUBLAS_STATUS_SUCCESS;
}

cublasStatus_t cublasSetLoggerCallback(cublasLogCallback cb)
{
	log_callback = cb;
	return CUBLAS_STATUS_SUCCESS;
}

cublasStatus_t cublasGetLoggerCallback(cublasLogCallback *cb)
{
	if (!cb)
		return CUBLAS_STATUS_INVALID_VALUE;
	*cb = log_callback;
	return CUBLAS_STATUS_SUCCESS;
}

cublasStatus_t cublasSgemm_v2(cublasHandle_t h, cublasOperation_t ta, cublasOperation_t tb, int m,
			      int n, int k, const float *alpha, const float *A, int lda, const float *B,
			      int ldb, const float *beta, float *C, int ldc)
{
	return gemm_ex(h, ta, tb, m, n, k, alpha, CUDA_R_32F, CUDA_R_32F, beta, CUDA_R_32F,
		       CUBLAS_COMPUTE_32F, args_strided(A, lda, 0, B, ldb, 0, C, ldc, 0, 1));
}

cublasStatus_t cublasHgemm(cublasHandle_t h, cublasOperation_t ta, cublasOperation_t tb, int m, int n,
			   int k, const __half *alpha, const __half *A, int lda, const __half *B, int ldb,
			   const __half *beta, __half *C, int ldc)
{
	return gemm_ex(h, ta, tb, m, n, k, alpha, CUDA_R_16F, CUDA_R_16F, beta, CUDA_R_16F,
		       CUBLAS_COMPUTE_16F, args_strided(A, lda, 0, B, ldb, 0, C, ldc, 0, 1));
}

cublasStatus_t cublasSgemmBatched(cublasHandle_t h, cublasOperation_t ta, cublasOperation_t tb, int m,
				  int n, int k, const float *alpha, const float *const Aarray[], int lda,
				  const float *const Barray[], int ldb, const float *beta,
				  float *const Carray[], int ldc, int batch)
{
	return gemm_ex(h, ta, tb, m, n, k, alpha, CUDA_R_32F, CUDA_R_32F, beta, CUDA_R_32F,
		       CUBLAS_COMPUTE_32F,
		       args_pointers((const void *const *)Aarray, lda, (const void *const *)Barray, ldb,
				     (void *const *)Carray, ldc, batch));
}

cublasStatus_t cublasSgemmStridedBatched(cublasHandle_t h, cublasOperation_t ta, cublasOperation_t tb,
					 int m, int n, int k, const float *alpha, const float *A,
					 int lda, long long sA, const float *B, int ldb, long long sB,
					 const float *beta, float *C, int ldc, long long sC, int batch)
{
	return gemm_ex(h, ta, tb, m, n, k, alpha, CUDA_R_32F, CUDA_R_32F, beta, CUDA_R_32F,
		       CUBLAS_COMPUTE_32F, args_strided(A, lda, sA, B, ldb, sB, C, ldc, sC, batch));
}

cublasStatus_t cublasGemmEx(cublasHandle_t h, cublasOperation_t ta, cublasOperation_t tb, int m, int n,
			    int k, const void *alpha, const void *A, cudaDataType at, int lda,
			    const void *B, cudaDataType bt, int ldb, const void *beta, void *C,
			    cudaDataType ct, int ldc, cublasComputeType_t compute, cublasGemmAlgo_t algo)
{
	(void)algo;
	return gemm_ex(h, ta, tb, m, n, k, alpha, at, bt, beta, ct, compute,
		       args_strided(A, lda, 0, B, ldb, 0, C, ldc, 0, 1));
}

cublasStatus_t cublasGemmBatchedEx(cublasHandle_t h, cublasOperation_t ta, cublasOperation_t tb, int m,
				   int n, int k, const void *alpha, const void *const Aarray[],
				   cudaDataType at, int lda, const void *const Barray[], cudaDataType bt,
				   int ldb, const void *beta, void *const Carray[], cudaDataType ct,
				   int ldc, int batch, cublasComputeType_t compute,
				   cublasGemmAlgo_t algo)
{
	(void)algo;
	return gemm_ex(h, ta, tb, m, n, k, alpha, at, bt, beta, ct, compute,
		       args_pointers(Aarray, lda, Barray, ldb, Carray, ldc, batch));
}

cublasStatus_t cublasGemmStridedBatchedEx(cublasHandle_t h, cublasOperation_t ta, cublasOperation_t tb,
					  int m, int n, int k, const void *alpha, const void *A,
					  cudaDataType at, int lda, long long sA, const void *B,
					  cudaDataType bt, int ldb, long long sB, const void *beta,
					  void *C, cudaDataType ct, int ldc, long long sC, int batch,
					  cublasComputeType_t compute, cublasGemmAlgo_t algo)
{
	(void)algo;
	return gemm_ex(h, ta, tb, m, n, k, alpha, at, bt, beta, ct, compute,
		       args_strided(A, lda, sA, B, ldb, sB, C, ldc, sC, batch));
}

cublasStatus_t cublasStrsmBatched(cublasHandle_t h, cublasSideMode_t side, cublasFillMode_t uplo,
				  cublasOperation_t trans, cublasDiagType_t diag, int m, int n,
				  const float *alpha, const float *const A[], int lda,
				  float *const B[], int ldb, int batch)
{
	float a;
	if (!h)
		return CUBLAS_STATUS_NOT_INITIALIZED;
	if (m < 0 || n < 0 || batch < 0 || uplo == CUBLAS_FILL_MODE_FULL)
		return CUBLAS_STATUS_INVALID_VALUE;
	if (m == 0 || n == 0 || batch == 0)
		return CUBLAS_STATUS_SUCCESS;
	cublasStatus_t s = read_scalar(h, alpha, false, &a);
	if (s != CUBLAS_STATUS_SUCCESS)
		return s;
	const int t = trans != CUBLAS_OP_N;
	const int upper = (uplo == CUBLAS_FILL_MODE_UPPER) != (t != 0);
	const long long vecs = (long long)(side == CUBLAS_SIDE_LEFT ? n : m) * batch;
	const int threads = 128;
	const int blocks = (int)((vecs + threads - 1) / threads < 4096 ? (vecs + threads - 1) / threads : 4096);
	trsm_kernel<<<blocks, threads, 0, h->stream>>>(side == CUBLAS_SIDE_LEFT, upper, t,
							diag == CUBLAS_DIAG_UNIT, m, n, a, A, lda, B,
							ldb, batch);
	return cudaGetLastError() == cudaSuccess ? CUBLAS_STATUS_SUCCESS : CUBLAS_STATUS_EXECUTION_FAILED;
}

} // extern "C"
