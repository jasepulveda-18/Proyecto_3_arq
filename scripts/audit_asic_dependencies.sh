#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_dir"

sources="$(cat scripts/asic_sources.f) rtl/asic/generated/pochoco_game_rom.v rtl/asic/generated/pochoco_unified_ff_memory.v"

if grep -nE '\$readmemh[[:space:]]*\(|SB_RAM40_4K[[:space:]]*#?[[:space:]]*\(' $sources; then
  echo "Se encontro una dependencia exclusiva de FPGA en el conjunto ASIC."
  exit 1
fi

if grep -nE '^[[:space:]]*initial([[:space:]]|$)' $sources; then
  echo "Se encontro un bloque initial en el conjunto ASIC."
  exit 1
fi

echo "Auditoria ASIC correcta: sin readmemh, initial ni primitivas SB_RAM40_4K."
