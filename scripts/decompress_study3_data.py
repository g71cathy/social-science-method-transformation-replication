"""Decompress the Study 3 panel distributed with this repository."""

from __future__ import annotations

import gzip
import shutil
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "data" / "study3_country_subfield_year_panel.csv.gz"
TARGET = ROOT / "data" / "study3_country_subfield_year_panel.csv"


def main() -> None:
    if not SOURCE.exists():
        raise FileNotFoundError(f"Compressed dataset not found: {SOURCE}")
    if TARGET.exists():
        print(f"Already present: {TARGET}")
        return
    with gzip.open(SOURCE, "rb") as source, TARGET.open("wb") as target:
        shutil.copyfileobj(source, target)
    print(f"Created: {TARGET}")


if __name__ == "__main__":
    main()
