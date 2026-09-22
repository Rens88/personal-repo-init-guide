# Human-run setup gate for workspaces initialized from a remote. Does not run agents.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'Task-Validation.ps1')
$control = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$rootPath = Split-Path $control -Parent
$state = Join-Path $rootPath 'state'
$pending = Join-Path $state 'setup-pending'
if (-not (Test-Path -LiteralPath $pending)) { throw 'No initial setup is pending. This command must not be used to skip tasks.' }
function Read-Git {
    param([string[]]$Arguments)
    $output = & git -C $control @Arguments
    if ($LASTEXITCODE -ne 0) { throw 'Git setup check failed.' }
    return ($output -join "`n").Trim()
}
if (Read-Git @('status', '--porcelain', '--untracked-files=all')) { throw 'Review and commit setup changes first.' }
$head = Read-Git @('rev-parse', 'HEAD')
$branch = Read-Git @('branch', '--show-current')
if ($branch -ne 'main') { throw 'The local pipeline must use main.' }
$expectedOrigin = [IO.Path]::GetFullPath((Join-Path $rootPath 'origin.git'))
$actualOrigin = Read-Git @('remote', 'get-url', 'origin')
if ([IO.Path]::GetFullPath($actualOrigin) -ne $expectedOrigin) { throw 'origin must point to the sibling local bare remote.' }
$remoteHead = & git "--git-dir=$expectedOrigin" rev-parse refs/heads/main
if ($LASTEXITCODE -ne 0 -or $remoteHead -ne $head) { throw 'Push the approved setup to local origin/main first.' }
$config = Read-Git @('show', 'HEAD:agent-pipeline.config.json')
$null = Get-TaskValidation "---`nid: TASK-0000`n---`n" $config 'TASK-0000' { param($gitArguments) Read-Git $gitArguments } $head
# All pre-existing history is baseline, not a queue of pipeline jobs to replay.
$history = Read-Git @('rev-list', 'HEAD')
Set-Content -LiteralPath (Join-Path $state 'processed-commits.txt') -Value $history -Encoding ASCII
Remove-Item -LiteralPath $pending
Write-Host 'Initial setup accepted. Historical commits will not be dispatched.' -ForegroundColor Green
