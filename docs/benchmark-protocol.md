# Benchmark protocol

Every number carries its full context. A token rate without kernel, DTB, driver, quant hash and
thermal state is not a measurement.

## Receipt fields

| Group | Required |
|---|---|
| Identification | board model, module/carrier revision, DTB filename, kernel `uname -r`, GPU driver and version, Omarchy commit, runtime commit, quant file SHA-256 |
| Hardware state | power mode (`nvpmodel`), supply voltage/current, cooling, CPU/GPU clocks during the run, throttle events, peripherals attached |
| Model | parameters, quant format and bits/weight, file bytes on disk, resident weight bytes, context length, tokenizer revision |
| Inference | TTFT, prefill tok/s, single-stream decode tok/s, aggregate tok/s separately, p50/p95 latency |
| Speculation | draft length, observed per-position acceptance, accepted tokens per round, verification ms, drafting ms |
| Correctness | reference logits check, held-out task accuracy, tool-call/JSON validity, failure modes |
| Memory | idle OS, compositor, model, KV cache, peak RSS, shared GPU memory, swap in/out |
| Energy | watts during decode, joules per generated token, thermal trace |
| Robustness | 30-minute soak, cold-start repeatability, 20 reboot cycles, recovery card boots |

## Rules

- Decode speed is single-stream, batch 1. Multi-user throughput is a different number and is labelled
  as such.
- Report the renderer for any desktop measurement (`llvmpipe` vs a hardware driver).
- Report whether kernels actually launched: a CUDA trace or counter evidence, never an inference.
- Tolerances are per-operator and recorded; quantized tolerance is not the same as BF16 tolerance.
- Every result file names the commit or tag of the code that produced it.

## Files

- `results/system/` - inventory, boot logs, card inventory.
- `results/graphics/` - renderer dumps, compositor logs, memory during a session.
- `results/inference/` - `cpu-baseline.json`, `gpu-smoke.json`, model run receipts.
