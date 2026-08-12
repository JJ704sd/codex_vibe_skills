---
name: diagnosing-bugs
description: Diagnose unknown failures, flaky behavior, and performance regressions, or optimize a measured bottleneck with a known workload and objective. Use for reproducible evidence, falsifiable hypotheses, profiling, and controlled experiments; default to diagnosis unless repair or optimization is explicitly requested.
---

# Diagnosing Bugs and Performance

For unknown causes, finish with a reproduced symptom, verified cause, evidence, uncertainty, and smallest recommendation. Optimize only from a representative measured baseline.

Read repository instructions, relevant specs, ADRs, history, and nearby tests before forming conclusions.

## Protect evidence

Redact credentials, tokens, cookies, authorization headers, personal data, and sensitive payloads. Keep credentials in configured stores. Request the smallest safe substitute when redaction removes required evidence.

## Build the feedback loop

Read [references/feedback-loops.md](references/feedback-loops.md) and choose the smallest safe loop that exercises the exact symptom or target workload. Record a runnable command and redacted signal.

Require the loop to be red-capable, repeatable, fast enough for experiments, and agent-runnable except for an explicit human step. For flakes, record sample count and reproduction rate. Treat static analysis as provisional when no safe loop exists.

## Reproduce and test hypotheses

1. Confirm the observation matches the report; minimize inputs, steps, configuration, and dependencies one at a time.
2. Generate three to five ranked hypotheses and name an observation or perturbation that would support or reject each.
3. Test one variable at a time. Prefer debugger, REPL, profile, trace, or query-plan evidence before narrow instrumentation.
4. Reject contradicted hypotheses and update the ranking.
5. Verify that the leading cause predicts the result, then rerun the original unminimized scenario.

Never log indiscriminately or expose secrets. Obtain approval before changing production observability.

## Optimize measured bottlenecks

When the workload and objective are known and optimization is requested, read [references/performance.md](references/performance.md). Establish a comparable distribution, profile the limiting resource, change one variable, and compare the same workload before and after.

Run repeated or worst-case workloads in a controlled local or test environment. Require separate approval, bounded load, and stop conditions before production profiling, load, or side effects. Reject changes within noise or with unacceptable correctness, security, durability, or resource trade-offs.

## Repair and report

If repair is explicitly in scope, use `$tdd` at the verified public seam. If no honest seam exists, use `$codebase-design`. Treat caches, batching, concurrency, retries, and approximations as semantic changes unless their behavior is specified.

Report the reproduction or workload, environment, baseline, causal or profile evidence, experiments, checks, result distribution when applicable, remaining uncertainty, and residual risk. Remove only confirmed-disposable temporary artifacts created during this work.
