#!/usr/bin/env python3
"""Reune las metricas finales de cada corrida y calcula el costo del dado."""

from __future__ import annotations

import csv
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RUNS = ROOT / "librelane" / "runs"
OUTPUT = ROOT / "evidence" / "librelane_metrics.csv"
COST_PER_MM2 = 23_000.0

BASE_KEYS = [
    "design__die__area",
    "design__core__area",
    "design__instance__area",
    "design__instance__count",
    "design__instance__utilization",
    "timing__setup__wns",
    "timing__setup__tns",
    "timing__hold__wns",
    "timing__hold__tns",
    "route__drc_errors",
    "magic__drc_error__count",
    "design__lvs_error__count",
    "antenna__violating__nets",
    "antenna__violating__pins",
]


def metric_files() -> list[Path]:
    candidates = list(RUNS.glob("*/final/metrics.json"))
    if not candidates:
        candidates = list(RUNS.glob("**/metrics.json"))
    return sorted(candidates)


def main() -> None:
    files = metric_files()
    if not files:
        raise SystemExit("No hay metricas: primero ejecuta una corrida de LibreLane.")

    loaded = [(path, json.loads(path.read_text(encoding="utf-8"))) for path in files]
    corner_keys = sorted(
        {
            key
            for _, metrics in loaded
            for key in metrics
            if key.startswith("timing__setup__wns__corner:")
            or key.startswith("timing__setup__tns__corner:")
            or key.startswith("timing__hold__wns__corner:")
            or key.startswith("timing__hold__tns__corner:")
        }
    )
    fieldnames = ["run", *BASE_KEYS, *corner_keys, "estimated_cost_usd"]
    rows = []
    for path, metrics in loaded:
        row = {"run": path.relative_to(RUNS).parts[0]}
        for key in [*BASE_KEYS, *corner_keys]:
            row[key] = metrics.get(key, "")
        die_area = metrics.get("design__die__area")
        row["estimated_cost_usd"] = (
            float(die_area) / 1_000_000.0 * COST_PER_MM2
            if die_area is not None
            else ""
        )
        rows.append(row)

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    with OUTPUT.open("w", newline="", encoding="utf-8") as output_file:
        writer = csv.DictWriter(output_file, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)
    print(f"Metricas escritas en {OUTPUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
