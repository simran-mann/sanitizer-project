#!/bin/bash
set -euo pipefail

VER="${1:-}"

find_tool() {
    local name="$1"
    if [[ -n "$VER" ]] && command -v "${name}-${VER}" &>/dev/null; then
        echo "${name}-${VER}"
    elif command -v "$name" &>/dev/null; then
        echo "$name"
    else
        echo "ERROR: '$name' not found." >&2
        exit 1
    fi
}

LLVM_DIS=$(find_tool llvm-dis)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${ROOT}/sanrazor-results/build"
RESULTS_DIR="${ROOT}/sanrazor-results/results"
BC_DIR="${ROOT}/sanrazor_state/objects"

mkdir -p "${RESULTS_DIR}"

min_time() {
    local exe="$1" best=""
    for _ in 1 2 3; do
        local t
        t=$( { TIMEFORMAT='%R'; time "$exe" > /dev/null 2>/dev/null; } 2>&1 )
        if [[ -z "$best" ]] || awk "BEGIN{exit !(${t}+0 < ${best}+0)}"; then
            best="$t"
        fi
    done
    printf "%.3f" "${best:-0.000}"
}

# Default pattern is intentionally broad.
# Override it by exporting CHECK_PATTERN before running the script.
: "${CHECK_PATTERN:=call.*(@__asan_|@__ubsan_|@.*check|@.*san)}"

count_checks_ll() {
    local ll="$1"
    if grep -E -q "${CHECK_PATTERN}" "$ll" 2>/dev/null; then
        grep -E -c "${CHECK_PATTERN}" "$ll" 2>/dev/null
    else
        echo 0
    fi
}
BENCHMARKS=(matrix_mult array_sum quicksort binary_search convolution knapsack)

TABLE_FILE="${RESULTS_DIR}/table.txt"
HEADER=$(printf "%-18s %10s %10s %10s %10s" \
    "Program" "Base(s)" "SanRz(s)" "Speedup" "Checks")
SEP=$(printf '─%.0s' {1..66})

echo ""
echo "$HEADER"
echo "$SEP"
{
    echo "$HEADER"
    echo "$SEP"
} > "${TABLE_FILE}"

for BENCH in "${BENCHMARKS[@]}"; do
    BIN_BASE="${BUILD_DIR}/${BENCH}_base"
    BIN_SR="${BUILD_DIR}/${BENCH}_sr"
    BC_FILE="${BC_DIR}/${BENCH}.orig.bc"
    LL_FILE="${RESULTS_DIR}/${BENCH}_sr.ll"

    [[ -x "${BIN_BASE}" ]] || { echo "ERROR: Missing baseline binary ${BIN_BASE}" >&2; exit 1; }
    [[ -x "${BIN_SR}" ]]   || { echo "ERROR: Missing SanRazor binary ${BIN_SR}" >&2; exit 1; }
    [[ -f "${BC_FILE}" ]]  || { echo "ERROR: Missing SanRazor bitcode ${BC_FILE}" >&2; exit 1; }

    T_BASE=$(min_time "${BIN_BASE}")
    T_SR=$(min_time "${BIN_SR}")

    "${LLVM_DIS}" "${BC_FILE}" -o "${LL_FILE}"

    N_CHECKS=$(count_checks_ll "${LL_FILE}")

    SPEEDUP="$(awk "BEGIN{ if (${T_SR}>0) printf \"%.2fx\", ${T_BASE}/${T_SR}; else print \"N/A\" }")"

    ROW=$(printf "%-18s %10s %10s %10s %10d" \
        "${BENCH}" "${T_BASE}s" "${T_SR}s" "${SPEEDUP}" "${N_CHECKS}")
    echo "$ROW"
    echo "$ROW" >> "${TABLE_FILE}"

    cat > "${RESULTS_DIR}/${BENCH}_summary.txt" <<EOF
Benchmark         : ${BENCH}
─────────────────────────────────────────
Runtime (minimum of 3 runs):
  Baseline        : ${T_BASE}s
  SanRazor        : ${T_SR}s
  Speedup         : ${SPEEDUP}
─────────────────────────────────────────
Static analysis on SanRazor IR:
  Bitcode file    : ${BC_FILE}
  LLVM IR file    : ${LL_FILE}
  Check pattern   : ${CHECK_PATTERN}
  Matched checks  : ${N_CHECKS}
EOF
done

echo "$SEP" | tee -a "${TABLE_FILE}"
echo ""
echo "Results saved to: ${RESULTS_DIR}/"
echo "Summary table  : ${TABLE_FILE}"
echo "Check pattern  : ${CHECK_PATTERN}"