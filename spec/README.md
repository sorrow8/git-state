# TLA+ model of the key inventory protocol

`KeyInventory.tla` models the key copy inventory protocol from [docs/logging-spec.md §4.3](../docs/logging-spec.md#43-proving-the-deletion-happened): plan entries logged before an operation, signed results after it, one open plan per key, freezing on an unknown result, reconciliation, and the terminal destruction of every copy.

The model separates **ground truth** (`actual`: which copies physically exist) from **what the protocol knows** (`inv` and `log`). The invariants check that the two never drift apart in a dangerous way.

## What the model covers

- one key, a bounded set of copies (`c1`, `c2`, `c3`), starting with `c1`;
- two proposers that read the inventory and may race to submit plans, possibly from a stale view;
- plans to create or destroy a copy, confirmed by the oversight body before execution;
- results *succeeded*, *failed* and *unknown*; an unknown result means a crash in which the physical change may or may not have happened;
- reconciliation by the oversight body, which records the true inventory;
- terminal destruction of every copy in the inventory.

## Checked properties

| Property | Meaning |
| --- | --- |
| `AtMostOneOpenPlan` | A key never has more than one unfinished plan |
| `LinearChain` | Every inventory entry starts where the previous one ended; the chain never forks |
| `HeadIsInventory` | The last entry in the chain is the current inventory |
| `NoUnregisteredCopy` | Every copy that physically exists is in the inventory or explicitly in doubt |
| `DoubtBlocksOperations` | While anything is in doubt, the only open plan is the one being reconciled |
| `DoubtfulDestroyStillCounted` | A copy whose destruction is in doubt still counts as existing |
| `FinalizedMeansNoCopies` | After terminal destruction, no copy of the key exists anywhere |
| `InventoryChangesOnlyWhenLogged` (action property) | The inventory changes only through a logged success, reconciliation or terminal step |

## How to run

You need Java 11 or later and `tla2tools.jar` from the [TLA+ releases](https://github.com/tlaplus/tlaplus/releases) (checked with v1.7.4, which reports itself as TLC 2.19). From this folder:

```sh
java -cp tla2tools.jar tlc2.TLC -deadlock -workers auto -config KeyInventory.cfg KeyInventory.tla
```

`-deadlock` turns off deadlock checking. The model is bounded by `MaxPlans`, and after terminal destruction nothing can happen, so it stops by design.

**Expected result:**

```
Model checking completed. No error has been found.
195820 states generated, 85734 distinct states found, 0 states left on queue.
The depth of the complete state graph search is 23.
```

### Negative control

`KeyInventory_race.cfg` is the same model with the one-open-plan rule switched off (`EnforceSingleOpenPlan = FALSE`). It shows that the rule is needed, and that the invariants are not trivially true:

```sh
java -cp tla2tools.jar tlc2.TLC -deadlock -workers auto -config KeyInventory_race.cfg KeyInventory.tla
```

**Expected result:** `Error: Invariant LinearChain is violated.` TLC prints a five-step trace: two plans are submitted from the same inventory, both are confirmed, and both succeed, so the second result is based on an inventory that no longer exists.

## Limits of the model

TLC checks **this model of the protocol**, exhaustively, within the bounds above. It does not prove:

- **that the hardware key store enforces the rules.** The model assumes a key store never acts without a confirmed plan. A key store that bypasses its own checks is outside the model; the spec relies on the key-store audit for that;
- **anything about cryptography.** Signatures, commitments, salts and inclusion proofs are assumed to work. The model has no adversary that forges them;
- **correctness beyond the bounds.** Results hold for 3 copies, 2 proposers and up to 4 plans. Larger values are likely to behave the same way, but this run doesn't prove it;
- **liveness.** Only safety is checked: nothing bad happens. The model doesn't show that plans eventually finish or that reconciliation eventually happens;
- **the rest of the spec.** Record deletion, audit cohorts and the oversight body's own honesty are not modelled.
