#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_dir"

tool_dir="${OSS_CAD_SUITE_BIN:-/Users/javiera/Applications/oss-cad-suite/bin}"
if [[ -d "$tool_dir" ]]; then export PATH="$tool_dir:$PATH"; fi

mkdir -p build/check
./scripts/audit_asic_dependencies.sh
sources="$(tr '\n' ' ' < scripts/asic_sources.f)"
generated="rtl/asic/generated/pochoco_game_rom.v rtl/asic/generated/pochoco_unified_ff_memory.v"

iverilog -g2012 -s asic_top -o build/check/rom.vvp $sources $generated
iverilog -g2012 -DPOCHOCO_UNIFIED_MEMORY -s asic_top \
  -o build/check/unified.vvp $sources $generated

yosys -q -l build/check/rom_yosys.log -p \
  "read_verilog -sv $sources $generated; hierarchy -check -top asic_top; synth -top asic_top; stat"
yosys -q -l build/check/unified_yosys.log -p \
  "read_verilog -sv -DPOCHOCO_UNIFIED_MEMORY $sources $generated; hierarchy -check -top asic_top; synth -top asic_top; stat"

echo "ASIC RTL valido para las arquitecturas ROM+RAM y memoria unificada."
