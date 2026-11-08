# Give the Assembly calibration instrument explicit player controls

The original Assembly optical acquisition and exposure window have no owned start/cancel driver or player readout. A future UI needs a bounded operation that captures the actual pre-motion sample, consumes its post-motion callback once and clears unfinished work on cancellation or a new runtime epoch. Reading a display cannot supply elapsed time or advance the mission.

Implement this controller without installing shared actor storage, tick or UI hooks. Show surface calibration and its last measured elapsed time. State that the original register is not authenticated and no register reading has been recorded. The source/consent join and qualified mission survey remain separate. [Implementation](PR-assembly-survey-controls.md).
