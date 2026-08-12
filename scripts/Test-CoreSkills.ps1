[CmdletBinding()]
param(
    [string]$SkillsRoot
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($SkillsRoot)) {
    $scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
    $SkillsRoot = Join-Path (Split-Path -Parent $scriptDirectory) 'skills'
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
