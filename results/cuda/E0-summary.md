# CUDA desk experiments E0a–E0d (2026-11-18, run on the Nano; raw outputs beside this file)

Packages: L4T R32.7.6 (CUDA 10.2, control), R35.6.5 and R36.4.7 (t234), CUDA 12.6.85 redist
(linux-sbsa), CUDA 10.2 compilers (jetson/common r32.7). Every archive sha256-verified.

| Exp | Question | Result | Meaning |
|---|---|---|---|
| E0a | R32 userspace ioctls vs R36 nvgpu/nvmap headers | 212 identical (number, direction, struct size), 1 changed (IVM heaps, irrelevant), 25 missing in R36 | The port can target the R36 nvgpu tree, if libcuda does not depend on the missing older calls (CHANNEL_ALLOC_GPFIFO, NVMAP_IOC_MMAP / ALLOC_KIND / PIN_MULT ...). Next: find which ioctls R32 libnvrm_gpu actually issues. |
| E0b | What R32 userspace needs from the OS | glibc ≤ 2.17; /dev/nvhost-ctrl, /dev/nvhost-ctrl-gpu, /dev/nvmap, /dev/ion; /sys/devices/soc0/{soc_id,revision}; /sys/module/tegra_fuse/parameters/{tegra_chip_id,tegra_chip_rev,tegra_cpu,tegra_platform} | Runs on Arch glibc. The fuse parameters need a small shim on mainline. |
| E0c | Does Orin-era userspace still know GM20B? | R36.4 and R35.6 libnvrm_gpu.so carry the same "NVIDIA Tegra X1 / GM20B / NVIDIA Tegra X1 (rev B)" chip entry as the R32 control. R36.4 libcuda lists sm_53 / compute_53 / -D__CUDA_ARCH__=530 in its JIT target list (R32 libcuda: none). Maxwell compute class bytes 0xB1C0: R36 libcuda 10, R32 1 (weak signal). | ADVANCE: R36 nvgpu + R36 userspace (CUDA 12.x) on GM20B is a credible, untested route to CUDA 12 on this board. |
| E0d | Can CUDA 12 code target this GPU through 10.2? | NVRTC 12.6 builds sm_53 PTX (ISA 8.5) and a sm_53 cubin. CUDA 10.2 cuobjdump parses the CUDA 12 cubin. CUDA 10.2 ptxas assembles CUDA 12 PTX after lowering .version to 6.5. Both cubins: OS/ABI CUDA, ABI version 7, flags 0x350535. | ADVANCE (file level): CUDA 12-built kernels are format-compatible with the 10.2 driver. Running them needs a working GPU driver (E4/E5). nvcc 12.6 itself cannot use GCC 16's libstdc++ (char8_t, __is_array); NVRTC avoids the host compiler. |

Not yet shown: anything running on the GPU. That starts with E2 (build R36 nvgpu against 7.2).
