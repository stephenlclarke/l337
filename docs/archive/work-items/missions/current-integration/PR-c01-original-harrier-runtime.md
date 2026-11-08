# Use the original SH026 hull for C01's disabled Harrier

Use the complete original Harrier native mesh for both mission rendering and collision, and read dry mass from its selected original profile. Build native NPC capacities from the same game record with zero initial shield charge/fuel and64current damaged hull energy. Generic prepared-cohort validation now distinguishes this exact disabled actor's current energy from its actual maximum; other prepared actors retain their existing full-stock guard.

Preserve native resources/velocity through the existing cohort admission and current save validators. Base recharge rates remain original; propulsion, weapons, drive, ammunition and ECM remain disabled. The original8kg recorder and the connected stage-five recovery hooks are preserved.

Validation is source-only: exact dependency hashes, native resource/profile numeric checks, scoped patch forward/inverse replay and unchanged outside tree metadata. Compiler, tests, actual actor admission/resource advancement/drawing/collision/current save, native gameplay, rendering, README media and CI are UNRUN and owned by G1. SH026 player/native mesh routing and original timing-standard prop replacement are separate remaining work; no M02/M03 completion is claimed.
