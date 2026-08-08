#!/usr/bin/env python3
"""release.py — Athena deterministic ZIP builder.

Usage:
  python3 scripts/release.py --version 1.0.0 --out dist/athena-v1.0.0.zip

The output is byte-identical across runs:
  - Fixed file order (sorted)
  - Fixed timestamps (1980-01-01 00:00:00)
  - Fixed permissions (preserved from disk)
  - No UUIDs, no random salts
  - Same compression level for same content

This lets operators verify the ZIP against a published SHA-256.

Exit codes:
  0  success
  1  source dir not found
  2  output zip creation failed
"""

from __future__ import annotations

import argparse
import hashlib
import os
import sys
import zipfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
BANNERS_DIR = REPO_ROOT / "banners"


def print_banner() -> None:
    """Print the Athena + NERV banner. Pure cosmetics. Writes to stderr
    so stdout stays clean for piping."""
    for name in ("athena", "nerv"):
        path = BANNERS_DIR / f"{name}.ascii"
        if path.exists():
            try:
                sys.stderr.write(path.read_text(encoding="utf-8"))
            except OSError:
                pass
    sys.stderr.flush()

# Files to exclude from the release ZIP
EXCLUDE_PATTERNS = (
    ".git/",
    ".venv/",
    "__pycache__/",
    "*.pyc",
    ".pytest_cache/",
    "build/",
    "dist/",
    "*.egg-info/",
    ".DS_Store",
    ".coverage",
    "htmlcov/",
    "test/runs/",  # local test logs are not part of the release
)


def should_exclude(p: Path) -> bool:
    s = str(p)
    return any(pat in s for pat in EXCLUDE_PATTERNS)


def iter_files(root: Path):
    """Yield Path objects in sorted order."""
    for p in sorted(root.rglob("*")):
        if p.is_file() and not should_exclude(p.relative_to(root)):
            yield p


def main() -> int:
    print_banner()
    ap = argparse.ArgumentParser(description="Athena deterministic ZIP builder")
    ap.add_argument("--version", required=True, help="Release version (e.g. 1.0.0)")
    ap.add_argument("--out", required=True, type=Path, help="Output ZIP path")
    ap.add_argument("--source", default=REPO_ROOT, type=Path,
                    help="Source directory (default: repo root)")
    args = ap.parse_args()

    src = args.source.resolve()
    if not src.is_dir():
        print(f"ERROR: source dir not found: {src}", file=sys.stderr)
        return 1

    out = args.out.resolve()
    out.parent.mkdir(parents=True, exist_ok=True)

    # Fixed datetime for determinism
    fixed_dt = (1980, 1, 1, 0, 0, 0)

    files = list(iter_files(src))
    print(f"Adding {len(files)} files to {out}")

    with zipfile.ZipFile(out, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
        for p in files:
            arcname = p.relative_to(src).as_posix()
            info = zipfile.ZipInfo(filename=arcname, date_time=fixed_dt)
            info.compress_type = zipfile.ZIP_DEFLATED
            # External attrs: preserve file mode bits
            st = p.stat()
            info.external_attr = (st.st_mode & 0xFFFF) << 16
            with p.open("rb") as f:
                zf.writestr(info, f.read(), compresslevel=9)

    # Compute SHA-256 of the output for downstream verification
    digest = hashlib.sha256()
    with out.open("rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            digest.update(chunk)
    sha = digest.hexdigest()
    print(f"OK: {out} ({out.stat().st_size} bytes, SHA-256: {sha})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
