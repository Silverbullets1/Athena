"""banners/_print_banner.py — Print the Athena + NERV banner.

Usage:
    python3 -m banners._print_banner          # both banners
    python3 -m banners._print_banner athena    # Athena only
    python3 -m banners._print_banner nerv      # NERV only

Pure cosmetics. Safe to call before any subprocess or CLI invocation.
"""

from __future__ import annotations

import sys
from pathlib import Path

BANNERS_DIR = Path(__file__).resolve().parent


def _emit(name: str) -> None:
    path = BANNERS_DIR / f"{name}.ascii"
    if path.exists():
        sys.stdout.write(path.read_text(encoding="utf-8"))
        sys.stdout.flush()


def main(argv: list[str]) -> int:
    if not argv or argv[0] in ("all", "--all"):
        _emit("athena")
        _emit("nerv")
    elif argv[0] in ("athena", "nerv"):
        _emit(argv[0])
    else:
        _emit("athena")
        _emit("nerv")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
