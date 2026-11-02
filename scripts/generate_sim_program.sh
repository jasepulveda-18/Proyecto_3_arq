#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_dir"
mkdir -p sim/generated

python3 sw/assembler.py sw/game.s sim/generated/game_sim.hex \
  -D WAIT_3S_HI=0 -D WAIT_3S_LO=30 \
  -D TENTH_HI=0 -D TENTH_LO=10 \
  -D ERROR_1S_HI=0 -D ERROR_1S_LO=10 \
  -D NUM_ROUNDS=1 -D AVERAGE_DIVISOR=1 -D AVERAGE_STEP=-1 \
  --rom-verilog sim/generated/pochoco_game_rom.v \
  --unified-verilog sim/generated/pochoco_unified_ff_memory.v \
  --unified-words 128 \
  --metadata sim/generated/program_metadata.json
