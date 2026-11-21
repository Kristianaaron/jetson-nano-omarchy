// SPDX-License-Identifier: MIT
// nvcc_axpy: the CUDA toolchain end to end on the Jetson Nano: nvcc (cuda-nano, host compiler
// g++-13 via NVCC_CCBIN) builds an sm_53 kernel and C++ host code, the kernel runs on GM20B.
// Build: nvcc -O2 -arch=sm_53 -o nvcc_axpy nvcc_axpy.cu
#include <cstdio>
#include <string>
#include <vector>

__global__ void axpy(int n, float a, const float *x, float *y)
{
	int i = blockIdx.x * blockDim.x + threadIdx.x;
	if (i < n)
		y[i] = a * x[i] + y[i];
}

int main()
{
	const int n = 1 << 20;
	std::vector<float> x(n, 1.5f), y(n, 2.0f);
	float *dx, *dy;
	cudaMalloc(&dx, n * sizeof(float));
	cudaMalloc(&dy, n * sizeof(float));
	cudaMemcpy(dx, x.data(), n * sizeof(float), cudaMemcpyHostToDevice);
	cudaMemcpy(dy, y.data(), n * sizeof(float), cudaMemcpyHostToDevice);
	axpy<<<(n + 255) / 256, 256>>>(n, 3.0f, dx, dy);
	cudaError_t e = cudaDeviceSynchronize();
	cudaMemcpy(y.data(), dy, n * sizeof(float), cudaMemcpyDeviceToHost);
	int bad = 0;
	for (float v : y)
		bad += v != 6.5f;
	std::string what = "sm_53 axpy";
	printf("%s: %s, %d wrong of %d\n", what.c_str(), cudaGetErrorString(e), bad, n);
	printf("%s\n", bad || e != cudaSuccess ? "NVCC FAIL" : "NVCC PASS");
	return bad != 0 || e != cudaSuccess;
}
