#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_dir"

architecture="${1:-rom}"

# Barrido temporal: incluye obligatoriamente 100 ns y dos puntos mas exigentes.
for period in 100 80 60; do
  ./scripts/run_librelane.sh "$architecture" "$period" 40 \
    "timing_${architecture}_${period}ns"
done

# Barrido de floorplan: tres utilizaciones con el periodo final de 100 ns.
for util in 30 40 50; do
  ./scripts/run_librelane.sh "$architecture" 100 "$util" \
    "floorplan_${architecture}_u${util}"
done
