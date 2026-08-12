[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RepositoryPath
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $RepositoryPath -PathType Container)) {
    throw "Repository path is not a directory: $RepositoryPath"
}

$resolvedRepository = (Resolve-Path -LiteralPath $RepositoryPath).Path
$identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$ghCommand = Get-Command gh -ErrorAction SilentlyContinue
$gitCommand = Get-Command git -ErrorAction SilentlyContinue

function Protect-SensitiveText([string]$Text) {
    $protected = $Text
    $protected = $protected -replace '(?i)(Token:)\s*.*$', '$1 [redacted]'
    $protected = $protected -replace '(?i)\b(?:gh[pousr]_[A-Za-z0-9_]{8,}|github_pat_[A-Za-z0-9_]{8,})\b', '[redacted-token]'
    $protected = $protected -replace '(?i)(authorization\s*:\s*(?:bearer|token)\s+)\S+', '$1[redacted]'
    $protected = $protected -replace '(?i)(account)\s+\S+', '$1 [redacted]'
    $protected = $protected -replace '(?i)(-u\s+)\S+', '$1[redacted]'
    $protected = $protected -replace '(?i)([?&](?:access_token|token|oauth_token)=)[^&\s]+', '$1[redacted]'
    $protected = $protected -replace '(?i)(https?://)[^/@\s]+@', '$1[redacted]@'
    return $protected
}

$tokenPresence = [ordered]@{}
foreach ($name in @('GH_TOKEN', 'GITHUB_TOKEN', 'GH_ENTERPRISE_TOKEN', 'GITHUB_ENTERPRISE_TOKEN')) {
    $tokenPresence[$name] = -not [string]::IsNullOrEmpty([Environment]::GetEnvironmentVariable($name))
}

$credentialHelperCount = 0
$remoteProtocol = $null
$gitRepositoryValid = $false
$gitRepositoryProbeExitCode = $null
if ($null -ne $gitCommand) {
    $safeDirectory = $resolvedRepository.Replace('\', '/')
    $gitRepositoryProbe = (& $gitCommand.Source -c "safe.directory=$safeDirectory" -C $resolvedRepository rev-parse --is-inside-work-tree 2>$null | Select-Object -First 1)
    $gitRepositoryProbeExitCode = $LASTEXITCODE
    $gitRepositoryValid = $gitRepositoryProbeExitCode -eq 0 -and $gitRepositoryProbe -eq 'true'

    if ($gitRepositoryValid) {
        $credentialHelpers = @(
            & $gitCommand.Source -c "safe.directory=$safeDirectory" -C $resolvedRepository config --show-origin --get-all credential.helper 2>$null |
                ForEach-Object { $_.ToString() }
        )
        $credentialHelperCount = $credentialHelpers.Count
        $remote = (& $gitCommand.Source -c "safe.directory=$safeDirectory" -C $resolvedRepository remote get-url origin 2>$null | Select-Object -First 1)
        if (-not [string]::IsNullOrWhiteSpace($remote)) {
            if ($remote -match '^https?://') { $remoteProtocol = 'https' }
            elseif ($remote -match '^(ssh://|git@)') { $remoteProtocol = 'ssh' }
            else { $remoteProtocol = 'other' }
        }
    }
}

$ghAuthOutput = @()
$ghAuthExitCode = $null
$ghVersion = $null
if ($null -ne $ghCommand) {
    $ghVersion = (& $ghCommand.Source --version | Select-Object -First 1).ToString()
    $savedErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $ghAuthOutput = @(& $ghCommand.Source auth status 2>&1 | ForEach-Object { $_.ToString() })
    $ghAuthExitCode = $LASTEXITCODE
    $ErrorActionPreference = $savedErrorActionPreference
    $ghAuthOutput = @($ghAuthOutput | ForEach-Object { Protect-SensitiveText $_ })
}

[ordered]@{
    timestamp_utc = [DateTime]::UtcNow.ToString('o')
    identity = $identity
    repository = $resolvedRepository
    git_executable = if ($null -ne $gitCommand) { $gitCommand.Source } else { $null }
    git_repository_valid = $gitRepositoryValid
    git_repository_probe_exit_code = $gitRepositoryProbeExitCode
    gh_executable = if ($null -ne $ghCommand) { $ghCommand.Source } else { $null }
    gh_version = $ghVersion
    remote_protocol = $remoteProtocol
    token_environment_present = $tokenPresence
    credential_helper_count = $credentialHelperCount
    gh_authenticated = ($null -ne $ghCommand -and $ghAuthExitCode -eq 0)
    gh_auth_exit_code = $ghAuthExitCode
    gh_auth_output_redacted = $ghAuthOutput
} | ConvertTo-Json -Depth 4

if ($null -eq $gitCommand -or -not $gitRepositoryValid -or $null -eq $ghCommand -or $ghAuthExitCode -ne 0) { exit 1 }
