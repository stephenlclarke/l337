# Decimal80 source-moment method for SH061 and SH122

Status: source-method proposal only. The code has not been imported, compiled, executed, or tested. One source-method review and a new exact Root scope disposition are required before a single authoring pass. The earlier Float64 results and both STOP records remain immutable. No earlier successful record is recomputed.

The proposed change is the arithmetic representation, not a changed source, tolerance, material role, omitted component, geometric approximation, or native admission rule. Saiga retains its separately approved 20 metres per source unit. SH122 retains declared metres at scale 1. Every source face, exact named material assignment, hardware count, source origin and +Z/+Y axis remains the same. The exact role semantics are checked against the two frozen parent maps before geometry is read.

## Arithmetic and input semantics

TOML floating literals stay strings during parsing. Each detailed coordinate token converts directly to `Decimal`; integers convert directly from integers. No source coordinate passes through Float64. Fixed precision is 80 significant decimal digits with `ROUND_HALF_EVEN`, exponent limits -999999 and 999999, capitals 1 and clamp 0. There is no precision search, escalation, alternate rounding attempt or retry.

Invalid operations, division by zero, overflow, underflow, subnormal results, clamping and accidental Decimal/float mixing trap and stop that row. Rounded and inexact flags are permitted and recorded: irrational triangle areas normally require rounding. A square root is evaluated once per source face from the nonnegative sum of squared cross-product components. A nonpositive or nonfinite area stops the row; no face is silently dropped. Positive component area, mass and finite moments are required before any centroid division.

The supplied source coordinates are scaled only by the already adopted 1 or 20 for engineering integration. Source files and their vertices, materials, textures, UVs, licences, topology and origin are never written or transformed. There is no span, bounding-volume, native query or geometry search.

## Independent moments in the original frame

For vertices a, b, c and triangle stock mass m, let s = a + b + c. The analytic first moment is m s / 3. Each analytic second-moment entry is

```text
m * (s_i*s_j + a_i*a_j + b_i*b_j + c_i*c_j) / 12
```

The quadrature implementation separately constructs these three points directly from the corners:

```text
(4a+b+c)/6, (a+4b+c)/6, (a+b+4c)/6
```

Each point receives weight m/3. This code receives no analytic sums or first/second-moment arrays. It independently accumulates mass, first moments and all nine second moments.

The rule integrates degree-two polynomials: its average barycentric coordinate is 1/3, average squared barycentric coordinate is (16+1+1)/108 = 1/6, and average product of distinct barycentric coordinates is (4+4+1)/108 = 1/12. These are the uniform triangle moments and yield the analytic formula above. The two implementations are thus independently expressed polynomial evaluations, not a copied verification array.

Every component compares mass, three first moments and nine second moments **in the original source frame**, before Float64 conversion, with the unchanged criterion:

```text
abs(analytic - quadrature) <= 1e-9 * max(1, abs(analytic), abs(quadrature))
```

There is no local-origin comparison, condition-number padding, increased near-zero allowance, diagonal-only comparison or manufactured equality. The method records both actual moment arrays and their maximum absolute difference. It can detect formula, sample-position, index, weighting and accumulation inconsistencies. Both calculations share the area and input coordinates, so agreement does not independently certify area, source correctness, native fidelity or collision geometry. Decimal80 is not interval arithmetic and supplies no measurement or rigorous uncertainty certificate.

## Assembly, reserve and Float64 output

Named intrinsic mechanisms remain point allocations at the exact component area centroid. They add to mass and original-origin first/second moments. The complete symmetric nine-entry tensor is formed by the standard trace-minus-second-moment relation and parallel-axis translation to the actual centre of mass. Finite values, symmetry under the same criterion and positive leading principal minors are required.

Exactly one ceiling to kilograms is performed on the Decimal mass. The reserve is placed at COM, which changes translational mass without changing COM inertia. The stored source-origin inertia remains explicitly before the reserve, matching the existing schema.

Only the finished record crosses to Float64. Every conversion must be finite and is counted. The bridge refuses if the Decimal ceiling differs from `ceil(Float64 mass)`, if the integer dry mass is not exactly representable, if the converted reserve leaves [0,1), or if the existing scalar, symmetry, parallel-axis or positive-definiteness checks fail. It never clamps, pads, uses nextafter, changes the reserve, replaces a tensor or reruns at another precision. Exact decimal audit strings remain alongside the schema's Float64 values.

## Frozen work and execution boundary

The input FIRST covers only SH061 and SH122: 2 source parses, 27,840 coordinate conversions and fixed-scale evaluations, 17,872 face/area/analytic evaluations and square roots, 53,616 owned-index checks and quadrature samples, 2,275 component moment comparisons, 15 hardware allocations, 5,374 output Float64 conversions and 2 output attempts. Per-row caps, byte limits and exact source hashes are frozen separately. Whole-face and coordinate bounds are not increased from their existing source inventories. Extra constant-size tensor and representation checks have explicit counters.

The script requires an authority-FIRST argument that pins the reviewed method/code/input and Root disposition before reading geometry. This is an auditable process guard, not a cryptographic authorization capability. It refuses existing output directories or result files, writes only a new output namespace, and retains actual failures as STOP records. No native, compiler, renderer, source creator, external helper, geometry probe or test framework is invoked.

Any future successful output would still be an authored empty-hull engineering estimate. It would establish neither occupied/loaded inertia nor people, cabins, paid equipment, population, acquisition, native 512-face compliance, void/collision qualification or game acceptance. Saiga's separate 1,720-face source blocker remains.
