# Issue: launcher compilation exceeds the aggregate memory guard

## Observed failure

Actual main validation session 54785 stopped after 694.873 seconds during L337Launcher compilation. Its selected process tree used 3,224,748,032 bytes against the unchanged 3,221,225,472-byte limit. No Swift error diagnostic appeared. Discovery and tests did not start.

## Cause and scope

The eight-line launcher imports L337Mac only to await its existing MainActor async throwing main. That import introduces an additional compiler process loading the Mac/Core dependency graph. The retained sample identifies the stopped process and aggregate memory; it does not prove which compiler allocation caused the overage. Import access restrictions alone do not hide nonresilient dependencies.

## Intended correction and acceptance

Make the existing L337App the direct executable entry point and remove the redundant importing launcher target. Preserve its complete main body, all test sources and declarations, resources, dependencies and external execution settings. The changed published main must complete the same guarded build, discovery and original 198-method qualification. Existing renderer, CLI, sanitizer, leak and full CI requirements remain open until actually run. See [the source handoff](PR-54785-launcher-import-memory.md).
