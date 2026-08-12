---
name: tdd
description: Implement known behavior or a verified bug fix through a stable public seam using red-green-refactor. Use when the user explicitly requests TDD or test-first work, or when a verified regression must be locked down before repair; use $diagnosing-bugs while the cause, workload, or expected behavior remains unknown.
---

# Test-Driven Development

Deliver one caller-observable behavior at a time through a stable public seam.

Read applicable repository instructions, the governing spec, relevant ADRs, and existing test conventions before editing.

## Establish the seam

Identify the interface through which a real caller observes the behavior. Derive it from the spec and codebase when clear; ask only when a different seam would materially change scope or architecture.

Use `$codebase-design` first when the interface itself is unresolved. Do not test private methods or internal collaborators merely because they are convenient.

## Plan behavior slices

Build a small behavior-slice graph from acceptance criteria to public seams, focused red commands, affected paths, and cross-slice dependencies. Keep one writer for the same public seam. Fan out only current-frontier slices with no cross-slice dependency that can demonstrate an independent red and have disjoint write sets, test state, and side effects; otherwise keep them serial. Parallelize only when critical-path savings exceed coordination cost. Give each worker a context capsule with objective/slice; pinned baseline; dependencies/constraints; allowed reads/writes/side effects; commands/evidence; budget/stop; and risks. Each worker completes one slice at a time through red-green-refactor. At fan-in, one integrator inspects the combined diff and creates a green checkpoint with the cross-slice checks before opening the next frontier.

## Repeat red-green-refactor

For one vertical behavior slice at a time:

1. **Red**: write the smallest behavior test and run it. Confirm it fails because the requested behavior is absent or wrong—not because of syntax, configuration, environment, or an unrelated baseline failure.
2. **Green**: implement only enough production code to pass the new test. Run the focused test again.
3. **Refactor**: improve names, duplication, and structure without changing behavior. Keep the relevant tests green after each change.

Do not write the entire test suite first or implement layer by layer. Let each completed slice inform the next.
Do not enter green without the intended red. Stop or route to `$codebase-design` or `$diagnosing-bugs` when another attempt would repeat the same failure without new evidence.

## Keep tests honest

- Assert outcomes callers care about, not private state, call counts, or internal order.
- Derive expected values from the spec, a worked example, or another independent source—not the implementation under test.
- Prefer real in-process collaborators and realistic local stand-ins.
- Replace only true external boundaries or nondeterministic sources such as time and randomness.
- Avoid speculative cases and abstractions beyond the current behavior.

Read [references/tests.md](references/tests.md) when evaluating a test seam, expectation, or boundary substitute.

If the task is explicitly behavior-preserving restructuring rather than new behavior, use `$refactoring-safely` for the preservation proof instead of inventing a red state.

## Verify and report

Run the focused test on every cycle. Regularly run the smallest relevant test group plus applicable static checks. At completion, run broader safe project checks in proportion to the change.

Only when repository CI exists and the behavior or requested change depends on it, map the focused and broad local commands to the repository CI jobs and required checks without making CI the inner development loop. A CI-only failure after push is not the first red: reproduce it locally or in an authorized equivalent environment before changing behavior. Record which checks are local equivalents and which remain remote-only. Commit, push, PR creation, rerun, merge, and deployment remain separate authorized actions; a green loop grants none of them.

Report the seam, behaviors added, red evidence, checks run, and residual risk. Do not claim TDD if the test never demonstrated the intended red state.
