[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$temporaryParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$temporaryRoot = Join-Path $temporaryParent ('codex-vibe-skills-validator-tests-' + [guid]::NewGuid().ToString('N'))
$errors = [System.Collections.Generic.List[string]]::new()

function New-TestFixture([string]$Name) {
    $fixtureRoot = Join-Path $temporaryRoot $Name
    New-Item -ItemType Directory -Path $fixtureRoot | Out-Null
    foreach ($path in @('.gitattributes', '.github', 'LICENSE', 'README.md', 'docs', 'scripts', 'skills')) {
        Copy-Item -Recurse -LiteralPath (Join-Path $repositoryRoot $path) -Destination $fixtureRoot
    }
    return $fixtureRoot
}

function Invoke-FixtureValidator([string]$FixtureRoot) {
    $fixtureValidator = Join-Path $FixtureRoot 'scripts\Test-CoreSkills.ps1'
    $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $fixtureValidator 2>&1 | Out-String
    return [PSCustomObject]@{
        ExitCode = $LASTEXITCODE
        Output = $output.Trim()
    }
}

function Assert-ValidatorResult(
    [string]$Case,
    [int]$ExpectedExitCode,
    [pscustomobject]$Actual,
    [string]$ExpectedMessage
) {
    if ($Actual.ExitCode -ne $ExpectedExitCode) {
        $errors.Add("${Case}: expected exit $ExpectedExitCode, got $($Actual.ExitCode). Output: $($Actual.Output)")
        return
    }
    if (-not [string]::IsNullOrWhiteSpace($ExpectedMessage) -and $Actual.Output -notmatch $ExpectedMessage) {
        $errors.Add("${Case}: output did not match '$ExpectedMessage'. Output: $($Actual.Output)")
    }
}

New-Item -ItemType Directory -Path $temporaryRoot | Out-Null
try {
    $baseline = New-TestFixture 'baseline'
    Assert-ValidatorResult 'valid repository' 0 (Invoke-FixtureValidator $baseline) 'validation passed'

    $invalidAgent = New-TestFixture 'invalid-agent-yaml'
    $agentPath = Join-Path $invalidAgent 'skills\tdd\agents\openai.yaml'
    [IO.File]::AppendAllText($agentPath, "unexpected: value`n", [Text.UTF8Encoding]::new($false))
    Assert-ValidatorResult 'unexpected agent metadata' 1 (Invoke-FixtureValidator $invalidAgent) 'invalid agents/openai\.yaml structure'

    $brokenLink = New-TestFixture 'broken-readme-link'
    $readmePath = Join-Path $brokenLink 'README.md'
    [IO.File]::AppendAllText($readmePath, "`n[broken local link](docs/does-not-exist.md)`n", [Text.UTF8Encoding]::new($false))
    Assert-ValidatorResult 'broken README link' 1 (Invoke-FixtureValidator $brokenLink) 'broken relative link'

    $duplicateFrontmatter = New-TestFixture 'duplicate-frontmatter-key'
    $skillPath = Join-Path $duplicateFrontmatter 'skills\tdd\SKILL.md'
    $skillText = Get-Content -Raw -Encoding UTF8 -LiteralPath $skillPath
    $skillText = $skillText -replace '(?m)^(description:.*)$', "`$1`nname: tdd"
    [IO.File]::WriteAllText($skillPath, $skillText, [Text.UTF8Encoding]::new($false))
    Assert-ValidatorResult 'duplicate frontmatter key' 1 (Invoke-FixtureValidator $duplicateFrontmatter) 'duplicate frontmatter key'

    $missingGitCiContract = New-TestFixture 'missing-semantic-contract'
    $skillPath = Join-Path $missingGitCiContract 'skills\tdd\SKILL.md'
    $skillText = Get-Content -Raw -Encoding UTF8 -LiteralPath $skillPath
    $skillText = $skillText -replace '\*\*Red\*\*', '**Start**'
    [IO.File]::WriteAllText($skillPath, $skillText, [Text.UTF8Encoding]::new($false))
    Assert-ValidatorResult 'missing semantic contract' 1 (Invoke-FixtureValidator $missingGitCiContract) 'semantic contract missing'

    $mutableAction = New-TestFixture 'mutable-workflow-action'
    $workflowPath = Join-Path $mutableAction '.github\workflows\validate.yml'
    $workflowText = Get-Content -Raw -Encoding UTF8 -LiteralPath $workflowPath
    $workflowText = $workflowText -replace 'actions/checkout@[0-9a-f]{40}', 'actions/checkout@v6'
    [IO.File]::WriteAllText($workflowPath, $workflowText, [Text.UTF8Encoding]::new($false))
    Assert-ValidatorResult 'mutable workflow action' 1 (Invoke-FixtureValidator $mutableAction) 'external action is not pinned to a full commit SHA'

    $writePermission = New-TestFixture 'write-enabled-workflow'
    $workflowPath = Join-Path $writePermission '.github\workflows\validate.yml'
    $workflowText = Get-Content -Raw -Encoding UTF8 -LiteralPath $workflowPath
    $workflowText = $workflowText -replace 'contents: read', 'contents: write'
    [IO.File]::WriteAllText($workflowPath, $workflowText, [Text.UTF8Encoding]::new($false))
    Assert-ValidatorResult 'write-enabled workflow' 1 (Invoke-FixtureValidator $writePermission) 'Validation workflow grants write permission'

    $orphanResource = New-TestFixture 'orphan-skill-resource'
    $orphanPath = Join-Path $orphanResource 'skills\tdd\references\orphan.md'
    [IO.File]::WriteAllText($orphanPath, "# Orphan`n", [Text.UTF8Encoding]::new($false))
    Assert-ValidatorResult 'orphan skill resource' 1 (Invoke-FixtureValidator $orphanResource) 'resource is unreachable from SKILL\.md'

    $indirectResource = New-TestFixture 'indirect-resource-link'
    $nestedReferencePath = Join-Path $indirectResource 'skills\tdd\references\nested.md'
    [IO.File]::WriteAllText($nestedReferencePath, "# Nested evidence`n", [Text.UTF8Encoding]::new($false))
    $testsReferencePath = Join-Path $indirectResource 'skills\tdd\references\tests.md'
    [IO.File]::AppendAllText($testsReferencePath, "`n[Read the nested evidence](nested.md)`n", [Text.UTF8Encoding]::new($false))
    Assert-ValidatorResult 'indirect resource link' 0 (Invoke-FixtureValidator $indirectResource) 'validation passed'

    $escapingLink = New-TestFixture 'escaping-relative-link'
    $readmePath = Join-Path $escapingLink 'README.md'
    [IO.File]::AppendAllText($readmePath, "`n[escape](../outside.md)`n", [Text.UTF8Encoding]::new($false))
    Assert-ValidatorResult 'escaping relative link' 1 (Invoke-FixtureValidator $escapingLink) 'Relative link escapes repository root'

    $escapingSkillLink = New-TestFixture 'escaping-skill-link'
    $skillPath = Join-Path $escapingSkillLink 'skills\tdd\SKILL.md'
    [IO.File]::AppendAllText($skillPath, "`n[repository file](../../README.md)`n", [Text.UTF8Encoding]::new($false))
    Assert-ValidatorResult 'escaping skill link' 1 (Invoke-FixtureValidator $escapingSkillLink) 'Relative link escapes skill root'

    $invalidPowerShell = New-TestFixture 'invalid-powershell-resource'
    $probePath = Join-Path $invalidPowerShell 'skills\diagnosing-bugs\scripts\Test-WindowsGitHubAuthContext.ps1'
    [IO.File]::AppendAllText($probePath, "`nif (`n", [Text.UTF8Encoding]::new($false))
    Assert-ValidatorResult 'invalid PowerShell resource' 1 (Invoke-FixtureValidator $invalidPowerShell) 'Invalid PowerShell syntax'

    $invalidUtf8 = New-TestFixture 'invalid-utf8-resource'
    $referencePath = Join-Path $invalidUtf8 'skills\tdd\references\tests.md'
    $referenceBytes = [IO.File]::ReadAllBytes($referencePath)
    [IO.File]::WriteAllBytes($referencePath, [byte[]]($referenceBytes + [byte[]](0xC3, 0x28)))
    Assert-ValidatorResult 'invalid UTF-8 resource' 1 (Invoke-FixtureValidator $invalidUtf8) 'Text file is not valid UTF-8'
} finally {
    $resolvedTemporaryRoot = [IO.Path]::GetFullPath($temporaryRoot)
    $expectedPrefix = $temporaryParent.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar + 'codex-vibe-skills-validator-tests-'
    if (-not $resolvedTemporaryRoot.StartsWith($expectedPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove unexpected test path: $resolvedTemporaryRoot"
    }
    if (Test-Path -LiteralPath $resolvedTemporaryRoot) {
        Remove-Item -Recurse -Force -LiteralPath $resolvedTemporaryRoot
    }
}

if ($errors.Count -gt 0) {
    Write-Host "Validator behavior tests failed with $($errors.Count) error(s):" -ForegroundColor Red
    $errors | ForEach-Object { Write-Host "- $_" -ForegroundColor Red }
    exit 1
}

Write-Host 'Validator behavior tests passed.' -ForegroundColor Green
