# Copyright 2026 Universidad de los Andes.
# Licensed under the Solderpad Hardware License, Version 0.51 (the "License");
# you may not use this file except in compliance with the License.
# SPDX-License-Identifier: SHL-0.51
#
# Course: Arquitectura de Computadores (2026)
#
# Authors:
# - Nicolás Villegas <navillegas@miuandes.cl>

# Assembles the .s sources in this folder into the $readmemh-style .hex
# files consumed by the pochoco_soc RTL.

# Change if needed
PREFIX  ?= riscv64-unknown-elf-
AS      = $(PREFIX)as
LD      = $(PREFIX)ld
OBJCOPY = $(PREFIX)objcopy

ASFLAGS = -march=rv32e -mabi=ilp32e
LDFLAGS = -m elf32lriscv -Ttext=0x0 --no-relax

SRCS  = $(wildcard *.s)
HEXS  = $(SRCS:.s=.hex)
PROGS = $(basename $(SRCS))
OTHER_PROGS = $(filter-out game,$(PROGS))

ASIC_GEN_DIR := ../rtl/asic/generated
GAME_ROM     := $(ASIC_GEN_DIR)/pochoco_game_rom.v
GAME_UNIFIED := $(ASIC_GEN_DIR)/pochoco_unified_ff_memory.v
GAME_META    := $(ASIC_GEN_DIR)/program_metadata.json

# El Proyecto 3 usa siempre el assembler del grupo. Ademas del .hex para la
# FPGA, una misma ejecucion produce las dos implementaciones ASIC de memoria.
game.hex $(GAME_ROM) $(GAME_UNIFIED) $(GAME_META): game.s assembler.py
	python3 assembler.py game.s game.hex \
		--rom-verilog $(GAME_ROM) \
		--unified-verilog $(GAME_UNIFIED) --unified-words 128 \
		--metadata $(GAME_META)

all: $(HEXS)

.PHONY: $(OTHER_PROGS)
$(OTHER_PROGS): %: %.hex

.PHONY: game
game:
	python3 assembler.py game.s game.hex \
		--rom-verilog $(GAME_ROM) \
		--unified-verilog $(GAME_UNIFIED) --unified-words 128 \
		--metadata $(GAME_META)

%.hex: %.s
	$(AS) $(ASFLAGS) -o $*.o $<
	$(LD) $(LDFLAGS) -o $*.elf $*.o
	$(OBJCOPY) -O binary $*.elf $*.bin
	od -An -tx4 -v $*.bin | tr -s ' ' '\n' | sed '/^$$/d' > $@
	rm -f $*.o $*.elf $*.bin

clean:
	rm -f *.o *.elf *.bin

clean-game:
	rm -f game.hex $(GAME_ROM) $(GAME_UNIFIED) $(GAME_META)

test: game.hex
	python3 -m unittest -v test_assembler.py

.PHONY: all clean clean-game test
