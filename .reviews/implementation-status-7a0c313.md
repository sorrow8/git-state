# Implementation status at main `7a0c313`

This is the baseline for automatic follow-up checks. Re-evaluate these findings against each later `main` snapshot and cite the implementation evidence.

| Finding | Status at `7a0c313` | Evidence / remaining work |
| --- | --- | --- |
| `f22f863`: an unconfirmed plan can remain open forever if confirmation is refused or never arrives | FIXED | `ed006a0` adds signed rejection, proposer withdrawal, and expiry entries; the model closes an unconfirmed plan. |
| `654a3f9`: the model did not record plan, confirmation, failure, or unknown events in its protocol history | FIXED | `c41b768` models these in `events` and documents the distinction between the full event history and the inventory chain. |
| `ed006a0`: the model did not cover the confirmation deadline | PARTIAL | `7a0c313` adds deadline and expiry transitions. The `7a0c313-follow-up` review remains open: the model still treats operation start and result recording as one atomic step. |
| `7a0c313-follow-up`: distinguish operation start from result recording so an operation started before the deadline may finish afterward | OPEN | `spec/KeyInventory.tla` gates `ExecuteSucceeded`/`ExecuteUnknown` and checks result-event order; there is no separate in-flight/start state. |