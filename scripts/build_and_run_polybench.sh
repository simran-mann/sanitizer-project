#!/usr/bin/env bash
set -euo pipefail

USE_POLYBENCH=1
SHOW_HELP=0
POLY_DIR=1
OPT_LEVEL="O0"
SUMMARY_OUT="summary_table.txt"

usage() {
    cat <<EOF
Usage:
  $0 POLYBENCH_PATH [OPT_LEVEL] [SUMMARY_OUTPUT]
  $0 -h|--help

Arguments:
  POLYBENCH_PATH   Path to the PolyBench directory
  OPT_LEVEL        Optional compiler optimization level: O0, O1, O2, O3 - defaults to O0
  SUMMARY_OUTPUT   Optional summary table output filename

Examples:
  $0 ../polybench-3.1
  $0 ../polybench-3.1 O0
  $0 ../polybench-3.1 O2
  $0 ../polybench-3.1 O2 my_summary.txt
EOF
}

if [[ $# -gt 0 && ( "$1" == "-h" || "$1" == "--help" ) ]]; then
    usage
    exit 0
fi

[[ $# -ge 1 ]] || { usage; exit 1; }

POLY_DIR="$1"
shift

OPT_LEVEL="O0"
SUMMARY_OUT="summary_table.txt"

if [[ $# -gt 0 ]]; then
    OPT_LEVEL="$1"
    shift
fi

if [[ $# -gt 0 ]]; then
    SUMMARY_OUT="$1"
    shift
fi

[[ $# -eq 0 ]] || { echo "ERROR: Too many arguments" >&2; usage; exit 1; }

case "${OPT_LEVEL}" in
    O0|O1|O2|O3) ;;
    *)
        echo "ERROR: OPT_LEVEL must be one of O0, O1, O2, O3" >&2
        usage
        exit 1
        ;;
esac

find_tool() {
    local name="$1"
    if command -v "$name" &>/dev/null; then
        echo "$name"
    else
        echo "ERROR: '$name' not found." >&2
        exit 1
    fi
}


CLANG=$(find_tool clang)
OPT=$(find_tool opt)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD="${ROOT}/build"
# RESULTS="${ROOT}/results/polybench_${OPT_LEVEL}"
if [[ "${USE_POLYBENCH}" -eq 1 ]]; then
    RESULTS="${ROOT}/results/polybench_${OPT_LEVEL}"
else
    RESULTS="${ROOT}/results/custom_${OPT_LEVEL}"
fi
RUNTIME_SRC="${ROOT}/runtime/check_access.c"
[[ "$(uname)" == "Darwin" ]] && PLUGIN="${BUILD}/SanitizerPlugin.dylib" || PLUGIN="${BUILD}/SanitizerPlugin.so"
mkdir -p "${BUILD}" "${RESULTS}" "${BUILD}/polybench/${OPT_LEVEL}"

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
        if [[ -z "$best" ]] || awk "BEGIN{exit !(${t}+0 < ${best}+0)}"; then
            best="$t"
        fi
    done
    printf "%.3f" "${best:-0.000}"
}

echo "PolyBench dir: ${POLY_DIR}"
count_checks() { grep -c '@check_access' "$1" 2>/dev/null || echo 0; }

get_dynamic_count() {
    local exe="$1"
    local tmpfile
    tmpfile=$(mktemp)
    "$exe" > /dev/null 2>"$tmpfile" || true
    grep -o '[0-9]*' "$tmpfile" | tail -1
    rm -f "$tmpfile"
}

TABLE_FILE="${RESULTS}/${SUMMARY_OUT}"
# HEADER=$(printf "%-24s %10s %10s %10s %10s %8s %8s %8s" \
#     "Program" "Base(s)" "Opt(s)" "Speedup" "Static checks for base" "Static checks for opt" "Static checks removed" "Reduction in static checks%" "Dynamic checks for base" "Dynamic checks for opt" "Dynamic checks removed" "Reduction in dynamic checks%")

HEADER=$(printf "%-18s %9s %9s %9s %8s %8s %8s %8s %14s %14s %14s %8s"  \
    "Program" "Base(s)" "Opt(s)" "Speedup" \
    "S-Base" "S-Opt" "S-Rem" "S-Red%" \
    "D-Base" "D-Opt" "D-Rem" "D-Red%")

SEP=$(printf '─%.0s' {1..170})
echo ""
echo "$HEADER"
echo "$SEP"
{
    echo "$HEADER"
    echo "$SEP"
} > "${TABLE_FILE}"

if [[ "${USE_POLYBENCH}" -eq 1 ]]; then
    if [[ -z "${POLY_DIR}" ]]; then
        POLY_DIR="${ROOT}/../polybench-3.1"
    fi

    POLY_DIR="$(cd "${POLY_DIR}" && pwd)"
    POLY_UTIL="${POLY_DIR}/utilities/polybench.c"
    POLY_UTIL_DIR="${POLY_DIR}/utilities"

    [[ -d "${POLY_DIR}" ]] || { echo "ERROR: PolyBench dir not found: ${POLY_DIR}" >&2; exit 1; }
    [[ -f "${POLY_UTIL}" ]] || { echo "ERROR: Missing ${POLY_UTIL}" >&2; exit 1; }

    # echo "PolyBench dir: ${POLY_DIR}"

    BENCHMARKS=(
        "datamining/correlation/correlation"
        "datamining/covariance/covariance"
        "linear-algebra/kernels/2mm/2mm"
        "linear-algebra/kernels/3mm/3mm"
        "linear-algebra/kernels/atax/atax"
        "linear-algebra/kernels/bicg/bicg"
        "linear-algebra/kernels/cholesky/cholesky"
        "linear-algebra/kernels/doitgen/doitgen"
        "linear-algebra/kernels/gemm/gemm"
        "linear-algebra/kernels/gemver/gemver"
        "linear-algebra/kernels/gesummv/gesummv"
        "linear-algebra/kernels/mvt/mvt"
        "linear-algebra/kernels/symm/symm"
        "linear-algebra/kernels/syr2k/syr2k"
        "linear-algebra/kernels/syrk/syrk"
        "linear-algebra/kernels/trisolv/trisolv"
        "linear-algebra/kernels/trmm/trmm"
        "linear-algebra/solvers/durbin/durbin"
        "linear-algebra/solvers/dynprog/dynprog"
        "linear-algebra/solvers/gramschmidt/gramschmidt"
        "linear-algebra/solvers/lu/lu"
        "linear-algebra/solvers/ludcmp/ludcmp"
        "medley/floyd-warshall/floyd-warshall"
        "medley/reg_detect/reg_detect"
        "stencils/adi/adi"
        "stencils/fdtd-2d/fdtd-2d"
        "stencils/fdtd-apml/fdtd-apml"
        "stencils/jacobi-1d-imper/jacobi-1d-imper"
        "stencils/jacobi-2d-imper/jacobi-2d-imper"
        "stencils/seidel-2d/seidel-2d"
    )

    for BENCH in "${BENCHMARKS[@]}"; do
        SRC="${POLY_DIR}/${BENCH}.c"
        BENCH_NAME="$(basename "${BENCH}")"
        BENCH_DIR="$(dirname "${SRC}")"
        # SAFE_NAME="$(echo "${BENCH}" | sed 's#/#__#g')"
        # SAFE_NAME="$(echo "${BENCH}" | sed 's#/#_#g')"

        LL_PLAIN="${BUILD}/polybench/${OPT_LEVEL}/${BENCH_NAME}.ll"
        LL_BASE="${RESULTS}/${BENCH_NAME}_baseline.ll"
        LL_OPT="${RESULTS}/${BENCH_NAME}_opt.ll"
        BIN_BASE="${BUILD}/polybench/${OPT_LEVEL}/${BENCH_NAME}_baseline"
        BIN_OPT="${BUILD}/polybench/${OPT_LEVEL}/${BENCH_NAME}_opt"
        STATS_BASE="${RESULTS}/${BENCH_NAME}_base_stats.txt"
        STATS_OPT="${RESULTS}/${BENCH_NAME}_opt_stats.txt"

        [[ -f "${SRC}" ]] || { echo "WARNING: Missing source, skipping: ${SRC}" >&2; continue; }

        # echo "Running ${BENCH}..."

        if [[ "${OPT_LEVEL}" == "O0" ]]; then
            "${CLANG}" -O0 -Xclang -disable-O0-optnone \
                -include stdlib.h \
                -I "${POLY_UTIL_DIR}" \
                -I "${BENCH_DIR}" \
                -S -emit-llvm "${SRC}" \
                -o "${LL_PLAIN}"
        else
            "${CLANG}" "-${OPT_LEVEL}" \
                -include stdlib.h \
                -I "${POLY_UTIL_DIR}" \
                -I "${BENCH_DIR}" \
                -S -emit-llvm "${SRC}" \
                -o "${LL_PLAIN}"
        fi

        "${OPT}" -load-pass-plugin "${PLUGIN}" \
            -passes="function(instrument),sanitizer-stats" \
            -S "${LL_PLAIN}" -o "${LL_BASE}" 2>"${STATS_BASE}"

        "${OPT}" -load-pass-plugin "${PLUGIN}" \
            -passes="function(instrument,remove-redundant),sanitizer-stats" \
            -S "${LL_PLAIN}" -o "${LL_OPT}" 2>"${STATS_OPT}"

        "${CLANG}" "-${OPT_LEVEL}" "${LL_BASE}" "${POLY_UTIL}" "${RUNTIME_SRC}" \
            -I "${POLY_UTIL_DIR}" \
            -I "${BENCH_DIR}" \
            -o "${BIN_BASE}" -lm

        "${CLANG}" "-${OPT_LEVEL}" "${LL_OPT}" "${POLY_UTIL}" "${RUNTIME_SRC}" \
            -I "${POLY_UTIL_DIR}" \
            -I "${BENCH_DIR}" \
            -o "${BIN_OPT}" -lm

        T_BASE=$(min_time "${BIN_BASE}")
        T_OPT=$(min_time "${BIN_OPT}")

        N_BASE=$(count_checks "${LL_BASE}")
        N_OPT=$(count_checks "${LL_OPT}")
        N_REM=$(( N_BASE - N_OPT ))

        REDUCTION="0%"
        [[ "${N_BASE}" -gt 0 ]] && REDUCTION="$(awk "BEGIN{printf \"%.0f%%\", 100*${N_REM}/${N_BASE}}")"
        SPEEDUP="$(awk "BEGIN{ if (${T_OPT}>0) printf \"%.2fx\", ${T_BASE}/${T_OPT}; else print \"N/A\" }")"

        # ROW=$(printf "%-24s %10s %10s %10s %10d %8d %8d %8s" \
        #     "${BENCH_NAME}" "${T_BASE}s" "${T_OPT}s" "${SPEEDUP}" \
        #     "${N_BASE}" "${N_OPT}" "${N_REM}" "${REDUCTION}")

        #count dynamic checks 
        DYN_BASE=$(get_dynamic_count "${BIN_BASE}")
        DYN_OPT=$(get_dynamic_count "${BIN_OPT}")
        DYN_BASE="${DYN_BASE:-0}"
        DYN_OPT="${DYN_OPT:-0}"
        DYN_REM=$(( DYN_BASE - DYN_OPT ))
        DYN_REDUCTION="0%"
        [[ "${DYN_BASE}" -gt 0 ]] && \
            DYN_REDUCTION="$(awk "BEGIN{printf \"%.0f%%\", 100*${DYN_REM}/${DYN_BASE}}")"


        ROW=$(printf "%-18s %9s %9s %9s %8d %8d %8d %8s %14d %14d %14d %8s"  \
            "${BENCH_NAME}" "${T_BASE}s" "${T_OPT}s" "${SPEEDUP}" \
            "${N_BASE}" "${N_OPT}" "${N_REM}" "${REDUCTION}" \
            "${DYN_BASE}" "${DYN_OPT}" "${DYN_REM}" "${DYN_REDUCTION}")
        echo "$ROW"
        echo "$ROW" >> "${TABLE_FILE}"

        cat > "${RESULTS}/${BENCH_NAME}_summary.txt" <<EOF
Benchmark         : ${BENCH}
─────────────────────────────────────────
Static check counts:
  Baseline checks : ${N_BASE}
  Final checks    : ${N_OPT}
  Removed checks  : ${N_REM}
  Reduction       : ${REDUCTION}
─────────────────────────────────────────
Dynamic check counts (actual executions):
  Baseline execs  : ${DYN_BASE}
  Final execs     : ${DYN_OPT}
  Saved execs     : ${DYN_REM}
  Dyn reduction   : ${DYN_REDUCTION}
─────────────────────────────────────────
Runtime (minimum of 3 runs):
  Baseline        : ${T_BASE}s
  Optimised       : ${T_OPT}s
  Speedup         : ${SPEEDUP}
EOF
    done

else
    BENCHMARKS=(matrix_mult array_sum quicksort binary_search convolution knapsack)

    for BENCH in "${BENCHMARKS[@]}"; do
        SRC="${ROOT}/benchmarks/${BENCH}.c"
        LL_PLAIN="${BUILD}/${BENCH}.ll"
        LL_BASE="${RESULTS}/${BENCH}_baseline.ll"
        LL_OPT="${RESULTS}/${BENCH}_opt.ll"
        BIN_BASE="${BUILD}/${BENCH}_baseline"
        BIN_OPT="${BUILD}/${BENCH}_opt"
        STATS_BASE="${RESULTS}/${BENCH}_base_stats.txt"
        STATS_OPT="${RESULTS}/${BENCH}_opt_stats.txt"

        # "${CLANG}" "-${OPT_LEVEL}" -S -emit-llvm "${SRC}" -o "${LL_PLAIN}"
        if [[ "${OPT_LEVEL}" == "O0" ]]; then
            "${CLANG}" -O0 -Xclang -disable-O0-optnone -S -emit-llvm "${SRC}" -o "${LL_PLAIN}"
        else
            "${CLANG}" "-${OPT_LEVEL}" -S -emit-llvm "${SRC}" -o "${LL_PLAIN}"
        fi

        "${OPT}" -load-pass-plugin "${PLUGIN}" \
            -passes="function(instrument),sanitizer-stats" \
            -S "${LL_PLAIN}" -o "${LL_BASE}" 2>"${STATS_BASE}"

        "${OPT}" -load-pass-plugin "${PLUGIN}" \
            -passes="function(instrument,remove-redundant),sanitizer-stats" \
            -S "${LL_PLAIN}" -o "${LL_OPT}" 2>"${STATS_OPT}"

        "${CLANG}" "-${OPT_LEVEL}" "${LL_BASE}" "${RUNTIME_SRC}" -o "${BIN_BASE}" -lm
        "${CLANG}" "-${OPT_LEVEL}" "${LL_OPT}"  "${RUNTIME_SRC}" -o "${BIN_OPT}"  -lm

        T_BASE=$(min_time "${BIN_BASE}")
        T_OPT=$(min_time "${BIN_OPT}")

        N_BASE="$(count_checks "${LL_BASE}" | tr -d '[:space:]')"
        N_OPT="$(count_checks "${LL_OPT}" | tr -d '[:space:]')"
        N_REM=$((N_BASE - N_OPT))

        REDUCTION="0%"
        [[ "${N_BASE}" -gt 0 ]] && REDUCTION="$(awk "BEGIN{printf \"%.0f%%\", 100*${N_REM}/${N_BASE}}")"
        SPEEDUP="$(awk "BEGIN{ if (${T_OPT}>0) printf \"%.2fx\", ${T_BASE}/${T_OPT}; else print \"N/A\" }")"

        #count dynamic checks
        DYN_BASE=$(get_dynamic_count "${BIN_BASE}")
        DYN_OPT=$(get_dynamic_count "${BIN_OPT}")
        DYN_BASE="${DYN_BASE:-0}"
        DYN_OPT="${DYN_OPT:-0}"
        DYN_REM=$(( DYN_BASE - DYN_OPT ))
        DYN_REDUCTION="0%"
        [[ "${DYN_BASE}" -gt 0 ]] && \
            DYN_REDUCTION="$(awk "BEGIN{printf \"%.0f%%\", 100*${DYN_REM}/${DYN_BASE}}")"

        # ROW=$(printf "%-24s %10s %10s %10s %10d %8d %8d %8s" \
        #     "${BENCH}" "${T_BASE}s" "${T_OPT}s" "${SPEEDUP}" \
        #     "${N_BASE}" "${N_OPT}" "${N_REM}" "${REDUCTION}")
        ROW=$(printf "%-18s %9s %9s %9s %8d %8d %8d %8s %14d %14d %14d %8s"  \
            "${BENCH}" "${T_BASE}s" "${T_OPT}s" "${SPEEDUP}" \
            "${N_BASE}" "${N_OPT}" "${N_REM}" "${REDUCTION}" \
            "${DYN_BASE}" "${DYN_OPT}" "${DYN_REM}" "${DYN_REDUCTION}")
        echo "$ROW"
        echo "$ROW" >> "${TABLE_FILE}"

cat > "${RESULTS}/${BENCH}_summary.txt" <<EOF
Benchmark         : ${BENCH}
─────────────────────────────────────────
Static check counts (IR call sites):
  Baseline checks : ${N_BASE}
  Final checks    : ${N_OPT}
  Removed checks  : ${N_REM}
  Reduction       : ${REDUCTION}
─────────────────────────────────────────
Dynamic check counts (actual executions):
  Baseline execs  : ${DYN_BASE}
  Final execs     : ${DYN_OPT}
  Saved execs     : ${DYN_REM}
  Dyn reduction   : ${DYN_REDUCTION}
─────────────────────────────────────────
Runtime (minimum of 3 runs):
  Baseline        : ${T_BASE}s
  Optimised       : ${T_OPT}s
  Speedup         : ${SPEEDUP}
EOF
    done
fi

echo "$SEP" | tee -a "${TABLE_FILE}"
echo ""
echo "Results saved to: ${RESULTS}/"
echo "Summary table  : ${TABLE_FILE}"
