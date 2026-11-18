# Inference smoke tests

Purpose: prove that CUDA actually executes on the Nano's GM20B (SM 5.3) and that its numbers match a
CPU reference. This runs on the **known-good vendor BSP** (L4T R32 / CUDA 10.2), never on the
experimental Arch card. Nothing here is a model-serving claim.

## T0 - toolchain identity

```sh
nvcc --version            # must be 10.2.x
nvidia-smi | head -5
cat /etc/nv_tegra_release
```

Record the exact versions; a CUDA 13 toolchain cannot target SM 5.3.

## T1 - build and run the kernel

```sh
nvcc -arch=sm_53 -O2 -o /tmp/sm53_smoke minimal_sm53.cu
/tmp/sm53_smoke
```

Expected: `PASS` lines for vector add, a 1-D convolution and an FP16 dot product, each compared
against the CPU reference with an explicit tolerance, followed by a summary that names the device,
compute capability, driver version and kernel-launch count.

Failure modes worth distinguishing:

- `no kernel image is available for execution` → the fatbin lacks SM 5.3; the build is wrong.
- `driver version is insufficient` → userspace driver mismatch, not a kernel problem.
- numbers off by more than tolerance → real bug; do not loosen tolerance to pass.

## T2 - prove launches happened

- Run under `nvprof` (`nvprof --print-gpu-trace`) if available on this BSP.
- Pass: the trace lists the three kernels with non-zero durations.
- A CPU fallback that prints "PASS" without a trace is a failed test, not a pass.

## T3 - CPU baseline

- Build the same arithmetic with the CPU reference only and time it.
- Record in `results/inference/cpu-baseline.json`: sizes, iterations, ms, and the ratio to GPU.

## T4 - model-level correctness (later, Phase 5)

- Only after T1-T3: MiniCPM5-1B tokenizer, embeddings, RMSNorm, RoPE, QKV, GQA attention, FFN,
  sampling and KV cache against reference logits from the RTX 5070 Ti.
- Tolerances are recorded per operation; quantized tolerance is separate from BF16 tolerance.
