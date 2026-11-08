# C06 needs two distinct ordinary market transactions

C06's original offer requires two completed ordinary sales. The replacement baseline `b3e3e0d1ed8731f8a9aa27dbb6bb9fe60b34361e` retains only its first sale. Cargo quantity cannot establish the number of transactions: one automatic sale of two tonnes is one operation. Repeated review, an empty hold or a replayed operation must not supply the second sale.

The earlier frozen sales implementation used namespaces that the current Newt kit now owns. Importing those shared afterimages would overwrite newer save, native and mission work. Rebind only the sales producer, immutable second record, history consumer and current publication/read checks. Preserve all existing Newt, watcher, first-trade and inquiry semantics.

Success means the ordinary market's actual balances and two distinct operations survive current save/load together. A failed writer must preserve the live commander, market, world and prior files. A restored writer can commit the same user action once. No Rakenor receiver, disabled drone, recovered ledger, issued consent, commission, payment, clue or mission completion follows from this prerequisite.
