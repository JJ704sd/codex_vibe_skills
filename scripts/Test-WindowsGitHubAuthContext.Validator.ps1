[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$probePath = Join-Path $repositoryRoot 'skills\diagnosing-bugs\scripts\Test-WindowsGitHubAuthContext.ps1'
$temporaryParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$temporaryRoot = Join-Path $temporaryParent ('codex-vibe-skills-auth-probe-tests-' + [guid]::NewGuid().ToString('N'))
$errors = [System.Collections.Generic.List[string]]::new()

function Add-TestError([string]$Message) {
    $errors.Add($Message)
}

function Write-FakeCommands([string]$BinPath) {
    New-Item -ItemType Directory -Path $BinPath | Out-Null
    $ghCommand = @'
@echo off
if "%1"=="--version" (
  echo gh version 0.0.0-test
  exit /b 0
)
if "%1"=="auth" if "%2"=="status" (
  echo github.com
  echo Logged in to github.com account octocat
  echo Token: ghp_FAKESECRET123456
  echo Endpoint: https://ghp_URLSECRET123456@example.invalid
  exit /b 0
)
exit /b 2
'@
    $gitCommand = @'
@echo off
echo %* | findstr /c:"rev-parse --is-inside-work-tree" >nul
if not errorlevel 1 (
  if "%CODEX_TEST_GIT_VALID%"=="1" (
    echo true
    exit /b 0
  )
  exit /b 128
)
echo %* | findstr /c:"config --show-origin --get-all credential.helper" >nul
if not errorlevel 1 (
  echo file:test credential-manager
  exit /b 0
)
echo %* | findstr /c:"remote get-url origin" >nul
if not errorlevel 1 (
  echo https://example.invalid/repository.git
  exit /b 0
)
exit /b 0
'@
    [IO.File]::WriteAllText((Join-Path $BinPath 'gh.cmd'), $ghCommand, [Text.ASCIIEncoding]::new())
    [IO.File]::WriteAllText((Join-Path $BinPath 'git.cmd'), $gitCommand, [Text.ASCIIEncoding]::new())
}

function Invoke-ProbeFixture([string]$RepositoryPath, [bool]$GitValid, [string]$BinPath) {
    $savedPath = $env:PATH
    $savedGitValid = $env:CODEX_TEST_GIT_VALID
    try {
        $env:PATH = $BinPath + [IO.Path]::PathSeparator + $savedPath
        $env:CODEX_TEST_GIT_VALID = if ($GitValid) { '1' } else { '0' }
        $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $probePath -RepositoryPath $RepositoryPath 2>&1 | Out-String
        return [PSCustomObject]@{
            ExitCode = $LASTEXITCODE
            Output = $output.Trim()
        }
    } finally {
        $env:PATH = $savedPath
        $env:CODEX_TEST_GIT_VALID = $savedGitValid
    }
}

New-Item -ItemType Directory -Path $temporaryRoot | Out-Null
try {
    $fakeBin = Join-Path $temporaryRoot 'bin'
    Write-FakeCommands $fakeBin
    $validRepository = Join-Path $temporaryRoot 'valid-repository'
    $invalidRepository = Join-Path $temporaryRoot 'not-a-repository'
    New-Item -ItemType Directory -Path $validRepository, $invalidRepository | Out-Null

    $valid = Invoke-ProbeFixture $validRepository $true $fakeBin
    if ($valid.ExitCode -ne 0) {
        Add-TestError "valid repository: expected exit 0, got $($valid.ExitCode). Output: $($valid.Output)"
    } else {
        try {
            $validJson = $valid.Output | ConvertFrom-Json
            if (-not $validJson.git_repository_valid) { Add-TestError 'valid repository: Git preflight was not reported as valid' }
            if (-not $validJson.gh_authenticated) { Add-TestError 'valid repository: gh authentication was not reported as valid' }
            if ($valid.Output -match 'ghp_FAKESECRET123456|ghp_URLSECRET123456') { Add-TestError 'valid repository: token-like text was not redacted' }
            if ($valid.Output -notmatch '\[redacted\]') { Add-TestError 'valid repository: expected redaction marker is missing' }
        } catch {
            Add-TestError "valid repository: output is not valid JSON. $($_.Exception.Message)"
        }
    }

    $invalid = Invoke-ProbeFixture $invalidRepository $false $fakeBin
    if ($invalid.ExitCode -ne 1) {
        Add-TestError "invalid repository: expected exit 1, got $($invalid.ExitCode). Output: $($invalid.Output)"
    } else {
        try {
            $invalidJson = $invalid.Output | ConvertFrom-Json
            if ($invalidJson.git_repository_valid) { Add-TestError 'invalid repository: Git preflight was incorrectly reported as valid' }
            if (-not $invalidJson.gh_authenticated) { Add-TestError 'invalid repository: fixture did not isolate the Git preflight failure' }
        } catch {
            Add-TestError "invalid repository: output is not valid JSON. $($_.Exception.Message)"
        }
    }
} finally {
    $resolvedTemporaryRoot = [IO.Path]::GetFullPath($temporaryRoot)
    $expectedPrefix = $temporaryParent.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar + 'codex-vibe-skills-auth-probe-tests-'
    if (-not $resolvedTemporaryRoot.StartsWith($expectedPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove unexpected test path: $resolvedTemporaryRoot"
    }
    if (Test-Path -LiteralPath $resolvedTemporaryRoot) {
        Remove-Item -Recurse -Force -LiteralPath $resolvedTemporaryRoot
    }
}

if ($errors.Count -gt 0) {
    Write-Host "Windows GitHub auth probe tests failed with $($errors.Count) error(s):" -ForegroundColor Red
    $errors | ForEach-Object { Write-Host "- $_" -ForegroundColor Red }
    exit 1
}

Write-Host 'Windows GitHub auth probe tests passed.' -ForegroundColor Green
