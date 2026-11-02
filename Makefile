# Copyright 2026 Universidad de los Andes.
# Licensed under the Solderpad Hardware License, Version 0.51 (the "License");
# you may not use this file except in compliance with the License.
# SPDX-License-Identifier: SHL-0.51
#
# Course: Arquitectura de Computadores (2026)
# 
# Authors:
# - Nicolás Villegas <navillegas@miuandes.cl>

# Configuration
TOP  ?= game_top
PCF  := goboard.pcf
GAME_HEX := sw/game.hex
ASIC_GEN := rtl/asic/generated/pochoco_game_rom.v \
	            rtl/asic/generated/pochoco_unified_ff_memory.v \
	            rtl/asic/generated/program_metadata.json

# RTL Sources
# El flujo FPGA excluye deliberadamente rtl/asic, donde existe otra
# implementacion del archivo de registros con el mismo nombre de modulo.
SRC  := $(wildcard ./rtl/*.v ./rtl/espino_core/*.v)

# Build Targets
JSON := $(TOP).json
ASC  := $(TOP).asc
BIN  := $(TOP).bin

.PHONY: all prog clean stats game test asic-generate asic-check sim-check

# Default target
all: prog

# Step 1: Synthesis using Yosys
$(JSON): $(SRC) $(GAME_HEX)
	yosys -p "read_verilog $(SRC); synth_ice40 -top $(TOP) -json ${TOP}.json; stat"

$(GAME_HEX): sw/game.s sw/assembler.py
	$(MAKE) -C sw game.hex

game:
	$(MAKE) -C sw game

asic-generate: $(ASIC_GEN)

$(ASIC_GEN): sw/game.s sw/assembler.py
	$(MAKE) -C sw game

test:
	$(MAKE) -C sw test

asic-check: asic-generate
	./scripts/check_asic_rtl.sh

sim-check:
	./scripts/run_functional_equivalence.sh

# Step 2: Place and Route using NextPNR
$(ASC): $(JSON) $(PCF)
	nextpnr-ice40 --hx1k --package vq100 --freq 25 --json $(JSON) --pcf $(PCF) --asc $(ASC)

# Step 3: Bitstream Generation
$(BIN): $(ASC)
	icepack $(ASC) $(BIN)

# Step 4: Flash the Board
prog: $(BIN)
	iceprog $(BIN)

# Clean up generated files
clean:
	rm -f $(JSON) $(ASC) $(BIN)
