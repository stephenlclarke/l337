# Pre-R3 showroom catalogue fixture

The ZIP contains the 171 ship TOMLs from commit
`e691630ccc3065748d4c02e90eed6a333da0d8b1`, before the R3 fleet replacement.
Historical authoring tests use these inputs to exercise recipe reconstruction,
geometry preservation, and texture conversion. The runtime and current fleet
checks use the installed R3 catalogue. See [NOTICE](../../NOTICE.md) for
asset attribution and terms.

Regenerate from the pinned source with
`git archive --format=zip -o Tests/Fixtures/pre-r3-showroom-catalogue.zip e691630ccc3065748d4c02e90eed6a333da0d8b1 Sources/EliteCore/Resources/Ships`.
