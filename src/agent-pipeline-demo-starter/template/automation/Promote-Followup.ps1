# Turns a reviewer-authored follow-up draft into a submittable task file.
# It never commits: you read, edit and then run Submit-Task.ps1. That commit is
# the sign-off, so no separate approval mechanism exists or is needed.
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TaskId,

    [Parameter(Mandatory = $true)]
    [string]$Slug,

    [Parameter(Mandatory = $false)]
    [string]$NewId,

    # Deliberately fork a thread that already has a committed follow-up.
    [Parameter(Mandatory = $false)]
    [switch]$Force
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot "Task-Validation.ps1")

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
if (Test-Path -LiteralPath (Join-Path (Split-Path $repoRoot -Parent) 'state/setup-pending')) {
    throw 'Confirm initial pipeline setup before promoting follow-ups.'
}

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

if ($TaskId -notmatch '^TASK-[0-9]+$') { throw "Malformed -TaskId: $TaskId" }
if ($Slug -notmatch '^[a-z0-9]+(-[a-z0-9]+)*$') {
    throw "-Slug must be lowercase words separated by single hyphens: $Slug"
}

Invoke-Git @("pull", "--ff-only", "origin", "main") | Out-Host

$pending = @((Invoke-Git @("status", "--porcelain", "--untracked-files=all")) -split "`n" | Where-Object { $_ })
if ($pending.Count) {
    throw "Commit or discard local changes before promoting. Current status:`n$($pending -join "`n")"
}

$reviewFile = "reviews/$TaskId.md"
$draftFile = "followups/$TaskId.draft.md"
foreach ($required in @($reviewFile, $draftFile)) {
    $entry = Invoke-Git @("ls-tree", "HEAD", "--", $required)
    if ($entry -notmatch '^100(644|755) blob ') {
        throw "Expected a committed regular file at $required. Has $TaskId been reviewed with a non-PASS verdict?"
    }
}

$draftContents = Invoke-Git @("show", "HEAD:$draftFile")
$draftFields = Get-TaskFields $draftContents
$reason = $draftFields['follow-up-reason']
if ($reason -notin @('changes-requested', 'decision-required')) {
    throw "Unexpected follow-up-reason in ${draftFile}: $reason"
}
if ($draftFields['parent-task'] -cne $TaskId) {
    throw "Draft parent-task does not match $TaskId."
}

# Promoting the same draft twice silently forks the thread into two live
# branches that each believe they continue it. The pattern is anchored so that
# TASK-0001 does not also match TASK-00011. git grep exits 1 for no match.
$previousErrorActionPreference = $ErrorActionPreference
try {
    $ErrorActionPreference = "Continue"
    $children = & git -C $repoRoot grep -l -E "^parent-task:[ `t]*$TaskId[ `t]*$" HEAD -- builder-instructions 2>&1
    $grepExit = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
if ($grepExit -gt 1) { throw "git grep failed:`n$($children -join "`n")" }
if ($grepExit -eq 0 -and -not $Force) {
    throw "$TaskId already has a committed follow-up ($($children -join ', ')). Pass -Force only if you mean to fork this thread."
}

$existingTaskFiles = @((Invoke-Git @("ls-tree", "-r", "--name-only", "HEAD", "--", "builder-instructions")) -split "`n" | Where-Object { $_ })
if ($NewId) {
    if ($NewId -notmatch '^TASK-[0-9]+$') { throw "Malformed -NewId: $NewId" }
}
else {
    $highest = 0
    foreach ($file in $existingTaskFiles) {
        if ([System.IO.Path]::GetFileName($file) -match '^TASK-([0-9]+)-') {
            $number = [int]$Matches[1]
            if ($number -gt $highest) { $highest = $number }
        }
    }
    $NewId = "TASK-{0:D4}" -f ($highest + 1)
}
if ($NewId -ceq $TaskId) { throw 'The follow-up needs a new task id; ids are immutable.' }

$clash = @($existingTaskFiles | Where-Object {
    [System.IO.Path]::GetFileName($_).StartsWith("$NewId-", [System.StringComparison]::OrdinalIgnoreCase)
})
if ($clash.Count) { throw "Task ids are immutable and unique. $NewId already exists at: $($clash -join ', ')" }

# Fill in the id inside the front matter only; the body is left exactly as written.
$document = Split-TaskDocument $draftContents
$updatedFields = $document.FrontMatter
if ($updatedFields -match '(?m)^id:') {
    $updatedFields = [regex]::Replace($updatedFields, '(?m)^id:.*$', "id: $NewId")
}
else {
    $updatedFields = "id: $NewId`n$updatedFields"
}
$promoted = "---`n" + $updatedFields + "`n---`n" + $document.Body
$relativePath = "builder-instructions/$NewId-$Slug.md"
$targetPath = Join-Path $repoRoot $relativePath
Assert-SafeRepoPath $relativePath
if (Test-Path -LiteralPath $targetPath) { throw "Refusing to overwrite $relativePath." }

# Prove the promoted text is submittable before writing it to disk. This also
# walks the parent-task chain, so an over-budget thread fails here, while you are
# still deciding whether it is worth another round.
$configuration = Invoke-Git @('show', 'HEAD:agent-pipeline.config.json')
$validation = Get-TaskValidation $promoted $configuration $NewId { param($gitArguments) Invoke-Git $gitArguments } "HEAD"
$round = $validation.FOLLOWUP_ROUND
$maxRounds = $validation.MAX_FOLLOWUP_ROUNDS

Set-Content -LiteralPath $targetPath -Value $promoted -Encoding UTF8 -NoNewline

Write-Host ""
Write-Host "Promoted $TaskId -> $NewId (follow-up round $round of $maxRounds, reason: $reason)" -ForegroundColor Green
Write-Host "Written to: $relativePath" -ForegroundColor Green
Write-Host "The draft stays committed at $draftFile as the audit trail." -ForegroundColor DarkGray
Write-Host ""
if ($reason -eq 'decision-required') {
    Write-Host "This follow-up needs YOUR DECISION." -ForegroundColor Yellow
    Write-Host "Answer every question under 'Decisions required', then delete that section." -ForegroundColor Yellow
}
else {
    Write-Host "No human decision was flagged. Read it anyway; you own what you submit." -ForegroundColor Cyan
}
Write-Host ""
Write-Host "Next:" -ForegroundColor Cyan
Write-Host "  1. Edit $relativePath"
Write-Host "  2. ./automation/Submit-Task.ps1 -Path ./$relativePath"
