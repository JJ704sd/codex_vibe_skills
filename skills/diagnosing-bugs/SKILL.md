---
name: diagnosing-bugs
description: Diagnose failures with unknown causes, flaky or environment-dependent behavior, CI failures, and measured performance regressions through reproducible evidence and falsifiable hypotheses. Use when the cause is unknown; stop at diagnosis unless repair or optimization is explicitly requested.
---

# Diagnosing Bugs and Performance

Default to diagnosis, not repair. Finish with a reproduced symptom, verified cause, evidence, uncertainty, and the smallest recommendation. Optimize only from a representative measured baseline.

Read applicable repository instructions, relevant specs, ADRs, history, and nearby tests before forming conclusions.

## Protect evidence

Redact credentials, tokens, cookies, authorization headers, personal data, and sensitive payloads from commands and artifacts. Keep credentials in their configured stores. Request the smallest safe substitute when redaction removes evidence needed to continue.

## Establish the feedback loop

Reuse an existing exact loop only after confirming it still matches the pinned revision and environment and remains repeatable, safe, and authorized. Otherwise, or for a flake, human step, or substitute reproduction, read [references/feedback-loops.md](references/feedback-loops.md) and choose the smallest safe loop. Record the command or workload and its redacted signal.

Require the loop to be red-capable, repeatable, fast enough for experiments, and agent-runnable except for an explicit human step. For flakes, record sample count and reproduction rate. Treat static analysis as provisional when no safe loop exists.

For a known workload and performance objective, read [references/performance.md](references/performance.md). Establish a comparable distribution and profile the limiting resource before changing code.

For Git or GitHub behavior that differs across Windows identities, sandboxes, services, or elevated processes, read [references/windows-github-credentials.md](references/windows-github-credentials.md) and run [scripts/Test-WindowsGitHubAuthContext.ps1](scripts/Test-WindowsGitHubAuthContext.ps1) in each relevant context. Distinguish an invalid repository or missing executable from an authentication result, and an authentication failure from a credential-visibility boundary.

For a reported or evidenced CI failure, pin the workflow revision, run and attempt, commit SHA, event, job, runner, timestamps, and relevant matrix cell. Start from redacted logs and the exact workflow revision, then distinguish code failure from workflow, permission, secret, runner, cache, artifact, environment, or provider failure. Log inspection and local reproduction are read-only; rerun, cancel, approve, repair, push, or deploy are separate mutations.

## Reproduce and test hypotheses

1. Confirm the observation matches the report; minimize inputs, steps, configuration, and dependencies one at a time.
2. Generate three to five ranked hypotheses and name an observation or perturbation that would support or reject each.
3. Test one variable at a time. Prefer debugger, REPL, profile, trace, or query-plan evidence before narrow instrumentation.
4. Reject contradicted hypotheses and update the ranking.
5. Verify that the leading cause predicts the result, then rerun the original unminimized scenario.

A workaround, retry, or symptom disappearance is not causal evidence by itself. Never log indiscriminately or expose secrets. Obtain approval before changing production observability or applying production load. If two consecutive experiment rounds add no evidence or repeat the same action and error, stop and redesign the loop or request the smallest missing input; exhausting a budget is not a diagnosis.

## Repair, optimize, and report

If repair is explicitly in scope, use `$tdd` at the verified public seam. If no honest seam exists, use `$codebase-design`. Treat caches, batching, concurrency, retries, and approximations as semantic changes unless their behavior is specified.

For optimization, compare the same workload before and after, reject changes within noise, and preserve correctness, security, durability, and acceptable resource use.

Report the reproduction or workload, environment, baseline, causal or profile evidence, experiments, checks, result distribution when applicable, remaining uncertainty, and residual risk. Remove only confirmed-disposable temporary artifacts created during this work.
