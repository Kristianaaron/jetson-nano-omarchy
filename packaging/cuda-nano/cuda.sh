# CUDA toolkit (cuda-nano)
export CUDA_PATH=/opt/cuda
append_path '/opt/cuda/bin'
export PATH
# nvcc 12.6's C++ front end supports host headers up to GCC 13
export NVCC_CCBIN='/usr/bin/g++-13'
