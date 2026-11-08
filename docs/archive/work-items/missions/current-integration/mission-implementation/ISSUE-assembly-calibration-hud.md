# Keep Assembly calibration readable and explicitly unqualified in the cockpit

The owned instrument has an immutable last-measurement readout, but the future cockpit hook needs concise, consistent text. It must distinguish seeking, measuring, pause, ready exposure and reset without implying that an original Darik register or mission reading exists. Rounded elapsed time must not decide readiness. Long warnings should not add many rows to the existing minimum-width cockpit.

Implement a pure formatter using only the existing readout. Off contributes no lines; other phases contribute three ASCII lines within the existing minimum 20-column budget for genuine bounded instrument values. Preserve an unverified marker and explicit no-register-reading warning. No shared UI, runtime state, query or authority change. [Implementation](PR-assembly-calibration-hud.md).
