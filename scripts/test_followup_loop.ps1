# End-to-end test of the human-gated follow-up loop, using a throwaway Git
# repository. It never starts an agent and never needs Docker or sbx: it seeds
# the reviewer's output by hand, then exercises Promote-Followup and Submit-Task.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$starter = (Resolve-Path (Join-Path $PSScriptRoot '../src/agent-pipeline-demo-starter')).Path
$root = Join-Path ([System.IO.Path]::GetTempPath()) ('pipeline-followup-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$origin = Join-Path $root 'origin.git'
$control = Join-Path $root 'control'

function Invoke-ControlGit {
    param([string[]]$Arguments)
    $previous = $ErrorActionPreference
    try {
        # Windows PowerShell 5.1 turns redirected native stderr into error records.
        $ErrorActionPreference = 'Continue'
        $output = & git -C $control @Arguments 2>&1
        $exitCode = $LASTEXITCODE
    }
    finally { $ErrorActionPreference = $previous }
    if ($exitCode -ne 0) { throw "git $($Arguments -join ' ') failed:`n$output" }
    return ($output -join "`n").Trim()
}

function Assert-Fails {
    param([string]$Label, [scriptblock]$Action)
    try { & $Action 2>&1 | Out-Null } catch { Write-Host "  rejected: $Label" -ForegroundColor DarkGray; return }
    throw "Expected rejection: $Label"
}

function Get-PendingTaskPath {
    $pending = @((Invoke-ControlGit @('status', '--porcelain', '--untracked-files=all')) -split "`n" | Where-Object { $_ })
    if ($pending.Count -ne 1) { throw "Expected exactly one pending file; found: $($pending -join '; ')" }
    return (Join-Path $control ($pending[0] -replace '^\s*\S+\s+', ''))
}

# Seeds what a reviewer would have committed for $TaskId. An empty $Slug means the
# instruction file already exists because it was submitted for real.
function Add-ReviewerOutput {
    param([string]$TaskId, [string]$Slug, [string]$Reason)
    if ($Slug) {
        $frontMatter = @('---', "id: $TaskId", 'title: Seeded', '---', '', '# Goal', 'Seeded task.')
        Set-Content -LiteralPath (Join-Path $control "builder-instructions/$TaskId-$Slug.md") -Value ($frontMatter -join "`n") -Encoding UTF8
    }
    Set-Content -LiteralPath (Join-Path $control "reviews/$TaskId.md") -Value "# Review $TaskId" -Encoding UTF8
    $draft = @('---', 'id:', "parent-task: $TaskId", 'title: Next round', "follow-up-reason: $Reason", '---', '', '# Goal', 'Do the next thing.')
    if ($Reason -eq 'decision-required') { $draft += @('', '# Decisions required', '1. Which option?') }
    Set-Content -LiteralPath (Join-Path $control "followups/$TaskId.draft.md") -Value ($draft -join "`n") -Encoding UTF8
    Invoke-ControlGit @('add', '-A') | Out-Null
    Invoke-ControlGit @('commit', '-m', "seed reviewer output for $TaskId") | Out-Null
    Invoke-ControlGit @('push', 'origin', 'main') | Out-Null
}

try {
    New-Item -ItemType Directory -Path $root, $control | Out-Null
    & git init --bare $origin | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Could not create the bare test remote.' }
    Get-ChildItem -LiteralPath (Join-Path $starter 'template') -Force | Copy-Item -Destination $control -Recurse -Force
    Invoke-ControlGit @('init', '-b', 'main') | Out-Null
    Invoke-ControlGit @('config', 'user.name', 'Pipeline Test') | Out-Null
    Invoke-ControlGit @('config', 'user.email', 'test@agent-pipeline.local') | Out-Null
    Invoke-ControlGit @('add', '.') | Out-Null
    Invoke-ControlGit @('commit', '-m', 'init') | Out-Null
    Invoke-ControlGit @('remote', 'add', 'origin', $origin) | Out-Null
    Invoke-ControlGit @('push', '-u', 'origin', 'main') | Out-Null

    $promote = Join-Path $control 'automation/Promote-Followup.ps1'
    $submit = Join-Path $control 'automation/Submit-Task.ps1'

    Add-ReviewerOutput 'TASK-0001' 'first' 'changes-requested'

    # A draft becomes a real task only through promotion, and promotion never commits.
    & $promote -TaskId 'TASK-0001' -Slug 'fix-validation' | Out-Null
    $promoted = Join-Path $control 'builder-instructions/TASK-0002-fix-validation.md'
    if (-not (Test-Path -LiteralPath $promoted)) { throw 'Promotion did not write the task file.' }
    $text = Get-Content -LiteralPath $promoted -Raw
    if ($text -notmatch '(?m)^id: TASK-0002$') { throw 'Promotion did not assign the next id.' }
    if ($text -notmatch '(?m)^parent-task: TASK-0001$') { throw 'Promotion dropped parent-task.' }
    if ($text -notmatch 'Do the next thing\.') { throw 'Promotion dropped the draft body.' }
    if (-not (Invoke-ControlGit @('status', '--porcelain'))) { throw 'Promotion must not commit; sign-off is the human step.' }

    & $submit -Path $promoted | Out-Null
    $body = Invoke-ControlGit @('show', '-s', '--format=%B', 'HEAD')
    if ($body -notmatch 'Agent-Event: instruction' -or $body -notmatch 'Task-ID: TASK-0002') {
        throw "Sign-off commit lacks instruction trailers:`n$body"
    }

    Assert-Fails 'promoting an already-promoted draft' { & $promote -TaskId 'TASK-0001' -Slug 'again' }
    & $promote -TaskId 'TASK-0001' -Slug 'forked' -Force | Out-Null
    if (-not (Test-Path -LiteralPath (Join-Path $control 'builder-instructions/TASK-0003-forked.md'))) {
        throw '-Force should allow a deliberate fork.'
    }
    Remove-Item -LiteralPath (Join-Path $control 'builder-instructions/TASK-0003-forked.md')
    Assert-Fails 'promoting a task that has no draft' { & $promote -TaskId 'TASK-0099' -Slug 'nope' }
    Assert-Fails 'a slug that is not lowercase-hyphenated' { & $promote -TaskId 'TASK-0001' -Slug 'Bad Slug' -Force }

    # The budget is committed as followups.maxRounds; rounds beyond it are refused.
    $maxRounds = 3
    $current = 'TASK-0002'
    foreach ($round in 2..$maxRounds) {
        Add-ReviewerOutput $current '' 'changes-requested'
        & $promote -TaskId $current -Slug "round$round" | Out-Null
        $path = Get-PendingTaskPath
        & $submit -Path $path | Out-Null
        $current = [regex]::Match([System.IO.Path]::GetFileName($path), '^TASK-[0-9]+').Value
    }
    Add-ReviewerOutput $current '' 'changes-requested'
    Assert-Fails "round $($maxRounds + 1), beyond followups.maxRounds" { & $promote -TaskId $current -Slug 'over-budget' }

    Add-ReviewerOutput 'TASK-0050' 'decide' 'decision-required'
    & $promote -TaskId 'TASK-0050' -Slug 'decide-next' | Out-Null
    if ((Get-Content -LiteralPath (Get-PendingTaskPath) -Raw) -notmatch '# Decisions required') {
        throw 'Promotion dropped the Decisions required section.'
    }

    Write-Host 'Follow-up loop: promotion, sign-off, fork guard and round budget passed.'
}
finally {
    if (Test-Path -LiteralPath $root) { Remove-Item -Recurse -Force $root }
}
