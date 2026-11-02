#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_dir"

tool_dir="${OSS_CAD_SUITE_BIN:-/Users/javiera/Applications/oss-cad-suite/bin}"
if [[ -d "$tool_dir" ]]; then export PATH="$tool_dir:$PATH"; fi
mkdir -p build/sim
./scripts/generate_sim_program.sh

sources="$(tr '\n' ' ' < scripts/asic_sources.f)"
generated="sim/generated/pochoco_game_rom.v sim/generated/pochoco_unified_ff_memory.v"
simcells="$(yosys-config --datdir)/simcells.v"

run_variant() {
  variant="$1"
  define="$2"

  iverilog -g2012 $define -s tb_game_asic -o "build/sim/${variant}_rtl.vvp" \
    $sources $generated sim/tb_game_asic.v
  vvp "build/sim/${variant}_rtl.vvp" | tee "build/sim/${variant}_rtl.log"

  yosys -q -l "build/sim/${variant}_synth.log" -p \
    "read_verilog -sv $define $sources $generated; hierarchy -check -top asic_top; synth -top asic_top; write_verilog -noattr -noexpr build/sim/${variant}_netlist.v"
  iverilog -g2012 -s tb_game_asic -o "build/sim/${variant}_netlist.vvp" \
    "build/sim/${variant}_netlist.v" "$simcells" sim/tb_game_asic.v
  vvp "build/sim/${variant}_netlist.vvp" | tee "build/sim/${variant}_netlist.log"

  grep -E '^(EVENT|PASS)' "build/sim/${variant}_rtl.log" > "build/sim/${variant}_rtl.events"
  grep -E '^(EVENT|PASS)' "build/sim/${variant}_netlist.log" > "build/sim/${variant}_netlist.events"
  diff -u "build/sim/${variant}_rtl.events" "build/sim/${variant}_netlist.events"
}

run_variant rom ""
run_variant unified "-DPOCHOCO_UNIFIED_MEMORY"
echo "Simulacion RTL y post-sintesis coinciden en ambas arquitecturas."
