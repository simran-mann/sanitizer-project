#!/usr/bin/env bash
set -euo pipefail

VER="${1:-}"
O_LEVEL="${2:-O2}"

find_tool() {
    local name="$1"
    if [[ -n "$VER" ]] && command -v "${name}-${VER}" &>/dev/null; then echo "${name}-${VER}"
    elif command -v "$name" &>/dev/null; then echo "$name"
    else echo "ERROR: '$name' not found." >&2; exit 1; fi
}

CLANG=$(find_tool clang)
OPT=$(find_tool opt)
echo "clang : $CLANG  ($(${CLANG} --version | head -1))"
echo "opt   : $OPT    ($(${OPT}   --version | head -1))"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD="${ROOT}/build"
RESULTS="${ROOT}/results"
RUNTIME_SRC="${ROOT}/runtime/check_access.c"
[[ "$(uname)" == "Darwin" ]] && PLUGIN="${BUILD}/SanitizerPlugin.dylib" || PLUGIN="${BUILD}/SanitizerPlugin.so"
mkdir -p "${BUILD}" "${RESULTS}"

echo ""
echo "=== Building LLVM plugin ==="
cmake -S "${ROOT}" -B "${BUILD}" -DCMAKE_BUILD_TYPE=Release -Wno-dev 2>/dev/null
cmake --build "${BUILD}" --target SanitizerPlugin \
      -j"$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)"
[[ -f "${PLUGIN}" ]] || { echo "ERROR: Plugin not found at ${PLUGIN}" >&2; exit 1; }
echo "Plugin ready: ${PLUGIN}"

min_time() {
    local exe="$1" best=""
    for _ in 1 2 3; do
        local t
        t=$( { TIMEFORMAT='%R'; time "$exe" > /dev/null 2>/dev/null; } 2>&1 )
        if [[ -z "$best" ]] || awk "BEGIN{exit !(${t}+0 < ${best}+0)}"; then best="$t"; fi
    done
    printf "%.3f" "${best:-0.000}"
}

count_checks() { grep -c '@check_access' "$1" 2>/dev/null || echo 0; }

BENCHMARKS=(matrix_mult array_sum quicksort binary_search convolution knapsack)

TABLE_FILE="${RESULTS}/table_${O_LEVEL}.txt"
HEADER=$(printf "%-18s %10s %10s %10s %10s %8s %8s %8s" \
    "Program" "Base(s)" "Opt(s)" "Speedup" "Checks" "Final" "Removed" "Reduction")
SEP=$(printf '─%.0s' {1..90})
echo ""; echo "$HEADER"; echo "$SEP"
{ echo "$HEADER"; echo "$SEP"; } > "${TABLE_FILE}"

# for each benchmakr, the following code will generate the stats files to see the impact on each program.
for BENCH in "${BENCHMARKS[@]}"; do
    SRC="${ROOT}/benchmarks/${BENCH}.c"
    LL_PLAIN="${BUILD}/${BENCH}.ll"
    LL_BASE="${RESULTS}/${BENCH}_baseline.ll"
    LL_OPT="${RESULTS}/${BENCH}_opt.ll"
    BIN_BASE="${BUILD}/${BENCH}_baseline"
    BIN_OPT="${BUILD}/${BENCH}_opt"
    STATS_BASE="${RESULTS}/${BENCH}_base_stats.txt"
    STATS_OPT="${RESULTS}/${BENCH}_opt_stats.txt"

    "${CLANG}" -"${O_LEVEL}" -Xclang -disable-O0-optnone -S -emit-llvm "${SRC}" -o "${LL_PLAIN}"

    "${OPT}" -load-pass-plugin "${PLUGIN}" \
        -passes="function(instrument),sanitizer-stats" \
        -S "${LL_PLAIN}" -o "${LL_BASE}" 2>"${STATS_BASE}"

    "${OPT}" -load-pass-plugin "${PLUGIN}" \
        -passes="function(instrument,remove-redundant),sanitizer-stats" \
        -S "${LL_PLAIN}" -o "${LL_OPT}" 2>"${STATS_OPT}"

    
    "${CLANG}" -"${O_LEVEL}" "${LL_BASE}" "${RUNTIME_SRC}" -o "${BIN_BASE}" -lm
    "${CLANG}" -"${O_LEVEL}" "${LL_OPT}"  "${RUNTIME_SRC}" -o "${BIN_OPT}"  -lm

    T_BASE=$(min_time "${BIN_BASE}")
    T_OPT=$(min_time "${BIN_OPT}")

    N_BASE=$(count_checks "${LL_BASE}")
    N_OPT=$(count_checks "${LL_OPT}")
    N_REM=$(( N_BASE - N_OPT ))

    REDUCTION="0%"
    [[ "${N_BASE}" -gt 0 ]] && REDUCTION="$(awk "BEGIN{printf \"%.0f%%\", 100*${N_REM}/${N_BASE}}")"
    SPEEDUP="$(awk "BEGIN{ if (${T_OPT}>0) printf \"%.2fx\", ${T_BASE}/${T_OPT}; else print \"N/A\" }")"

    ROW=$(printf "%-18s %10s %10s %10s %10d %8d %8d %8s" \
        "${BENCH}" "${T_BASE}s" "${T_OPT}s" "${SPEEDUP}" \
        "${N_BASE}" "${N_OPT}" "${N_REM}" "${REDUCTION}")
    echo "$ROW"
    echo "$ROW" >> "${TABLE_FILE}"

    cat > "${RESULTS}/${BENCH}_summary.txt" <<EOF
Benchmark         : ${BENCH}
─────────────────────────────────────────
Static check counts:
  Baseline checks : ${N_BASE}
  Final checks    : ${N_OPT}
  Removed checks  : ${N_REM}
  Reduction       : ${REDUCTION}
─────────────────────────────────────────
Runtime (minimum of 3 runs):
  Baseline        : ${T_BASE}s
  Optimised       : ${T_OPT}s
  Speedup         : ${SPEEDUP}
EOF
done

echo "$SEP" | tee -a "${TABLE_FILE}"
echo ""
echo "Results saved to: ${RESULTS}/"
echo "Summary table  : ${TABLE_FILE}"
