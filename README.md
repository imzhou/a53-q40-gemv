# A53-safe Q4_0 GEMV on 32-bit Android

Reproduction artefacts for:

> Zhou, J., & Wang, W. Instruction-set alignment of Q4_0 GEMV for 32-bit Android on Cortex-A53. *Malaysian Journal of Computing* (submitted).

On Allwinner A133 (`armeabi-v7a`, Cortex-A53, ~1 GB RAM) the NDK ARMv7 default turns each Q4_0/Q4_1 block scale into an FP16 libcall. Compiling only `ggml-cpu` with `-mcpu=cortex-a53 -mfpu=neon-fp-armv8` emits `vcvtb.f32.f16`. Locked 1.512 GHz, ten cold starts: Qwen3-0.6B Q4_0 decode **3.26 → 4.78 tok/s (1.47×)**; FMA-off still **1.33×**.

## What is in this repository

| Path | Role in the paper |
|---|---|
| `logs/board_20261026_120900_review_q40.log` | Table 3, Table 6, Figure 4–5 (Q4_0, n = 10) |
| `logs/board_20261026_130154_review_q41.log` | Table 4, Figure 6 (Q4_1, n = 3) |
| `logs/board_20261026_151803_review_q40_nofma.log` | Table 3 FMA-off column |
| `patches/cpu-a53.patch` | ggml-cpu flags + `vcvtnq` polyfill guard |
| `scripts/build_android_cpu.sh` | `v7` / `a53` / `a53nofma` CPU-only `llama-bench` |
| `board/run_review.sh` | Locked-frequency board protocol |
| `scripts/parse_review_log.py` | Mean / s.d. / 95% t-interval from a log |

## What is not redistributed

- The commercial Android 10 Go image and Allwinner firmware
- GGUF weight files (download from Hugging Face; see below)
- llama.cpp itself (clone commit `d772569`)
- PowerVR OpenCL libraries (GPU rows in Table 5 are directional only)

## Reproduce the tables from the logs (no board)

```bash
python3 scripts/parse_review_log.py logs/board_20261026_120900_review_q40.log
python3 scripts/parse_review_log.py logs/board_20261026_130154_review_q41.log
python3 scripts/parse_review_log.py logs/board_20261026_151803_review_q40_nofma.log
```

Headline Q4_0 `tg32` (tok/s): ARMv7-A 3.257 ± 0.041, A53 4.783 ± 0.148 (1.47×), A53 minus FMA 4.333 ± 0.143 (1.33×).

## Rebuild the three CPU binaries

Need NDK r27d (Clang 18), CMake ≥ 3.14, Python 3.

```bash
export ANDROID_NDK=/path/to/android-ndk-r27d
git clone https://github.com/ggml-org/llama.cpp third_party/llama.cpp
git -C third_party/llama.cpp checkout d77256999f211f8c0a5b12d13564f48d685b59e7
git -C third_party/llama.cpp apply ../../patches/cpu-a53.patch

./scripts/build_android_cpu.sh v7
./scripts/build_android_cpu.sh a53
./scripts/build_android_cpu.sh a53nofma
```

`unicode-data.cpp` is compiled at `-O0` because Clang 18 with `-mcpu=cortex-a53 -O3` is pathologically slow on that file. Flags are scoped to the `ggml-cpu` target only.

Q4_0 / Q4_1 GGUF (not in git):

```bash
./scripts/download_model.sh
./scripts/download_q41.sh
```

## Board protocol (root shell)

Lock all cores to `performance` at `cpuinfo_max_freq` (1 512 000 Hz on A133). Each cold start drops page cache, runs `llama-bench -r 1 -ngl 0 -dev none -t 4 -b 128 -ub 64 -p 128,256 -n 32`, then sleeps 8 s.

```bash
adb root
adb push out/llama-bench-v7       /data/local/tmp/qwen/bin/
adb push out/llama-bench-a53      /data/local/tmp/qwen/bin/
adb push out/llama-bench-a53nofma /data/local/tmp/qwen/bin/
adb push board/run_review.sh      /data/local/tmp/qwen/
adb push models/*.gguf            /data/local/tmp/qwen/models/
adb shell "cd /data/local/tmp/qwen && sh ./run_review.sh q40"
adb shell "cd /data/local/tmp/qwen && sh ./run_review.sh q41"
adb shell "cd /data/local/tmp/qwen && sh ./run_review.sh q40-nofma"
```

A second Cortex-A53 32-bit image was not tested. Absolute tok/s will differ on another SoC; the libcall-to-`vcvtb` change should still appear in the Q4_0 hot loop.

## Licence

Scripts and logs: MIT. llama.cpp remains under its upstream licence. Qwen3 weights follow the Qwen licence.
