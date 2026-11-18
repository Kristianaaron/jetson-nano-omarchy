# Inference backend: MiniCPM5-1B on GM20B (SM 5.3)

Status: not started; blocked on hardware and on a legacy CUDA path. This document fixes the
constraints so no one mistakes a CPU fallback for GPU inference.

## Hard facts

- GM20B: 128 CUDA cores, compute capability **5.3**, no Tensor Cores. FP16 arithmetic per SM exists
  but throughput per watt is low; bandwidth is the binding constraint at ~25.6 GB/s.
- TensorFold release archives require glibc 2.28+ and **NVIDIA driver R580+ / CUDA 13.0**, and ship
  fatbins for `sm_80`, `sm_86`, `sm_120`, `sm_121` only. `-Dgpu` accepts those plus `spark`.
  Verified in https://github.com/ashhart/TensorFold/blob/main/RUNBOOK.md on 2026-11-16.
  Therefore no release artifact can run on SM 5.3.
- The only CUDA proven on this board is CUDA 10.2 on L4T R32 (kernel 4.9). Running the vendor
  driver on a mainline kernel is untested, not impossible: NVIDIA's current R36 nvgpu tree still
  carries GM20B support and builds out-of-tree (see docs/cuda-feasibility.md, experiments E0-E7).
- Desk checks E0a-E0d (2026-11-18, results/cuda/E0-summary.md): R32 userspace matches R36 nvgpu
  headers on 212 of 238 ioctls; R36.4 userspace (CUDA 12.x) still carries the GM20B chip entry;
  CUDA 12.6 NVRTC builds sm_53 code that the CUDA 10.2 tools accept. Nothing has run on the GPU
  yet.

## Consequences

1. A **legacy backend** must be built against CUDA 10.2, gated at compile time and runtime on
   `compute_53`/`sm_53`, and must refuse to run anywhere else.
2. Model work is per (model version, quant format, backend) qualification. MiniCPM5-1B is a
   `LlamaForCausalLM` with GQA; positional encoding, chat template and special tokens must be
   verified against the published config, not inferred from the family name.
3. Weight streaming dominates. 540 MB of 4-bit weights per token at 25.6 GB/s is ~21 ms, an
   optimistic single-stream ceiling near 47 tok/s before any overhead. Fusion alone cannot pass 100
   tok/s; speculation would have to amortise weight traffic and still pay verification.

## First qualification steps (on the vendor BSP, after `tests/inference-smoke`)

1. T1-T3 pass: real SM 5.3 kernels with correct numbers and a GPU trace.
2. Minimal model path: embeddings, RMSNorm, RoPE, QKV, GQA attention, FFN, final logits, sampling,
   KV cache, each with a CPU reference and explicit tolerance.
3. Reference logits from the RTX 5070 Ti for a fixed prompt set, stored with hashes.
4. Only then quant format bring-up. Start with a format the backend already dequantises correctly;
   treat EXL3 as a separate project.

## What must not happen

- Sending CUDA 13 PTX to SM 5.3 and treating a JIT failure as a tolerance problem.
- Reporting throughput from a CPU path, or from a batch greater than one, as single-stream GPU tok/s.
- Overwriting Arch Mesa libraries with vendor blobs to make something load.
