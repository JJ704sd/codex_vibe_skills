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
    $fakeCommandSource = @'
using System;
using System.IO;

public static class FakeCommand
{
    public static int Main(string[] args)
    {
        string command = Path.GetFileNameWithoutExtension(Environment.GetCommandLineArgs()[0]);
        if (String.Equals(command, "gh", StringComparison.OrdinalIgnoreCase)) return RunGh(args);
        if (String.Equals(command, "git", StringComparison.OrdinalIgnoreCase)) return RunGit(args);
        return 2;
    }

    private static int RunGh(string[] args)
    {
        if (HasSequence(args, "--version"))
        {
            Console.WriteLine("gh version 0.0.0-test");
            return 0;
        }
        if (HasSequence(args, "auth", "status"))
        {
            Console.WriteLine("github.com");
            Console.WriteLine("Logged in to github.com account octocat");
            Console.WriteLine("Token: ghp_FAKESECRET123456");
            Console.WriteLine("Endpoint: https://ghp_URLSECRET123456@example.invalid");
            return Environment.GetEnvironmentVariable("CODEX_TEST_GH_AUTH_VALID") == "1" ? 0 : 1;
        }
        return 2;
    }

    private static int RunGit(string[] args)
    {
        if (HasSequence(args, "rev-parse", "--is-inside-work-tree"))
        {
            if (Environment.GetEnvironmentVariable("CODEX_TEST_GIT_VALID") != "1") return 128;
            Console.WriteLine("true");
            System.Threading.Thread.Sleep(250);
            return 0;
        }
        if (HasSequence(args, "config", "--show-origin", "--get-all", "credential.helper"))
        {
            Console.WriteLine("file:test credential-manager");
            return 0;
        }
        if (HasSequence(args, "remote", "get-url", "origin"))
        {
            Console.WriteLine("https://example.invalid/repository.git");
            return 0;
        }
        return 2;
    }

    private static bool HasSequence(string[] args, params string[] expected)
    {
        for (int start = 0; start <= args.Length - expected.Length; start++)
        {
            bool matches = true;
            for (int offset = 0; offset < expected.Length; offset++)
            {
                if (!String.Equals(args[start + offset], expected[offset], StringComparison.Ordinal))
                {
                    matches = false;
                    break;
                }
            }
            if (matches) return true;
        }
        return false;
    }
}
'@
    $gitPath = Join-Path $BinPath 'git.exe'
    Add-Type -TypeDefinition $fakeCommandSource -Language CSharp -OutputAssembly $gitPath -OutputType ConsoleApplication
    Copy-Item -LiteralPath $gitPath -Destination (Join-Path $BinPath 'gh.exe')
}

function Invoke-ProbeFixture([string]$RepositoryPath, [bool]$GitValid, [bool]$GhAuthValid, [string]$BinPath) {
    $savedPath = $env:PATH
    $savedGitValid = $env:CODEX_TEST_GIT_VALID
    $savedGhAuthValid = $env:CODEX_TEST_GH_AUTH_VALID
    try {
        $env:PATH = $BinPath + [IO.Path]::PathSeparator + $savedPath
        $env:CODEX_TEST_GIT_VALID = if ($GitValid) { '1' } else { '0' }
        $env:CODEX_TEST_GH_AUTH_VALID = if ($GhAuthValid) { '1' } else { '0' }
        $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $probePath -RepositoryPath $RepositoryPath 2>&1 | Out-String
        return [PSCustomObject]@{
            ExitCode = $LASTEXITCODE
            Output = $output.Trim()
        }
    } finally {
        $env:PATH = $savedPath
        $env:CODEX_TEST_GIT_VALID = $savedGitValid
        $env:CODEX_TEST_GH_AUTH_VALID = $savedGhAuthValid
    }
}

New-Item -ItemType Directory -Path $temporaryRoot | Out-Null
try {
    $fakeBin = Join-Path $temporaryRoot 'bin'
    Write-FakeCommands $fakeBin
    $validRepository = Join-Path $temporaryRoot 'valid-repository'
    $invalidRepository = Join-Path $temporaryRoot 'not-a-repository'
    New-Item -ItemType Directory -Path $validRepository, $invalidRepository | Out-Null

    $valid = Invoke-ProbeFixture $validRepository $true $true $fakeBin
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

    $invalid = Invoke-ProbeFixture $invalidRepository $false $true $fakeBin
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

    $unauthenticated = Invoke-ProbeFixture $validRepository $true $false $fakeBin
    if ($unauthenticated.ExitCode -ne 1) {
        Add-TestError "unauthenticated context: expected exit 1, got $($unauthenticated.ExitCode). Output: $($unauthenticated.Output)"
    } else {
        try {
            $unauthenticatedJson = $unauthenticated.Output | ConvertFrom-Json
            if (-not $unauthenticatedJson.git_repository_valid) { Add-TestError 'unauthenticated context: valid Git repository was not preserved' }
            if ($unauthenticatedJson.gh_authenticated) { Add-TestError 'unauthenticated context: failed gh status was reported as authenticated' }
            if ($unauthenticatedJson.gh_auth_exit_code -ne 1) { Add-TestError 'unauthenticated context: gh exit code was not preserved' }
            if ($unauthenticated.Output -match 'ghp_FAKESECRET123456|ghp_URLSECRET123456') { Add-TestError 'unauthenticated context: token-like text was not redacted' }
        } catch {
            Add-TestError "unauthenticated context: output is not valid JSON. $($_.Exception.Message)"
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
