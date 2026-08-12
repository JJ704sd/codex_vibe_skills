# Preservation Evidence

Use the least coupled evidence that can detect a caller-visible change.

## Evidence ladder

1. Existing behavior tests at a stable public seam.
2. Type checking, compilation, linters, and repository-specific structural checks.
3. Focused characterization tests for important but undocumented current behavior.
4. Golden or snapshot comparison for reviewed, stable external formats.
5. Differential execution of old and new implementations over representative inputs.
6. Property checks for invariants that should hold across broad input ranges.
7. Recorded query plans, API fixtures, serialized data, or CLI output when these are part of the preservation boundary.

Do not treat line coverage, a clean compile, or a single happy-path example as proof of semantic equivalence.

## Wide mechanical changes

Prefer an expand-move-contract sequence:

1. Introduce the new internal form without deleting the old path.
2. Move callers in small compilable batches.
3. Search independently for remaining references, including configuration, reflection, generated code, and tests.
4. Delete the old form only after the search and verification suite agree it is unused.

For language-aware renames, inspect tool output and version-control moves. For text replacement, constrain file types and identifiers, preview matches, and inspect every semantic category of replacement.

## Characterization limits

Capture behavior a real caller relies on, including errors and side effects. Avoid asserting private method calls, incidental formatting, nondeterministic values, or known defects unless an authoritative compatibility requirement protects them. Label uncertain observations rather than silently turning them into permanent contracts.
