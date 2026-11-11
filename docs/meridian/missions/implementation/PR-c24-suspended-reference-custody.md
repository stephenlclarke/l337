# Preserve Under Tow's original instrument through suspension

The custody validator now provides a held-reference projection that retains the existing case, serial, issue obligation, provenance, physical item and cargo-capacity checks. The current save validator uses that projection. The live resolver checks suspension before returning the same projection.

The regression obtains the original instrument through commissioning and collection, then uses the installed-pack loader to make the content unavailable. It verifies the same inventory, issue and one-tonne occupancy through the current writer, reader and runtime loader. Resuming with the content missing refuses. Installing the exact original pack and resuming restores access to the same case and instrument, while the separate collection remains unavailable.

Later Under Tow stages still require the original Allion collar sources, their permissions and signed independent load limits, a qualified test rig, named tug and crew, and actual receiving. Root routes those source dependencies and G1 owns native execution. See the [gameplay specification](../gameplay/C24-UNDER-TOW.md).

Independent source review and all five focused native cases passed on `baa1f6af806a0ac3777328bbb101f29463313704`. The cases cover the actual installed-pack suspension, save, current reader, runtime cold load and exact-pack resume, plus unchanged malformed-leaf, missing-original and writer controls. The publication retains the same Swift source and test bytes. Full CI, protected PR review and later mission acceptance remain open. See the [problem description](ISSUE-c24-suspended-reference-custody.md).
