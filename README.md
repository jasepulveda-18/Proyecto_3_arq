# Proyecto 3 - Pochoco SoC de RTL a ASIC

Este repositorio contiene la adaptación a ASIC del Pochoco SoC con el juego de
reflejos desarrollado en el Proyecto 2. El objetivo es llevar el diseño desde
RTL hasta GDSII usando LibreLane y el PDK GF180MCU.

El resultado es un **macro digital implementado con celdas estándar**, no un
chip completo con pads y encapsulado. El top-level del flujo ASIC es
`rtl/asic/asic_top.v` y expone terminales lógicos para reloj, reset, botones,
LEDs, displays de 7 segmentos y SPI.

## Parámetros de la corrida final

- Período de reloj (`CLOCK_PERIOD`): **100 ns** (10 MHz).
- Utilización de core (`FP_CORE_UTIL`): **40 %**.
- PDK: `gf180mcuD`.
- Biblioteca de celdas: `gf180mcu_fd_sc_mcu7t5v0`.

Para trabajar a 10 MHz, `sw/game.s` utiliza 30 000 000 ciclos para la espera de
tres segundos, 10 000 000 ciclos para el mensaje de error y 1 000 000 de ciclos
por décima de segundo.

## Versiones utilizadas

| Herramienta o dependencia | Versión |
|---|---|
| LibreLane | `3.0.16` |
| Yosys del entorno LibreLane | `0.62` (`7326bb7d6641500ecb285c291a54a662cb1e76cf`) |
| OpenROAD | build `2026-02-17` (`dcf36133a369abc8f3c5e5738cd4d82e4903c0e0`) |
| KLayout | `0.30.7` |
| Magic | `8.3.623` |
| Netgen | `1.5.316` |
| Icarus Verilog usado en simulación | `14.0` (`s20260301-391-g64f13540a`) |
| PDK | `gf180mcuD`, revisión Open_PDKs `54435919abffb937387ec956209f9cf5fd2dfbee` |
| Biblioteca estándar | `gf180mcu_fd_sc_mcu7t5v0` |

## Organización relevante

```text
sw/game.s                         programa del juego
sw/assembler.py                   assembler y generador de memorias ASIC
rtl/asic/asic_top.v               top-level del macro ASIC
rtl/asic/pochoco_soc_asic.v       conexión entre Espino, memorias y periféricos
rtl/asic/generated/               memorias generadas desde game.s
rtl/pochoco_cycle_counter.v       contador de ciclos del juego
librelane/                        configuración, SDC y orden de terminales
sim/tb_game_asic.v                testbench funcional
scripts/                          validación, corridas y recolección de métricas
```

## Instalación de LibreLane en macOS

### 1. Instalar Nix

Instale Nix desde [nixos.org](https://nixos.org/download/) y reinicie Terminal
para que el comando `nix-shell` quede disponible.

### 2. Descargar LibreLane 3.0.16

```bash
cd ~/Desktop
curl -L https://github.com/librelane/librelane/archive/refs/tags/3.0.16.tar.gz \
  -o LibreLane-3.0.16.tar.gz
tar -xzf LibreLane-3.0.16.tar.gz
cd LibreLane-3.0.16
nix-shell
librelane --version
```

Los comandos ASIC deben ejecutarse dentro de ese `nix-shell`. La primera
corrida descarga automáticamente el PDK en `~/.ciel`; no se debe copiar el PDK
ni los resultados de las corridas al repositorio.

Para volver a entrar al entorno después de cerrar Terminal:

```bash
cd ~/Desktop/LibreLane-3.0.16
nix-shell
cd ~/Desktop/Proyecto_3_arq
```

Si las carpetas se guardaron en otra ubicación, se deben reemplazar esas rutas.

## Regenerar el programa desde `game.s`

Desde la raíz de este repositorio:

```bash
make game
```

El assembler produce tres representaciones del mismo programa:

```text
sw/game.hex                                      imagen usada por la FPGA
rtl/asic/generated/pochoco_game_rom.v           ROM + RAM de datos reducida
rtl/asic/generated/pochoco_unified_ff_memory.v  memoria unificada con flip-flops
```

También genera `rtl/asic/generated/program_metadata.json`. Para el juego actual
registra 111 palabras de instrucciones y cero palabras de RAM de datos usadas;
los accesos `lw` y `sw` del juego corresponden a periféricos mapeados en
memoria.

No es necesario borrar `game.hex` manualmente. Si se modifica `game.s`,
`make game` actualiza el archivo hexadecimal y las dos memorias Verilog.

## Pruebas antes de una corrida física

```bash
make test
make asic-check
make sim-check
```

- `make test` ejecuta las 12 pruebas del assembler.
- `make asic-check` comprueba y sintetiza las dos arquitecturas con Yosys,
  además de rechazar dependencias exclusivas de FPGA como `SB_RAM40_4K`,
  `$readmemh` o bloques `initial`.
- `make sim-check` compara la simulación RTL y post-síntesis para ambas
  estrategias. El testbench verifica inicio, objetivo, respuesta incorrecta,
  reinicio de la ronda y respuesta correcta en ciclos definidos.

Los archivos temporales de simulación quedan en `build/sim/` y no se incluyen
en Git.

## Estrategias de memoria

El mismo top-level permite comparar las dos alternativas exigidas:

1. **ROM + RAM reducida:** `pochoco_game_rom.v` implementa el programa como
   lógica combinacional y `pochoco_data_ram_ff.v` conserva una RAM mínima.
2. **Memoria unificada con flip-flops:**
   `pochoco_unified_ff_memory.v` contiene 128 palabras de 32 bits y se selecciona
   mediante `POCHOCO_UNIFIED_MEMORY`.

Las configuraciones correspondientes son `librelane/config_rom.yaml` y
`librelane/config_unified.yaml`.

## Ejecutar las corridas finales

Dentro del entorno de LibreLane y desde la raíz del repositorio:

```bash
./scripts/run_librelane.sh rom 100 40 final_rom
./scripts/run_librelane.sh unified 100 40 final_unified
```

Los argumentos del script son:

```text
run_librelane.sh <rom|unified> <periodo_ns> <utilizacion_pct> <nombre_corrida>
```

Cada nombre de corrida debe ser nuevo. Los resultados quedan localmente en
`librelane/runs/<nombre_corrida>/`; esa carpeta está excluida de Git.

Una corrida se considera cerrada solo si LibreLane completa el flujo, DRC y LVS
están limpios, no quedan violaciones de antena sin justificar y setup y hold
cumplen `WNS >= 0` y `TNS = 0` en los corners exigidos.

## Barridos de timing y floorplan

El siguiente comando ejecuta períodos de 100, 80 y 60 ns y utilizaciones de
core de 30, 40 y 50 % para la arquitectura indicada:

```bash
./scripts/run_required_sweeps.sh rom
```

Para repetir el barrido con la memoria unificada:

```bash
./scripts/run_required_sweeps.sh unified
```

Después de las corridas, las métricas se reúnen con:

```bash
python3 scripts/collect_librelane_metrics.py
```

El resumen se escribe en `evidence/librelane_metrics.csv` e incluye área,
utilización, WNS/TNS de setup y hold, resultados de signoff y el costo académico
estimado usando US$23 000 por mm².

## Flujo FPGA y flujo ASIC

El Proyecto 3 conserva el flujo de FPGA únicamente como referencia y para
comprobar que el juego original sigue funcionando:

```bash
make all
```

Ese comando genera `game_top.bin` y programa la Go Board. No genera un ASIC.
Las corridas con `scripts/run_librelane.sh` usan `asic_top.v`, celdas GF180MCU y
producen los reportes y vistas físicas del macro, incluido el GDSII.
