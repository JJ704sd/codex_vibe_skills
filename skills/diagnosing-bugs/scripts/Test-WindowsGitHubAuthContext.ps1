[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RepositoryPath
)

$ErrorActionPreference = 'Stop'
$resolvedRepository = (Resolve-Path -LiteralPath $RepositoryPath).Path
$identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$ghCommand = Get-Command gh -ErrorAction SilentlyContinue
$gitCommand = Get-Command git -ErrorAction SilentlyContinue

$tokenPresence = [ordered]@{}
foreach ($name in @('GH_TOKEN', 'GITHUB_TOKEN', 'GH_ENTERPRISE_TOKEN', 'GITHUB_ENTERPRISE_TOKEN')) {
    $tokenPresence[$name] = -not [string]::IsNullOrEmpty([Environment]::GetEnvironmentVariable($name))
}

$credentialHelperCount = 0
$remoteProtocol = $null
if ($null -ne $gitCommand) {
    $credentialHelpers = @(
        & $gitCommand.Source -c "safe.directory=$($resolvedRepository.Replace('\', '/'))" -C $resolvedRepository config --show-origin --get-all credential.helper 2>$null |
            ForEach-Object { $_.ToString() }
    )
    $credentialHelperCount = $credentialHelpers.Count
    $remote = (& $gitCommand.Source -c "safe.directory=$($resolvedRepository.Replace('\', '/'))" -C $resolvedRepository remote get-url origin 2>$null | Select-Object -First 1)
    if (-not [string]::IsNullOrWhiteSpace($remote)) {
        if ($remote -match '^https?://') { $remoteProtocol = 'https' }
        elseif ($remote -match '^(ssh://|git@)') { $remoteProtocol = 'ssh' }
        else { $remoteProtocol = 'other' }
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
    $ghAuthOutput = @($ghAuthOutput | ForEach-Object {
        $_ -replace '(?i)(Token:)\s*.*$', '$1 [redacted]' `
           -replace '(?i)(account)\s+\S+', '$1 [redacted]' `
           -replace '(?i)(-u\s+)\S+', '$1[redacted]' `
           -replace '(?i)(oauth_token=)[^\s&]+', '$1[redacted]' `
           -replace '(?i)(https?://)[^/@\s]+@', '$1[redacted]@'
    })
}

[ordered]@{
    timestamp_utc = [DateTime]::UtcNow.ToString('o')
    identity = $identity
    repository = $resolvedRepository
    git_executable = if ($null -ne $gitCommand) { $gitCommand.Source } else { $null }
    gh_executable = if ($null -ne $ghCommand) { $ghCommand.Source } else { $null }
    gh_version = $ghVersion
    remote_protocol = $remoteProtocol
    token_environment_present = $tokenPresence
    credential_helper_count = $credentialHelperCount
    gh_authenticated = ($null -ne $ghCommand -and $ghAuthExitCode -eq 0)
    gh_auth_exit_code = $ghAuthExitCode
    gh_auth_output_redacted = $ghAuthOutput
} | ConvertTo-Json -Depth 4

if ($null -eq $ghCommand -or $ghAuthExitCode -ne 0) { exit 1 }
