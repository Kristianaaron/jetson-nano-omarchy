/* SPDX-License-Identifier: MIT */
/* nanoblas: the cuBLAS v2 API names, mapped to the exported _v2 symbols as in cuBLAS. */
#ifndef NANOBLAS_CUBLAS_V2_H
#define NANOBLAS_CUBLAS_V2_H

#include "cublas_api.h"

#define cublasCreate cublasCreate_v2
#define cublasDestroy cublasDestroy_v2
#define cublasGetVersion cublasGetVersion_v2
#define cublasSetWorkspace cublasSetWorkspace_v2
#define cublasSetStream cublasSetStream_v2
#define cublasGetStream cublasGetStream_v2
#define cublasGetPointerMode cublasGetPointerMode_v2
#define cublasSetPointerMode cublasSetPointerMode_v2
#define cublasSgemm cublasSgemm_v2

#endif /* NANOBLAS_CUBLAS_V2_H */
