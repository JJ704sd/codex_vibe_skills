---
name: codebase-design
description: Design or compare interfaces, seams, adapters, module boundaries, and trust boundaries for a selected part of a codebase. Use when the caller-visible contract, dependency direction, test surface, or materially different alternatives remain unresolved; do not use for codebase-wide architecture scans or implementation of an already settled design.
---

# Codebase Design

Design substantial behavior behind a small, explicit interface at a clean seam.

## Vocabulary

- **Interface**: everything callers must know, including inputs, invariants, ordering, errors, configuration, performance, and security constraints.
- **Depth**: useful behavior gained per unit of interface callers must learn.
- **Seam**: a boundary where behavior genuinely needs to vary without editing callers.
- **Adapter**: a concrete implementation of a seam.
- **Locality**: keeping related knowledge, change, bugs, and verification in one module.

## Workflow

1. Read applicable repository instructions, the governing spec, relevant ADRs, callers, tests, and deployed topology when it affects the design.
2. State caller-visible behavior and constraints before proposing types or abstractions.
3. Map only the callers, state, dependencies, and trust boundaries needed to make the decision. Keep this task-local rather than creating an unsolicited architecture artifact.
4. Define the smallest interface that fully expresses the caller's needs, including error and timing behavior callers must handle.
5. Place seams only where variation is real. Accept remote or replaceable dependencies at the boundary.
6. Read [references/deepening.md](references/deepening.md) when consolidating shallow modules or choosing an I/O, process, or network seam.
7. For authentication, authorization, secrets, untrusted input, tenant isolation, or privileged operations, read [references/security-design.md](references/security-design.md) before settling the contract.
8. Treat the public interface and approved invariants as the primary test surface; keep implementation details private.
9. When alternatives matter, read [references/design-it-twice.md](references/design-it-twice.md) and compare materially different contracts.

When the requested design includes a CI/CD workflow or release path, treat triggers, permissions, credentials, artifacts, environments, concurrency, required-check names, provenance, and rollback as part of the contract and trust model. Keep untrusted builds separate from trusted promotion. Designing the path does not authorize workflow edits, repository-setting changes, pushes, or deployments.

## Guardrails

- Apply the deletion test: if removing a module only removes indirection, it is shallow; if complexity spreads into callers, it earns its place.
- Do not add a seam or security control for hypothetical variation or an implausible attack path.
- Prefer fewer entry points and simpler parameters, but never hide constraints callers must understand.
- Use `$grilling` only when the remaining blocker is an undiscoverable judgment held by the current user.
- Use `$evolving-contracts` when old and new public, persisted, or dependency versions must coexist.
- If the design is settled and implementation is requested, use normal implementation or `$tdd` when test-first work is desired.

Recommend one design. Cover the contract, dependency strategy, migration path, leverage, locality, trade-offs, verification seams, and unresolved risks. Write a durable design document only when the user requests it and identifies or approves the destination.
