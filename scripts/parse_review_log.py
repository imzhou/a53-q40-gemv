#!/usr/bin/env python3
"""Parse board_*_review.log: mean/std/95% t-interval per (model, bin, test)."""
import math
import re
import sys
from collections import defaultdict

def mean(xs):
    return sum(xs) / len(xs)

def std(xs):
    if len(xs) < 2:
        return 0.0
    m = mean(xs)
    return math.sqrt(sum((x - m) ** 2 for x in xs) / (len(xs) - 1))

# df -> t_0.975 (two-sided 95%)
T975 = {1: 12.706, 2: 4.303, 3: 3.182, 4: 2.776, 5: 2.571,
        6: 2.447, 7: 2.365, 8: 2.306, 9: 2.262, 10: 2.228, 19: 2.093}

def ci95(xs):
    n = len(xs)
    if n < 2:
        return 0.0
    t = T975.get(n - 1, 1.96)
    return t * std(xs) / math.sqrt(n)

def main(path):
    text = open(path, encoding="utf-8", errors="replace").read()
    blocks = re.split(r"\n==== ", text)
    acc = defaultdict(list)
    hdr = None
    for b in blocks:
        m = re.match(
            r"(q40|q41)-(llama-bench-v7|llama-bench-a53|llama-bench-a53nofma) run (\d+)/(\d+).*?model=(\S+)",
            b,
        )
        if not m:
            continue
        label, binname, _k, _n, model = m.groups()
        for row in b.splitlines():
            mm = re.search(r"\|\s+(pp\d+|tg\d+)\s+\|\s+([\d.]+)\s*±\s*([\d.]+)", row)
            if not mm:
                # llama-bench -r 1 still prints ± 0.00
                mm = re.search(r"\|\s+(pp\d+|tg\d+)\s+\|\s+([\d.]+)", row)
                if not mm or "test" in row:
                    continue
                test, val = mm.group(1), float(mm.group(2))
            else:
                test, val = mm.group(1), float(mm.group(2))
            acc[(label, binname, test)].append(val)
            hdr = model

    print(f"# {path}")
    print(f"model_hint={hdr}")
    print("| model | bin | test | n | mean | std | 95% CI |")
    print("|---|---|---|---:|---:|---:|---:|")
    for key in sorted(acc):
        xs = acc[key]
        label, binname, test = key
        m, s, c = mean(xs), std(xs), ci95(xs)
        print(f"| {label} | {binname} | {test} | {len(xs)} | {m:.3f} | {s:.3f} | ±{c:.3f} |")
        print(f"  values {label} {binname} {test}: " + ", ".join(f"{x:.3f}" for x in xs))

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("usage: parse_review_log.py logs/board_*_review.log", file=sys.stderr)
        sys.exit(1)
    main(sys.argv[1])
