#!/usr/bin/env bash
# Download Qwen3-0.6B Q4_0 GGUF (~365 MiB).
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/env.sh"
mkdir -p "$QROOT/models"
out="$MODEL_Q4"
if [[ -f "$out" ]] && [[ "$(stat -c%s "$out")" -gt 300000000 ]]; then
  echo "OK: $out ($(stat -c%s "$out") bytes)"
  exit 0
fi

urls=(
  "https://hf-mirror.com/unsloth/Qwen3-0.6B-GGUF/resolve/main/Qwen3-0.6B-Q4_0.gguf"
  "https://huggingface.co/unsloth/Qwen3-0.6B-GGUF/resolve/main/Qwen3-0.6B-Q4_0.gguf"
  "https://hf-mirror.com/bartowski/Qwen_Qwen3-0.6B-GGUF/resolve/main/Qwen3-0.6B-Q4_0.gguf"
)

fetch() {
  local url="$1"
  echo "GET $url"
  curl -L --fail --retry 3 --retry-delay 2 -C - -o "$out.part" "$url"
}

ok=0
for url in "${urls[@]}"; do
  if fetch "$url"; then
    ok=1
    break
  fi
  echo "failed, try next"
done
[[ "$ok" -eq 1 ]]
mv -f "$out.part" "$out"
ls -lh "$out"
echo "OK: $out"
