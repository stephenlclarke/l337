# Use the original Bison-family native geometry throughout runtime

## Problem

SH005 Bison and SH006 Bison Mk II must use their complete original records and the same native geometry in player, catalogue actor and salvage consumers. Accepting retired records or falling back to preview geometry would leave the replacement incomplete.

## Change

The two stable original IDs select their required nativeDesign raw meshes directly. The loader always requires the exact original name for each ID, bison family and valid native geometry. It rejects retired, partial, swapped or missing-native records. Salvage reads directly from the record to avoid raw-cache recursion. Active basis labels describe the original Bison designs.

## Dependencies and validation

G4 owns both complete original resources, geometry, materials and profiles. MC1 owns meaningful fresh-game stats/mesh/loader/fitting/pending-fabrication checks and ordinary fresh save behavior where relevant. No old-save migration, inherited purchase/custody preservation or compatibility bridge is required. Normal current saving, purchases and game rules must work.

All compiler, tests, renderer, media and CI execution is UNRUN. G1 owns coherent integration and qualification. This bounded family change does not complete the full fleet or missions.
