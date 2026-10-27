#!/usr/bin/env bash
# Qwen3-0.6B Q4_1 (~same size as Q4_0). Second quant for FP16-scale ablation.
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/env.sh"
mkdir -p "$QROOT/models" "$QROOT/board_payload/models"
out="$QROOT/models/Qwen3-0.6B-Q4_1.gguf"
if [[ -f "$out" ]] && [[ "$(stat -c%s "$out")" -gt 300000000 ]]; then
  echo "OK: $out ($(stat -c%s "$out") bytes)"
  cp -f "$out" "$QROOT/board_payload/models/"
  exit 0
fi
urls=(
  "https://hf-mirror.com/unsloth/Qwen3-0.6B-GGUF/resolve/main/Qwen3-0.6B-Q4_1.gguf"
  "https://huggingface.co/unsloth/Qwen3-0.6B-GGUF/resolve/main/Qwen3-0.6B-Q4_1.gguf"
)
ok=0
for url in "${urls[@]}"; do
  echo "GET $url"
  if curl -L --fail --retry 3 --retry-delay 2 -C - -o "$out.part" "$url"; then
    ok=1
    break
  fi
done
[[ "$ok" -eq 1 ]]
mv -f "$out.part" "$out"
cp -f "$out" "$QROOT/board_payload/models/"
ls -lh "$out"
echo "OK: $out"
