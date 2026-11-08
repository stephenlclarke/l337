# fix(fleet): require the original Bison-family runtime records

SH005 Bison and SH006 Bison Mk II always use their actual nativeDesign raw meshes for player, catalogue actor and salvage geometry. Their loader contract always requires the correct original name, bison family and valid native geometry. Retired records and missing-native fallbacks are rejected. Salvage reads directly from the record, and active basis labels are original-only.

This simplifies four existing source hunks by removing old-record compatibility predicates. G4 owns complete original resources; MC1 owns fresh-game stats/native-geometry/loader/fitting/pending-fabrication checks. No old-save migration, historical purchase/custody preservation or compatibility framework is included; ordinary current saving, purchasing and game rules remain required.

Static forward/inverse/outside evidence is recorded in the source packet. Compiler, tests, native rendering, media and CI are UNRUN. Both actual resource records and focused regressions must join this source before G1-owned integration and qualification. No whole-fleet or mission completion is claimed.
