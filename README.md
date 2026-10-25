# Pochoco SoC & Espino Core

> Meet Pochoco SoC and Espino Core. Inspired by the native flora of the Pochoco trails, it is an entry-level, highly efficient architecture designed to flourish in resource-constrained environments.

![Pochoco SoC Architecture](pochoco_soc.svg)

Welcome to the repository! This project contains the RTL for a custom 32-bit processor and its surrounding System-on-Chip (SoC) designed for FPGA deployment. The design is kept straightforward to help explore and understand computer architecture fundamentals.

This is meant to be forked, not just cloned. You'll be poking around the RTL, so make it your own, we won't judge (we might even be a little proud).

## Proyecto 2: juego de reflejos

Este fork agrega un juego de reflejos para la Go Board. Al arrancar, los
displays muestran `88` para indicar que el programa esta listo; la partida se
inicia presionando y soltando cualquier boton. Cada ronda enciende los cuatro LEDs
durante tres segundos, selecciona un LED objetivo, mide la respuesta en decimas
de segundo y conserva diez tiempos correctos. Un boton incorrecto muestra `EE`
y reinicia solamente la ronda actual. El tiempo del decimo acierto permanece
visible hasta presionar y soltar cualquier boton; entonces se muestra el
promedio.

El flujo del software es:

```text
sw/game.s -> sw/assembler.py -> sw/game.hex -> memoria de Pochoco -> Espino Core
```

`game.hex` se genera con el assembler desarrollado para el proyecto; no depende
de un assembler RISC-V externo.

Desde la raiz del repositorio:

```bash
make game       # regenera sw/game.hex desde sw/game.s
make test       # ejecuta las pruebas del assembler
make all        # sintetiza, genera el bitstream y programa la Go Board
```

`make all` requiere la Go Board conectada. El top-level sintetizado es
`rtl/game_top.v`, que selecciona `sw/game.hex` como imagen de memoria.

## Proyecto 3: implementacion ASIC con GF180MCU

El Proyecto 3 conserva el juego y Espino, pero agrega un flujo ASIC separado
del flujo de la Go Board. El top-level fisico es `rtl/asic/asic_top.v`; recibe
reloj y reset externos y no contiene primitivas de iCE40, `$readmemh`, bloques
`initial` ni el reset de encendido propio de la FPGA.

El reloj final es de 10 MHz (`CLOCK_PERIOD = 100 ns`). Por eso `game.s` usa:

- 30 000 000 ciclos para tres segundos.
- 10 000 000 ciclos para un segundo de error.
- 1 000 000 ciclos por decima de segundo.

El assembler genera simultaneamente tres representaciones del mismo programa:

```text
sw/game.s
  +-- sw/game.hex                                      (FPGA)
  +-- rtl/asic/generated/pochoco_game_rom.v            (ROM + RAM reducida)
  +-- rtl/asic/generated/pochoco_unified_ff_memory.v   (memoria unificada FF)
```

La metadata generada registra 111 palabras de instruccion y cero palabras de
datos usadas por el juego. Esto ultimo se comprobo revisando que todos sus
`lw`/`sw` apuntan a los perifericos, no a RAM interna.

### Comandos de trabajo

Los comandos de esta seccion se ejecutan desde la raiz de
`Proyecto_3_arq`. No hace falta borrar manualmente `game.hex`: `make game`
lo vuelve a generar cuando cambia `game.s` o `assembler.py`.

```bash
make game          # regenera el .hex y ambas memorias ASIC
make test          # ejecuta las 12 pruebas del assembler
make asic-check    # elabora y sintetiza ambas arquitecturas con Yosys
make sim-check     # compara el juego en RTL y post-sintesis, ciclo por ciclo
```

### Instalacion reproducible del flujo ASIC en macOS

La implementacion fisica se probo con estas versiones exactas:

- LibreLane `3.0.16`.
- PDK `gf180mcuD`, revision Open_PDKs
  `54435919abffb937387ec956209f9cf5fd2dfbee`.
- Biblioteca de celdas `gf180mcu_fd_sc_mcu7t5v0`.

Primero se instala Nix siguiendo el instalador oficial de
[nixos.org](https://nixos.org/download/). Despues de cerrar y abrir Terminal,
se descarga la version usada de LibreLane:

```bash
cd ~/Desktop
curl -L https://github.com/librelane/librelane/archive/refs/tags/3.0.16.tar.gz \
  -o LibreLane-3.0.16.tar.gz
tar -xzf LibreLane-3.0.16.tar.gz
cd LibreLane-3.0.16
nix-shell
librelane --version
```

Los comandos siguientes deben ejecutarse dentro de ese `nix-shell`. En la
primera corrida, LibreLane descarga automaticamente el PDK en `~/.ciel`; no
hay que copiarlo al repositorio. En otra terminal o despues de reiniciar el
computador se vuelve a entrar asi:

```bash
cd ~/Desktop/LibreLane-3.0.16
nix-shell
cd ~/Desktop/Proyecto_3_arq
```

Si el repositorio se guardo en otra carpeta, solo cambia las dos rutas de
`cd`. Para comprobar la instalacion y el RTL antes de una corrida larga:

```bash
make game
make test
make asic-check
make sim-check
```

### Corridas fisicas y recoleccion de resultados

Una corrida recibe cuatro argumentos: estrategia de memoria, periodo en ns,
utilizacion objetivo y nombre de la corrida. Las corridas finales a 10 MHz son:

```bash
./scripts/run_librelane.sh rom 100 40 final_rom
./scripts/run_librelane.sh unified 100 40 final_unified
```

El barrido exigido de timing (100, 80 y 60 ns) y floorplan (30, 40 y 50 %)
se ejecuta con:

```bash
./scripts/run_required_sweeps.sh rom
python3 scripts/collect_librelane_metrics.py
```

El CSV queda en `evidence/librelane_metrics.csv`. Cada corrida conserva sus
reportes, metricas y vistas finales bajo `librelane/runs/<nombre>/`. Para
repetir una corrida se recomienda usar otro nombre; asi no se mezclan sus
resultados con una anterior.

### Diferencia entre los dos flujos

- **FPGA:** `make all` sintetiza `rtl/game_top.v`, genera `game_top.bin` y lo
  programa en la Go Board. Este flujo usa las herramientas iCE40.
- **ASIC:** `run_librelane.sh` sintetiza `rtl/asic/asic_top.v` con las celdas
  GF180MCU y genera layout, reportes y GDSII. No programa la placa.

## Repository Structure

The hardware is written in Verilog and divided into these main categories:

* **The Espino Core**: The central processing unit. It includes all standard pipeline stages like instruction fetch, instruction decode, an ALU for execution, a register file, a load/store unit for memory operations, and a pipeline controller. It implements [RV32E](https://docs.riscv.org/reference/isa/v20260120/unpriv/rv32.html) with a catch you might want to check out the code for.
* **The Pochoco SoC**: The top-level system wrapper. It connects the CPU core to a unified instruction/data RAM, physical board peripherals (like LEDs, switches, and displays), and an external SPI slave interface.
* **Build Files**: Constraints to map the design to the physical FPGA pins, and automation scripts for synthesis, routing, and flashing using an open-source toolchain.

## Memory Map

The SoC routes memory and data requests using a hardcoded address decoding scheme based on the highest bits of the 32-bit address.

* **`0x0000_0000` - Unified RAM**: The shared memory space for both instructions and data.
* **`0x8000_0000` - Board Peripherals**: Memory-mapped I/O for the physical board.
  * `Offset 0x00`: 7-Segment Displays
  * `Offset 0x04`: LEDs
  * `Offset 0x08`: Button Inputs
  * `Offset 0x0C`: Free-running 32-bit cycle counter
* **`0x8001_0000` - SPI Slave**: Custom SPI interface routing.
  * `Offset 0x00`: SPI Status (Chip Select state, New Data flag)
  * `Offset 0x04`: Received "Price" byte (from external master)
  * `Offset 0x08`: "Decision" byte (written by CPU to transmit)

Dive into the source code to see exactly how these components and connections are built under the hood!

## How to Build

To synthesize and build the project, you will need the open-source FPGA toolchain.

1. Install the tools by following the instructions at the [oss-cad-suite-build repository](https://github.com/yosyshq/oss-cad-suite-build).
2. Once installed, ~~blindly copy-paste~~ (we strongly encourage reading the Makefile first to make sure we aren't deleting your home directory) the following command in the project root to generate and program the final bitstream:

```bash
make all
```

## Software

The `sw/` folder holds the RV32E assembly example programs that run on the Espino Core (`blink.s`, `7seg.s`, `buttons_leds.s`), plus a `Makefile` to assemble them into the `.hex` files the RTL loads at boot via `$readmemh`.

You'll need a RISC-V toolchain on your `PATH` (`riscv64-unknown-elf-{as,ld,objcopy}` on Debian/Ubuntu/WSL via `sudo apt install gcc-riscv64-unknown-elf`, or `brew install riscv64-unknown-elf-gcc` on macOS). If your toolchain uses a different prefix, override it on the command line rather than editing the Makefile:

```bash
cd sw
make blink                        # assembles blink.s -> blink.hex
make PREFIX=riscv64-elf- blink    # if your toolchain uses a different prefix
```

Drop a new `<name>.s` file in `sw/` and `make <name>` picks it up automatically, no `Makefile` changes needed. The Project 2 game is selected by `rtl/game_top.v`.

**CATCH:** The core implements [RV32E](https://docs.riscv.org/reference/isa/v20260120/unpriv/rv32.html), with one thing worth knowing: shift instructions (`SLL`/`SRL`/`SRA`/`SLLI`/`SRLI`/`SRAI`) are decoded correctly but disabled in the ALU to save LUTs on the target FPGA, so they currently execute as `ADD` instead. Avoid shifts in your assembly, or design your own shifter...
