[CmdletBinding()]
param(
    [string]$SkillsRoot
)

$ErrorActionPreference = 'Stop'
$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$repositoryRoot = Split-Path -Parent $scriptDirectory
if ([string]::IsNullOrWhiteSpace($SkillsRoot)) {
    $SkillsRoot = Join-Path $repositoryRoot 'skills'
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

$descriptionContracts = @{
    'grilling' = @{ Label = 'current-user decision boundary'; Patterns = @('(?i)do not use for facts Codex can discover', '(?i)knowledge held only by another person') }
    'codebase-design' = @{ Label = 'selected unresolved design boundary'; Patterns = @('(?i)do not use for codebase-wide architecture scans', '(?i)already settled design') }
    'tdd' = @{ Label = 'known behavior boundary'; Patterns = @('(?i)use \$diagnosing-bugs while the cause or expected behavior remains unknown') }
    'refactoring-safely' = @{ Label = 'behavior-preserving boundary'; Patterns = @('(?i)do not use when behavior should change', '(?i)cross-version public contract') }
    'evolving-contracts' = @{ Label = 'mixed-state contract boundary'; Patterns = @('(?i)do not use for purely internal refactors', '(?i)undecided target contract') }
    'diagnosing-bugs' = @{ Label = 'diagnosis-only default boundary'; Patterns = @('(?i)stop at diagnosis unless repair or optimization is explicitly requested') }
    'review-code-against-spec' = @{ Label = 'fixed read-only review boundary'; Patterns = @('(?i)fixed change set', '(?i)without modifying code unless fixes are separately requested') }
    'resolving-merge-conflicts' = @{ Label = 'active merge-or-rebase boundary'; Patterns = @('(?i)use only when Git reports unresolved merge or rebase conflicts') }
}

function Test-PathWithinRoot([string]$Candidate, [string]$AllowedRoot) {
    $rootPath = [IO.Path]::GetFullPath($AllowedRoot).TrimEnd([char[]]@([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar))
    $candidatePath = [IO.Path]::GetFullPath($Candidate)
    if ($candidatePath.Equals($rootPath, [StringComparison]::OrdinalIgnoreCase)) { return $true }
    $rootPrefix = $rootPath + [IO.Path]::DirectorySeparatorChar
    return $candidatePath.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)
}

function Get-DisplayPath([string]$Path, [string]$AllowedRoot) {
    $rootPath = [IO.Path]::GetFullPath($AllowedRoot).TrimEnd([char[]]@([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar))
    $fullPath = [IO.Path]::GetFullPath($Path)
    if (Test-PathWithinRoot $fullPath $rootPath) {
        if ($fullPath.Equals($rootPath, [StringComparison]::OrdinalIgnoreCase)) { return '.' }
        return $fullPath.Substring($rootPath.Length + 1)
    }
    return $fullPath
}

function Get-MarkdownTargets([string]$MarkdownText) {
    foreach ($match in [regex]::Matches($MarkdownText, '!?(?:\[[^\]]*\])\((?<target>[^)]+)\)')) {
        $target = $match.Groups['target'].Value.Trim()
        if ($target.StartsWith('<')) {
            $closing = $target.IndexOf('>')
            if ($closing -gt 0) { $target = $target.Substring(1, $closing - 1) }
        } elseif ($target -match '^(?<path>\S+)(?:\s+["''].*)?$') {
            $target = $Matches['path']
        }
        if (-not [string]::IsNullOrWhiteSpace($target)) { $target }
    }
}

function Resolve-MarkdownTarget([string]$Target, [IO.FileInfo]$MarkdownFile, [string]$AllowedRoot) {
    if ($Target.StartsWith('#') -or $Target -match '^[a-z][a-z0-9+.-]*:') { return $null }

    $pathPart = ($Target -split '[?#]', 2)[0]
    if ([string]::IsNullOrWhiteSpace($pathPart)) { return $null }

    $pathPart = [Uri]::UnescapeDataString($pathPart)
    if ($pathPart.StartsWith('/') -or $pathPart.StartsWith('\')) {
        return [IO.Path]::GetFullPath((Join-Path $AllowedRoot $pathPart.TrimStart([char[]]@('/', '\'))))
    }
    return [IO.Path]::GetFullPath((Join-Path $MarkdownFile.DirectoryName $pathPart))
}

function Test-MarkdownRelativeLinks([IO.FileInfo]$MarkdownFile, [string]$AllowedRoot, [string]$ScopeLabel) {
    $markdownText = Get-Content -Raw -Encoding UTF8 -LiteralPath $MarkdownFile.FullName
    foreach ($target in @(Get-MarkdownTargets $markdownText)) {
        try {
            $resolvedTarget = Resolve-MarkdownTarget $target $MarkdownFile $AllowedRoot
        } catch {
            Add-ValidationError "Invalid relative link '$target' in $(Get-DisplayPath $MarkdownFile.FullName $repositoryRoot)"
            continue
        }
        if ($null -eq $resolvedTarget) { continue }

        if (-not (Test-PathWithinRoot $resolvedTarget $AllowedRoot)) {
            Add-ValidationError "Relative link escapes ${ScopeLabel}: '$target' in $(Get-DisplayPath $MarkdownFile.FullName $repositoryRoot)"
        } elseif (-not (Test-Path -LiteralPath $resolvedTarget)) {
            Add-ValidationError "Broken relative link '$target' in $(Get-DisplayPath $MarkdownFile.FullName $repositoryRoot)"
        }
    }
}

function Get-ReachableSkillFiles([string]$SkillRoot, [string]$EntryPath) {
    $reachable = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $queuedMarkdown = [System.Collections.Generic.Queue[string]]::new()
    $entryFullPath = [IO.Path]::GetFullPath($EntryPath)
    [void]$reachable.Add($entryFullPath)
    $queuedMarkdown.Enqueue($entryFullPath)

    while ($queuedMarkdown.Count -gt 0) {
        $markdownPath = $queuedMarkdown.Dequeue()
        $markdownFile = Get-Item -LiteralPath $markdownPath
        $markdownText = Get-Content -Raw -Encoding UTF8 -LiteralPath $markdownPath
        foreach ($target in @(Get-MarkdownTargets $markdownText)) {
            try {
                $resolvedTarget = Resolve-MarkdownTarget $target $markdownFile $SkillRoot
            } catch {
                continue
            }
            if ($null -eq $resolvedTarget -or -not (Test-PathWithinRoot $resolvedTarget $SkillRoot) -or -not (Test-Path -LiteralPath $resolvedTarget)) {
                continue
            }

            if (Test-Path -LiteralPath $resolvedTarget -PathType Container) {
                $linkedFiles = @(Get-ChildItem -LiteralPath $resolvedTarget -Recurse -File)
            } else {
                $linkedFiles = @(Get-Item -LiteralPath $resolvedTarget)
            }
            foreach ($linkedFile in $linkedFiles) {
                if ($reachable.Add($linkedFile.FullName) -and $linkedFile.Extension -eq '.md') {
                    $queuedMarkdown.Enqueue($linkedFile.FullName)
                }
            }
        }
    }
    return ,$reachable
}

function Test-StrictUtf8([IO.FileInfo]$File) {
    try {
        $utf8 = [Text.UTF8Encoding]::new($false, $true)
        [void]$utf8.GetString([IO.File]::ReadAllBytes($File.FullName))
    } catch {
        Add-ValidationError "Text file is not valid UTF-8: $(Get-DisplayPath $File.FullName $repositoryRoot)"
    }
}

function Test-PowerShellSyntax([IO.FileInfo]$ScriptFile) {
    $tokens = $null
    $parseErrors = $null
    [void][Management.Automation.Language.Parser]::ParseFile($ScriptFile.FullName, [ref]$tokens, [ref]$parseErrors)
    foreach ($parseError in $parseErrors) {
        Add-ValidationError "Invalid PowerShell syntax in $(Get-DisplayPath $ScriptFile.FullName $repositoryRoot):$($parseError.Extent.StartLineNumber): $($parseError.Message)"
    }
}

$semanticContracts = @{
    'grilling' = @(
        @{ Label = 'decision graph and frontier'; Patterns = @('(?i)decision graph', '(?i)current frontier') },
        @{ Label = 'discoverable facts stay with the agent'; Patterns = @('(?i)discoverable facts', '(?i)investigate facts directly') },
        @{ Label = 'no implicit implementation'; Patterns = @('(?i)never authorizes implementation|do not begin implementation') },
        @{ Label = 'stalled interview stop'; Patterns = @('(?i)two consecutive rounds add no evidence', '(?i)stop before repeating a question') }
    )
    'codebase-design' = @(
        @{ Label = 'caller-visible contract first'; Patterns = @('(?i)caller-visible', '(?i)before proposing types or abstractions') },
        @{ Label = 'honest seams'; Patterns = @('(?i)seams? only where variation is real') },
        @{ Label = 'conditional deepening and security references'; Patterns = @('references/deepening\.md', 'references/security-design\.md') },
        @{ Label = 'ranked recommendation'; Patterns = @('(?i)recommend one design') },
        @{ Label = 'incompatible constraint stop'; Patterns = @('(?i)authoritative constraints are mutually incompatible', '(?i)stop short of inventing a contract') }
    )
    'tdd' = @(
        @{ Label = 'stable public seam'; Patterns = @('(?i)public seam', '(?i)real caller') },
        @{ Label = 'red green refactor cycle'; Patterns = @('(?i)\*\*Red\*\*', '(?i)\*\*Green\*\*', '(?i)\*\*Refactor\*\*') },
        @{ Label = 'intended red evidence'; Patterns = @('(?i)intended red', '(?i)do not claim TDD') },
        @{ Label = 'unexpected pass and flake handling'; Patterns = @('(?i)passes before production changes', '(?i)neither valid red nor valid green evidence') }
    )
    'refactoring-safely' = @(
        @{ Label = 'observable behavior preservation'; Patterns = @('(?i)preserve observable behavior', '(?i)what must remain unchanged') },
        @{ Label = 'green baseline'; Patterns = @('(?i)baseline', '(?i)failing baseline is not green') },
        @{ Label = 'reversible verified steps'; Patterns = @('(?i)reversible steps', '(?i)focused proof after every step') },
        @{ Label = 'pre-existing work protection'; Patterns = @('(?i)pre-existing changes', '(?i)never reset or check out pre-existing work') },
        @{ Label = 'unprovable invariant boundary'; Patterns = @('(?i)no runnable or comparative evidence', '(?i)claim behavior preservation without proof') }
    )
    'evolving-contracts' = @(
        @{ Label = 'compatibility matrix'; Patterns = @('(?i)compatibility matrix', '(?i)mixed-version') },
        @{ Label = 'expand migrate observe contract phases'; Patterns = @('(?i)\*\*Expand readers', '(?i)\*\*Migrate writers', '(?i)\*\*Observe', '(?i)\*\*Contract') },
        @{ Label = 'resume and recovery evidence'; Patterns = @('(?i)before resuming', '(?i)recovery path') },
        @{ Label = 'ambiguous resume stop'; Patterns = @('(?i)cursor is ambiguous', '(?i)do not replay writes') }
    )
    'diagnosing-bugs' = @(
        @{ Label = 'repeatable feedback loop'; Patterns = @('(?i)feedback loop', '(?i)repeatable') },
        @{ Label = 'falsifiable single-variable experiments'; Patterns = @('(?i)ranked hypotheses', '(?i)test one variable at a time') },
        @{ Label = 'original scenario confirmation'; Patterns = @('(?i)original unminimized scenario') },
        @{ Label = 'conditional specialist resources'; Patterns = @('references/performance\.md', 'references/windows-github-credentials\.md', 'scripts/Test-WindowsGitHubAuthContext\.ps1') },
        @{ Label = 'diagnosis before repair'; Patterns = @('(?i)default to diagnosis, not repair', '(?i)repair is explicitly in scope') },
        @{ Label = 'causal and stalled-loop boundary'; Patterns = @('(?i)symptom disappearance is not causal evidence', '(?i)two consecutive experiment rounds add no evidence') }
    )
    'review-code-against-spec' = @(
        @{ Label = 'pinned change set'; Patterns = @('(?i)pinned change set', '(?i)effective endpoints') },
        @{ Label = 'independent Standards and Spec axes'; Patterns = @('(?i)two separate passes', '(?i)### Standards pass', '(?i)### Spec pass') },
        @{ Label = 'read-only default'; Patterns = @('(?i)do not modify code') },
        @{ Label = 'empty and opaque change handling'; Patterns = @('(?i)effective change set is empty', '(?i)opaque change or green summary as reviewed') }
    )
    'resolving-merge-conflicts' = @(
        @{ Label = 'in-progress conflict trigger'; Patterns = @('(?i)use only when Git reports unresolved') },
        @{ Label = 'intent reconstruction and ambiguity stop'; Patterns = @('(?i)preserve both intents', '(?i)do not stage that path') },
        @{ Label = 'safe staging and abort boundary'; Patterns = @('(?i)stage only resolved conflict paths', '(?i)never run .*--abort') },
        @{ Label = 'preserve unrelated work'; Patterns = @('(?i)unrelated working-tree changes', '(?i)preserved unrelated changes') },
        @{ Label = 'stale conflict state stop'; Patterns = @('(?i)unmerged-path set changes after analysis', '(?i)never apply a stale resolution plan') }
    )
}

if (-not (Test-Path -LiteralPath $SkillsRoot -PathType Container)) {
    throw "Skills root does not exist: $SkillsRoot"
}
$SkillsRoot = [IO.Path]::GetFullPath($SkillsRoot)

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

$readmePath = Join-Path $repositoryRoot 'README.md'
$specPath = Join-Path $repositoryRoot 'docs\coding-core-skills-spec.md'
$attributesPath = Join-Path $repositoryRoot '.gitattributes'
$workflowPath = Join-Path $repositoryRoot '.github\workflows\validate.yml'

if (-not (Test-Path -LiteralPath $attributesPath -PathType Leaf)) {
    Add-ValidationError '.gitattributes is missing'
} elseif ((Get-Content -Raw -Encoding UTF8 -LiteralPath $attributesPath) -notmatch '(?m)^\* text=auto eol=lf\s*$') {
    Add-ValidationError '.gitattributes does not enforce LF text files'
}

if (-not (Test-Path -LiteralPath $workflowPath -PathType Leaf)) {
    Add-ValidationError 'Core skill validation workflow is missing'
} else {
    $workflowText = Get-Content -Raw -Encoding UTF8 -LiteralPath $workflowPath
    $workflowContracts = @(
        @{ Label = 'push trigger'; Patterns = @('(?m)^  push:\s*$') },
        @{ Label = 'pull request trigger'; Patterns = @('(?m)^  pull_request:\s*$') },
        @{ Label = 'manual trigger'; Patterns = @('(?m)^  workflow_dispatch:\s*$') },
        @{ Label = 'read-only repository permission'; Patterns = @('(?ms)^permissions:\r?\n  contents: read\s*(?:\r?\n|$)') },
        @{ Label = 'credential-free checkout'; Patterns = @('(?m)^\s+persist-credentials: false\s*$') },
        @{ Label = 'bounded validation job'; Patterns = @('(?m)^\s+timeout-minutes: 5\s*$') }
    )
    foreach ($rule in $workflowContracts) {
        if (-not (Test-ContractRule $workflowText $rule.Patterns)) {
            Add-ValidationError "Validation workflow contract missing: $($rule.Label)"
        }
    }
    if ($workflowText -match '(?m)^\s*pull_request_target\s*:') {
        Add-ValidationError 'Validation workflow must not use pull_request_target'
    }
    if ($workflowText -match '(?im)^\s*(?:permissions|[a-z-]+):\s*(?:write|write-all)\s*$') {
        Add-ValidationError 'Validation workflow grants write permission'
    }
    foreach ($actionUse in [regex]::Matches($workflowText, '(?m)^\s*uses:\s*(?<action>[^\s#]+)')) {
        $action = $actionUse.Groups['action'].Value
        if ($action.StartsWith('./') -or $action.StartsWith('docker://')) { continue }
        if ($action -notmatch '@[0-9a-fA-F]{40}$') {
            Add-ValidationError "Validation workflow external action is not pinned to a full commit SHA: $action"
        }
    }
    foreach ($scriptName in @(
        'Test-CoreSkills.ps1',
        'Test-CoreSkills.Validator.ps1',
        'Test-WindowsGitHubAuthContext.Validator.ps1'
    )) {
        if ($workflowText -notmatch [regex]::Escape("scripts\$scriptName")) {
            Add-ValidationError "Validation workflow does not run scripts\$scriptName"
        }
        if (-not (Test-Path -LiteralPath (Join-Path $repositoryRoot "scripts\$scriptName") -PathType Leaf)) {
            Add-ValidationError "Validation script is missing: scripts\$scriptName"
        }
    }
}

if (-not (Test-Path -LiteralPath $readmePath -PathType Leaf)) {
    Add-ValidationError 'README.md is missing'
} else {
    $readmeText = Get-Content -Raw -Encoding UTF8 -LiteralPath $readmePath
    if ($readmeText -notmatch '\(docs/coding-core-skills-spec\.md\)') {
        Add-ValidationError 'README does not link the core skill design spec'
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
if (-not (Test-Path -LiteralPath $specPath -PathType Leaf)) {
    Add-ValidationError 'Core skill design spec is missing'
}

$repositoryMarkdownFiles = @()
if (Test-Path -LiteralPath $readmePath -PathType Leaf) {
    $repositoryMarkdownFiles += Get-Item -LiteralPath $readmePath
}
$docsRoot = Join-Path $repositoryRoot 'docs'
if (Test-Path -LiteralPath $docsRoot -PathType Container) {
    $repositoryMarkdownFiles += Get-ChildItem -LiteralPath $docsRoot -Recurse -File -Filter '*.md'
}
foreach ($markdownFile in $repositoryMarkdownFiles) {
    Test-MarkdownRelativeLinks $markdownFile $repositoryRoot 'repository root'
}

$repositoryTextFiles = @()
foreach ($relativeTextRoot in @('.gitattributes', 'LICENSE', 'README.md', '.github', 'docs', 'scripts', 'skills')) {
    $textRoot = Join-Path $repositoryRoot $relativeTextRoot
    if (Test-Path -LiteralPath $textRoot -PathType Leaf) {
        $repositoryTextFiles += Get-Item -LiteralPath $textRoot
    } elseif (Test-Path -LiteralPath $textRoot -PathType Container) {
        $repositoryTextFiles += Get-ChildItem -LiteralPath $textRoot -Recurse -File |
            Where-Object { $_.Extension -in @('.md', '.ps1', '.yaml', '.yml') }
    }
}
$repositoryTextFiles = @($repositoryTextFiles | Sort-Object FullName -Unique)
foreach ($textFile in $repositoryTextFiles) {
    Test-StrictUtf8 $textFile
}
foreach ($scriptFile in @($repositoryTextFiles | Where-Object { $_.Extension -eq '.ps1' })) {
    Test-PowerShellSyntax $scriptFile
}

foreach ($skillName in $expectedSkills) {
    $skillRoot = Join-Path $SkillsRoot $skillName
    if (-not (Test-Path -LiteralPath $skillRoot -PathType Container)) { continue }
    $skillRoot = [IO.Path]::GetFullPath($skillRoot)

    $skillFile = Join-Path $skillRoot 'SKILL.md'
    $agentFile = Join-Path $skillRoot 'agents\openai.yaml'
    if (-not (Test-Path -LiteralPath $skillFile -PathType Leaf)) {
        Add-ValidationError "${skillName}: SKILL.md is missing"
        continue
    }
    if (-not (Test-Path -LiteralPath $agentFile -PathType Leaf)) {
        Add-ValidationError "${skillName}: agents/openai.yaml is missing"
    }

    $skillMarkdownFiles = @(Get-ChildItem -LiteralPath $skillRoot -Recurse -File -Filter '*.md')
    foreach ($markdownFile in $skillMarkdownFiles) {
        Test-MarkdownRelativeLinks $markdownFile $skillRoot "skill root '$skillName'"
    }

    $skillText = Get-Content -Raw -Encoding UTF8 -LiteralPath $skillFile
    $frontmatterMatch = [regex]::Match($skillText, '\A---\r?\n(?<yaml>.*?)\r?\n---(?:\r?\n|\z)', 'Singleline')
    if (-not $frontmatterMatch.Success) {
        Add-ValidationError "${skillName}: invalid YAML frontmatter delimiters"
    } else {
        $frontmatter = @{}
        $frontmatterKeys = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
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
        } elseif ($description -notmatch '(?i)\buse (?:only )?when\b|\buse for\b') {
            Add-ValidationError "${skillName}: description does not state when to use the skill"
        } elseif (-not (Test-ContractRule $description $descriptionContracts[$skillName].Patterns)) {
            Add-ValidationError "${skillName}: description boundary missing: $($descriptionContracts[$skillName].Label)"
        }
    }

    if ($skillText -match '(?i)\bTODO\b|\[TODO') {
        Add-ValidationError "${skillName}: unfinished placeholder remains in SKILL.md"
    }
    foreach ($rule in $semanticContracts[$skillName]) {
        if (-not (Test-ContractRule $skillText $rule.Patterns)) {
            Add-ValidationError "${skillName}: semantic contract missing: $($rule.Label)"
        }
    }

    $rootFiles = @(Get-ChildItem -LiteralPath $skillRoot -File | Select-Object -ExpandProperty Name)
    $unexpectedRootFiles = @($rootFiles | Where-Object { $_ -ne 'SKILL.md' })
    if ($unexpectedRootFiles.Count -gt 0) {
        Add-ValidationError "${skillName}: unexpected root files: $($unexpectedRootFiles -join ', ')"
    }
    $unexpectedRootDirectories = @(
        Get-ChildItem -LiteralPath $skillRoot -Directory |
            Where-Object { $_.Name -notin $allowedRootDirectories } |
            Select-Object -ExpandProperty Name
    )
    if ($unexpectedRootDirectories.Count -gt 0) {
        Add-ValidationError "${skillName}: unexpected root directories: $($unexpectedRootDirectories -join ', ')"
    }

    $reachableFiles = Get-ReachableSkillFiles $skillRoot $skillFile
    $resourceFiles = @(foreach ($resourceDirectory in @('assets', 'references', 'scripts')) {
        $resourceRoot = Join-Path $skillRoot $resourceDirectory
        if (Test-Path -LiteralPath $resourceRoot -PathType Container) {
            Get-ChildItem -LiteralPath $resourceRoot -Recurse -File
        }
    })
    foreach ($resourceFile in $resourceFiles) {
        if (-not $reachableFiles.Contains($resourceFile.FullName)) {
            Add-ValidationError "${skillName}: resource is unreachable from SKILL.md: $($resourceFile.FullName.Substring($skillRoot.Length + 1))"
        }
    }

    foreach ($markdownFile in $skillMarkdownFiles) {
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
