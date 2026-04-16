#!/bin/bash
set -euo pipefail

BENCH="${1:?need benchmark name}"
BIN="/home/project/results/sanrazor/${BENCH}_sr_profile"

"${BIN}" >/dev/null 2>/dev/null
