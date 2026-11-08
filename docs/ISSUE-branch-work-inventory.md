# Branch work reference gap

Coders need exact existing branch/commit/path references before implementing a ledger packet. Squashed history and duplicate local/remote pointers made names and ancestry unreliable indicators of what was delivered.

The branch inventory records current refs, actual work, file/blob equivalence, exact added hunks, identities, dependencies and uncertainty. It preserves useful unintegrated work and separates conservative cleanup candidates from implementation status. It changes no game code or ledger state.

Acceptance: every current scoped ref has a unique tip card; every available tip has source/commit evidence; the remote-only patch is explicitly limited; the work-item index resolves commit/path/tip joins; deletion candidates carry complete-content proof and retained history. Source review is separate from native validation.
