---
name: resolving-merge-conflicts
description: Resolve an in-progress Git merge or rebase conflict by reconstructing both sides' intent, preserving unrelated work, validating the result, and safely continuing when authorized. Use only when Git reports unresolved merge or rebase conflicts.
---

# Resolving Merge Conflicts

1. Inspect `git status`, the merge or rebase state, recent history, conflicting paths, staged content, and unrelated working-tree changes.
2. Trace each side to primary evidence: the conflicting commits, surrounding history, tests, specs, issues, and available PR context.
3. Resolve each hunk to preserve both intents when compatible. When intents conflict, follow the authorized merge goal and report the trade-off; do not invent unrelated behavior.
4. If evidence suggests aborting, explain why and ask the user to decide. Never run `merge --abort`, `rebase --abort`, reset, or another destructive recovery step autonomously.
5. Stage only resolved conflict paths with explicit path arguments. Never use a whole-tree add or include unrelated changes.
6. Run the smallest relevant formatting, type, build, and test checks. Inspect `git diff --check`, the remaining unmerged paths, and the staged diff before continuing.
7. Continue the merge or rebase only when completing the active operation is within the user's request. During a rebase, handle later conflicts one commit at a time.

Do not create an extra commit, amend unrelated history, push, or clean the worktree unless the user separately requests it or the already-authorized Git operation strictly requires it.

Report resolved files, intent decisions, checks run, remaining conflicts, preserved unrelated changes, and whether the operation was continued.
