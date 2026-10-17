# Decision logs: technical specification

This document specifies the decision logs described in the [README](../README.md#decision-logs): who can see what, how the logs resist tampering and omission, how personal data is protected, and how records are retained and deleted.

A law's real runtime is how it is applied, so the logs cover decisions made under a law, not just its text.

## 1. Openness and exceptions

### Layers

| Layer | What is recorded | Who can see it |
| --- | --- | --- |
| Law and configuration | Every change as a diff, signed by a named official, with a public rationale and an effective date | Everyone |
| Decisions about individuals | The decision, the legal basis, the responsible official and who accessed the data | The person concerned sees their own records; the public sees aggregate statistics; courts and auditors have access under law |
| Restricted material (security, ongoing investigations, sensitive criteria) | The fact that an exception exists, its legal basis, who approved it and when it will be reviewed | An independent oversight body is notified immediately and receives the content. The public notice follows as soon as it is safe (§1.3) |

### 1.1 No secret law

An unpublished annex can't create obligations for citizens and can't be the basis for sanctions against them. Operational details may be restricted, but the legal basis, people's rights and people's obligations are always public.

### 1.2 Exceptions

Every exception needs a named legal basis, an approving authority, independent review and periodic public reporting.

When an exception expires, its content is **reviewed for release**. It is released unless a fresh, reasoned assessment shows that disclosure would harm people or an investigation, and that assessment is itself recorded. An exception that keeps getting renewed should be visible as exactly that.

### 1.3 When the existence of an exception is itself sensitive

Even announcing that an exception exists can sometimes reveal an ongoing investigation or operation. So the public notice is published immediately only when that is safe. Otherwise:
- the independent oversight body is notified immediately, with the legal basis, the approving authority and the content;
- the public notice is deferred, and the oversight body reviews the deferral on a fixed schedule; a deferral that is not renewed lapses, and the notice is published;
- aggregate figures (how many deferred notices each agency holds, and for how long) are published regularly, so the use of deferrals stays visible without exposing any single case.

## 2. Integrity and completeness

Hash chains and public anchoring prove only that **already recorded** entries haven't been changed afterwards. They can't detect a missing event, a false entry or a substitution made before recording. Each threat needs its own control:

| Threat | Control |
| --- | --- |
| An entry is changed after recording | Append-only log; hashes anchored publicly and mirrored by independent parties |
| An event is never recorded | **A missing record counts against the state, never against the person.** An unrecorded decision that burdens someone is presumed irregular: the burden of proof is on the authority, and the person gets a fast route to challenge it, with enforcement suspended meanwhile (§2.2). An unrecorded decision in someone's favor (a benefit, a permit, urgent help) still stands. Sequence numbers make gaps visible, but only if they are assigned at the right moment (§2.1) |
| The logging system fails | A defined emergency procedure: decisions are made and documented offline, urgent help is never delayed because the log is unavailable, and records are added within a fixed deadline with a note on the outage. Outages are reported publicly |
| A false or wrong entry | Every entry is signed by a named official; independent monitors and auditors reconcile logs with other registers and with what affected people received |
| An entry is substituted before recording | The affected party gets a signed receipt that must match the public log, the same idea as Certificate Transparency's signed timestamps |
| Errors | Corrections are added as new linked entries; history is never rewritten |

### 2.1 Where sequence numbers come from

A number assigned when an entry is added to the log can't reveal an event that was never added: the event is simply skipped before numbering, and no gap appears. So:
- the number is assigned and signed **when the decision is issued**, by the system that issues it, and it is printed on the decision and on the person's receipt. A decision document without a number is itself visible evidence of a fault;
- the counter's state is periodically countersigned and anchored by an independent party, so it can't be quietly reset or forked;
- auditors reconcile the numbered sequence against evidence held outside the register: payments made, letters sent, court filings and receipts held by the people concerned. An event that left traces outside but has no number shows up as a gap.

### 2.2 Interim protection while a missing record is challenged

Once a person challenges a burdensome decision that has no record, enforcement stops automatically until the challenge is decided: no collection, no penalties, no sanctions. The authority can't lift the suspension itself. Only a court can order interim enforcement, and only to prevent imminent serious harm. The remedy is free and simple, and the authority must produce the record within a fixed deadline. If it doesn't, the decision is annulled and anything already collected is refunded.

The idea comes from the Robodebt Royal Commission's [recommendation 18.1](https://robodebt.royalcommission.gov.au/publications/report), which is narrower. It covers debt recovery only, and it applies subject to any express legal authority to the contrary: recovery action should not begin or continue while a debt is being reviewed or disputed. This concept deliberately extends the principle to any burdensome decision with a missing record, and allows exceptions only by court order.

## 3. Privacy and verification

### 3.1 Commitments

**Personal data never goes into a publicly replicated immutable log.** The data itself stays in registers that have retention periods, so lawful deletion remains possible. A public hash can still leak data: a plain hash of an ID number, a date of birth or any value from a small set can be reversed by trying every possible input, and the same hash appearing in two logs links them. So the public layer follows these rules:
- no plain hashes of identifiers or low-entropy values;
- each record is committed with its own long random salt, and **the salt is never published**. A salt published next to its hash protects nothing, because guessing works again. A secret per-record salt also means identical inputs don't produce identical outputs, so records can't be linked across logs;
- where possible, only aggregate commitments are published (for example, Merkle roots of batches), not per-record hashes;
- the commitment scheme has its own written threat model (guessing, linking across logs, salt or key leakage) and an independent review.

A keyed hash (for example, an HMAC whose key stays with the register) is used, if at all, only as an internal index for lookups. It is never the public commitment, because an outside auditor couldn't check it without the key.

### 3.2 Who can verify what

Secret salts mean the public can't check the *contents* of a record. Verification is split by role:
- **Anyone** can check the integrity of the log itself: it is append-only, sequence numbers have no gaps, and published roots are consistent with earlier ones (as in Certificate Transparency monitoring).
- **The person concerned** receives their record together with its salt and an inclusion proof as part of their receipt. They can recompute the commitment and confirm that exactly this record is in the public log.
- **Authorized auditors and courts** get the record and its salt from the register under their legal access powers, and verify them the same way. During the retention period, a register that can't produce a matching record and salt for a commitment is itself evidence of a fault.

## 4. Retention and deletion

### 4.1 Deletion entries

When the retention period ends, the record and its salt are deleted, and the register appends a signed deletion entry to the log: which commitment, when it was deleted and on what legal basis. From then on **the register** can no longer open the commitment, and that is expected. The person concerned may still hold their receipt with the record and salt, and can still open the commitment themselves, for example as evidence in a later dispute. That is their right: the duty to delete binds the state, not the person. A missing record with no deletion entry, or a deletion before the retention period ends, remains evidence of a fault.

### 4.2 Proving the deletion was allowed

A deletion entry signed only by the register is just the register's own claim, so it doesn't prove that the period really ended. Two safeguards back it up:
- **The deadline is fixed at creation.** When the record is first committed, its retention deadline (a date and the rule it comes from, which is non-personal metadata) goes into the public log with it. Anyone can then check that a routine deletion entry came no earlier than that deadline, without seeing the record.
- **Independent countersignature before destruction.** Any deletion that doesn't follow the original deadline (an early erasure ordered by a court, a changed retention rule, a correction) must be checked and countersigned by an independent party, such as the data protection authority or an auditor, *before* the record and salt are destroyed. The deletion entry carries both signatures. A register can't destroy data early on its own authority.

### 4.3 Proving the deletion happened

Permission to delete isn't proof of deletion, especially with backups. Each record and its salt are stored encrypted under their own key. Deletion means destroying that key (cryptographic erase: [NIST definition](https://csrc.nist.gov/glossary/term/cryptographic_erase), [NIST SP 800-88 Rev. 2](https://csrc.nist.gov/pubs/sp/800/88/r2/final)). Encrypted copies may physically remain in storage and backups, but without the key, decrypting them becomes practically infeasible. The claim is "the key is destroyed and the copies can't be decrypted", not "the record and salt no longer exist anywhere".

| What | Checked for | How |
| --- | --- | --- |
| Every enrolled copy of the record's key was destroyed | **Every record** | Keys live only in hardware key stores and can't be exported. When a key is created, the register records the identifiers of all its copies (the primary, replicas and key backups) as the key's copy inventory. At deletion, each device holding a copy signs the destruction of that copy, and the receipt lists every copy ID from the inventory. The independent oversight body checks automatically that the receipt covers the whole inventory, and appends a signed confirmation to the log. What is public and what isn't is set out below the table |
| No copy of the key exists outside its inventory | The key-management system as a whole | A signature proves where a receipt came from, not that the hardware listed every copy. So auditors independently check the key stores' configuration and replication logs for any path that could create an unenrolled copy, and reconcile the devices' own logs against the inventories |
| No plaintext copy of the record or salt exists outside the encrypted store | **A sample** of storage and backup systems | Independent auditors search sampled systems for plaintext copies. A sample gives reasonable assurance, not proof for every copy, and the report says so |

**Copy identifiers are not public.** Copy IDs, device identities and the full receipts would reveal how the key stores and replication are laid out, so they never go into the public log. Only these do:
- a salted commitment to each key's copy inventory, made when the key is created, so the inventory can't be changed afterwards without detection;
- a salted commitment to each destruction receipt;
- the oversight body's signed confirmation that the receipt covers the committed inventory.

**What the confirmation is bound to.** The oversight body signs a statement that names, together, the log identifier of the deletion entry, the inventory commitment and the receipt commitment, plus the result of the check. Because the signature covers all three, the confirmation can't be reused for a different deletion, and an auditor can see exactly which public entries it vouches for.

**Who holds the salts.** The salts behind the inventory and receipt commitments are never published, just like record salts (§3.1). The register keeps them alongside the full inventories and receipts and hands them to the oversight body and auditors together with those documents. Those bodies recompute the commitments and check them against the public log. A register that can't produce matching salts and documents for a commitment is evidence of a fault, the same rule as in §3.2.

**How long these are kept, and who can access them.** Inventories, receipts and their salts describe key infrastructure, not people, so keeping them after the record itself is deleted doesn't undo that deletion. They are audit evidence, kept only as long as they can still be needed:
- **Retention:** tied to the deletion's audit cohort (§4.4), because most deletions are never sampled and "audited" alone would never happen for them. The materials of every deletion in a cohort are kept until that cohort's audit is completed *and* the period in which a deletion can be challenged has ended. For deletions that were sampled, materials are also kept until any findings about them are closed. The exact period is set by law per register (a placeholder to fix in a pilot), and it is committed to the log when the key is created, the same way as the record's own deadline (§4.2).
- **Access during retention:** only the oversight body, auditors and courts, for a stated purpose. Every access is itself logged: who, when and why. The material is never released to the public.
- **At the end:** the materials are destroyed by a **terminal procedure** that creates no new materials to retain, so the cycle stops here instead of repeating for every level of evidence (see below).

**The terminal procedure.** Audit materials are not stored item by item under their own keys, which would need their own inventories and audits. Instead, all materials of one cohort sit in a single container encrypted under a **cohort key**. When the cohort's retention ends:
1. the cohort key is destroyed in the hardware key store, in the presence of the oversight body (it witnesses the destruction directly instead of checking an inventory afterwards);
2. the oversight body appends one signed statement to the log, bound to the cohort identifier, a commitment to the cohort key's copy inventory and the destruction result;
3. nothing else is kept. The destroyed key has no further inventory, receipt or audit, and the encrypted container can't be decrypted.

**What stays in the log permanently, and what goes:**

| Stays permanently (public, no personal data) | Removed, with no further audit cycle |
| --- | --- |
| Record commitments and deletion entries | Records, record salts and record keys (§4.1–4.3) |
| Inventory and receipt commitments for record keys | Full inventories, receipts and their salts (when the cohort key is destroyed) |
| Oversight confirmations of coverage (§4.3) | The cohort container's contents |
| Signed cohort audit reports (§4.4) | — |
| The oversight body's witnessed destruction statement for each cohort key | — |

Everything that stays is a commitment, signature or report. None of it reveals personal data or the layout of the key infrastructure, so it doesn't need deleting, and it remains the permanent evidence that each check took place.

### 4.4 What every deletion gets, and how audits run

Every deletion gets the same automatic minimum: the register's signed deletion entry, a destruction receipt covering every enrolled copy of the key, and a check of its date against the committed deadline.

Audits are **periodic and sample-based**, not run on every deletion. Deletions are grouped into **audit cohorts**: all deletions made within one audit period. For each cohort, independent auditors examine a random sample of its deletions and of the storage and backup systems, and append a signed report to the log. The report names the cohort, lists the deletions and systems it covered, and gives the method and the findings, so anyone can see which deletions were audited and which were not. A cohort's audit counts as completed when its report is in the log, even though most of its deletions weren't sampled.

The extra **prior** independent countersignature (§4.2) applies only to deletions outside the original deadline. A routine deletion doesn't need one, because anyone can check its date against the deadline committed when the record was created.
