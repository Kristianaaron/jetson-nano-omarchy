/* SPDX-License-Identifier: MIT */
/*
 * nanoblas: the cuBLASLt API subset applications compile against. GM20B has no FP8 or tensor
 * cores, the reason applications use cuBLASLt, so handles and descriptors work and matmul reports
 * CUBLAS_STATUS_NOT_SUPPORTED (heuristics return no algorithm). Applications then use their GEMM
 * path. Names, values and struct layouts match cuBLASLt 12.
 */
#ifndef NANOBLAS_CUBLASLT_H
#define NANOBLAS_CUBLASLT_H

#include "cublas_api.h"

#ifdef __cplusplus
extern "C" {
#endif

struct cublasLtContext;
typedef struct cublasLtContext *cublasLtHandle_t;

typedef struct { uint64_t data[8]; } cublasLtMatmulAlgo_t;
typedef struct { uint64_t data[32]; } cublasLtMatmulDescOpaque_t;
typedef cublasLtMatmulDescOpaque_t *cublasLtMatmulDesc_t;
typedef struct { uint64_t data[8]; } cublasLtMatrixLayoutOpaque_t;
typedef cublasLtMatrixLayoutOpaque_t *cublasLtMatrixLayout_t;
typedef struct { uint64_t data[8]; } cublasLtMatmulPreferenceOpaque_t;
typedef cublasLtMatmulPreferenceOpaque_t *cublasLtMatmulPreference_t;

typedef struct {
	cublasLtMatmulAlgo_t algo;
	size_t workspaceSize;
	cublasStatus_t state;
	float wavesCount;
	int reserved[4];
} cublasLtMatmulHeuristicResult_t;

typedef enum {
	CUBLASLT_MATMUL_DESC_TRANSA = 3,
	CUBLASLT_MATMUL_DESC_TRANSB = 4,
	CUBLASLT_MATMUL_DESC_A_SCALE_POINTER = 17,
	CUBLASLT_MATMUL_DESC_B_SCALE_POINTER = 18
} cublasLtMatmulDescAttributes_t;

typedef enum {
	CUBLASLT_MATRIX_LAYOUT_BATCH_COUNT = 5,
	CUBLASLT_MATRIX_LAYOUT_STRIDED_BATCH_OFFSET = 6
} cublasLtMatrixLayoutAttribute_t;

typedef enum { CUBLASLT_MATMUL_PREF_MAX_WORKSPACE_BYTES = 1 } cublasLtMatmulPreferenceAttributes_t;

CUBLASAPI cublasStatus_t CUBLASWINAPI cublasLtCreate(cublasLtHandle_t *lightHandle);
CUBLASAPI cublasStatus_t CUBLASWINAPI cublasLtDestroy(cublasLtHandle_t lightHandle);
CUBLASAPI size_t CUBLASWINAPI cublasLtGetVersion(void);

CUBLASAPI cublasStatus_t CUBLASWINAPI cublasLtMatmulDescCreate(cublasLtMatmulDesc_t *matmulDesc,
							       cublasComputeType_t computeType,
							       cudaDataType_t scaleType);
CUBLASAPI cublasStatus_t CUBLASWINAPI cublasLtMatmulDescDestroy(cublasLtMatmulDesc_t matmulDesc);
CUBLASAPI cublasStatus_t CUBLASWINAPI cublasLtMatmulDescSetAttribute(
	cublasLtMatmulDesc_t matmulDesc, cublasLtMatmulDescAttributes_t attr, const void *buf,
	size_t sizeInBytes);

CUBLASAPI cublasStatus_t CUBLASWINAPI cublasLtMatrixLayoutCreate(cublasLtMatrixLayout_t *matLayout,
								 cudaDataType type, uint64_t rows,
								 uint64_t cols, int64_t ld);
CUBLASAPI cublasStatus_t CUBLASWINAPI cublasLtMatrixLayoutDestroy(cublasLtMatrixLayout_t matLayout);
CUBLASAPI cublasStatus_t CUBLASWINAPI cublasLtMatrixLayoutSetAttribute(
	cublasLtMatrixLayout_t matLayout, cublasLtMatrixLayoutAttribute_t attr, const void *buf,
	size_t sizeInBytes);

CUBLASAPI cublasStatus_t CUBLASWINAPI cublasLtMatmulPreferenceCreate(cublasLtMatmulPreference_t *pref);
CUBLASAPI cublasStatus_t CUBLASWINAPI cublasLtMatmulPreferenceDestroy(cublasLtMatmulPreference_t pref);
CUBLASAPI cublasStatus_t CUBLASWINAPI cublasLtMatmulPreferenceSetAttribute(
	cublasLtMatmulPreference_t pref, cublasLtMatmulPreferenceAttributes_t attr, const void *buf,
	size_t sizeInBytes);

CUBLASAPI cublasStatus_t CUBLASWINAPI cublasLtMatmulAlgoGetHeuristic(
	cublasLtHandle_t lightHandle, cublasLtMatmulDesc_t operationDesc,
	cublasLtMatrixLayout_t Adesc, cublasLtMatrixLayout_t Bdesc, cublasLtMatrixLayout_t Cdesc,
	cublasLtMatrixLayout_t Ddesc, cublasLtMatmulPreference_t preference, int requestedAlgoCount,
	cublasLtMatmulHeuristicResult_t heuristicResultsArray[], int *returnAlgoCount);

CUBLASAPI cublasStatus_t CUBLASWINAPI cublasLtMatmul(
	cublasLtHandle_t lightHandle, cublasLtMatmulDesc_t computeDesc, const void *alpha,
	const void *A, cublasLtMatrixLayout_t Adesc, const void *B, cublasLtMatrixLayout_t Bdesc,
	const void *beta, const void *C, cublasLtMatrixLayout_t Cdesc, void *D,
	cublasLtMatrixLayout_t Ddesc, const cublasLtMatmulAlgo_t *algo, void *workspace,
	size_t workspaceSizeInBytes, cudaStream_t stream);

#ifdef __cplusplus
}
#endif

#endif /* NANOBLAS_CUBLASLT_H */
