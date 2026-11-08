# Use the original Lion Citadel mesh and port in the game

MainStationGeometry now reads native mesh and docking port from the same complete SH028 record. Existing rendering, collision and entry consumers use that shared producer. Missing or malformed original station input fails closed; no old cube or old port fallback remains.

Decode the existing Port shape through CatalogueShip.nativeDocking and require finite orthonormal axes, positive tunnel depth and a strict convex counterclockwise planar aperture. Reject malformed ports before aperture fit; preserve final Bison/Buffalo catalogue guards exactly.

Validation is source-only: SHA/size/data checks, exact patch replay and unchanged outside metadata. Compiler, tests, attained entry/exit sweeps, supported hull/mission variants, moving/rotating docking, current fit checks, rendering, README media and CI remain UNRUN and owned by G1. This is not M02/M03 acceptance; the separate RRS-derived station paths remain unresolved.
