# SH026 original native mesh routing

The complete original Harrier record and C01 actor can use the authored native mesh, but player, raw mesh cache and generated salvage paths still fall through to preview geometry. Add onlySH026 to the existing strict original hull routing pattern and require the actual Harrier/family/nativeDesign record at load.

This is geometry routing. The existing generic100000kg player collision mass is a separate unresolved loaded-mass policy/data gap. The authored25545kg Harrier dry budget is not a loaded-player mass and must not replace missing fuel, people, equipment or cargo terms.
