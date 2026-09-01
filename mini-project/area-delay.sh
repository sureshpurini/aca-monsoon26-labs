#!/usr/bin/env bash
# area-delay.sh --- report area and logic depth for a BSV module.
#
# Bluesim counts cycles but knows nothing about clock period, so a design that
# does more per cycle always looks better there.  A one-cycle 64-multiplier
# array "wins" on cycles while being three times the area and a third slower
# per cycle -- and nothing in a Bluesim run will tell you.  This closes that
# gap with open-source tools only: bsc emits Verilog, yosys reports cell count
# (area) and longest topological path (a clock-period proxy).
#
# Setup -- no sudo, no licence, works on Linux/macOS/WSL:
#
#     pip install --user yowasp-yosys
#
# Usage:
#
#     ./area-delay.sh <top-module> <file.bsv> [bsv-dir]
#
# e.g.  ./area-delay.sh mkMatMul MatMul.bsv tut1-combinational
#
# NOTE ON THE DEPTH NUMBER.  It is a *proxy*, not static timing analysis: it
# counts gate levels on the longest combinational path and ignores gate and
# wire delay.  It is deterministic, reproducible on any machine, and needs no
# vendor tool -- which is what matters for scoring.  It is not a substitute for
# real STA, and should not be quoted as one.
#
# The flow deliberately stops before `abc`: ABC's result depends on the target
# cell library, and it is slow enough under WebAssembly to time out on larger
# designs.  Generic techmap keeps the number comparable across machines.
set -euo pipefail

TOP=${1:?usage: area-delay.sh <top-module> <file.bsv> [dir]}
SRC=${2:?usage: area-delay.sh <top-module> <file.bsv> [dir]}
DIR=${3:-.}

YOSYS=${YOSYS:-yowasp-yosys}
command -v "$YOSYS" >/dev/null || {
    echo "error: '$YOSYS' not found.  Install it with:" >&2
    echo "         pip install --user yowasp-yosys" >&2
    echo "       (or set YOSYS=/path/to/yosys for a native build)" >&2
    exit 1; }
command -v bsc >/dev/null || { echo "error: bsc not on PATH" >&2; exit 1; }

BSC_ROOT=$(dirname "$(dirname "$(command -v bsc)")")
BSCLIB="$BSC_ROOT/lib/Verilog"

# yowasp-yosys runs in a WASI sandbox that can only reach files at or below the
# working directory -- /tmp is invisible to it.  So the scratch directory has
# to live here, and the bsc primitives have to be copied in rather than read
# from the install tree.
WORK="./.area-delay-$TOP"
rm -rf "$WORK"; mkdir -p "$WORK"
trap 'rm -rf "$WORK"' EXIT

# bsc auto-adds -bdir to the head of its search path, so passing -p as well is
# rejected; run from the source directory instead.
SRC_BASE=$(basename "$SRC")
WORK_ABS=$(cd "$WORK" && pwd)
( cd "$DIR" && bsc -verilog -u \
      -bdir "$WORK_ABS" -vdir "$WORK_ABS" -info-dir "$WORK_ABS" \
      -g "$TOP" "$SRC_BASE" ) >/dev/null

[ -f "$WORK/$TOP.v" ] || { echo "error: bsc produced no $TOP.v" >&2; exit 1; }

# Pull in only the bsc primitives this design actually instantiates.
mapfile -t names < <(grep -oE '^  [A-Za-z][A-Za-z0-9_]* ' "$WORK/$TOP.v" \
                     | tr -d ' ' | sort -u)
prims=()
for p in "${names[@]}"; do
    if [ -f "$BSCLIB/$p.v" ]; then
        cp "$BSCLIB/$p.v" "$WORK/"
        prims+=("$p.v")
    fi
done

{
  for f in "${prims[@]}"; do
      echo "read_verilog -DBSV_ASSIGNMENT_DELAY= -DBSV_POSITIVE_RESET $f"
  done
  echo "read_verilog $TOP.v"
  echo "hierarchy -top $TOP"
  echo "flatten"
  echo "proc; opt -fast; memory; opt -fast; techmap; opt -fast"
  echo "stat"
  echo "ltp -noff"
} > "$WORK/run.ys"

( cd "$WORK" && "$YOSYS" -s run.ys > out.log 2>&1 ) || {
    echo "error: yosys failed; last lines:" >&2
    tail -20 "$WORK/out.log" >&2
    exit 1; }

python3 - "$WORK/out.log" "$TOP" <<'PY'
import re, sys
log, top = sys.argv[1], sys.argv[2]
t = open(log, errors="ignore").read()
m = re.search(r'=== ' + re.escape(top) + r' ===(.*?)(?:\n\s*\n\s*\d+\.|\Z)', t, re.S)
blk = m.group(1) if m else ""

def num(pat, where=blk):
    g = re.search(pat, where)
    return int(g.group(1)) if g else 0

cells = num(r'(\d+)\s+cells')
depth = num(r'length=(\d+)', t)
print(f"{top:16s}  cells={cells:>8d}   logic_depth={depth:>4d}"
      f"   area_x_delay={cells*depth:>12d}")
PY
