#!/usr/bin/env python3
"""Check mirrored tutorial documentation before CI can start a Swift build."""

import argparse
from pathlib import Path
import sys

DOCS_README = Path("docs/mission-packs/l337-navigation-trade/README.md")
BUNDLED_README = Path("Sources/L337Core/Resources/ScriptPacks/l337-navigation-trade/README.md")


class ReadmeParityError(ValueError):
    """The original three-file Swift parity test would reject the README copies."""


def check_readme_parity(repo_root: Path) -> None:
    copies = []
    for relative in (DOCS_README, BUNDLED_README):
        try:
            copies.append((repo_root / relative).read_bytes())
        except OSError as error:
            raise ReadmeParityError(f"Cannot read tutorial README {relative}: {error}") from error
    if copies[0] != copies[1]:
        raise ReadmeParityError(
            f"Tutorial README copies differ: {DOCS_README} and {BUNDLED_README}. "
            "Keep their complete bytes identical, including documentation links."
        )


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path(__file__).resolve().parents[2])
    args = parser.parse_args(argv)
    try:
        check_readme_parity(args.repo_root)
    except ReadmeParityError as error:
        print(error, file=sys.stderr)
        return 1
    print("Navigation/trade tutorial README copies are byte-identical.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
