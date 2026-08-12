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

Build a requirements-files-checks coverage map over the pinned change set. For a large review, run Standards and Spec as independent read-only workers only in the same current frontier when saved critical-path time exceeds dispatch, rereading, and fan-in cost; give both the same capsule of endpoints, raw diff, governing sources, and exclusions. At fan-in, a single report writer verifies the input is unchanged, resolves conflicting evidence from primary sources, deduplicates findings, and fills coverage gaps. A changed diff invalidates worker conclusions.

Use a risk-first review pass and iteration budget: inspect high-impact requirements, trust boundaries, shared state, and cross-file behavior before low-risk areas. Expand the review only when new evidence or a material coverage gap justifies the cost. A budget stop is not a clean review; report every unreviewed area as a residual verification gap.

## Find governing sources

Find the spec in this order:

1. a path, issue, PR, or acceptance criteria supplied by the user;
2. references in the reviewed commits or branch context;
3. matching files under conventional documentation or spec directories;
4. nearby approved tickets or behavior tests.

If no authoritative spec exists, run only the Standards axis and label the Spec axis `No spec available`.

Collect applicable repository rules, including root and nested `AGENTS.md`, contribution guides, coding standards, and tool configuration. Repository rules override the fallback [code-smell baseline](references/code-smells.md). Treat fallback smells as judgment calls, not hard violations.

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

Iterate only to gather missing evidence or close coverage-map gaps. Do not let review workers modify code, vote findings into correctness, or fragment work so narrowly that cross-file behavior is lost.

## Report findings first

Keep `## Standards` and `## Spec` separate. For each actionable finding include severity, a tight file/line or hunk location, evidence, impact, and the smallest correction. State explicitly when an axis has no findings or no source.

End with finding count and highest severity per axis plus residual verification gaps. Do not merge the axes into one score, and do not modify code unless the user separately requests fixes.
