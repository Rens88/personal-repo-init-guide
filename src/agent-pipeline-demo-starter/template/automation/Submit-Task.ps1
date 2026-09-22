[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Path
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot "Task-Validation.ps1")

function Invoke-Git {
    param([string[]]$Arguments)
    $previousErrorActionPreference = $ErrorActionPreference
    try {
        # Windows PowerShell 5.1 turns redirected native stderr into error
        # records. Git writes normal fetch progress to stderr, so capture it
        # under Continue and rely on the process exit code instead.
        $ErrorActionPreference = "Continue"
        $output = & git -C $repoRoot @Arguments 2>&1
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    if ($exitCode -ne 0) {
        throw "git $($Arguments -join ' ') failed:`n$($output -join "`n")"
    }
    return ($output -join "`n").Trim()
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
if (Test-Path -LiteralPath (Join-Path (Split-Path $repoRoot -Parent) 'state/setup-pending')) {
    throw 'Confirm initial pipeline setup before submitting tasks.'
}
$taskPath = (Resolve-Path -LiteralPath $Path).Path
$repoUri = [System.Uri]::new($repoRoot.TrimEnd([char[]]@("\", "/")) + [System.IO.Path]::DirectorySeparatorChar)
$taskUri = [System.Uri]::new($taskPath)
$relativePath = [System.Uri]::UnescapeDataString($repoUri.MakeRelativeUri($taskUri).ToString()).Replace("\", "/")

if (-not $relativePath.StartsWith("builder-instructions/", [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Task file must be under builder-instructions/: $relativePath"
}

$fileName = [System.IO.Path]::GetFileName($taskPath)
if ($fileName -notmatch '^(TASK-[0-9]+)-.+\.md$') {
    throw "Task filename must look like TASK-0001-description.md: $fileName"
}
$taskId = $Matches[1].ToUpperInvariant()

$contents = Get-Content -LiteralPath $taskPath -Raw
if ($contents -notmatch "(?m)^id:\s*$([regex]::Escape($taskId))\s*$") {
    throw "Task front matter must contain: id: $taskId"
}

Invoke-Git @("pull", "--ff-only", "origin", "main") | Out-Host

$pending = @((Invoke-Git @("status", "--porcelain", "--untracked-files=all")) -split "`n" | Where-Object { $_ })
if ($pending.Count -ne 1 -or -not $pending[0].EndsWith($relativePath)) {
    throw "Only the submitted task file may be changed. Current status:`n$($pending -join "`n")"
}

$existingTaskFiles = @((Invoke-Git @("ls-tree", "-r", "--name-only", "HEAD", "--", "builder-instructions")) -split "`n" | Where-Object { $_ })
$matchingTask = @($existingTaskFiles | Where-Object { [System.IO.Path]::GetFileName($_).StartsWith("$taskId-", [System.StringComparison]::OrdinalIgnoreCase) })
if ($matchingTask.Count -gt 0) {
    throw "Task IDs are immutable and unique. $taskId already exists at: $($matchingTask -join ', ')"
}

Assert-SafeRepoPath $relativePath
$configuration = Invoke-Git @('show', 'HEAD:agent-pipeline.config.json')
$null = Get-TaskValidation $contents $configuration $taskId { param($gitArguments) Invoke-Git $gitArguments } "HEAD"

$subject = "instruction($taskId): submit task"
$body = "Agent-Event: instruction`nTask-ID: $taskId`nTask-File: $relativePath"

Invoke-Git @("add", "--", $relativePath) | Out-Null
Invoke-Git @("commit", "-m", $subject, "-m", $body) | Out-Host
Invoke-Git @("push", "origin", "main") | Out-Host

Write-Host "Submitted $taskId. The running dispatcher will pick it up." -ForegroundColor Green
