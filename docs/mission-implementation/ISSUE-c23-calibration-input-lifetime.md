# Reject queued calibration commands after their input lifetime ends

A captured Start can remain current after calibration starts or refuses an optical sample. Replaying it can reset a newer exposure. A captured Stop can also cancel a later run, including after calibration returns to the same off state.

Consume the existing input context after each handled Start or Stop, including an optical refusal. Recheck Stop before cancellation. Keep current Stop available after target or fit loss. Use the existing actor turn and input epoch; add no persistent field or measurement authority.

The reviewed source packet is `/tmp/l337-c23-calibration-input-lifetime-v2/COMMITTED-SOURCE.json`, source reference `5808ffbb4549dbf779807d83caf81b17fd8fcaba`. Its current beforeimages match the maintained files, including the newer diagnostic prefix. [Implementation and validation](PR-c23-calibration-input-lifetime.md).
