"""Load the frozen pre-R3 showroom input for historical authoring-tool tests."""

from pathlib import Path
import tomllib
from zipfile import ZipFile


CATALOGUE = Path(__file__).resolve().parents[2] / "Tests/Fixtures/pre-r3-showroom-catalogue.zip"
SHIP_PATH = "Sources/EliteCore/Resources/Ships/"


def ship_bytes(identity):
    with ZipFile(CATALOGUE) as archive:
        return archive.read(f"{SHIP_PATH}{identity}.toml")


def read_ships():
    with ZipFile(CATALOGUE) as archive:
        names = sorted(
            name for name in archive.namelist()
            if name.startswith(SHIP_PATH) and name.endswith(".toml")
        )
        return [tomllib.loads(archive.read(name).decode()) for name in names]
