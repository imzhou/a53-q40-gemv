#!/system/bin/sh
# Review remeasure on device. cwd = /data/local/tmp/qwen
# 10 cold starts, CPU locked to max, no OpenCL binary.
#   sh ./run_review.sh              # Q4_0 v7+a53, 10 runs
#   sh ./run_review.sh q41          # Q4_1 v7+a53, 3 runs
#   sh ./run_review.sh q40-nofma    # Q4_0 a53nofma only, 10 runs (FMA isolation)
#   sh ./run_review.sh all          # both models
set -e
export LD_LIBRARY_PATH="$PWD/libs:${LD_LIBRARY_PATH:-}"
THREADS="${THREADS:-4}"
PP="${PP:-128,256}"
TG="${TG:-32}"
BATCH="${BATCH:-128}"
UBATCH="${UBATCH:-64}"
SLEEP_S="${SLEEP_S:-8}"
N_Q40="${N_Q40:-10}"
N_Q41="${N_Q41:-3}"

MODEL_Q40="./models/Qwen3-0.6B-Q4_0.gguf"
MODEL_Q41="./models/Qwen3-0.6B-Q4_1.gguf"

echo "==== env ===="
uname -a
getprop ro.product.cpu.abi || true
date
id

lock_cpu() {
  echo "==== lock cpufreq performance / max ===="
  i=0
  while [ "$i" -lt 8 ]; do
    gov="/sys/devices/system/cpu/cpu${i}/cpufreq/scaling_governor"
    maxf="/sys/devices/system/cpu/cpu${i}/cpufreq/cpuinfo_max_freq"
    minp="/sys/devices/system/cpu/cpu${i}/cpufreq/scaling_min_freq"
    maxp="/sys/devices/system/cpu/cpu${i}/cpufreq/scaling_max_freq"
    if [ -f "$gov" ]; then
      echo performance > "$gov" 2>/dev/null || echo "WARN: cannot set governor cpu$i"
      if [ -f "$maxf" ]; then
        f=$(cat "$maxf")
        echo "$f" > "$maxp" 2>/dev/null || true
        echo "$f" > "$minp" 2>/dev/null || true
      fi
      echo "cpu$i gov=$(cat $gov 2>/dev/null) cur=$(cat /sys/devices/system/cpu/cpu${i}/cpufreq/scaling_cur_freq 2>/dev/null) min=$(cat $minp 2>/dev/null) max=$(cat $maxp 2>/dev/null)"
    fi
    i=$((i + 1))
  done
}

print_therm() {
  echo "---- freq/temp ----"
  i=0
  while [ "$i" -lt 4 ]; do
    f="/sys/devices/system/cpu/cpu${i}/cpufreq/scaling_cur_freq"
    [ -f "$f" ] && echo "cpu$i $(cat $f)"
    i=$((i + 1))
  done
  for t in /sys/class/thermal/thermal_zone*/temp; do
    [ -f "$t" ] || continue
    typ=$(cat "$(dirname $t)/type" 2>/dev/null || echo zone)
    echo "therm $typ $(cat $t)"
  done | head -12
}

drop_cache() {
  sync
  echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || echo "WARN: drop_caches denied"
}

run_one() {
  bin="$1"
  model="$2"
  tag="$3"
  k="$4"
  n="$5"
  echo
  echo "==== $tag run $k/$n bin=$bin model=$model ===="
  print_therm
  drop_cache
  sleep 1
  "$bin" -m "$model" -t "$THREADS" -ngl 0 -dev none \
    -p "$PP" -n "$TG" -r 1 -b "$BATCH" -ub "$UBATCH" -o md
  print_therm
  sleep "$SLEEP_S"
}

run_model() {
  model="$1"
  nrun="$2"
  label="$3"
  shift 3
  if [ ! -f "$model" ]; then
    echo "SKIP $label: missing $model"
    ls -l ./models 2>/dev/null || true
    return 0
  fi
  if [ "$#" -eq 0 ]; then
    set -- llama-bench-v7 llama-bench-a53
  fi
  for binname in "$@"; do
    bin="./bin/$binname"
    if [ ! -x "$bin" ]; then
      echo "ERROR: missing $bin"
      exit 1
    fi
    k=1
    while [ "$k" -le "$nrun" ]; do
      run_one "$bin" "$model" "${label}-${binname}" "$k" "$nrun"
      k=$((k + 1))
    done
  done
}

lock_cpu
echo "threads=$THREADS batch=$BATCH/$UBATCH pp=$PP tg=$TG sleep=${SLEEP_S}s"

case "${1:-q40}" in
  q40|q4_0) run_model "$MODEL_Q40" "$N_Q40" q40 ;;
  q41|q4_1) run_model "$MODEL_Q41" "$N_Q41" q41 ;;
  q40-nofma|nofma)
    run_model "$MODEL_Q40" "$N_Q40" q40 llama-bench-a53nofma
    ;;
  all)
    run_model "$MODEL_Q40" "$N_Q40" q40
    run_model "$MODEL_Q41" "$N_Q41" q41
    ;;
  *) echo "usage: $0 [q40|q41|q40-nofma|all]"; exit 1 ;;
esac

echo "==== done ===="
date
