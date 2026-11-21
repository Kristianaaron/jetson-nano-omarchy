// SPDX-License-Identifier: MIT
// nanoblas: cuBLASLt API subset (see include/cublasLt.h). Handles and descriptors are real
// allocations; matmul is not supported on GM20B, so the heuristic offers no algorithm.
#include <stdlib.h>
#include <string.h>
#include "cublasLt.h"

struct cublasLtContext {
	int unused;
};

cublasStatus_t cublasLtCreate(cublasLtHandle_t *h)
{
	if (!h)
		return CUBLAS_STATUS_INVALID_VALUE;
	*h = calloc(1, sizeof(**h));
	return *h ? CUBLAS_STATUS_SUCCESS : CUBLAS_STATUS_ALLOC_FAILED;
}

cublasStatus_t cublasLtDestroy(cublasLtHandle_t h)
{
	if (!h)
		return CUBLAS_STATUS_NOT_INITIALIZED;
	free(h);
	return CUBLAS_STATUS_SUCCESS;
}

size_t cublasLtGetVersion(void) { return CUBLAS_VERSION; }

#define DESC_CREATE(type, out)                                                                 \
	do {                                                                                   \
		if (!(out))                                                                    \
			return CUBLAS_STATUS_INVALID_VALUE;                                    \
		*(out) = calloc(1, sizeof(type));                                              \
		return *(out) ? CUBLAS_STATUS_SUCCESS : CUBLAS_STATUS_ALLOC_FAILED;            \
	} while (0)

cublasStatus_t cublasLtMatmulDescCreate(cublasLtMatmulDesc_t *d, cublasComputeType_t c,
					cudaDataType_t s)
{
	(void)c;
	(void)s;
	DESC_CREATE(cublasLtMatmulDescOpaque_t, d);
}

cublasStatus_t cublasLtMatmulDescDestroy(cublasLtMatmulDesc_t d)
{
	free(d);
	return CUBLAS_STATUS_SUCCESS;
}

cublasStatus_t cublasLtMatmulDescSetAttribute(cublasLtMatmulDesc_t d, cublasLtMatmulDescAttributes_t a,
					      const void *buf, size_t size)
{
	(void)a;
	(void)size;
	return d && buf ? CUBLAS_STATUS_SUCCESS : CUBLAS_STATUS_INVALID_VALUE;
}

cublasStatus_t cublasLtMatrixLayoutCreate(cublasLtMatrixLayout_t *l, cudaDataType t, uint64_t rows,
					  uint64_t cols, int64_t ld)
{
	(void)t;
	(void)rows;
	(void)cols;
	(void)ld;
	DESC_CREATE(cublasLtMatrixLayoutOpaque_t, l);
}

cublasStatus_t cublasLtMatrixLayoutDestroy(cublasLtMatrixLayout_t l)
{
	free(l);
	return CUBLAS_STATUS_SUCCESS;
}

cublasStatus_t cublasLtMatrixLayoutSetAttribute(cublasLtMatrixLayout_t l,
						cublasLtMatrixLayoutAttribute_t a, const void *buf,
						size_t size)
{
	(void)a;
	(void)size;
	return l && buf ? CUBLAS_STATUS_SUCCESS : CUBLAS_STATUS_INVALID_VALUE;
}

cublasStatus_t cublasLtMatmulPreferenceCreate(cublasLtMatmulPreference_t *p)
{
	DESC_CREATE(cublasLtMatmulPreferenceOpaque_t, p);
}

cublasStatus_t cublasLtMatmulPreferenceDestroy(cublasLtMatmulPreference_t p)
{
	free(p);
	return CUBLAS_STATUS_SUCCESS;
}

cublasStatus_t cublasLtMatmulPreferenceSetAttribute(cublasLtMatmulPreference_t p,
						    cublasLtMatmulPreferenceAttributes_t a,
						    const void *buf, size_t size)
{
	(void)a;
	(void)size;
	return p && buf ? CUBLAS_STATUS_SUCCESS : CUBLAS_STATUS_INVALID_VALUE;
}

cublasStatus_t cublasLtMatmulAlgoGetHeuristic(cublasLtHandle_t h, cublasLtMatmulDesc_t op,
					      cublasLtMatrixLayout_t A, cublasLtMatrixLayout_t B,
					      cublasLtMatrixLayout_t C, cublasLtMatrixLayout_t D,
					      cublasLtMatmulPreference_t pref, int requested,
					      cublasLtMatmulHeuristicResult_t results[], int *count)
{
	(void)h;
	(void)op;
	(void)A;
	(void)B;
	(void)C;
	(void)D;
	(void)pref;
	if (results && requested > 0)
		memset(results, 0, sizeof(*results) * (size_t)requested);
	if (count)
		*count = 0;
	return CUBLAS_STATUS_NOT_SUPPORTED;
}

cublasStatus_t cublasLtMatmul(cublasLtHandle_t h, cublasLtMatmulDesc_t d, const void *alpha,
			      const void *A, cublasLtMatrixLayout_t Ad, const void *B,
			      cublasLtMatrixLayout_t Bd, const void *beta, const void *C,
			      cublasLtMatrixLayout_t Cd, void *D, cublasLtMatrixLayout_t Dd,
			      const cublasLtMatmulAlgo_t *algo, void *ws, size_t wss, cudaStream_t s)
{
	(void)h; (void)d; (void)alpha; (void)A; (void)Ad; (void)B; (void)Bd; (void)beta;
	(void)C; (void)Cd; (void)D; (void)Dd; (void)algo; (void)ws; (void)wss; (void)s;
	return CUBLAS_STATUS_NOT_SUPPORTED;
}
