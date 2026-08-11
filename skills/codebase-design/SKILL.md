---
name: codebase-design
description: Design or compare interfaces, seams, adapters, and module boundaries for a selected part of a codebase. Use when the public contract, test surface, dependency direction, or alternative designs remain unresolved; do not use for codebase-wide architecture scans or straightforward implementation of an already settled design.
---

# Codebase Design

Design a deep module: substantial behavior behind a small, explicit interface at a clean seam.

## Vocabulary

- **Interface**: everything callers must know, including inputs, invariants, ordering, errors, configuration, and performance.
- **Depth**: useful behavior gained per unit of interface callers must learn.
- **Seam**: a boundary where behavior genuinely needs to vary without editing callers.
- **Adapter**: a concrete implementation of a seam.
- **Locality**: keeping related knowledge, change, bugs, and verification in one module.

## Workflow

1. Read applicable repository instructions, the governing spec, relevant ADRs, callers, and current tests.
2. State the caller-visible behavior and constraints before proposing types or abstractions.
3. Define the smallest interface that fully expresses those needs, including error and timing behavior callers must handle.
4. Place seams only where variation is real. Accept dependencies at the boundary instead of constructing remote or replaceable dependencies internally.
5. Classify dependencies before choosing adapters. Read [references/deepening.md](references/deepening.md) when consolidating shallow modules or crossing I/O, process, or network boundaries.
6. Treat the public interface as the primary test surface; keep implementation details private.
7. When alternatives matter, read [references/design-it-twice.md](references/design-it-twice.md) and compare materially different contracts.
8. Recommend one design. State the contract, dependency strategy, migration path, leverage, locality, trade-offs, and unresolved risks.

## Guardrails

- Apply the deletion test: if removing a module only removes indirection, it is shallow; if complexity spreads into callers, it earns its place.
- Do not add a seam for a hypothetical future implementation. Require justified variation.
- Prefer fewer entry points and simpler parameters, but never hide constraints callers must understand.
- If the design is settled and the user asks for implementation, hand off to normal implementation or `$tdd` when test-first work is explicitly desired.
