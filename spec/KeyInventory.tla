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
    view,       \* the inventory each proposer last read (may be stale)
    plans,      \* open plans
    doubt,      \* copies whose state is in doubt after an unknown result
    nPlans,     \* number of plans submitted so far
    finalized   \* terminal destruction has happened

vars == <<actual, inv, log, view, plans, doubt, nPlans, finalized>>

Ops == {"create", "destroy"}
PlanStates == {"pending", "confirmed", "unknown"}

Plan == [id : Nat, base : SUBSET Copies, target : SUBSET Copies,
         op : Ops, copy : Copies, state : PlanStates]

Apply(s, op, c) == IF op = "create" THEN s \cup {c} ELSE s \ {c}

Frozen == doubt # {}

TypeOK ==
    /\ actual \subseteq Copies
    /\ inv \subseteq Copies
    /\ view \in [Proposers -> SUBSET Copies]
    /\ plans \subseteq Plan
    /\ doubt \subseteq Copies
    /\ nPlans \in Nat
    /\ finalized \in BOOLEAN

Init ==
    /\ actual = InitialCopies
    /\ inv = InitialCopies
    /\ log = << [base |-> {}, new |-> InitialCopies, kind |-> "create-key"] >>
    /\ view = [p \in Proposers |-> InitialCopies]
    /\ plans = {}
    /\ doubt = {}
    /\ nPlans = 0
    /\ finalized = FALSE

(* A proposer reads the current inventory. *)
Read(p) ==
    /\ ~finalized
    /\ view' = [view EXCEPT ![p] = inv]
    /\ UNCHANGED <<actual, inv, log, plans, doubt, nPlans, finalized>>

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
    /\ plans' = plans \ {pl}
    /\ UNCHANGED <<view, doubt, nPlans, finalized>>

ExecuteFailed(pl) ==
    /\ pl \in plans
    /\ pl.state = "confirmed"
    /\ ~Frozen
    /\ plans' = plans \ {pl}
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
    /\ UNCHANGED <<view, plans, doubt, nPlans>>

Next ==
    \/ \E p \in Proposers : Read(p)
    \/ \E p \in Proposers, op \in Ops, c \in Copies : Submit(p, op, c)
    \/ \E pl \in plans :
          Confirm(pl) \/ ExecuteSucceeded(pl) \/ ExecuteFailed(pl)
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

(* Action property: the inventory changes only through a successful      *)
(* result, a reconciliation or the terminal step, each logged as it       *)
(* happens.                                                               *)
InventoryChangesOnlyWhenLogged ==
    [][inv' # inv =>
         /\ Len(log') = Len(log) + 1
         /\ log'[Len(log')].kind \in {"succeeded", "reconcile", "terminal"}
         /\ log'[Len(log')].new = inv']_vars

=============================================================================
