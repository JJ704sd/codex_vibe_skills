---
name: codebase-design
description: Design or compare interfaces, seams, adapters, module boundaries, and security-sensitive trust boundaries for a selected part of a codebase. Use when the public contract, test surface, dependency direction, design alternatives, or security invariants remain unresolved; do not use for codebase-wide architecture scans or straightforward implementation of an already settled design.
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

1. Read repository instructions, the governing spec, relevant ADRs, callers, tests, and deployed topology when relevant.
2. Build the smallest dependency and trust-boundary graph needed to expose callers, state, replaceable dependencies, and verification seams. Use it as a task-local working map, not a permanent architecture artifact.
3. State caller-visible behavior and constraints before proposing types or abstractions.
4. Define the smallest interface that fully expresses those needs, including error and timing behavior callers must handle.
5. Place seams only where variation is real. Accept remote or replaceable dependencies at the boundary.
6. Read [references/deepening.md](references/deepening.md) when consolidating shallow modules or crossing I/O, process, or network boundaries.
7. For authentication, authorization, secrets, untrusted input, tenant isolation, privileged operations, or new exposure, read [references/security-design.md](references/security-design.md) and derive security invariants before settling the contract.
8. Treat the public interface and approved invariants as the primary test surface; keep implementation details private.
9. When alternatives matter, read [references/design-it-twice.md](references/design-it-twice.md) and compare materially different contracts.
10. Recommend one design. State the contract, dependency strategy, migration path, leverage, locality, trade-offs, verification seams, and unresolved risks.

For a consequential design, independent subagents may derive alternatives from the same context capsule: pinned evidence, caller constraints, relevant paths, permitted read/write scope, expected evidence, and stop budget. One integrator compares them against the constraints, resolves conflicts from primary evidence, and owns the durable design. Do not use majority vote or let workers concurrently edit one design draft.

## Guardrails

- Apply the deletion test: if removing a module only removes indirection, it is shallow; if complexity spreads into callers, it earns its place.
- Do not add a seam or threat control for hypothetical variation. Require concrete caller needs or plausible attack paths.
- Prefer fewer entry points and simpler parameters, but never hide constraints callers must understand.
- Freeze a constraint checkpoint before implementation. Invalidate affected alternatives when the spec, topology, trust boundary, or pinned repository input changes.
- Use `$evolving-contracts` when old and new public, persisted, or dependency versions must coexist.
- If the design is settled and implementation is requested, use normal implementation or `$tdd` when test-first work is desired.
