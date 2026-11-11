# Under Tow suspension blocks saving its borrowed instrument

After collecting Penn's original one-tonne reference instrument, the player can make the mission pack unavailable through the normal installed-pack loader. That suspends the case. The current claim validator checks the held instrument through a resolver that requires an unsuspended mission, so it rejects the commander during saving and during cold loading with the pack unavailable.

The same issued instrument, loan obligation and occupied tonne must remain valid while the case is suspended. Actions that use the mission still require its unsuspended state. Installing the exact saved pack and resuming must recover the original case and serial without issuing another instrument. See the [change and acceptance record](PR-c24-suspended-reference-custody.md).
