---------------------------- MODULE KeyInventory ----------------------------
(***************************************************************************)
(* Model of the key copy inventory protocol in docs/logging-spec.md, §4.3. *)
(*                                                                         *)
(* One key, a bounded set of copies, several proposers that may race to   *)
(* submit plans, results succeeded / failed / unknown, crashes that leave  *)
(* the physical state unknown, reconciliation, and the terminal           *)
(* destruction of every copy.                                              *)
(*                                                                         *)
(* `actual` is the ground truth: which copies physically exist. The log   *)
(* and the inventory are what the protocol knows. The invariants check    *)
(* that the two never drift apart in a dangerous way.                     *)
(***************************************************************************)
EXTENDS Naturals, Sequences, FiniteSets

CONSTANTS
    Copies,                 \* possible copy identifiers
    InitialCopies,          \* copies that exist when the key is created
    Proposers,              \* parties that may submit plans concurrently
    MaxPlans,               \* bound on the number of plans, to keep the model finite
    EnforceSingleOpenPlan   \* TRUE = the protocol rule; FALSE = the rule switched off

ASSUME InitialCopies \subseteq Copies /\ InitialCopies # {}
ASSUME MaxPlans \in Nat
ASSUME EnforceSingleOpenPlan \in BOOLEAN

VARIABLES
    actual,     \* copies that physically exist in key stores
    inv,        \* the current inventory according to the log
    log,        \* inventory chain: sequence of [base, new, kind]
    events,     \* protocol event history: sequence of [kind, id]
    view,       \* the inventory each proposer last read (may be stale)
    plans,      \* open plans
    doubt,      \* copies whose state is in doubt after an unknown result
    nPlans,     \* number of plans submitted so far
    finalized   \* terminal destruction has happened

vars == <<actual, inv, log, events, view, plans, doubt, nPlans, finalized>>

Ops == {"create", "destroy"}
PlanStates == {"pending", "confirmed", "unknown"}
EventKinds == {"plan", "confirm", "closed-unconfirmed",
               "succeeded", "failed", "unknown", "reconcile"}
ResultKinds == {"succeeded", "failed", "unknown"}
\* Ways a plan can end: a key-store result, or closure before confirmation.
OutcomeKinds == ResultKinds \cup {"closed-unconfirmed"}

Event(k, id) == [kind |-> k, id |-> id]

Plan == [id : Nat, base : SUBSET Copies, target : SUBSET Copies,
         op : Ops, copy : Copies, state : PlanStates]

Apply(s, op, c) == IF op = "create" THEN s \cup {c} ELSE s \ {c}

Frozen == doubt # {}

TypeOK ==
    /\ actual \subseteq Copies
    /\ inv \subseteq Copies
    /\ events \in Seq([kind : EventKinds, id : Nat])
    /\ view \in [Proposers -> SUBSET Copies]
    /\ plans \subseteq Plan
    /\ doubt \subseteq Copies
    /\ nPlans \in Nat
    /\ finalized \in BOOLEAN

Init ==
    /\ actual = InitialCopies
    /\ inv = InitialCopies
    /\ log = << [base |-> {}, new |-> InitialCopies, kind |-> "create-key"] >>
    /\ events = << >>
    /\ view = [p \in Proposers |-> InitialCopies]
    /\ plans = {}
    /\ doubt = {}
    /\ nPlans = 0
    /\ finalized = FALSE

(* A proposer reads the current inventory. *)
Read(p) ==
    /\ ~finalized
    /\ view' = [view EXCEPT ![p] = inv]
    /\ UNCHANGED <<actual, inv, log, events, plans, doubt, nPlans, finalized>>

(* Steps 1-3: a plan entry is accepted by the log only if it starts from  *)
(* the current inventory, the key is not frozen and (with the rule on)    *)
(* no other plan is open. A stale view is simply rejected.                *)
Submit(p, op, c) ==
    /\ ~finalized
    /\ nPlans < MaxPlans
    /\ IF op = "create" THEN c \notin view[p] ELSE c \in view[p]
    /\ view[p] = inv
    /\ ~Frozen
    /\ EnforceSingleOpenPlan => plans = {}
    /\ plans' = plans \cup
         {[id |-> nPlans, base |-> view[p], target |-> Apply(view[p], op, c),
           op |-> op, copy |-> c, state |-> "pending"]}
    /\ events' = Append(events, Event("plan", nPlans))
    /\ nPlans' = nPlans + 1
    /\ UNCHANGED <<actual, inv, log, view, doubt, finalized>>

(* The oversight body confirms a plan after checking the same conditions. *)
Confirm(pl) ==
    /\ pl \in plans
    /\ pl.state = "pending"
    /\ pl.base = inv
    /\ ~Frozen
    /\ EnforceSingleOpenPlan => plans = {pl}
    /\ plans' = (plans \ {pl}) \cup {[pl EXCEPT !.state = "confirmed"]}
    /\ events' = Append(events, Event("confirm", pl.id))
    /\ UNCHANGED <<actual, inv, log, view, doubt, nPlans, finalized>>

(* A plan that is never confirmed is closed without changing anything:   *)
(* the oversight body rejects it, the proposer withdraws it, or it        *)
(* expires. All three have the same effect, so the model has one action. *)
CloseUnconfirmed(pl) ==
    /\ pl \in plans
    /\ pl.state = "pending"
    /\ plans' = plans \ {pl}
    /\ events' = Append(events, Event("closed-unconfirmed", pl.id))
    /\ UNCHANGED <<actual, inv, log, view, doubt, nPlans, finalized>>

(* Steps 4-5: the key store acts only on a confirmed plan, then records   *)
(* a signed result. The inventory changes only on success.                *)
ExecuteSucceeded(pl) ==
    /\ pl \in plans
    /\ pl.state = "confirmed"
    /\ ~Frozen
    /\ actual' = Apply(actual, pl.op, pl.copy)
    /\ inv' = pl.target
    /\ log' = Append(log, [base |-> pl.base, new |-> pl.target, kind |-> "succeeded"])
    /\ events' = Append(events, Event("succeeded", pl.id))
    /\ plans' = plans \ {pl}
    /\ UNCHANGED <<view, doubt, nPlans, finalized>>

ExecuteFailed(pl) ==
    /\ pl \in plans
    /\ pl.state = "confirmed"
    /\ ~Frozen
    /\ plans' = plans \ {pl}
    /\ events' = Append(events, Event("failed", pl.id))
    /\ UNCHANGED <<actual, inv, log, view, doubt, nPlans, finalized>>

(* A crash mid-operation: the physical change may or may not have         *)
(* happened. The copy is marked in doubt and the key is frozen.           *)
ExecuteUnknown(pl) ==
    /\ pl \in plans
    /\ pl.state = "confirmed"
    /\ ~Frozen
    /\ \/ actual' = actual
       \/ actual' = Apply(actual, pl.op, pl.copy)
    /\ plans' = (plans \ {pl}) \cup {[pl EXCEPT !.state = "unknown"]}
    /\ doubt' = doubt \cup {pl.copy}
    /\ events' = Append(events, Event("unknown", pl.id))
    /\ UNCHANGED <<inv, log, view, nPlans, finalized>>

(* The oversight body checks the devices' actual state and records the    *)
(* true inventory, which closes the plan and unfreezes the key.           *)
Reconcile(pl) ==
    /\ pl \in plans
    /\ pl.state = "unknown"
    /\ inv' = actual
    /\ log' = Append(log, [base |-> inv, new |-> actual, kind |-> "reconcile"])
    /\ doubt' = doubt \ {pl.copy}
    /\ plans' = plans \ {pl}
    /\ events' = Append(events, Event("reconcile", pl.id))
    /\ UNCHANGED <<actual, view, nPlans, finalized>>

(* Terminal destruction: with no open plan and nothing in doubt, the      *)
(* oversight body witnesses the destruction of every copy in the          *)
(* inventory. Copies outside the inventory are not touched, because       *)
(* nobody knows about them; the invariants check that none exist.         *)
Finalize ==
    /\ ~finalized
    /\ plans = {}
    /\ ~Frozen
    /\ actual' = actual \ inv
    /\ inv' = {}
    /\ log' = Append(log, [base |-> inv, new |-> {}, kind |-> "terminal"])
    /\ finalized' = TRUE
    /\ UNCHANGED <<events, view, plans, doubt, nPlans>>

Next ==
    \/ \E p \in Proposers : Read(p)
    \/ \E p \in Proposers, op \in Ops, c \in Copies : Submit(p, op, c)
    \/ \E pl \in plans :
          Confirm(pl) \/ CloseUnconfirmed(pl)
          \/ ExecuteSucceeded(pl) \/ ExecuteFailed(pl)
          \/ ExecuteUnknown(pl) \/ Reconcile(pl)
    \/ Finalize

Spec == Init /\ [][Next]_vars

-----------------------------------------------------------------------------
(* Invariants *)

\* At most one unfinished plan per key.
AtMostOneOpenPlan == Cardinality(plans) <= 1

\* The inventory chain is a single line: every entry starts where the previous one ended.
LinearChain == \A i \in 2..Len(log) : log[i].base = log[i-1].new

\* The head of the chain is the current inventory.
HeadIsInventory == log[Len(log)].new = inv

\* Every copy that physically exists is in the inventory or explicitly in doubt.
NoUnregisteredCopy == actual \subseteq (inv \cup doubt)

\* While anything is in doubt, the only open plan is the one being reconciled.
DoubtBlocksOperations == Frozen => \A pl \in plans : pl.state = "unknown"

\* A copy whose destruction is in doubt still counts as existing.
DoubtfulDestroyStillCounted ==
    \A pl \in plans : (pl.state = "unknown" /\ pl.op = "destroy") => pl.copy \in inv

\* After terminal destruction, no copy of the key exists anywhere.
FinalizedMeansNoCopies == finalized => actual = {}

(* Event history: every plan's authorization and outcome is recorded.    *)

\* Positions in the event history of events of kind k for plan id.
At(k, id) == {i \in 1..Len(events) : events[i].kind = k /\ events[i].id = id}

\* Positions of any result event for plan id.
ResultsOf(id) == UNION {At(k, id) : k \in ResultKinds}

\* Positions of any outcome (a result or closure before confirmation) for plan id.
OutcomesOf(id) == UNION {At(k, id) : k \in OutcomeKinds}

\* Each kind of event appears at most once per plan; in particular a plan has at most one outcome.
NoDuplicateEvents ==
    \A id \in 0..(nPlans - 1) :
        /\ \A k \in EventKinds \ OutcomeKinds : Cardinality(At(k, id)) <= 1
        /\ Cardinality(OutcomesOf(id)) <= 1

\* A plan closed before confirmation was never confirmed and has no key-store result.
ClosedUnconfirmedMeansNeverConfirmed ==
    \A id \in 0..(nPlans - 1) :
        At("closed-unconfirmed", id) # {} =>
            /\ At("confirm", id) = {}
            /\ ResultsOf(id) = {}

\* Every result was preceded by the plan entry and then the oversight confirmation.
ResultHasPriorAuthorization ==
    \A id \in 0..(nPlans - 1) : \A r \in ResultsOf(id) :
        \E i \in At("plan", id), j \in At("confirm", id) : i < j /\ j < r

\* A reconciliation happens only after an unknown result for the same plan.
ReconcileFollowsUnknown ==
    \A id \in 0..(nPlans - 1) : \A r \in At("reconcile", id) :
        \E u \in At("unknown", id) : u < r

\* A plan that is no longer open has a terminal outcome on record:
\* succeeded, failed, or unknown followed by a reconciliation.
ClosedPlanHasOutcome ==
    \A id \in 0..(nPlans - 1) :
        (\A pl \in plans : pl.id # id) =>
            \/ At("succeeded", id) # {}
            \/ At("failed", id) # {}
            \/ At("closed-unconfirmed", id) # {}
            \/ At("unknown", id) # {} /\ At("reconcile", id) # {}

\* An open plan has no terminal outcome yet, so recovery can tell open from closed.
OpenPlanHasNoOutcome ==
    \A pl \in plans :
        /\ At("succeeded", pl.id) = {}
        /\ At("failed", pl.id) = {}
        /\ At("closed-unconfirmed", pl.id) = {}
        /\ At("reconcile", pl.id) = {}
        /\ (pl.state = "unknown") <=> (At("unknown", pl.id) # {})

(* Action property: the inventory changes only through a successful      *)
(* result, a reconciliation or the terminal step, each logged as it       *)
(* happens.                                                               *)
InventoryChangesOnlyWhenLogged ==
    [][inv' # inv =>
         /\ Len(log') = Len(log) + 1
         /\ log'[Len(log')].kind \in {"succeeded", "reconcile", "terminal"}
         /\ log'[Len(log')].new = inv']_vars

(* Action property: a copy is physically created or destroyed only in a   *)
(* step that records the plan's result (succeeded or unknown), or in the  *)
(* terminal step. Together with ResultHasPriorAuthorization this means    *)
(* no physical change happens without a logged, confirmed plan.           *)
PhysicalChangeOnlyWithRecordedResult ==
    [][actual' # actual =>
         \/ /\ Len(events') = Len(events) + 1
            /\ events'[Len(events')].kind \in {"succeeded", "unknown"}
         \/ ~finalized /\ finalized']_vars

=============================================================================
