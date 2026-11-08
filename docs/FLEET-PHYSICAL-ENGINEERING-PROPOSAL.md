# Whole-fleet physical engineering proposal

Status: NEW proposed engineering assumptions, awaiting Root disposition. These are not recovered ship measurements, source material properties, accepted geometry, an activation authority or a completed fleet. No areas, scales, mass totals or inertia tensors have been evaluated. The companion JSON names all 171 exact contracts and source references, including unresolved assumptions. Independent resource and runtime coding continues.

## Existing per-ID authority

Keep SH026's adopted 25,545 kg Harrier budget from manifest `31d4c1e8edd28aef71274be8668e7ee669f054bcd8a4743aae0fd54acec7e042`. Preserve the later bare geometry and bridges; the earlier FIRST's 23,741 kg subtotal is superseded. The selected station records retain SH141 2,000,000 kg and SH034/SH102 12,000,000 kg each from adopted `4add9de4cbe21a7ba4b5b266af8ee607ecce199556912172080e440eb36a4c42`. These estimates supply no sibling masses. The separate C01 cradle supplies no fleet-hull mass. Preserve later geometry corrections and actual current resource pins; historical whole resource images are never overlay authority.

## Scale proposal

For the 27 baseline runtime routes, retain the independently selected per-ID calibration; do not replace it with an R3 layout target. For 60 unconnected records explicitly handed off in metres, retain scale one and the authored origin, axes and proportions. Also retain the two adopted SH008/SH009 detailed-only calibrations (10000000/1028273 and 30000000/3186991 metres/source unit), which confer no native qualification. For the other 82 unconnected records, propose a NEW per-ID authoring rule `S = R3 target length / detailed source Z span`, with exact source and R3 SHA pins. This uniform scale is a proposed design choice, not discovered units. Do not force width/height independently, centre the mesh or close openings. An absent/zero Z span, later calibration or inconsistent axis/unit declaration stops that source; no alternative dimension or display normalization is substituted.

Each source still needs structural/cockpit/support/void review and a native representation at no more than 512 faces. A scale rule certifies no material or empty channel. Preserve detailed/source materials, UVs and retained parts. Bare-hull preview ammunition and role-kit parts need explicit per-ID declarations. Do not remove geometry because of palette colour or a generic family assumption. No further SH008 union experiments are proposed.

## Material-area and hardware proposal

Reuse the form of the adopted Harrier budget as NEW choices for other hulls: structural opaque stock 14 kg/m2 and explicit glazing stock 5 kg/m2. These are authored areal stock budgets, not real material density/thickness claims. A source-owned component/face role table must identify each counted structural/glazing part and every excluded preview item. Unknown roles stay unresolved. Composition and structural roles cannot come from RGB, family, cargo, price, bounding-box volume or predecessor resemblance.

Evaluate area only from explicitly named original detailed triangles in approved metre coordinates. Overlapping assembly skins count as separately fabricated component stock, as in the Harrier model; this is not a solid-union volume estimate. Shared/duplicate face references need explicit accounting. Sparse instrumentation receives no arbitrary skin/hardware mass. All source parts and retained voids remain in the fidelity review.

Proposed intrinsic hardware for ships/capsules is itemized in every JSON row: 900 kg per explicitly mapped intrinsic drive mechanism; one 750 kg electrical plant; one 180 kg empty tank/plumbing assembly when a fuel tank is specified; 120 kg of empty life-support/quarters hardware per R3 intrinsic crew place; one 90 kg control/sensor assembly; one 140 kg empty equipment interface when an equipment budget is specified; one 160 kg empty launcher assembly when missile capacity is specified. Drive count and position need an actual per-ID role map; there is no two-engine default. These are proposed empty intrinsic mechanisms, never paid equipment, people, cabin modules, fuel, missiles or role kit. Autonomous/Larvaal internals need explicit authored declarations; human biology is not inferred.

Stations/platforms without performance/accommodation specifications retain an existing adopted budget where available. Otherwise propose the same stock-area procedure, with service, weapon, habitat and drive mechanism counts/masses unissued until the object-specific contract names them. SH162 likewise needs its native probe mechanism declaration. These rows remain unresolved; no ship fallback mass is proposed.

## Centre of mass and inertia

After Root adoption, integrate each triangle's uniform areal mass and full second moment about the unmodified source origin. Add hardware at explicitly declared original assembly anchors. Anchor placement is a new design decision, not an AABB-centre substitute. Retain the centre-of-mass offset and full symmetric tensor. Use the parallel-axis theorem for the runtime mass frame, without re-centring renderer/collision vertices or filling openings with a solid box/convex proxy. Do not drop off-diagonal terms for convenience.

The proposed dry-mass budget rounds up once to a kilogram, with the less-than-one-kilogram reserve explicitly placed at the calculated centre of mass. Retain unrounded stock/hardware totals and reserve separately so scalar mass and tensor agree. Check finite positive total mass, symmetry, positive principal moments and exact per-ID source/unit bindings before use. Loaded mass, people, fuel, carried modules, ammunition and cargo remain actual independent inventories; capacity is never loaded mass.

## Disposition and implementation boundary

Root owns this one batch proposal. Adoption would authorize bounded per-ID source-area/anchor calculations and physical record implementation, without waiving native cap, fidelity, scale, fitting, acquisition, collision, save or gameplay gates. Freeze exact source/role-map pins and operation caps before calculation. This proposal starts no geometry query, compiler, renderer, native helper or tests. Missing role maps, mechanism declarations and conflicting calibrations remain explicit per-ID blockers while other coding proceeds.
