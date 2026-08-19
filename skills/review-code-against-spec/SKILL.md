---
name: review-code-against-spec
description: Review a branch, pull request, commit range, or working-tree diff against repository standards and an originating specification as independent axes. Use when the user asks whether a fixed change set is compliant and complete; report findings without modifying code unless fixes are separately requested.
---

# Review Code Against Spec

Review one pinned change set independently for **Standards** and **Spec**. Findings must be introduced by the reviewed changes and supported by actionable evidence.

## Pin the change set

Honor a user-supplied base, range, PR, or commit. Otherwise infer only when unambiguous and state the assumption.

- **Branch or PR**: compare from the merge base to the review head, such as `git diff <base>...HEAD`.
- **Commit or explicit range**: review exactly that commit or range.
- **Working tree**: use `git diff HEAD --` for tracked staged and unstaged changes, inspect `git status --short`, and include every relevant untracked file explicitly.

Capture the effective endpoints, commit context when applicable, changed-file list, and raw patch. Stop clearly if the reference is invalid or the effective change set is empty. Ask before proceeding only when competing bases materially change the review.

## Find governing sources

Find the spec in this order:

1. a path, issue, PR, or acceptance criteria supplied by the user;
2. references in the reviewed commits or branch context;
3. matching files under conventional documentation or spec directories;
4. nearby approved tickets or behavior tests.

If no authoritative spec exists, run only the Standards axis and label the Spec axis `No spec available`.

Collect applicable repository rules, including root and nested `AGENTS.md`, contribution guides, coding standards, and tool configuration. Repository rules override the fallback [code-smell baseline](references/code-smells.md). Treat fallback smells as judgment calls, not hard violations.

Build a small requirements-to-files-and-checks map when it helps expose omissions. If the diff changes delivery workflows, inspect triggers, action revisions, permissions, artifacts, required-check names, and check results for the pinned head. Green CI is supporting evidence, not proof of Spec completeness or unexercised deployment safety.

## Review independently

Perform two separate passes over the same raw change set so one conclusion does not anchor the other.

### Standards pass

- Find correctness, security, data-loss, concurrency, compatibility, maintainability, and documented-rule problems introduced by the change.
- Cite the governing rule when one exists; otherwise explain the concrete cost of a heuristic concern.
- Ignore unrelated pre-existing problems and suppress style nits already enforced by tooling.

### Spec pass

- Find missing or partial requirements, incorrect implemented behavior, and unrequested scope.
- Cite the exact requirement, acceptance criterion, or approved behavior for every finding.
- Do not reinterpret an ambiguous spec as a definite defect; surface the ambiguity separately.

## Report findings first

Keep `## Standards` and `## Spec` separate. For each actionable finding include severity, a tight file/line or hunk location, evidence, impact, and the smallest correction. State explicitly when an axis has no findings or no source.

End with finding count and highest severity per axis plus residual verification gaps. Do not merge the axes into one score, and do not modify code, rerun remote checks, approve, merge, or deploy unless separately requested.
