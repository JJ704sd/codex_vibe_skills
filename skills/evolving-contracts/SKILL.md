---
name: evolving-contracts
description: Evolve APIs, events, schemas, persisted data, configuration, dependencies, frameworks, runtimes, or toolchains through explicit compatibility evidence and bounded transitions. Use when versions or representations must change while producers, consumers, data, or build environments may differ; do not use for purely internal refactors or an undecided target contract.
---

# Evolving Contracts and Dependencies

Move a live contract or external dependency from one valid state to another without assuming every consumer, record, or environment changes atomically.

## Define the change

1. Read repository instructions, governing contracts, manifests, lockfiles, deployment topology, supported versions, ownership, and recovery expectations.
2. Inventory readers, writers, validators, persisted forms, generated clients, manifests, workspace overrides, runtime constraints, CI/container versions, and repository-used dependency APIs as applicable.
3. Build the smallest producer-reader-storage-deployment map and compatibility matrix needed to expose incompatible states, phase gates, ownership, and recovery paths.
4. State the current and target forms or resolved versions, compatibility window, invariants, supported matrix, irreversible operations, and unrelated changes that are out of scope.
5. Use `$codebase-design` first when the target public contract remains unresolved. Use `$refactoring-safely` when no mixed-version or external compatibility boundary exists.

## Select evidence and transition

For API, schema, data, event, or configuration changes, read [references/transition-patterns.md](references/transition-patterns.md) and default to:

1. **Expand readers:** deploy readers that accept old and new forms without requiring or emitting the new form.
2. **Migrate writers:** only after supported readers are proven compatible, emit the new form and migrate or backfill in bounded, idempotent, resumable batches.
3. **Observe:** measure interoperability, migration failures, data reconciliation, and remaining legacy use.
4. **Contract:** remove the old form only after evidence proves no required reader, writer, or record depends on it.

For dependency, framework, runtime, or toolchain changes, read [references/dependency-upgrades.md](references/dependency-upgrades.md). Use exact-version official guidance, establish a frozen baseline, upgrade one dependency family or compatibility line at a time, and inspect the final resolved graph and lockfile churn.

When a delivery workflow changes, treat triggers, action and runner versions, permissions, caches, artifacts, environments, required-check names, concurrency, and rollback as compatibility contracts. Verify old and new paths across the branches, events, and in-flight releases that must coexist. A successful run proves only the exercised state.

Do not choose “latest” reflexively, rely on rollout order as compatibility proof, or assume application rollback reverses destructive data changes.

## Gate and verify every phase

Treat expand, migrate, observe, and contract as explicit phase gates. At each checkpoint record the repository revision, compatibility-matrix version, completed phase, durable batch cursor, validation results, unfinished side effects, and next gate. Before resuming, revalidate these fields. If they differ or the cursor is ambiguous, do not replay writes; return to the last verified safe boundary.

Test initial, intermediate mixed-version, and final states plus retries, partial failure, supported runtimes, packaging, integrations, and rollback or forward recovery as applicable. Keep destructive, irreversible, and production steps separately authorized, bounded, resumable where possible, and backed by a tested recovery mechanism.

Use `$tdd` for settled behavior slices. Use `$diagnosing-bugs` for unclear migration or upgrade failures. Report the compatibility matrix, authoritative evidence, sequence, manifest or data changes, recovery path, checks, contraction condition, and residual risk.
