#!/usr/bin/env bash
set -euo pipefail
umask 022

OPT_LEVEL="O0"
POLY_DIR=""
BENCH_MODE="LOCAL_BENCH"

usage() {
    cat <<EOF
Usage:
  $0 [--polybench|--local] [POLYBENCH_PATH] [OPT_LEVEL]
  $0 -h|--help

Arguments:
  none             Run local benchmarks with optimization level O0 (default)
  --polybench      Run PolyBench benchmarks
  --local          Run local benchmarks (default)
  POLYBENCH_PATH   Path to the PolyBench directory (only needed for --polybench)
  OPT_LEVEL        Optional compiler optimization level: O0, O1, O2, O3 (default: O0)

Examples:
  $0 --local
  $0 --local O2
  $0 --polybench ../polybench-3.1 
  $0 --polybench ../polybench-3.1 O0
EOF
}
# [[ $# -gt 0 ]] || { usage; exit 1; }

# First argument may be POLYBENCH_PATH OR a flag
# if [[ "$1" != --* ]]; then
#     POLY_DIR="$1"
#     shift
# fi

# Parse flags
while [[ $# -gt 0 ]]; do
    case "$1" in
        --polybench)
            BENCH_MODE="POLY_BENCH"
            shift
            ;;
        --local)
            BENCH_MODE="LOCAL_BENCH"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            break
            ;;
    esac
done

# First positional arg: either path or opt level
if [[ $# -gt 0 ]]; then
    case "$1" in
        O0|O1|O2|O3)
            OPT_LEVEL="$1"
            shift
            ;;
        *)
            POLY_DIR="$1"
            shift
            ;;
    esac
fi

# Second positional arg: opt level
if [[ $# -gt 0 ]]; then
    OPT_LEVEL="$1"
    shift
fi

# Validate OPT_LEVEL
case "$OPT_LEVEL" in
    O0|O1|O2|O3) ;;
    *)
        echo "ERROR: OPT_LEVEL must be one of O0, O1, O2, O3" >&2
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

if [[ "${BENCH_MODE}" == "LOCAL_BENCH" ]]; then
    RESULTS="${ROOT}/results/local_bench/${OPT_LEVEL}" 
    BUILD="${ROOT}/build/local_bench/${OPT_LEVEL}"
    mkdir -p "${BUILD}" "${RESULTS}" 

else
    RESULTS="${ROOT}/results/polybench/${OPT_LEVEL}"   
    BUILD="${ROOT}/build/polybench/${OPT_LEVEL}"
    POLY_DIR="$(cd "${POLY_DIR}" && pwd)"
    POLY_UTIL="${POLY_DIR}/utilities/polybench.c"
    POLY_UTIL_DIR="${POLY_DIR}/utilities"
    [[ -d "${POLY_DIR}" ]] || { echo "ERROR: PolyBench dir not found: ${POLY_DIR}" >&2; exit 1; }
    [[ -f "${POLY_UTIL}" ]] || { echo "ERROR: Missing ${POLY_UTIL}" >&2; exit 1; }
    mkdir -p "${BUILD}" "${RESULTS}" 
fi

RUNTIME_SRC="${ROOT}/runtime/check_access.c"
[[ -f "${RUNTIME_SRC}" ]] || { echo "ERROR: Missing runtime source: ${RUNTIME_SRC}" >&2; exit 1; }
[[ "$(uname)" == "Darwin" ]] && PLUGIN="${BUILD}/SanitizerPlugin.dylib" || PLUGIN="${BUILD}/SanitizerPlugin.so"

# echo "PolyBench Directory         = ${POLY_DIR}"
echo "Clang optimization level    = ${OPT_LEVEL}"
echo "Build directory             = ${BUILD}"
echo "Results directory           = ${RESULTS}"

echo ""
echo "=== Building LLVM plugin ==="
cmake -S "${ROOT}" -B "${BUILD}" -DCMAKE_BUILD_TYPE=Release -Wno-dev 2>/dev/null
cmake --build "${BUILD}" --target SanitizerPlugin \
      -j"$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)"
[[ -f "${PLUGIN}" ]] || { echo "ERROR: Plugin not found at ${PLUGIN}" >&2; exit 1; }
echo "Plugin ready: ${PLUGIN}"

echo ""
echo "BENCH_MODE = ${BENCH_MODE}"
echo ""

min_time() {
    local exe="$1" best=""
    for _ in 1 2 3; do
        local t
        t=$( { TIMEFORMAT='%R'; time "$exe" > /dev/null 2>/dev/null; } 2>&1 )
        if [[ -z "$best" ]] || awk "BEGIN{exit !(${t}+0 < ${best}+0)}"; then
            best="$t"
        fi
    done
    printf "%.2f" "${best:-0.00}"
}

count_checks() {
    grep -c '@check_access' "$1" 2>/dev/null || echo 0
}

get_dynamic_count() {
    local exe="$1"
    local tmpfile
    tmpfile=$(mktemp)

    "$exe" >"$tmpfile" 2>&1 || true

    awk -F': ' '/Runtime checks executed/ {print $2}' "$tmpfile" | tail -n1

    rm -f "$tmpfile"
}

RUNTIME_TABLE="${RESULTS}/runtime_summary.txt"
CHECK_TABLE="${RESULTS}/check_access_summary.txt"

# create output tables
RUNTIME_HEADER=$(printf "%-15s %14s %14s %14s %14s %14s %14s %14s %17s" \
    "Benchmark" "Baseline(s)" "ASan(s)" "ToolBase(s)" "ToolOpt(s)" \
    "Speedup(x)" "Overhead(x)" "ASan_OH(x)" "Speedup_v_ASan(x)")

CHECK_HEADER=$(printf "%-15s %14s %14s %14s %14s %14s %14s %14s %14s" \
    "Benchmark" "S-Base" "S-Opt" "S-Rem" "S-Red%" \
    "D-Base" "D-Opt" "D-Rem" "D-Red%")

SEP_RUNTIME=$(printf '─%.0s' $(seq 1 ${#RUNTIME_HEADER}))
SEP_CHECK=$(printf '─%.0s' $(seq 1 ${#CHECK_HEADER}))
# SEP_RUNTIME=$(printf '─%.0s' {1..125})
# SEP_CHECK=$(printf '─%.0s' {1..92})

{
    echo "$RUNTIME_HEADER"
    echo "$SEP_RUNTIME"
} > "${RUNTIME_TABLE}"

{
    echo "$CHECK_HEADER"
    echo "$SEP_CHECK"
} > "${CHECK_TABLE}"

# echo "$RUNTIME_HEADER"
echo "$CHECK_HEADER"
echo "$SEP_CHECK"


if [[ "${BENCH_MODE}" == "LOCAL_BENCH" ]]; then
    BENCHMARKS=(
        "matrix_mult" 
        "array_sum" 
        "quicksort" 
        "binary_search" 
        "knapsack"
        )
else
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
fi

for BENCH in "${BENCHMARKS[@]}"; do

    if [[ "${BENCH_MODE}" == "LOCAL_BENCH" ]]; then
        SRC="benchmarks/${BENCH}.c"
    else
        SRC="${POLY_DIR}/${BENCH}.c"
    fi
    
    BENCH_NAME="$(basename "${BENCH}")"
    BENCH_DIR="$(dirname "${SRC}")"
    mkdir -p "${RESULTS}/${BENCH_NAME}" 
    
    [[ -f "${SRC}" ]] || { echo "WARNING: Missing source, skipping: ${SRC}" >&2; continue; }

    # pathname for IR files
    LL_BASELINE="${RESULTS}/${BENCH_NAME}/${BENCH_NAME}_baseline.ll"
    LL_TOOL_BASE="${RESULTS}/${BENCH_NAME}/${BENCH_NAME}_tool_base.ll"
    LL_TOOL_OPT="${RESULTS}/${BENCH_NAME}/${BENCH_NAME}_tool_opt.ll"

    # pathname for executables
    BIN_BASELINE="${BUILD}/${BENCH_NAME}_baseline"
    BIN_TOOL_BASE="${BUILD}/${BENCH_NAME}_tool_base"
    BIN_TOOL_OPT="${BUILD}/${BENCH_NAME}_tool_opt"
    BIN_ASAN="${BUILD}/${BENCH_NAME}_asan"

    # pathname for stats files
    STATS_TOOL_BASE="${RESULTS}/${BENCH_NAME}/check_base_stats.txt"
    STATS_TOOL_OPT="${RESULTS}/${BENCH_NAME}/check_opt_stats.txt"

    [[ -f "${SRC}" ]] || { echo "WARNING: Missing source, skipping: ${SRC}" >&2; continue; }

    # echo "Running ${BENCH_NAME} benchmark"

    # 1) Build plain LLVM IR
    if [[ "${OPT_LEVEL}" == "O0" && "${BENCH_MODE}" == "LOCAL_BENCH" ]]; then
        "${CLANG}" -O0 -Xclang -disable-O0-optnone \
            -I "${BENCH_DIR}" \
            -S -emit-llvm "${SRC}" \
            -o "${LL_BASELINE}"

    elif [[ "${OPT_LEVEL}" == "O0" && "${BENCH_MODE}" == "POLY_BENCH" ]]; then
        "${CLANG}" -O0 -Xclang -disable-O0-optnone \
            -include stdlib.h \
            -I "${POLY_UTIL_DIR}" \
            -I "${BENCH_DIR}" \
            -S -emit-llvm "${SRC}" \
            -o "${LL_BASELINE}"

    elif [[ "${BENCH_MODE}" == "POLY_BENCH" ]]; then
        "${CLANG}" "-${OPT_LEVEL}" \
            -include stdlib.h \
            -I "${POLY_UTIL_DIR}" \
            -I "${BENCH_DIR}" \
            -S -emit-llvm "${SRC}" \
            -o "${LL_BASELINE}"

    else
        "${CLANG}" "-${OPT_LEVEL}" \
            -I "${BENCH_DIR}" \
            -S -emit-llvm "${SRC}" \
            -o "${LL_BASELINE}"
    fi


    # 2) Build baseline executable (executable with nothing else applied)
    if [[ "${BENCH_MODE}" == "LOCAL_BENCH" ]]; then
        "${CLANG}" "-${OPT_LEVEL}" \
            -I "${BENCH_DIR}" \
            "${SRC}" \
            -o "${BIN_BASELINE}" -lm
    else
        "${CLANG}" "-${OPT_LEVEL}" \
            -include stdlib.h \
            -I "${POLY_UTIL_DIR}" \
            -I "${BENCH_DIR}" \
            "${SRC}" "${POLY_UTIL}" \
            -o "${BIN_BASELINE}" -lm
    fi
    
    # 3) Build ASan executable (executable with -fsanitize=address applied)
    if [[ "${BENCH_MODE}" == "LOCAL_BENCH" ]]; then
        "${CLANG}" "-${OPT_LEVEL}" -fsanitize=address \
            -I "${BENCH_DIR}" \
            "${SRC}" \
            -o "${BIN_ASAN}" -lm
    else
        "${CLANG}" "-${OPT_LEVEL}" -fsanitize=address \
            -include stdlib.h \
            -I "${POLY_UTIL_DIR}" \
            -I "${BENCH_DIR}" \
            "${SRC}" "${POLY_UTIL}" \
            -o "${BIN_ASAN}" -lm
    fi

    # 4) Build tool baseline IR (.ll with tool instrumentation applied - i.e. all checks present)
    "${OPT}" -load-pass-plugin "${PLUGIN}" \
        -passes="function(instrument),sanitizer-stats" \
        -S "${LL_BASELINE}" -o "${LL_TOOL_BASE}" 2>"${STATS_TOOL_BASE}"

    # 5) Build tool optimized IR (.ll with tool instrumentation and redundant checks removed)
    "${OPT}" -load-pass-plugin "${PLUGIN}" \
        -passes="function(instrument,remove-redundant),sanitizer-stats" \
        -S "${LL_BASELINE}" -o "${LL_TOOL_OPT}" 2>"${STATS_TOOL_OPT}"

    # 6) Compile tool baseline executable from IR (executable with all checks inserted)
    if [[ "${BENCH_MODE}" == "LOCAL_BENCH" ]]; then
        "${CLANG}" "-${OPT_LEVEL}" "${LL_TOOL_BASE}" "${RUNTIME_SRC}" \
            -I "${BENCH_DIR}" \
            -o "${BIN_TOOL_BASE}" -lm
    else
        "${CLANG}" "-${OPT_LEVEL}" "${LL_TOOL_BASE}" "${POLY_UTIL}" "${RUNTIME_SRC}" \
            -I "${POLY_UTIL_DIR}" \
            -I "${BENCH_DIR}" \
            -o "${BIN_TOOL_BASE}" -lm
    fi


    # 7) Compile tool optimized executable from IR (executable with redundant checks removed)
    if [[ "${BENCH_MODE}" == "LOCAL_BENCH" ]]; then
        "${CLANG}" "-${OPT_LEVEL}" "${LL_TOOL_OPT}" "${RUNTIME_SRC}" \
            -I "${BENCH_DIR}" \
            -o "${BIN_TOOL_OPT}" -lm
    else
        "${CLANG}" "-${OPT_LEVEL}" "${LL_TOOL_OPT}" "${POLY_UTIL}" "${RUNTIME_SRC}" \
            -I "${POLY_UTIL_DIR}" \
            -I "${BENCH_DIR}" \
            -o "${BIN_TOOL_OPT}" -lm
    fi

    # collect runtime time stats:
    T_BASELINE=$(min_time "${BIN_BASELINE}")
    T_TOOL_BASE=$(min_time "${BIN_TOOL_BASE}")
    T_TOOL_OPT=$(min_time "${BIN_TOOL_OPT}")
    T_ASAN=$(min_time "${BIN_ASAN}")

    # collect check counts for tool_base and tool_opt
    N_BASE=$(count_checks "${LL_TOOL_BASE}")
    N_OPT=$(count_checks "${LL_TOOL_OPT}")
    N_REM=$(( N_BASE - N_OPT ))

    # calc 'check' attributes
    REDUCTION="0%"
    [[ "${N_BASE}" -gt 0 ]] && \
        REDUCTION="$(awk "BEGIN{printf \"%.0f\", 100*${N_REM}/${N_BASE}}")"
    DYN_BASE=$(get_dynamic_count "${BIN_TOOL_BASE}")
    DYN_OPT=$(get_dynamic_count "${BIN_TOOL_OPT}")
    DYN_BASE="${DYN_BASE:-0}"
    DYN_OPT="${DYN_OPT:-0}"
    DYN_REM=$(( DYN_BASE - DYN_OPT ))
    DYN_REDUCTION="0%"
    [[ "${DYN_BASE}" -gt 0 ]] && \
        DYN_REDUCTION="$(awk "BEGIN{printf \"%.0f\", 100*${DYN_REM}/${DYN_BASE}}")"

    # calc 'runtime' attributes
    SPEEDUP="$(awk "BEGIN{ if (${T_TOOL_OPT}>0) printf \"%.2f\", ${T_TOOL_BASE}/${T_TOOL_OPT}; else print \"N/A\" }")"
    OVERHEAD="$(awk "BEGIN{ if (${T_BASELINE}>0) printf \"%.2f\", ${T_TOOL_OPT}/${T_BASELINE}; else print \"N/A\" }")"
    ASAN_OH="$(awk "BEGIN{ if (${T_BASELINE}>0) printf \"%.2f\", ${T_ASAN}/${T_BASELINE}; else print \"N/A\" }")"
    SPEEDUP_V_ASAN="$(awk "BEGIN{ if (${T_TOOL_OPT}>0) printf \"%.2f\", ${T_ASAN}/${T_TOOL_OPT}; else print \"N/A\" }")"

    # create columns for runtime_summary.txt
    RUNTIME_ROW=$(printf "%-15s %14s %14s %14s %14s %14s %14s %14s %17s" \
        "${BENCH_NAME}" \
        "${T_BASELINE}" "${T_ASAN}" "${T_TOOL_BASE}" "${T_TOOL_OPT}" \
        "${SPEEDUP}" "${OVERHEAD}" "${ASAN_OH}" "${SPEEDUP_V_ASAN}")

    # create columns for check_access_summary.txt
    CHECK_ROW=$(printf "%-15s %14s %14s %14s %14s %14s %14s %14s %14s" \
        "${BENCH_NAME}" "${N_BASE}" "${N_OPT}" "${N_REM}" "${REDUCTION}" \
        "${DYN_BASE}" "${DYN_OPT}" "${DYN_REM}" "${DYN_REDUCTION}")

    # echo "$RUNTIME_ROW"
    echo "$CHECK_ROW"
    echo "$RUNTIME_ROW" >> "${RUNTIME_TABLE}"
    echo "$CHECK_ROW" >> "${CHECK_TABLE}"

    cat > "${RESULTS}/${BENCH_NAME}/${BENCH_NAME}_summary.txt" <<EOF
Benchmark         : ${BENCH_NAME}
─────────────────────────────────────────
Executables:
  Baseline        : ${BIN_BASELINE}
  ASan            : ${BIN_ASAN}
  Tool baseline   : ${BIN_TOOL_BASE}
  Tool optimized  : ${BIN_TOOL_OPT}
─────────────────────────────────────────
Runtime (minimum of 3 runs):
  Baseline        : ${T_BASELINE}s
  ASan            : ${T_ASAN}s
  Tool baseline   : ${T_TOOL_BASE}s
  Tool optimized  : ${T_TOOL_OPT}s
─────────────────────────────────────────
Runtime comparisons:
  Speedup         : ${SPEEDUP}
  Overhead        : ${OVERHEAD}
  ASan_OH         : ${ASAN_OH}
  Speedup_v_ASan  : ${SPEEDUP_V_ASAN}
─────────────────────────────────────────
Static check counts:
  Checks          : ${N_BASE}
  Final           : ${N_OPT}
  Removed         : ${N_REM}
  Reduction       : ${REDUCTION}
─────────────────────────────────────────
Dynamic check counts (actual executions):
  Baseline execs  : ${DYN_BASE}
  Final execs     : ${DYN_OPT}
  Saved execs     : ${DYN_REM}
  Dyn reduction   : ${DYN_REDUCTION}
─────────────────────────────────────────
IR / stats files:
  Baseline IR     : ${LL_BASELINE}
  ToolBase IR     : ${LL_TOOL_BASE}
  ToolOpt IR      : ${LL_TOOL_OPT}
  ToolBase stats  : ${STATS_TOOL_BASE}
  ToolOpt stats   : ${STATS_TOOL_OPT}
EOF
done

echo "$SEP_RUNTIME" >> "${RUNTIME_TABLE}"
echo "$SEP_CHECK" >> "${CHECK_TABLE}"

echo ""
echo "Results saved to: ${RESULTS}/"
echo "Runtime summary : ${RUNTIME_TABLE}"
echo "Check summary   : ${CHECK_TABLE}"
# echo "Finished ${BENCH_NAME} benchmark"