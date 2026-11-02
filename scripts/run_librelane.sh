#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_dir"

architecture="${1:-rom}"
period="${2:-100}"
util="${3:-40}"
tag="${4:-${architecture}_p${period}_u${util}}"

case "$architecture" in
  rom) config="librelane/config_rom.yaml" ;;
  unified) config="librelane/config_unified.yaml" ;;
  *) echo "Uso: $0 {rom|unified} [periodo_ns] [utilizacion_pct] [tag]"; exit 2 ;;
esac

if ! command -v librelane >/dev/null 2>&1; then
  echo "No se encontro LibreLane. Sigue la seccion de instalacion ASIC del README."
  exit 1
fi

make asic-generate
librelane librelane/config_base.yaml "$config" \
  --pdk gf180mcuD --scl gf180mcu_fd_sc_mcu7t5v0 \
  --run-tag "$tag" \
  --override-config "CLOCK_PERIOD=${period}" \
  --override-config "FP_CORE_UTIL=${util}"
