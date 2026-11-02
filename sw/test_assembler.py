#!/usr/bin/env python3
"""Pruebas del assembler contra los ejemplos oficiales del repositorio."""

from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
import re

from assembler import (
    AssemblyError,
    assemble,
    write_combinational_rom,
    write_unified_ff_memory,
)


SW_DIR = Path(__file__).resolve().parent


class ExampleProgramsTest(unittest.TestCase):
    def assert_matches_reference(self, program: str) -> None:
        source = (SW_DIR / f"{program}.s").read_text(encoding="utf-8")
        expected = (SW_DIR / f"{program}.hex").read_text(encoding="ascii").splitlines()
        actual = [f"{word:08x}" for word in assemble(source)]
        self.assertEqual(actual, expected)

    def test_blink(self) -> None:
        self.assert_matches_reference("blink")

    def test_buttons_leds(self) -> None:
        self.assert_matches_reference("buttons_leds")

    def test_7seg(self) -> None:
        self.assert_matches_reference("7seg")

    def test_game(self) -> None:
        self.assert_matches_reference("game")

    def test_game_loads_and_stores_only_use_mmio_base_registers(self) -> None:
        source = (SW_DIR / "game.s").read_text(encoding="utf-8")
        memory_lines = [
            line.split("#", 1)[0].strip()
            for line in source.splitlines()
            if re.match(r"^\s*(lw|sw)\s", line)
        ]
        self.assertTrue(memory_lines)
        for line in memory_lines:
            match = re.search(r"\((x\d+)\)\s*$", line)
            self.assertIsNotNone(match, line)
            self.assertIn(match.group(1), {"x3", "x4", "x5", "x6"}, line)


class ValidationTest(unittest.TestCase):
    def test_rejects_registers_missing_from_rv32e(self) -> None:
        with self.assertRaisesRegex(AssemblyError, "x0 y x15"):
            assemble("addi x16, x0, 1")

    def test_rejects_unknown_instruction(self) -> None:
        with self.assertRaisesRegex(AssemblyError, "no soportada"):
            assemble("inventada x1, x2, x3")

    def test_rejects_unknown_label(self) -> None:
        with self.assertRaisesRegex(AssemblyError, "numero invalido"):
            assemble("beq x1, x2, no_existe")

    def test_equ_symbol_can_be_overridden(self) -> None:
        source = ".equ VALUE, 7\naddi x1, x0, VALUE\n"
        default_word = assemble(source)[0]
        overridden_word = assemble(source, {"VALUE": 9})[0]
        self.assertNotEqual(default_word, overridden_word)
        self.assertEqual(overridden_word, assemble("addi x1, x0, 9")[0])

    def test_generated_rom_has_no_fpga_initialization(self) -> None:
        with TemporaryDirectory() as directory:
            path = Path(directory) / "game_rom.v"
            write_combinational_rom([0x00000013, 0x00100093], path, "game_rom")
            generated = path.read_text(encoding="ascii")
            self.assertIn("module game_rom", generated)
            self.assertIn("8'd1: rdata_o = 32'h00100093", generated)
            self.assertNotIn("initial", generated)
            self.assertNotIn("$readmemh", generated)

    def test_generated_unified_memory_checks_capacity(self) -> None:
        with TemporaryDirectory() as directory:
            path = Path(directory) / "unified.v"
            with self.assertRaisesRegex(AssemblyError, "programa usa 3"):
                write_unified_ff_memory(
                    [0x13, 0x13, 0x13], path, "unified_memory", 2
                )

    def test_generated_unified_memory_embeds_program(self) -> None:
        with TemporaryDirectory() as directory:
            path = Path(directory) / "unified.v"
            write_unified_ff_memory(
                [0x00000013, 0x00100093], path, "unified_memory", 4
            )
            generated = path.read_text(encoding="ascii")
            self.assertIn("module unified_memory", generated)
            self.assertIn("mem[1] <= 32'h00100093", generated)
            self.assertNotIn("initial", generated)
            self.assertNotIn("$readmemh", generated)


if __name__ == "__main__":
    unittest.main()
