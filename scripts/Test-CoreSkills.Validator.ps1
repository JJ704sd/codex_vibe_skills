[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$validatorPath = Join-Path $repositoryRoot 'scripts\Test-CoreSkills.ps1'
$temporaryParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$temporaryRoot = Join-Path $temporaryParent ('codex-vibe-skills-validator-tests-' + [guid]::NewGuid().ToString('N'))
$errors = [System.Collections.Generic.List[string]]::new()

function New-TestFixture([string]$Name) {
    $fixtureRoot = Join-Path $temporaryRoot $Name
    New-Item -ItemType Directory -Path $fixtureRoot | Out-Null
    foreach ($path in @('README.md', 'docs', 'skills')) {
        Copy-Item -Recurse -LiteralPath (Join-Path $repositoryRoot $path) -Destination $fixtureRoot
    }
    $fixtureScripts = Join-Path $fixtureRoot 'scripts'
    New-Item -ItemType Directory -Path $fixtureScripts | Out-Null
    Copy-Item -LiteralPath $validatorPath -Destination $fixtureScripts
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

    $missingGitCiContract = New-TestFixture 'missing-git-ci-contract'
    $skillPath = Join-Path $missingGitCiContract 'skills\tdd\SKILL.md'
    $skillText = Get-Content -Raw -Encoding UTF8 -LiteralPath $skillPath
    $skillText = $skillText -replace 'Map the focused and broad local commands to the repository CI jobs and required checks', 'Run the focused and broad local commands'
    [IO.File]::WriteAllText($skillPath, $skillText, [Text.UTF8Encoding]::new($false))
    Assert-ValidatorResult 'missing Git and CI contract' 1 (Invoke-FixtureValidator $missingGitCiContract) 'Git/CI contract missing'
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
