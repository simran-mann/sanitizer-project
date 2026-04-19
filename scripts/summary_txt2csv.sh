#!/usr/bin/env bash
set -euo pipefail

INPUT="${1:-}"

[[ -f "$INPUT" ]] || { echo "Usage: $0 input.txt [output.csv]"; exit 1; }

# If output not provided, replace .txt with .csv
if [[ $# -ge 2 ]]; then
    OUTPUT="$2"
else
    OUTPUT="${INPUT%.txt}.csv"
fi

awk '
BEGIN { OFS="," }

/^[─]+$/ { next }

{
    gsub(/^[ \t]+|[ \t]+$/, "")
    gsub(/[ \t]+/, ",")
    print
}
' "$INPUT" > "$OUTPUT"

echo "CSV written to: $OUTPUT"