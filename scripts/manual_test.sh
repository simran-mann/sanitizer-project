#!/usr/bin/env bash

#  use like this to ru one single llvm IR pass  ./scripts/manual_test.sh <source.c> [LLVM_VERSION]

set -euo pipefail

SRC="${1:?Usage: $0 <source.c> [LLVM_VER]}"
VER="${2:-}"

find_tool() {
    local name="$1"
    if [[ -n "$VER" ]] && command -v "${name}-${VER}" &>/dev/null; then
        echo "${name}-${VER}"
    else
        command -v "$name" || { echo "ERROR: $name not found" >&2; exit 1; }
    fi
}

CLANG=$(find_tool clang)
OPT=$(find_tool opt)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD="${ROOT}/build"
PLUGIN="${BUILD}/SanitizerPlugin.so"
[[ "$(uname)" == "Darwin" ]] && PLUGIN="${BUILD}/SanitizerPlugin.dylib"
RUNTIME_SRC="${ROOT}/runtime/check_access.c"
TMPDIR="${BUILD}/manual_test_tmp"
mkdir -p "${TMPDIR}"

BASE=$(basename "${SRC}" .c)

LL_PLAIN="${TMPDIR}/${BASE}.ll"
LL_BASE="${TMPDIR}/${BASE}_baseline.ll"
LL_OPT="${TMPDIR}/${BASE}_opt.ll"
BIN_BASE="${TMPDIR}/${BASE}_baseline"
BIN_OPT="${TMPDIR}/${BASE}_opt"


# for each benchmakr, the following code will generate the stats files to see the impact on each program.
echo "=== Source: ${SRC} ==="
echo ""


"${CLANG}" -O0 -S -emit-llvm "${SRC}" -o "${LL_PLAIN}"
echo "IR emitted: ${LL_PLAIN}"

echo ""
echo "=== BASELINE PASS OUTPUT ==="
"${OPT}" -load-pass-plugin "${PLUGIN}" \
    -passes="instrument,sanitizer-stats" \
    -S "${LL_PLAIN}" -o "${LL_BASE}"


echo ""
echo "=== OPTIMISED PASS OUTPUT ==="
"${OPT}" -load-pass-plugin "${PLUGIN}" \
    -passes="instrument,remove-redundant,sanitizer-stats" \
    -S "${LL_PLAIN}" -o "${LL_OPT}"


N_BASE=$(grep -c '@check_access' "${LL_BASE}" 2>/dev/null || echo 0)
N_OPT=$(grep -c '@check_access' "${LL_OPT}"  2>/dev/null || echo 0)
N_REM=$(( N_BASE - N_OPT ))
echo ""
echo "=== Static check counts ==="
echo "  Baseline  : ${N_BASE}"
echo "  Optimised : ${N_OPT}"
echo "  Removed   : ${N_REM}"
if [[ "${N_BASE}" -gt 0 ]]; then
    awk "BEGIN{printf \"  Reduction : %.0f%%\n\", 100*${N_REM}/${N_BASE}}"
fi

"${CLANG}" -O0 "${LL_BASE}" "${RUNTIME_SRC}" -o "${BIN_BASE}" -lm
"${CLANG}" -O0 "${LL_OPT}"  "${RUNTIME_SRC}" -o "${BIN_OPT}"  -lm

echo ""
echo "=== Runtime output (baseline) ==="
"${BIN_BASE}"

echo ""
echo "=== Runtime output (optimised) ==="
"${BIN_OPT}"

echo ""
echo "IR files in ${TMPDIR}/"
