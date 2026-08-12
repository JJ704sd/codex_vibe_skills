# Contract Transition Patterns

## Select by contract shape

| Change | Compatible expansion | Migration evidence | Safe contraction condition |
| --- | --- | --- | --- |
| Rename field or endpoint | Accept both; emit canonical form with an adapter or alias | Legacy-read/write telemetry and consumer inventory | Supported consumers no longer use the old name |
| Add required value | Add it as optional or defaulted first | Records and callers populated in bounded batches | Every reader tolerates it and every required record has it |
| Change representation | Dual-read; dual-write only when consistency semantics are explicit | Reconciliation between old and new forms | New form is authoritative and legacy reads are absent |
| Database column/table move | Add new storage, backfill, switch reads, then stop old writes | Row counts, checksums, error ledger, resumable cursor | Reads and writes use new storage; recovery is proven |
| Event or message evolution | Additive schema or versioned event; tolerant readers | Consumer compatibility matrix and replay fixtures | All supported consumers understand the retained version |
| Configuration change | Read old and new keys with precedence defined | Environment/config inventory and deprecation signal | Old key is absent from supported deployments |

Avoid dual-write when partial failure can silently diverge stores. Prefer one authoritative write plus derived propagation, an outbox, or an idempotent reconciler when consistency matters.

## Migration properties

- Make retries safe and progress observable.
- Bound batch size, locks, load, and transaction duration.
- Preserve an error ledger instead of skipping malformed records silently.
- Make resume position explicit and stable.
- Reconcile counts and business invariants, not only command success.
- Define whether rollback restores the old state or forward-fixes the new one.

## Compatibility questions

- Can an old reader consume new output?
- Can a new reader consume old output and existing records?
- What happens during partial deployment, retry, replay, or downgrade?
- Are unknown fields retained, ignored, or rejected?
- Do defaults preserve meaning, or only syntax?
- Which observation proves the old form is no longer required?
