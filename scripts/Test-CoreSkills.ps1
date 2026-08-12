[CmdletBinding()]
param(
    [string]$SkillsRoot
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($SkillsRoot)) {
    $scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
    $repositoryRoot = Split-Path -Parent $scriptDirectory
    $SkillsRoot = Join-Path $repositoryRoot 'skills'
} else {
    $repositoryRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
}
$expectedSkills = @(
    'codebase-design',
    'diagnosing-bugs',
    'evolving-contracts',
    'grilling',
    'refactoring-safely',
    'resolving-merge-conflicts',
    'review-code-against-spec',
    'tdd'
)
$allowedRootDirectories = @('agents', 'assets', 'references', 'scripts')
$errors = [System.Collections.Generic.List[string]]::new()

function Add-ValidationError([string]$Message) {
    $errors.Add($Message)
}

function Test-ContractRule([string]$Text, [string[]]$Patterns) {
    foreach ($pattern in $Patterns) {
        if ($Text -notmatch $pattern) { return $false }
    }
    return $true
}

function Test-MarkdownRelativeLinks([IO.FileInfo]$MarkdownFile, [string]$AllowedRoot) {
    $markdownText = Get-Content -Raw -Encoding UTF8 -LiteralPath $MarkdownFile.FullName
    $rootPath = [IO.Path]::GetFullPath($AllowedRoot).TrimEnd([IO.Path]::DirectorySeparatorChar)
    $rootPrefix = $rootPath + [IO.Path]::DirectorySeparatorChar
    foreach ($match in [regex]::Matches($markdownText, '!?(?:\[[^\]]*\])\((?<target>[^)]+)\)')) {
        $target = $match.Groups['target'].Value.Trim()
        if ($target.StartsWith('<') -and $target.EndsWith('>')) {
            $target = $target.Substring(1, $target.Length - 2)
        }
        if ([string]::IsNullOrWhiteSpace($target) -or $target.StartsWith('#') -or $target -match '^[a-z][a-z0-9+.-]*:') {
            continue
        }

        $pathPart = ($target -split '[?#]', 2)[0]
        if ([string]::IsNullOrWhiteSpace($pathPart)) { continue }
        try {
            $pathPart = [Uri]::UnescapeDataString($pathPart)
            if ($pathPart.StartsWith('/') -or $pathPart.StartsWith('\')) {
                $resolvedTarget = [IO.Path]::GetFullPath((Join-Path $rootPath $pathPart.TrimStart([char[]]@('/', '\'))))
            } else {
                $resolvedTarget = [IO.Path]::GetFullPath((Join-Path $MarkdownFile.DirectoryName $pathPart))
            }
        } catch {
            Add-ValidationError "Invalid relative link '$target' in $($MarkdownFile.FullName.Substring($rootPrefix.Length))"
            continue
        }

        if (-not $resolvedTarget.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase) -and
            -not $resolvedTarget.Equals($rootPath, [StringComparison]::OrdinalIgnoreCase)) {
            Add-ValidationError "Relative link escapes repository root: '$target' in $($MarkdownFile.FullName.Substring($rootPrefix.Length))"
        } elseif (-not (Test-Path -LiteralPath $resolvedTarget)) {
            Add-ValidationError "Broken relative link '$target' in $($MarkdownFile.FullName.Substring($rootPrefix.Length))"
        }
    }
}

$efficiencyContracts = @{
    'grilling' = @(
        @{ Label = 'decision graph and frontier'; Patterns = @('(?i)\bdecision graph\b', '(?i)\bcurrent frontier\b') },
        @{ Label = 'checkpoint with pinned inputs'; Patterns = @('(?i)\bcheckpoint\b', '(?i)\bpinned inputs\b') },
        @{ Label = 'bounded no-progress stop'; Patterns = @('(?i)two consecutive rounds', '(?i)neither close, narrow, nor reorder', '(?i)add evidence', '(?i)change constraints', '(?i)stop before repeating a question', '(?i)budget exhaustion is incomplete') },
        @{ Label = 'fixed fact-finding capsule'; Patterns = @('(?i)pin the question', '(?i)repository revision/paths', '(?i)expected evidence', '(?i)budget/stop', '(?i)otherwise investigate serially') },
        @{ Label = 'user judgment is not delegated'; Patterns = @("(?i)do not delegate the user's judgment") }
    )
    'codebase-design' = @(
        @{ Label = 'dependency and trust-boundary graph'; Patterns = @('(?i)dependency and trust-boundary graph') },
        @{ Label = 'independent alternatives share one capsule'; Patterns = @('(?i)independent subagents', '(?i)same context capsule') },
        @{ Label = 'one design integrator'; Patterns = @('(?i)one integrator', '(?i)do not use majority vote') },
        @{ Label = 'response-only design by default'; Patterns = @('(?i)report one final recommendation in the response', '(?i)only when the user requests it', '(?i)identifies or approves the destination') },
        @{ Label = 'user-judgment handoff'; Patterns = @('(?i)\$grilling', '(?i)undiscoverable judgment held by the current user') }
    )
    'tdd' = @(
        @{ Label = 'behavior-slice graph'; Patterns = @('(?i)behavior-slice graph') },
        @{ Label = 'safe independent red fan-out'; Patterns = @('(?i)current-frontier slices with no cross-slice dependency', '(?i)independent red', '(?i)disjoint write sets', '(?i)coordination cost') },
        @{ Label = 'complete worker capsule'; Patterns = @('(?i)objective/slice', '(?i)pinned baseline', '(?i)dependencies/constraints', '(?i)allowed reads/writes/side effects', '(?i)commands/evidence', '(?i)budget/stop', '(?i)and risks') },
        @{ Label = 'single seam owner and worker-local loop'; Patterns = @('(?i)one writer for the same public seam', '(?i)each worker completes one slice at a time') },
        @{ Label = 'fan-in gates the next frontier'; Patterns = @('(?i)at fan-in', '(?i)before opening the next frontier') }
    )
    'refactoring-safely' = @(
        @{ Label = 'impact graph and migration waves'; Patterns = @('(?i)impact graph', '(?i)migration wave') },
        @{ Label = 'bounded current-frontier parallelism'; Patterns = @('(?i)unlocked current frontier', '(?i)saved critical-path time exceeds dispatch, rereading, and fan-in cost') },
        @{ Label = 'complete migration-wave capsule'; Patterns = @('(?i)exclusive paths/side effects', '(?i)completion command/evidence', '(?i)budget/stop', '(?i)risks', '(?i)checkpoint/resume gate') },
        @{ Label = 'single writer and serial proof'; Patterns = @('(?i)a single writer', '(?i)global preservation proof.{0,80}remain serial') },
        @{ Label = 'preservation checkpoint invalidation'; Patterns = @('(?i)preservation checkpoint', '(?i)stop the current wave immediately', '(?i)revalidate affected work before resuming') }
    )
    'evolving-contracts' = @(
        @{ Label = 'contract dependency graph and matrix'; Patterns = @('(?i)producer-reader-storage-deployment dependency graph', '(?i)pinned compatibility matrix') },
        @{ Label = 'phase gates and checkpoints'; Patterns = @('(?i)explicit phase gates', '(?i)safe checkpoints') },
        @{ Label = 'bounded current-frontier parallelism'; Patterns = @('(?i)unlocked current frontier', '(?i)saved critical-path time exceeds dispatch, rereading, and fan-in cost') },
        @{ Label = 'authoritative writes remain serial'; Patterns = @('(?i)authoritative writes', '(?i)remain serial under one owner') },
        @{ Label = 'checkpoint resume payload'; Patterns = @('(?i)repository revision and compatibility-matrix version', '(?i)durable batch cursor', '(?i)before resume, revalidate every field', '(?i)do not replay writes') }
    )
    'diagnosing-bugs' = @(
        @{ Label = 'conditional feedback-loop disclosure'; Patterns = @('(?i)reuse an established exact loop only after confirming', '(?i)pinned revision and environment', '(?i)repeatable, safe, and authorized', '(?i)otherwise.{0,160}read \[references/feedback-loops\.md\]', '(?i)known workload and objective.{0,80}read \[references/performance\.md\].{0,80}instead') },
        @{ Label = 'Windows GitHub credential-context diagnosis'; Patterns = @('(?i)references/windows-github-credentials\.md', '(?i)scripts/Test-WindowsGitHubAuthContext\.ps1', '(?i)credential-visibility boundary', '(?i)before asking the user to log in again') },
        @{ Label = 'experiment evidence graph and capsule'; Patterns = @('(?i)observation-hypothesis-experiment evidence graph', '(?i)context capsule') },
        @{ Label = 'parallel read-only evidence'; Patterns = @('(?i)independent read-only evidence.{0,80}parallel') },
        @{ Label = 'causal experiments stay serial'; Patterns = @('(?i)causal experiments remain serial') },
        @{ Label = 'no-progress stop'; Patterns = @('(?i)two consecutive rounds add no new evidence', '(?i)a budget stop is not a diagnosis') }
    )
    'review-code-against-spec' = @(
        @{ Label = 'review coverage map'; Patterns = @('(?i)requirements-files-checks coverage map') },
        @{ Label = 'pinned read-only dual-axis review'; Patterns = @('(?i)Standards and Spec as independent read-only workers', '(?i)pinned change set') },
        @{ Label = 'bounded current-frontier workers'; Patterns = @('(?i)same current frontier', '(?i)saved critical-path time exceeds dispatch, rereading, and fan-in cost') },
        @{ Label = 'single report fan-in'; Patterns = @('(?i)at fan-in', '(?i)a single report writer') },
        @{ Label = 'risk-first bounded review'; Patterns = @('(?i)risk-first review pass and iteration budget', '(?i)new evidence or a material coverage gap', '(?i)unreviewed area.{0,40}residual verification gap') }
    )
    'resolving-merge-conflicts' = @(
        @{ Label = 'conflict dependency graph'; Patterns = @('(?i)conflict dependency graph') },
        @{ Label = 'read-only independent analysis'; Patterns = @('(?i)analyze independent conflicts read-only', '(?i)pinned Git state') },
        @{ Label = 'bounded current-frontier analysis'; Patterns = @('(?i)unlocked current frontier', '(?i)saved critical-path time exceeds dispatch, rereading, and fan-in cost') },
        @{ Label = 'ambiguous-semantics stop'; Patterns = @('(?i)cannot uniquely determine the semantics', '(?i)request the minimum user decision', '(?i)do not stage it') },
        @{ Label = 'single Git resolver'; Patterns = @('(?i)a single resolver', '(?i)user retains every abort decision', '(?i)Git-state change invalidates') }
    )
}

$gitCiContracts = @{
    'grilling' = @(
        @{ Label = 'conditional delivery activation'; Patterns = @('(?i)only when the current decision depends on delivery state') },
        @{ Label = 'discoverable delivery state first'; Patterns = @('(?i)inspect branch, PR, required-check, environment, and deployment state', '(?i)do not ask the user to recite discoverable Git or CI facts') },
        @{ Label = 'release judgment and authorization boundary'; Patterns = @('(?i)release policy, risk acceptance, rollout timing, or business approval', '(?i)never implies authorization to commit, push, merge, rerun, approve, or deploy') }
    )
    'codebase-design' = @(
        @{ Label = 'conditional delivery activation'; Patterns = @('(?i)only when the requested design includes or changes a CI/CD workflow or release path') },
        @{ Label = 'delivery workflow as trust-boundary design'; Patterns = @('(?i)CI/CD workflow or release path is part of the selected design', '(?i)triggers, permissions, credentials, artifacts, environments, concurrency', '(?i)rollback') },
        @{ Label = 'immutable action and least-privilege evidence'; Patterns = @('(?i)least-privilege permissions', '(?i)immutable action revisions') }
    )
    'tdd' = @(
        @{ Label = 'conditional delivery activation'; Patterns = @('(?i)only when repository CI exists and the behavior or requested change depends on it') },
        @{ Label = 'local and CI command alignment'; Patterns = @('(?i)map the focused and broad local commands to the repository CI jobs', '(?i)CI-only failure after push is not the first red') },
        @{ Label = 'publish authorization separation'; Patterns = @('(?i)commit, push, PR creation, rerun, merge, and deployment remain separate authorized actions') }
    )
    'refactoring-safely' = @(
        @{ Label = 'conditional delivery activation'; Patterns = @('(?i)only when the refactor can affect build, packaging, workflow, or deployment behavior') },
        @{ Label = 'required-check preservation baseline'; Patterns = @('(?i)required CI checks and their local equivalents', '(?i)do not weaken, skip, or rewrite a CI gate merely to make the refactor green') },
        @{ Label = 'published-check invalidation'; Patterns = @('(?i)published commit changes, treat prior remote check conclusions as stale', '(?i)push or deployment.{0,40}requires separate authorization') }
    )
    'evolving-contracts' = @(
        @{ Label = 'conditional delivery activation'; Patterns = @('(?i)only when they change or the transition depends on them') },
        @{ Label = 'pipeline compatibility inventory'; Patterns = @('(?i)treat CI/CD workflows, action versions, runner images, permissions, caches, artifacts, environments, and deployment interfaces as contracts', '(?i)old and new workflow paths coexist') },
        @{ Label = 'delivery migration gates'; Patterns = @('(?i)pin third-party actions to reviewed immutable revisions', '(?i)required-check names and branch-protection expectations') }
    )
    'diagnosing-bugs' = @(
        @{ Label = 'conditional delivery activation'; Patterns = @('(?i)only for a reported or evidenced CI/CD failure') },
        @{ Label = 'pinned CI failure evidence'; Patterns = @('(?i)pin the repository, workflow, run and attempt IDs, commit SHA, event, job, runner', '(?i)distinguish code failure from workflow, permission, secret, runner, cache, artifact, environment, or provider failure') },
        @{ Label = 'CI mutation authorization'; Patterns = @('(?i)log inspection and local reproduction are read-only', '(?i)rerun, cancel, approve, repair, commit, push, or deploy') }
    )
    'review-code-against-spec' = @(
        @{ Label = 'conditional delivery activation'; Patterns = @('(?i)only when the pinned diff, governing spec, or requested evidence makes delivery behavior relevant') },
        @{ Label = 'CI evidence in review coverage'; Patterns = @('(?i)include changed workflows, action revisions, permissions, scripts, required checks, and observed check results', '(?i)green CI is supporting evidence, not proof of Spec completeness') },
        @{ Label = 'review remains read-only'; Patterns = @('(?i)do not rerun checks, push fixes, approve deployments, or merge unless separately requested') }
    )
    'resolving-merge-conflicts' = @(
        @{ Label = 'conditional delivery activation'; Patterns = @('(?i)only for actual workflow or deployment configuration conflicts') },
        @{ Label = 'workflow conflict semantics'; Patterns = @('(?i)workflow or deployment configuration conflicts', '(?i)triggers, permissions, expressions, action revisions, environments, and required-check names') },
        @{ Label = 'post-resolution CI invalidation'; Patterns = @('(?i)conflict resolution changes (?:a|the) (?:commit|workflow)', '(?i)prior CI conclusions are stale', '(?i)push and deployment remain separately authorized') }
    )
}

$credentialContextContracts = @{
    'grilling' = @(
        @{ Label = 'credential mismatch is discoverable evidence'; Patterns = @('(?i)authentication results differ across execution identities', '(?i)discoverable fact, not a user decision', '(?i)authorized read-only credential probe', '(?i)before asking the user to authenticate') }
    )
    'codebase-design' = @(
        @{ Label = 'credential context as trust boundary'; Patterns = @('(?i)execution identity, credential-store visibility, repository ownership, and command placement as trust boundaries', '(?i)credentials in their owning store', '(?i)only credential-dependent commands in an approved context', '(?i)global safe-directory exceptions') }
    )
    'tdd' = @(
        @{ Label = 'local loop isolated from credential context'; Patterns = @('(?i)red-green-refactor in the local execution context', '(?i)gh auth status.{0,80}is not test evidence', '(?i)credential-context diagnosis to `?\$diagnosing-bugs`?', '(?i)do not copy tokens') }
    )
    'refactoring-safely' = @(
        @{ Label = 'preservation proof isolated from credential context'; Patterns = @('(?i)preservation proof in a stable local execution context', '(?i)do not change global credential helpers, ACLs, repository ownership, or `?safe\.directory`?', '(?i)credential-dependent Git command separately authorized') }
    )
    'evolving-contracts' = @(
        @{ Label = 'credential topology as explicit contract'; Patterns = @('(?i)execution identities, credential stores and helpers, secret injection, repository ownership, and runner authentication as contracts', '(?i)without copying tokens or weakening ACLs', '(?i)store migration or global configuration change.{0,80}separately authorized phase') }
    )
    'diagnosing-bugs' = @(
        @{ Label = 'identity comparison before reauthentication'; Patterns = @('(?i)failed `?gh auth status`? in one identity is not sufficient evidence', '(?i)authorized comparison identity', '(?i)only credential-dependent network commands use the approved context', '(?i)process-local `?git -c safe\.directory=<absolute-repo>`?') },
        @{ Label = 'Git channel and fixed-SHA publication proof'; Patterns = @('(?i)public repository as reachability evidence only, not proof of write authentication', '(?i)successful `?gh auth status`?.{0,80}does not prove the Git credential helper can push', '(?i)push --dry-run origin <verified-sha>:<explicit-ref>', '(?i)preserve the configured Git Credential Manager', '(?i)do not set `?GCM_INTERACTIVE=Never`?', '(?i)without `?-u`? or `?--force`?', '(?i)prove the remote ref equals that SHA') }
    )
    'review-code-against-spec' = @(
        @{ Label = 'read-only remote evidence through credential owner'; Patterns = @('(?i)PR or check evidence is inaccessible in the current identity', '(?i)evidence gap, not a defect', '(?i)read-only remote metadata in the approved credential-owning context', '(?i)record the execution identity and head SHA') }
    )
    'resolving-merge-conflicts' = @(
        @{ Label = 'single identity owns conflict Git state'; Patterns = @('(?i)index, HEAD, and worktree mutations under one authorized execution identity', '(?i)do not alternate identities', '(?i)credential-dependent network commands outside conflict resolution', '(?i)do not change repository ownership, credential helpers, or global `?safe\.directory`?') }
    )
}

if (-not (Test-Path -LiteralPath $SkillsRoot -PathType Container)) {
    throw "Skills root does not exist: $SkillsRoot"
}

$actualSkills = @(
    Get-ChildItem -LiteralPath $SkillsRoot -Directory |
        Where-Object { -not $_.Name.StartsWith('.') } |
        Select-Object -ExpandProperty Name |
        Sort-Object
)
$missingSkills = @($expectedSkills | Where-Object { $_ -notin $actualSkills })
$extraSkills = @($actualSkills | Where-Object { $_ -notin $expectedSkills })
if ($missingSkills.Count -gt 0) { Add-ValidationError "Missing skills: $($missingSkills -join ', ')" }
if ($extraSkills.Count -gt 0) { Add-ValidationError "Unexpected skills: $($extraSkills -join ', ')" }

$efficiencySpecPath = Join-Path $repositoryRoot 'docs\development-orchestration-efficiency-spec.md'
$readmePath = Join-Path $repositoryRoot 'README.md'
if (-not (Test-Path -LiteralPath $efficiencySpecPath -PathType Leaf)) {
    Add-ValidationError 'Development orchestration efficiency spec is missing'
} else {
    $efficiencySpecText = Get-Content -Raw -Encoding UTF8 -LiteralPath $efficiencySpecPath
    $specContracts = @(
        @{ Label = 'current LangGraph sources'; Patterns = @('https://docs\.langchain\.com/oss/python/langgraph/workflows-agents', 'https://docs\.langchain\.com/oss/python/langgraph/persistence') },
        @{ Label = 'fixed input invalidation'; Patterns = @('pinned input', 'revalidate') },
        @{ Label = 'independent frontier and non-conflicting writes'; Patterns = @('current frontier', 'non-conflicting read/write sets') },
        @{ Label = 'single fan-in owner and Git exclusivity'; Patterns = @('fan-in', 'staging.{0,20}commit.{0,20}merge.{0,20}rebase.{0,20}push') },
        @{ Label = 'bounded routing'; Patterns = @('advance \| retry-with-new-evidence \| serial-takeover \| handoff-to-existing-skill \| stop') },
        @{ Label = 'no-progress and authorization stops'; Patterns = @('no-progress', 'safety/authorization stop') },
        @{ Label = 'complete context capsule'; Patterns = @('pinned input/revision; dependencies', 'allowed read/write and side effects', 'budget and stop condition') }
    )
    foreach ($rule in $specContracts) {
        if (-not (Test-ContractRule $efficiencySpecText $rule.Patterns)) {
            Add-ValidationError "Efficiency spec contract missing: $($rule.Label)"
        }
    }
    if ($efficiencySpecText -match '(?i)langchain-ai\.github\.io/langgraph|FastContext') {
        Add-ValidationError 'Development orchestration efficiency spec contains a retired source'
    }
}

if (-not (Test-Path -LiteralPath $readmePath -PathType Leaf)) {
    Add-ValidationError 'README.md is missing'
} else {
    $readmeText = Get-Content -Raw -Encoding UTF8 -LiteralPath $readmePath
    if ($readmeText -notmatch '\(docs/development-orchestration-efficiency-spec\.md\)') {
        Add-ValidationError 'README does not link the development orchestration efficiency spec'
    }
    foreach ($term in @('Graph', 'loop', 'subagent', 'not a ninth skill', 'single-writer')) {
        if ($readmeText -notmatch [regex]::Escape($term)) {
            Add-ValidationError "README efficiency guidance is missing '$term'"
        }
    }
    $documentedSkills = @(
        [regex]::Matches($readmeText, '(?m)^\| `(?<name>[a-z0-9]+(?:-[a-z0-9]+)*)` \|') |
            ForEach-Object { $_.Groups['name'].Value } |
            Sort-Object -Unique
    )
    $missingDocumentedSkills = @($expectedSkills | Where-Object { $_ -notin $documentedSkills })
    $extraDocumentedSkills = @($documentedSkills | Where-Object { $_ -notin $expectedSkills })
    if ($missingDocumentedSkills.Count -gt 0) { Add-ValidationError "README missing skills: $($missingDocumentedSkills -join ', ')" }
    if ($extraDocumentedSkills.Count -gt 0) { Add-ValidationError "README has unexpected skills: $($extraDocumentedSkills -join ', ')" }
}

$repositoryMarkdownFiles = @()
if (Test-Path -LiteralPath $readmePath -PathType Leaf) {
    $repositoryMarkdownFiles += Get-Item -LiteralPath $readmePath
}
foreach ($markdownRootName in @('docs', 'skills')) {
    $markdownRoot = Join-Path $repositoryRoot $markdownRootName
    if (Test-Path -LiteralPath $markdownRoot -PathType Container) {
        $repositoryMarkdownFiles += Get-ChildItem -LiteralPath $markdownRoot -Recurse -File -Filter '*.md'
    }
}
foreach ($markdownFile in $repositoryMarkdownFiles) {
    Test-MarkdownRelativeLinks $markdownFile $repositoryRoot
}

foreach ($skillName in $expectedSkills) {
    $skillRoot = Join-Path $SkillsRoot $skillName
    if (-not (Test-Path -LiteralPath $skillRoot -PathType Container)) { continue }

    $skillFile = Join-Path $skillRoot 'SKILL.md'
    $agentFile = Join-Path $skillRoot 'agents\openai.yaml'
    if (-not (Test-Path -LiteralPath $skillFile -PathType Leaf)) {
        Add-ValidationError "${skillName}: SKILL.md is missing"
        continue
    }
    if (-not (Test-Path -LiteralPath $agentFile -PathType Leaf)) {
        Add-ValidationError "${skillName}: agents/openai.yaml is missing"
    }

    $skillText = Get-Content -Raw -Encoding UTF8 -LiteralPath $skillFile
    $frontmatterMatch = [regex]::Match($skillText, '\A---\r?\n(?<yaml>.*?)\r?\n---(?:\r?\n|\z)', 'Singleline')
    if (-not $frontmatterMatch.Success) {
        Add-ValidationError "${skillName}: invalid YAML frontmatter delimiters"
    } else {
        $frontmatter = @{}
        $frontmatterKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
        foreach ($line in ($frontmatterMatch.Groups['yaml'].Value -split '\r?\n')) {
            $field = [regex]::Match($line, '^(?<key>[A-Za-z0-9-]+):\s*(?<value>.*)$')
            if (-not $field.Success) {
                Add-ValidationError "${skillName}: unsupported frontmatter line '$line'"
                continue
            }
            $key = $field.Groups['key'].Value
            if (-not $frontmatterKeys.Add($key)) {
                Add-ValidationError "${skillName}: duplicate frontmatter key '$key'"
                continue
            }
            $frontmatter[$key] = $field.Groups['value'].Value.Trim()
        }

        $unexpectedKeys = @($frontmatter.Keys | Where-Object { $_ -notin @('name', 'description') })
        if ($unexpectedKeys.Count -gt 0) {
            Add-ValidationError "${skillName}: unexpected frontmatter keys: $($unexpectedKeys -join ', ')"
        }
        if ($frontmatter['name'] -ne $skillName) {
            Add-ValidationError "${skillName}: frontmatter name does not match directory"
        }
        if ($skillName -notmatch '^[a-z0-9]+(?:-[a-z0-9]+)*$' -or $skillName.Length -gt 64) {
            Add-ValidationError "${skillName}: invalid skill name"
        }
        $description = [string]$frontmatter['description']
        if ([string]::IsNullOrWhiteSpace($description) -or $description.Length -gt 1024 -or $description -match '[<>]') {
            Add-ValidationError "${skillName}: invalid description"
        }
    }

    if (($skillText -split '\r?\n').Count -gt 100) {
        Add-ValidationError "${skillName}: SKILL.md exceeds the 100-line local budget"
    }
    if ($skillText -match '(?i)\bTODO\b') {
        Add-ValidationError "${skillName}: TODO remains in SKILL.md"
    }
    foreach ($rule in $efficiencyContracts[$skillName]) {
        if (-not (Test-ContractRule $skillText $rule.Patterns)) {
            Add-ValidationError "${skillName}: efficiency contract missing: $($rule.Label)"
        }
    }
    foreach ($rule in $gitCiContracts[$skillName]) {
        if (-not (Test-ContractRule $skillText $rule.Patterns)) {
            Add-ValidationError "${skillName}: Git/CI contract missing: $($rule.Label)"
        }
    }
    $credentialContractText = $skillText
    if ($skillName -eq 'diagnosing-bugs') {
        $credentialReference = Join-Path $skillRoot 'references\windows-github-credentials.md'
        if (Test-Path -LiteralPath $credentialReference -PathType Leaf) {
            $credentialContractText += "`n" + (Get-Content -Raw -Encoding UTF8 -LiteralPath $credentialReference)
        }
    }
    foreach ($rule in $credentialContextContracts[$skillName]) {
        if (-not (Test-ContractRule $credentialContractText $rule.Patterns)) {
            Add-ValidationError "${skillName}: credential-context contract missing: $($rule.Label)"
        }
    }

    $rootFiles = @(Get-ChildItem -LiteralPath $skillRoot -File | Select-Object -ExpandProperty Name)
    $unexpectedRootFiles = @($rootFiles | Where-Object { $_ -ne 'SKILL.md' })
    if ($unexpectedRootFiles.Count -gt 0) {
        Add-ValidationError "${skillName}: unexpected root files: $($unexpectedRootFiles -join ', ')"
    }
    $unexpectedRootDirectories = @(Get-ChildItem -LiteralPath $skillRoot -Directory | Where-Object { $_.Name -notin $allowedRootDirectories } | Select-Object -ExpandProperty Name)
    if ($unexpectedRootDirectories.Count -gt 0) {
        Add-ValidationError "${skillName}: unexpected root directories: $($unexpectedRootDirectories -join ', ')"
    }

    $directLinks = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($match in [regex]::Matches($skillText, '\[[^\]]*\]\((?<target>[^)]+)\)')) {
        $target = $match.Groups['target'].Value.Split('#')[0]
        if ([string]::IsNullOrWhiteSpace($target) -or $target -match '^[a-z]+://') { continue }
        $normalizedTarget = $target.Replace('/', '\')
        [void]$directLinks.Add($normalizedTarget)
        $resolvedTarget = Join-Path $skillRoot $normalizedTarget
        if (-not (Test-Path -LiteralPath $resolvedTarget)) {
            Add-ValidationError "${skillName}: broken relative link '$target'"
        }
    }

    $resourceFiles = @(foreach ($resourceDirectory in @('assets', 'references', 'scripts')) {
        $resourceRoot = Join-Path $skillRoot $resourceDirectory
        if (Test-Path -LiteralPath $resourceRoot -PathType Container) {
            Get-ChildItem -LiteralPath $resourceRoot -Recurse -File
        }
    })
    foreach ($resourceFile in $resourceFiles) {
        $relativeResource = $resourceFile.FullName.Substring($skillRoot.Length + 1)
        if (-not $directLinks.Contains($relativeResource)) {
            Add-ValidationError "${skillName}: resource is not linked directly from SKILL.md: $relativeResource"
        }
    }

    foreach ($markdownFile in @(Get-ChildItem -LiteralPath $skillRoot -Recurse -File -Filter '*.md')) {
        $markdownText = Get-Content -Raw -Encoding UTF8 -LiteralPath $markdownFile.FullName
        foreach ($call in [regex]::Matches($markdownText, '\$(?<name>[a-z0-9]+(?:-[a-z0-9]+)*)')) {
            if ($call.Groups['name'].Value -notin $expectedSkills) {
                Add-ValidationError "${skillName}: references uninstalled skill '$($call.Groups['name'].Value)' in $($markdownFile.Name)"
            }
        }
    }

    if (Test-Path -LiteralPath $agentFile -PathType Leaf) {
        $agentText = Get-Content -Raw -Encoding UTF8 -LiteralPath $agentFile
        $agentPattern = '\Ainterface:\r?\n' +
            '  display_name: "(?<display_name>[^"\r\n]+)"\r?\n' +
            '  short_description: "(?<short_description>[^"\r\n]+)"\r?\n' +
            '  default_prompt: "(?<default_prompt>[^"\r\n]+)"\r?\n?\z'
        $agentMatch = [regex]::Match($agentText, $agentPattern)
        if (-not $agentMatch.Success) {
            Add-ValidationError "${skillName}: invalid agents/openai.yaml structure"
        } else {
            $shortLength = $agentMatch.Groups['short_description'].Value.Length
            if ($shortLength -lt 25 -or $shortLength -gt 64) {
                Add-ValidationError "${skillName}: short_description must be 25-64 characters"
            }
            if (-not $agentMatch.Groups['default_prompt'].Value.Contains('$' + $skillName)) {
                Add-ValidationError ($skillName + ': default_prompt must explicitly mention $' + $skillName)
            }
        }
    }
}

if ($errors.Count -gt 0) {
    Write-Host "Core skill validation failed with $($errors.Count) error(s):" -ForegroundColor Red
    $errors | ForEach-Object { Write-Host "- $_" -ForegroundColor Red }
    exit 1
}

Write-Host "Core skill validation passed for $($expectedSkills.Count) skills." -ForegroundColor Green
