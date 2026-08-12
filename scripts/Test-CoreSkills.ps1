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

$efficiencyContracts = @{
    'grilling' = @(
        @{ Label = 'decision graph and frontier'; Patterns = @('(?i)\bdecision graph\b', '(?i)\bcurrent frontier\b') },
        @{ Label = 'checkpoint with pinned inputs'; Patterns = @('(?i)\bcheckpoint\b', '(?i)\bpinned inputs\b') },
        @{ Label = 'user judgment is not delegated'; Patterns = @("(?i)do not delegate the user's judgment") }
    )
    'codebase-design' = @(
        @{ Label = 'dependency and trust-boundary graph'; Patterns = @('(?i)dependency and trust-boundary graph') },
        @{ Label = 'independent alternatives share one capsule'; Patterns = @('(?i)independent subagents', '(?i)same context capsule') },
        @{ Label = 'one design integrator'; Patterns = @('(?i)one integrator', '(?i)do not use majority vote') }
    )
    'tdd' = @(
        @{ Label = 'behavior-slice graph'; Patterns = @('(?i)behavior-slice graph') },
        @{ Label = 'safe independent red fan-out'; Patterns = @('(?i)current-frontier slices with no cross-slice dependency', '(?i)independent red', '(?i)disjoint write sets', '(?i)coordination cost') },
        @{ Label = 'single seam owner and worker-local loop'; Patterns = @('(?i)one writer for the same public seam', '(?i)each worker completes one slice at a time') },
        @{ Label = 'fan-in gates the next frontier'; Patterns = @('(?i)at fan-in', '(?i)before opening the next frontier') }
    )
    'refactoring-safely' = @(
        @{ Label = 'impact graph and migration waves'; Patterns = @('(?i)impact graph', '(?i)migration wave') },
        @{ Label = 'single writer and serial proof'; Patterns = @('(?i)a single writer', '(?i)global preservation proof.{0,80}remain serial') },
        @{ Label = 'preservation checkpoint invalidation'; Patterns = @('(?i)preservation checkpoint', '(?i)stop the current wave immediately', '(?i)revalidate affected work before resuming') }
    )
    'evolving-contracts' = @(
        @{ Label = 'contract dependency graph and matrix'; Patterns = @('(?i)producer-reader-storage-deployment dependency graph', '(?i)pinned compatibility matrix') },
        @{ Label = 'phase gates and checkpoints'; Patterns = @('(?i)explicit phase gates', '(?i)safe checkpoints') },
        @{ Label = 'authoritative writes remain serial'; Patterns = @('(?i)authoritative writes', '(?i)remain serial under one owner') },
        @{ Label = 'checkpoint resume payload'; Patterns = @('(?i)repository revision and compatibility-matrix version', '(?i)durable batch cursor', '(?i)before resume, revalidate every field', '(?i)do not replay writes') }
    )
    'diagnosing-bugs' = @(
        @{ Label = 'experiment evidence graph and capsule'; Patterns = @('(?i)observation-hypothesis-experiment evidence graph', '(?i)context capsule') },
        @{ Label = 'parallel read-only evidence'; Patterns = @('(?i)independent read-only evidence.{0,80}parallel') },
        @{ Label = 'causal experiments stay serial'; Patterns = @('(?i)causal experiments remain serial') },
        @{ Label = 'no-progress stop'; Patterns = @('(?i)two consecutive rounds add no new evidence', '(?i)a budget stop is not a diagnosis') }
    )
    'review-code-against-spec' = @(
        @{ Label = 'review coverage map'; Patterns = @('(?i)requirements-files-checks coverage map') },
        @{ Label = 'pinned read-only dual-axis review'; Patterns = @('(?i)Standards and Spec passes', '(?i)independent read-only workers', '(?i)pinned change set') },
        @{ Label = 'single report fan-in'; Patterns = @('(?i)at fan-in', '(?i)a single report writer') },
        @{ Label = 'risk-first bounded review'; Patterns = @('(?i)risk-first worker and iteration budget', '(?i)new evidence or a material coverage gap', '(?i)unreviewed area.{0,40}residual verification gap') }
    )
    'resolving-merge-conflicts' = @(
        @{ Label = 'conflict dependency graph'; Patterns = @('(?i)conflict dependency graph') },
        @{ Label = 'read-only independent analysis'; Patterns = @('(?i)read-only analysis of independent conflicts', '(?i)pinned Git state') },
        @{ Label = 'single Git resolver'; Patterns = @('(?i)a single resolver', '(?i)user retains every abort decision', '(?i)Git-state change invalidates') }
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
        foreach ($line in ($frontmatterMatch.Groups['yaml'].Value -split '\r?\n')) {
            $field = [regex]::Match($line, '^(?<key>[A-Za-z0-9-]+):\s*(?<value>.*)$')
            if (-not $field.Success) {
                Add-ValidationError "${skillName}: unsupported frontmatter line '$line'"
                continue
            }
            $frontmatter[$field.Groups['key'].Value] = $field.Groups['value'].Value.Trim()
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
        foreach ($key in @('display_name', 'short_description', 'default_prompt')) {
            $interfacePattern = '(?m)^  ' + [regex]::Escape($key) + ': "[^"]+"\r?$'
            if ($agentText -notmatch $interfacePattern) {
                Add-ValidationError "${skillName}: missing or unquoted interface.$key"
            }
        }
        $shortMatch = [regex]::Match($agentText, '(?m)^  short_description: "(?<value>[^"]+)"\r?$')
        if ($shortMatch.Success) {
            $shortLength = $shortMatch.Groups['value'].Value.Length
            if ($shortLength -lt 25 -or $shortLength -gt 64) {
                Add-ValidationError "${skillName}: short_description must be 25-64 characters"
            }
        }
        if (-not $agentText.Contains('$' + $skillName)) {
            Add-ValidationError ($skillName + ': default_prompt must explicitly mention $' + $skillName)
        }
    }
}

if ($errors.Count -gt 0) {
    Write-Host "Core skill validation failed with $($errors.Count) error(s):" -ForegroundColor Red
    $errors | ForEach-Object { Write-Host "- $_" -ForegroundColor Red }
    exit 1
}

Write-Host "Core skill validation passed for $($expectedSkills.Count) skills." -ForegroundColor Green
