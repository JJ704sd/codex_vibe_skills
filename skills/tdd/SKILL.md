---
name: tdd
description: Implement known behavior or a verified bug fix through a stable public seam using red-green-refactor. Use when the user explicitly requests TDD or test-first work, or when a verified regression must be locked down before repair; use $diagnosing-bugs while the cause or expected behavior remains unknown.
---

# Test-Driven Development

Deliver one caller-observable behavior at a time through a stable public seam.

Read applicable repository instructions, the governing spec, relevant ADRs, and existing test conventions before editing.

## Establish the seam

Identify the interface through which a real caller observes the behavior. Derive it from the spec and codebase when clear; ask only when a different seam would materially change scope or architecture.

Use `$codebase-design` first when the interface itself is unresolved. Do not test private methods or internal collaborators merely because they are convenient.

## Repeat red-green-refactor

For one vertical behavior slice at a time:

1. **Red**: write the smallest behavior test and run it. Confirm it fails because the requested behavior is absent or wrong—not because of syntax, configuration, environment, or an unrelated baseline failure.
2. **Green**: implement only enough production code to pass the new test. Run the focused test again.
3. **Refactor**: improve names, duplication, and structure without changing behavior. Keep the relevant tests green after each change.

Do not write the entire test suite first or implement layer by layer. Let each completed slice inform the next.

## Keep tests honest

- Assert outcomes callers care about, not private state, call counts, or internal order.
- Derive expected values from the spec, a worked example, or another independent source—not the implementation under test.
- Prefer real in-process collaborators and realistic local stand-ins.
- Replace only true external boundaries or nondeterministic sources such as time and randomness.
- Avoid speculative cases and abstractions beyond the current behavior.

Read [references/tests.md](references/tests.md) when evaluating a test seam, expectation, or boundary substitute.

## Verify and report

Run the focused test on every cycle. Regularly run the smallest relevant test group plus applicable static checks. At completion, run broader safe project checks in proportion to the change.

Report the seam, behaviors added, red evidence, checks run, and residual risk. Do not claim TDD if the test never demonstrated the intended red state.
