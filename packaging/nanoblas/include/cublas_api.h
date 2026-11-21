/* SPDX-License-Identifier: MIT */
/*
 * nanoblas: the cuBLAS API subset that CUDA applications use (handles, GEMM in FP32/FP16/BF16,
 * batched GEMM, batched TRSM), implemented with kernels built for the Jetson Nano's GM20B GPU
 * (compute capability 5.3). NVIDIA's cuBLAS ships no sm_53 code, and the Tegra driver runs only
 * exact-architecture code, so cuBLAS cannot run there.
 *
 * Written for source and binary compatibility with cuBLAS 12: the same type names, enumerator
 * values and exported symbol names (cublas_v2.h maps the v2 names the same way). Functions
 * outside the subset are not declared.
 */
#ifndef NANOBLAS_CUBLAS_API_H
#define NANOBLAS_CUBLAS_API_H

#include <stddef.h>
#include <stdint.h>
#include <cuda_runtime_api.h>
#include <library_types.h>
#include <cuda_fp16.h>

#define CUBLAS_VER_MAJOR 12
#define CUBLAS_VER_MINOR 9
#define CUBLAS_VER_PATCH 0
#define CUBLAS_VER_BUILD 0
#define CUBLAS_VERSION (CUBLAS_VER_MAJOR * 10000 + CUBLAS_VER_MINOR * 100 + CUBLAS_VER_PATCH)

/* __half in C++; in C, cuda_fp16.h defines only the layout-identical __half_raw */
#ifdef __cplusplus
#define NANOBLAS_HALF __half
#else
#define NANOBLAS_HALF __half_raw
#endif

#ifndef CUBLASWINAPI
#define CUBLASWINAPI
#endif
#ifndef CUBLASAPI
#define CUBLASAPI __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
	CUBLAS_STATUS_SUCCESS = 0,
	CUBLAS_STATUS_NOT_INITIALIZED = 1,
	CUBLAS_STATUS_ALLOC_FAILED = 3,
	CUBLAS_STATUS_INVALID_VALUE = 7,
	CUBLAS_STATUS_ARCH_MISMATCH = 8,
	CUBLAS_STATUS_MAPPING_ERROR = 11,
	CUBLAS_STATUS_EXECUTION_FAILED = 13,
	CUBLAS_STATUS_INTERNAL_ERROR = 14,
	CUBLAS_STATUS_NOT_SUPPORTED = 15,
	CUBLAS_STATUS_LICENSE_ERROR = 16
} cublasStatus_t;

typedef enum {
	CUBLAS_FILL_MODE_LOWER = 0,
	CUBLAS_FILL_MODE_UPPER = 1,
	CUBLAS_FILL_MODE_FULL = 2
} cublasFillMode_t;

typedef enum { CUBLAS_DIAG_NON_UNIT = 0, CUBLAS_DIAG_UNIT = 1 } cublasDiagType_t;

typedef enum { CUBLAS_SIDE_LEFT = 0, CUBLAS_SIDE_RIGHT = 1 } cublasSideMode_t;

typedef enum {
	CUBLAS_OP_N = 0,
	CUBLAS_OP_T = 1,
	CUBLAS_OP_C = 2,
	CUBLAS_OP_HERMITAN = 2,
	CUBLAS_OP_CONJG = 3
} cublasOperation_t;

typedef enum { CUBLAS_POINTER_MODE_HOST = 0, CUBLAS_POINTER_MODE_DEVICE = 1 } cublasPointerMode_t;

typedef enum {
	CUBLAS_DEFAULT_MATH = 0,
	CUBLAS_TENSOR_OP_MATH = 1,
	CUBLAS_PEDANTIC_MATH = 2,
	CUBLAS_TF32_TENSOR_OP_MATH = 3,
	CUBLAS_MATH_DISALLOW_REDUCED_PRECISION_REDUCTION = 16
} cublasMath_t;

/* Algorithm hints are accepted and ignored: one kernel family serves every request. */
typedef enum {
	CUBLAS_GEMM_DEFAULT = -1,
	CUBLAS_GEMM_DFALT = -1,
	CUBLAS_GEMM_DEFAULT_TENSOR_OP = 99,
	CUBLAS_GEMM_DFALT_TENSOR_OP = 99
} cublasGemmAlgo_t;

typedef enum {
	CUBLAS_COMPUTE_16F = 64,
	CUBLAS_COMPUTE_16F_PEDANTIC = 65,
	CUBLAS_COMPUTE_32F = 68,
	CUBLAS_COMPUTE_32F_PEDANTIC = 69,
	CUBLAS_COMPUTE_32F_FAST_16F = 74,
	CUBLAS_COMPUTE_32F_FAST_16BF = 75,
	CUBLAS_COMPUTE_32F_FAST_TF32 = 77,
	CUBLAS_COMPUTE_64F = 70,
	CUBLAS_COMPUTE_64F_PEDANTIC = 71,
	CUBLAS_COMPUTE_32I = 72,
	CUBLAS_COMPUTE_32I_PEDANTIC = 73
} cublasComputeType_t;

struct cublasContext;
typedef struct cublasContext *cublasHandle_t;
typedef void (*cublasLogCallback)(const char *msg);

/* Handle and stream */
CUBLASAPI cublasStatus_t CUBLASWINAPI cublasCreate_v2(cublasHandle_t *handle);
CUBLASAPI cublasStatus_t CUBLASWINAPI cublasDestroy_v2(cublasHandle_t handle);
CUBLASAPI cublasStatus_t CUBLASWINAPI cublasGetVersion_v2(cublasHandle_t handle, int *version);
CUBLASAPI cublasStatus_t CUBLASWINAPI cublasGetProperty(libraryPropertyType type, int *value);
CUBLASAPI size_t CUBLASWINAPI cublasGetCudartVersion(void);
CUBLASAPI cublasStatus_t CUBLASWINAPI cublasSetWorkspace_v2(cublasHandle_t handle, void *workspace,
							    size_t workspaceSizeInBytes);
CUBLASAPI cublasStatus_t CUBLASWINAPI cublasSetStream_v2(cublasHandle_t handle, cudaStream_t streamId);
CUBLASAPI cublasStatus_t CUBLASWINAPI cublasGetStream_v2(cublasHandle_t handle, cudaStream_t *streamId);
CUBLASAPI cublasStatus_t CUBLASWINAPI cublasGetPointerMode_v2(cublasHandle_t handle,
							      cublasPointerMode_t *mode);
CUBLASAPI cublasStatus_t CUBLASWINAPI cublasSetPointerMode_v2(cublasHandle_t handle,
							      cublasPointerMode_t mode);
CUBLASAPI cublasStatus_t CUBLASWINAPI cublasGetMathMode(cublasHandle_t handle, cublasMath_t *mode);
CUBLASAPI cublasStatus_t CUBLASWINAPI cublasSetMathMode(cublasHandle_t handle, cublasMath_t mode);
CUBLASAPI const char *CUBLASWINAPI cublasGetStatusName(cublasStatus_t status);
CUBLASAPI const char *CUBLASWINAPI cublasGetStatusString(cublasStatus_t status);
CUBLASAPI cublasStatus_t CUBLASWINAPI cublasLoggerConfigure(int logIsOn, int logToStdOut,
							    int logToStdErr, const char *logFileName);
CUBLASAPI cublasStatus_t CUBLASWINAPI cublasSetLoggerCallback(cublasLogCallback userCallback);
CUBLASAPI cublasStatus_t CUBLASWINAPI cublasGetLoggerCallback(cublasLogCallback *userCallback);

/* GEMM: C = alpha * op(A) * op(B) + beta * C, column-major, as in cuBLAS */
CUBLASAPI cublasStatus_t CUBLASWINAPI cublasSgemm_v2(cublasHandle_t handle, cublasOperation_t transa,
						     cublasOperation_t transb, int m, int n, int k,
						     const float *alpha, const float *A, int lda,
						     const float *B, int ldb, const float *beta,
						     float *C, int ldc);
CUBLASAPI cublasStatus_t CUBLASWINAPI cublasHgemm(cublasHandle_t handle, cublasOperation_t transa,
						  cublasOperation_t transb, int m, int n, int k,
						  const NANOBLAS_HALF *alpha, const NANOBLAS_HALF *A,
						  int lda, const NANOBLAS_HALF *B, int ldb,
						  const NANOBLAS_HALF *beta, NANOBLAS_HALF *C, int ldc);
CUBLASAPI cublasStatus_t CUBLASWINAPI cublasSgemmBatched(cublasHandle_t handle, cublasOperation_t transa,
							 cublasOperation_t transb, int m, int n, int k,
							 const float *alpha,
							 const float *const Aarray[], int lda,
							 const float *const Barray[], int ldb,
							 const float *beta, float *const Carray[],
							 int ldc, int batchCount);
CUBLASAPI cublasStatus_t CUBLASWINAPI cublasSgemmStridedBatched(
	cublasHandle_t handle, cublasOperation_t transa, cublasOperation_t transb, int m, int n, int k,
	const float *alpha, const float *A, int lda, long long int strideA, const float *B, int ldb,
	long long int strideB, const float *beta, float *C, int ldc, long long int strideC,
	int batchCount);
CUBLASAPI cublasStatus_t CUBLASWINAPI cublasGemmEx(cublasHandle_t handle, cublasOperation_t transa,
						   cublasOperation_t transb, int m, int n, int k,
						   const void *alpha, const void *A, cudaDataType Atype,
						   int lda, const void *B, cudaDataType Btype, int ldb,
						   const void *beta, void *C, cudaDataType Ctype, int ldc,
						   cublasComputeType_t computeType,
						   cublasGemmAlgo_t algo);
CUBLASAPI cublasStatus_t CUBLASWINAPI cublasGemmBatchedEx(
	cublasHandle_t handle, cublasOperation_t transa, cublasOperation_t transb, int m, int n, int k,
	const void *alpha, const void *const Aarray[], cudaDataType Atype, int lda,
	const void *const Barray[], cudaDataType Btype, int ldb, const void *beta,
	void *const Carray[], cudaDataType Ctype, int ldc, int batchCount,
	cublasComputeType_t computeType, cublasGemmAlgo_t algo);
CUBLASAPI cublasStatus_t CUBLASWINAPI cublasGemmStridedBatchedEx(
	cublasHandle_t handle, cublasOperation_t transa, cublasOperation_t transb, int m, int n, int k,
	const void *alpha, const void *A, cudaDataType Atype, int lda, long long int strideA,
	const void *B, cudaDataType Btype, int ldb, long long int strideB, const void *beta, void *C,
	cudaDataType Ctype, int ldc, long long int strideC, int batchCount,
	cublasComputeType_t computeType, cublasGemmAlgo_t algo);

/* Triangular solve, batched: op(A) X = alpha B (left) or X op(A) = alpha B (right), X over B */
CUBLASAPI cublasStatus_t CUBLASWINAPI cublasStrsmBatched(cublasHandle_t handle, cublasSideMode_t side,
							 cublasFillMode_t uplo, cublasOperation_t trans,
							 cublasDiagType_t diag, int m, int n,
							 const float *alpha, const float *const A[],
							 int lda, float *const B[], int ldb,
							 int batchCount);

#ifdef __cplusplus
}
#endif

#endif /* NANOBLAS_CUBLAS_API_H */
