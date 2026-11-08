# M04: reserve compact showroom quote space

## Problem and result

A selected Redtail or Besra can show three price and review rows. The final row overlaps the browse heading at compact sizes. Move only the narrow list down by sixteen logical pixels. Its existing model placement and click targets follow the same layout; wide columns retain their positions.

## Implementation

Change ShowroomLayout in ShowroomDisplay.swift and add one ShowroomComparisonUnitTests regression. The regression examines actual rendered price, balance, review and heading rectangles for both M04 hulls across four widths, three heights and two cash balances. It checks that rendering preserves commander property. Register it in the maintained isolated selection and update the count from 569 to 570.

Update the README's current qualification status. Keep older source-only statements in the completion ledger as history and append the actual main result and interactive failure.

## Validation

The original main branch passed both full 3,455-case runs (3,449 passes and six declared skips each), main-only Sonar and leak checks. Those results qualify the original main source, not this correction. This proposal has no compiler or test execution yet. The new regression, 570-test selection and corrected GUI remain UNRUN. Static format, whitespace and source-composition results are recorded in the adjacent immutable manifest.

## Compatibility and limits

No save format, equipment, hull data, credits, ownership, discovery, purchase rule or resource guard changes. No release, media regeneration or later source-queue overlay. Full-screen, flight, docking and physical trackpad acceptance remain pending.

See [the reported problem](ISSUE-m04-compact-showroom-quote.md).

## Native result and regression cost

PR299 native validation on the exact merge execution passed: 3,456 unique cases, 3,450 passes, six declared skips and no failures or errors. Coverage was 116,355 of 128,477 lines (90.56%); the lifecycle and zero-leak checks passed. The separate hosted isolated run reported 570 passes. These results apply to the original correction only; they do not qualify this test optimization or the next hull batch.

The new 48-scenario showroom regression passed but took 1,358.9215 seconds. The optimized source calls the same trade-row and heading label emitters used by the actual showroom screen, with one fresh fixture copied per scenario. It retains all widths, heights, both hulls, both cash balances, actual font bounds, quote decisions and commander immutability. It avoids preview meshes, specification rows and unrelated screen content. The source does not establish which old call dominated runtime. The focused timing and original-position failure/restored-position pass checks are pending.
