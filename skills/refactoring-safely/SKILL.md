---
name: refactoring-safely
description: Restructure existing code while preserving caller-visible behavior through explicit invariants, a green baseline, small reversible steps, and continuous verification. Use for behavior-preserving refactors, module moves, renames, extractions, or broad mechanical cleanup; do not use when behavior should change, the defect cause is unknown, or a cross-version public contract must migrate.
---

# Refactoring Safely

Preserve observable behavior while improving internal structure. Treat “no behavior change” as a claim that requires evidence.

## Fix the preservation boundary

1. Read repository instructions, relevant specs and ADRs, callers, tests, and the requested refactor scope. Inspect the worktree and record pre-existing changes, especially overlaps with target files.
2. Build an impact graph from definitions to callers, tests, configuration, reflection, generated artifacts, and external formats; use it to order migration waves and expose independent paths.
3. State what must remain unchanged: public inputs and outputs, errors, side effects, ordering, persistence, wire formats, timing guarantees, and supported compatibility where applicable.
4. Record intended structural changes separately. If the request mixes behavioral and structural changes, split them into independently verifiable phases.
5. Use `$codebase-design` first when the target boundary or interface is unresolved. Use `$evolving-contracts` when old and new contract versions must coexist.

## Establish proof

Run the smallest relevant existing checks before editing and record the baseline. A failing baseline is not green; isolate the failure or obtain an explicit comparison basis before attributing later results.

Read [references/preservation-evidence.md](references/preservation-evidence.md) when tests are sparse, outputs are large, or the change is mechanical across many callers. Add characterization coverage only for important observable behavior not already protected. Do not freeze accidental internals merely to make the refactor feel safer.

## Change in reversible steps

Give each migration wave a pinned baseline context capsule, exclusive paths, and completion command. Read-only impact discovery may run in parallel. Writes may fan out only over disjoint paths; a single writer owns each shared boundary, generated artifact, and final integration. Old-path deletion, global preservation proof, and Git operations remain serial. After every wave, create a preservation checkpoint. If the input, baseline, impact graph, or evidence changes, stop the current wave immediately, re-pin them, and revalidate affected work before resuming.

1. Make one coherent structural transformation at a time.
2. Keep the tree runnable whenever the language and migration shape permit it. Prefer compiler- or tool-assisted moves and renames over blind text replacement.
3. Run the focused proof after every step. Inspect the diff for behavior edits, widened scope, generated noise, and unintended public-contract changes.
4. Revert or correct only edits created by the current step when evidence changes unexpectedly; never reset or check out pre-existing work, and do not stack more edits on an unexplained failure.
5. Remove obsolete paths only after all callers and checks use the replacement.

Never weaken assertions, update expected outputs, or change public behavior merely to obtain green. If an apparent behavior change is actually required, stop the refactor boundary and obtain an authoritative requirement; use `$tdd` for the separately approved behavior slice.

## Verify the whole claim

Run focused tests, relevant static checks, and the broadest safe project checks proportionate to the blast radius. Compare externally meaningful artifacts before and after when tests alone cannot prove preservation.

Report the preserved invariants, baseline, structural transformations, evidence after each phase, final checks, and any behavior not covered by proof.
