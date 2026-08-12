# Windows GitHub credential context

Use this procedure only when Git or GitHub CLI behavior differs across Windows execution identities or process boundaries.

## Invariants

- Treat Windows Keyring/Credential Manager entries, environment tokens, Git credential helpers, and GitHub connector sessions as separate credential channels.
- Never print, copy, export, persist, or move a token to make identities share access. Do not put credentials in a repository, command line, log, skill, or global environment variable.
- Do not change ACLs, repository ownership, global `safe.directory`, credential-helper configuration, or authentication storage during diagnosis.
- A successful GitHub connector call does not prove local `gh` or `git` authentication. A successful Administrator check does not prove the sandbox sees the same credential.
- Keep Git index/HEAD mutations and remote writes under one authorized owner. Identity comparison is read-only.

## Diagnostic loop

1. Pin the repository, exact failing command, timestamp, shell identity, executable paths, and whether the action ran in a sandbox, service, ordinary terminal, or elevated terminal.
2. Run `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Test-WindowsGitHubAuthContext.ps1 -RepositoryPath <repo>` in the failing context. This bypass is process-local and must not change the machine or user execution policy. Preserve the redacted JSON and exit status.
3. If authentication fails and another authorized context may own the credential, request approval and run the same read-only probe there once. Do not ask the user to log in again until this comparison is complete.
4. Classify the result:

   | Default context | Authorized comparison | Classification | Next action |
   | --- | --- | --- | --- |
   | authenticated | authenticated | authentication is not the blocker | reproduce the exact Git command; inspect remote, authorization, branch protection, and network separately |
   | failed | authenticated | credential-visibility boundary | run only credential-dependent network commands in the approved context; keep tests and local diff review in the sandbox |
   | failed | failed | authentication likely invalid or absent | ask the user to authenticate once in the context intended for Git network operations, then rerun both probes |
   | authenticated | failed | contexts use different stores or configuration | keep the working authenticated context; do not migrate credentials without explicit authorization |

5. After a successful comparison, run the smallest read-only remote check needed. Before `push` or PR creation, separately confirm scope, authorization, branch, commit, and repository.
6. Report identities, redacted auth states, credential-channel mismatch, exact context used for each mutation, and remaining uncertainty.

## Safe execution pattern

- Keep local tests, generation, diff inspection, and scope checks in the sandbox.
- Use the approved external identity only for commands that need its credential store, such as `git fetch`, `git push`, or `gh pr view`.
- Prefer a configured GitHub connector for PR creation when it is already authorized, but verify the pushed branch and returned PR URL independently.
- Treat a reusable approval prefix as authorization for the matching command shape, not as permission for unrelated Git or filesystem mutations.

Stop on permission denial, an unexpected identity, a different repository/remote, secret-bearing output that cannot be redacted, or any request to weaken credential isolation.
