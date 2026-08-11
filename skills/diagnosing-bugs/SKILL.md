---
name: diagnosing-bugs
description: Diagnose failures with unknown causes, hard-to-reproduce or flaky behavior, and performance regressions through reproducible evidence and falsifiable hypotheses. Use when the root cause is unknown; stop at diagnosis unless repair is explicitly requested, and use $tdd only after the behavior or cause is verified.
---

# Diagnosing Bugs

Default to diagnosis, not repair. Finish with a reproduced symptom, verified cause, evidence, uncertainty, and the smallest recommended fix.

Read applicable repository instructions, relevant specs, ADRs, history, and nearby tests before forming conclusions.

## Protect evidence

Redact credentials, tokens, cookies, authorization headers, personal data, and sensitive payloads from commands and artifacts. Keep credentials in their configured stores or environment variables. If redaction removes evidence needed to continue, request the smallest safe substitute.

## Build the feedback loop

Read [references/feedback-loops.md](references/feedback-loops.md) and choose the smallest safe loop that exercises the exact symptom. Record at least one command actually run and its redacted signal.

Require the loop to be:

- red-capable: it asserts the reported wrong outcome, not merely a crash;
- repeatable: deterministic or measured over enough samples for a flaky failure;
- fast enough for repeated hypothesis tests;
- agent-runnable, except for an explicitly structured human step.

If no safe loop is possible, report what was tried and request the minimum missing access or artifact. Treat static analysis as provisional evidence, never a verified cause.

## Reproduce and minimize

Confirm the observed failure matches the report. Remove inputs, steps, configuration, and dependencies one at a time, rerunning after each change. Stop when every remaining element is load-bearing. For flakes, record sample count and reproduction rate.

## Test falsifiable hypotheses

1. Generate three to five ranked hypotheses from current evidence.
2. For each, name an observation or controlled perturbation that would support or reject it.
3. Test one variable at a time. Prefer debugger or REPL inspection, then narrowly tagged instrumentation.
4. For performance regressions, establish a repeatable timing, profile, trace, or query-plan baseline before changing code.
5. Reject hypotheses contradicted by results and update the ranking.

Never log everything indiscriminately or expose secrets through temporary instrumentation. Obtain approval before changing production observability.

## Establish the cause

Verify that the leading hypothesis predicts the symptom and that a controlled change affects the loop in the predicted direction. Then rerun the original, unminimized scenario.

Report the reproduction command, minimized case, verified causal chain, evidence, remaining uncertainty, recommended fix, and regression seam. Do not call a single passing run a fix.

## Repair only when authorized

If repair is explicitly in scope, use `$tdd` at the verified public seam: convert the minimized case into a failing regression test, apply the smallest fix, and rerun both the regression and original loop. If no honest public seam exists, use `$codebase-design` before adding an implementation-coupled test.

Remove only temporary artifacts created during this diagnosis and confirmed disposable. Preserve user-owned and unrelated changes.
