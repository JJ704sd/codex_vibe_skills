---
name: evolving-contracts
description: Evolve APIs, events, schemas, persisted data, configuration, dependencies, frameworks, runtimes, toolchains, or CI/CD workflows through explicit compatibility evidence and bounded transitions. Use when versions or representations must change while producers, consumers, data, build environments, or delivery paths may differ; do not use for purely internal refactors or an undecided target contract.
---

# Evolving Contracts and Dependencies

Move a live contract or external dependency from one valid state to another without assuming every consumer, record, or environment changes atomically.

## Define the change

1. Read repository instructions, governing contracts, manifests, lockfiles, deployment topology, supported versions, ownership, and rollback expectations.
2. Inventory readers, writers, validators, persisted forms, generated clients, manifests, workspace overrides, runtime constraints, CI/container versions, and repository-used dependency APIs as applicable. Treat CI/CD workflows, action versions, runner images, permissions, caches, artifacts, environments, and deployment interfaces as contracts only when they change or the transition depends on them.
3. Build a producer-reader-storage-deployment dependency graph and a pinned compatibility matrix. Use them to identify phase gates, ownership, recovery paths, and safe batches.
4. State the current and target forms or resolved versions, compatibility window, invariants, supported matrix, irreversible operations, and unrelated changes that are out of scope.
5. Use `$codebase-design` first when the target public contract remains unresolved. Use `$refactoring-safely` when no mixed-version or external compatibility boundary exists.

## Select evidence and transition

For API, schema, data, event, or configuration changes, read [references/transition-patterns.md](references/transition-patterns.md) and default to:

1. **Expand readers:** deploy readers that accept old and new forms without requiring or emitting the new form.
2. **Migrate writers:** only after supported readers are proven compatible, emit the new form and migrate or backfill in bounded, idempotent, resumable batches. Use a versioned contract or adapter when old readers reject it.
3. **Observe:** measure interoperability, migration failures, data reconciliation, and remaining legacy use.
4. **Contract:** remove the old form only after evidence proves no required reader, writer, or record depends on it.

For dependency, framework, runtime, or toolchain changes, read [references/dependency-upgrades.md](references/dependency-upgrades.md). Use exact-version official guidance, establish a frozen baseline, upgrade one dependency family or compatibility line at a time, and inspect the final resolved graph and lockfile churn.

For delivery changes, and only then, record how old and new workflow paths coexist across branches, forks, reruns, environments, and in-flight releases. Pin third-party actions to reviewed immutable revisions; preserve least-privilege permissions, secret isolation, artifact provenance, required-check names and branch-protection expectations, environment approvals, concurrency semantics, and rollback or forward recovery. A successful workflow run proves only the exercised matrix cell, not compatibility of every state.

When the change affects Git or delivery authentication, treat execution identities, credential stores and helpers, secret injection, repository ownership, and runner authentication as contracts. Prove old and new contexts separately without copying tokens or weakening ACLs. Make any credential-store migration or global configuration change a separately authorized phase with explicit rollback; a process-local command exception is not evidence that every context migrated.

Do not choose “latest” reflexively, rely on rollout order as compatibility proof, or assume application rollback reverses destructive data changes.

Treat expand, migrate, observe, and contract as explicit phase gates and safe checkpoints. Parallelize same-matrix read checks or authorized write batches only within one unlocked current frontier when saved critical-path time exceeds dispatch, rereading, and fan-in cost; writes must be disjoint and bounded, idempotent, and resumable. Authoritative writes, contraction, recovery decisions, shared data, and Git state remain serial under one owner. Before an irreversible or production action, stop with an approval capsule naming evidence, impact, recovery, budget, and next action.

At each checkpoint record the repository revision and compatibility-matrix version, completed phase, durable batch cursor, validation results, unfinished side effects, and next gate. Before resume, revalidate every field against current state. If they differ or the cursor is ambiguous, do not replay writes; return to the last verified safe boundary and choose an authorized recovery path.

## Verify every state

Test initial, intermediate mixed-version, and final states plus retries, partial failure, supported runtimes, packaging, integrations, and rollback or forward recovery as applicable. Keep destructive steps separately authorized and backed by a tested recovery mechanism.

Use `$tdd` for settled behavior slices. Use `$diagnosing-bugs` for unclear migration or upgrade failures. Report the compatibility matrix, authoritative evidence, sequence, manifest/data changes, recovery path, checks, contraction condition, and residual risk.
