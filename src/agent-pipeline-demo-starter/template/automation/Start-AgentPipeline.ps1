[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Root = (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent),

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 300)]
    [int]$PollSeconds = 3,

    [Parameter(Mandatory = $false)]
    [string]$BuilderSandbox = "agent-demo-builder",

    [Parameter(Mandatory = $false)]
    [string]$ReviewerSandbox = "agent-demo-reviewer"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot "Task-Validation.ps1")

$rootPath = [System.IO.Path]::GetFullPath($Root)
$originPath = Join-Path $rootPath "origin.git"
$controlPath = Join-Path $rootPath "control"
$builderPath = Join-Path $rootPath "builder"
$reviewerPath = Join-Path $rootPath "reviewer"
$logsPath = Join-Path $rootPath "logs"
$statePath = Join-Path $rootPath "state"
$processedPath = Join-Path $statePath "processed-commits.txt"

foreach ($requiredPath in @($originPath, $controlPath, $builderPath, $reviewerPath, $logsPath, $statePath)) {
    if (-not (Test-Path -LiteralPath $requiredPath)) {
        throw "Required pipeline path is missing: $requiredPath"
    }
}

foreach ($command in @("git", "sbx")) {
    if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
        throw "Required command '$command' was not found in PATH."
    }
}

function Invoke-Git {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Repository,
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $previousErrorActionPreference = $ErrorActionPreference
    try {
        # Windows PowerShell 5.1 turns redirected native stderr into error
        # records. Git writes normal progress to stderr, so judge success by
        # its exit code rather than by the stderr stream.
        $ErrorActionPreference = "Continue"
        $output = & git -C $Repository @Arguments 2>&1
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    if ($exitCode -ne 0) {
        throw "git -C $Repository $($Arguments -join ' ') failed:`n$($output -join "`n")"
    }
    return ($output -join "`n").Trim()
}

function Invoke-OriginGit {
    param([string[]]$Arguments)
    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        $output = & git --git-dir=$originPath @Arguments 2>&1
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    if ($exitCode -ne 0) {
        throw "git --git-dir=$originPath $($Arguments -join ' ') failed:`n$($output -join "`n")"
    }
    return ($output -join "`n").Trim()
}

function Test-SandboxExists {
    param([string]$Name)

    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        $names = & sbx ls --quiet 2>&1
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    if ($exitCode -ne 0) {
        throw "sbx ls --quiet failed:`n$($names -join "`n")"
    }

    $normalizedNames = @($names | ForEach-Object { $_.ToString().Trim() } | Where-Object { $_ })
    return $normalizedNames -contains $Name
}

function Get-CommitBody {
    param([string]$Commit)
    return Invoke-OriginGit @("show", "-s", "--format=%B", $Commit)
}

function Get-Trailer {
    param(
        [string]$Body,
        [string]$Name,
        [switch]$Required
    )

    $match = [regex]::Match($Body, "(?mi)^$([regex]::Escape($Name)):\s*(.+?)\s*$")
    if (-not $match.Success) {
        if ($Required) {
            throw "Commit message is missing required trailer '$Name'."
        }
        return $null
    }
    return $match.Groups[1].Value.Trim()
}

function Sync-Checkout {
    param(
        [string]$Repository,
        [string]$Commit
    )

    Invoke-Git $Repository @("fetch", "origin", "main") | Out-Null
    Invoke-Git $Repository @("checkout", "-B", "main", $Commit) | Out-Null
    Invoke-Git $Repository @("reset", "--hard", $Commit) | Out-Null
    Invoke-Git $Repository @("clean", "-fdx") | Out-Null
}

function Assert-CleanSingleCommit {
    param(
        [string]$Repository,
        [string]$BaseCommit
    )

    $status = Invoke-Git $Repository @("status", "--porcelain", "--untracked-files=all")
    if ($status) {
        throw "Agent left an unclean working tree in ${Repository}:`n$status"
    }

    $head = Invoke-Git $Repository @("rev-parse", "HEAD")
    if ($head -eq $BaseCommit) {
        throw "Agent did not create a commit."
    }

    $count = Invoke-Git $Repository @("rev-list", "--count", "$BaseCommit..$head")
    if ($count -ne "1") {
        throw "Agent must create exactly one commit; found $count."
    }
    $parents = Invoke-Git $Repository @("show", "-s", "--format=%P", $head)
    if ($parents -ne $BaseCommit) { throw 'Agent commit must have the expected base as its only parent.' }
    return $head
}

function Expand-Prompt {
    param(
        [string]$TemplatePath,
        [hashtable]$Values
    )

    $prompt = Get-Content -LiteralPath $TemplatePath -Raw
    foreach ($key in $Values.Keys) {
        $prompt = $prompt.Replace("{{$key}}", [string]$Values[$key])
    }
    return $prompt
}

function Publish-Commit {
    param(
        [string]$Repository,
        [string]$ExpectedRemoteHead
    )

    $actualRemoteHead = Invoke-OriginGit @("rev-parse", "refs/heads/main")
    if ($actualRemoteHead -ne $ExpectedRemoteHead) {
        throw "Remote main changed during the agent run. Expected $ExpectedRemoteHead, found $actualRemoteHead. Nothing was pushed."
    }
    Invoke-Git $Repository @("push", "origin", "HEAD:refs/heads/main") | Out-Host
}

function Test-PublishedEvent {
    param(
        [string]$AfterCommit,
        [string]$Event,
        [string]$ReferenceTrailer,
        [string]$ReferenceValue
    )

    $laterCommits = @((Invoke-OriginGit @("rev-list", "$AfterCommit..refs/heads/main")) -split "`n" | Where-Object { $_ })
    foreach ($laterCommit in $laterCommits) {
        $laterBody = Get-CommitBody $laterCommit
        if ((Get-Trailer $laterBody "Agent-Event") -eq $Event -and
            (Get-Trailer $laterBody $ReferenceTrailer) -eq $ReferenceValue) {
            return $true
        }
    }
    return $false
}

function Assert-TaskMetadata {
    param(
        [string]$TaskId,
        [string]$TaskFile
    )

    if ($TaskId -notmatch '^TASK-[0-9]+$') {
        throw "Refusing malformed Task-ID: $TaskId"
    }
    if ($TaskFile -notmatch '^builder-instructions/TASK-[0-9]+-[^/]+\.md$') {
        throw "Refusing unexpected Task-File path: $TaskFile"
    }
    if (-not $TaskFile.StartsWith("builder-instructions/$TaskId-", [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Task-ID and Task-File do not match: $TaskId / $TaskFile"
    }
}

function Assert-BuilderChangedNoProtectedFiles {
    param(
        [string]$BaseCommit,
        [string]$ImplementationCommit
    )

    $changedFiles = @((Invoke-Git $builderPath @("diff", "--name-only", "$BaseCommit..$ImplementationCommit")) -split "`n" | Where-Object { $_ })
    $protected = @(
        "AGENTS.md",
        "CLAUDE.md",
        "agent-pipeline.config.json",
        ".gitignore"
    )
    foreach ($file in $changedFiles) {
        if ($file -in $protected -or
            $file.StartsWith("automation/") -or
            $file.StartsWith("builder-instructions/") -or
            $file.StartsWith("examples/") -or
            $file.StartsWith("reviews/") -or
            $file.StartsWith("test-results/") -or
            $file.StartsWith("playwright-report/")) {
            throw "Builder changed protected pipeline file: $file"
        }
    }
}

function Get-CommittedTaskValidation {
    param([string]$InstructionCommit, [string]$TaskId, [string]$TaskFile)
    if ($InstructionCommit -notmatch '^(?:[0-9a-fA-F]{40}|[0-9a-fA-F]{64})$') {
        throw 'Instruction-Commit must be a full Git commit hash.'
    }
    Assert-SafeRepoPath $TaskFile
    $contents = Invoke-OriginGit @('show', "${InstructionCommit}:$TaskFile")
    $configuration = Invoke-OriginGit @('show', "${InstructionCommit}:agent-pipeline.config.json")
    return Get-TaskValidation $contents $configuration $TaskId { param($gitArguments) Invoke-OriginGit $gitArguments } $InstructionCommit
}

function Invoke-Builder {
    param(
        [string]$InstructionCommit,
        [string]$TaskId,
        [string]$TaskFile
    )

    Assert-TaskMetadata $TaskId $TaskFile
    $validation = Get-CommittedTaskValidation $InstructionCommit $TaskId $TaskFile

    Write-Host "[$TaskId] Syncing builder to $InstructionCommit" -ForegroundColor Cyan
    Sync-Checkout $builderPath $InstructionCommit
    if (-not (Test-Path -LiteralPath (Join-Path $builderPath $TaskFile) -PathType Leaf)) {
        throw "Instruction file is missing at its instruction commit: $TaskFile"
    }

    $values = @{
        TASK_ID = $TaskId
        TASK_FILE = $TaskFile
        INSTRUCTION_COMMIT = $InstructionCommit
    }

    $prompt = Expand-Prompt (Join-Path $controlPath "automation/prompts/builder.md") ($values + $validation)

    $logFile = Join-Path $logsPath "$TaskId-builder-$($InstructionCommit.Substring(0, 8)).log"
    Write-Host "[$TaskId] Starting Claude builder; log: $logFile" -ForegroundColor Yellow
    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        if (Test-SandboxExists $BuilderSandbox) {
            & sbx run --name $BuilderSandbox -- -p --output-format text $prompt 2>&1 | Tee-Object -FilePath $logFile
        }
        else {
            & sbx run --name $BuilderSandbox claude $builderPath -- -p --output-format text $prompt 2>&1 | Tee-Object -FilePath $logFile
        }
        $agentExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    if ($agentExitCode -ne 0) {
        throw "Claude builder exited with code $agentExitCode."
    }

    $implementationCommit = Assert-CleanSingleCommit $builderPath $InstructionCommit
    Assert-BuilderChangedNoProtectedFiles $InstructionCommit $implementationCommit
    $body = Invoke-Git $builderPath @("show", "-s", "--format=%B", $implementationCommit)
    if ((Get-Trailer $body "Agent-Event" -Required) -ne "build-complete") { throw "Builder commit has the wrong Agent-Event." }
    if ((Get-Trailer $body "Task-ID" -Required) -ne $TaskId) { throw "Builder commit has the wrong Task-ID." }
    if ((Get-Trailer $body "Task-File" -Required) -ne $TaskFile) { throw "Builder commit has the wrong Task-File." }
    if ((Get-Trailer $body "Instruction-Commit" -Required) -ne $InstructionCommit) { throw "Builder commit has the wrong Instruction-Commit." }

    Publish-Commit $builderPath $InstructionCommit
    Write-Host "[$TaskId] Published implementation $implementationCommit" -ForegroundColor Green
}

function Invoke-Reviewer {
    param(
        [string]$ImplementationCommit,
        [string]$TaskId,
        [string]$TaskFile,
        [string]$InstructionCommit
    )

    $reportFile = "reviews/$TaskId.md"
    Assert-TaskMetadata $TaskId $TaskFile
    $validation = Get-CommittedTaskValidation $InstructionCommit $TaskId $TaskFile
    Write-Host "[$TaskId] Syncing reviewer to $ImplementationCommit" -ForegroundColor Cyan
    Sync-Checkout $reviewerPath $ImplementationCommit

    $values = @{
        TASK_ID = $TaskId
        TASK_FILE = $TaskFile
        INSTRUCTION_COMMIT = $InstructionCommit
        IMPLEMENTATION_COMMIT = $ImplementationCommit
        REPORT_FILE = $reportFile
    }

    $prompt = Expand-Prompt (Join-Path $controlPath "automation/prompts/reviewer.md") ($values + $validation)

    $logFile = Join-Path $logsPath "$TaskId-reviewer-$($ImplementationCommit.Substring(0, 8)).log"
    Write-Host "[$TaskId] Starting Codex reviewer; log: $logFile" -ForegroundColor Yellow
    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        if (Test-SandboxExists $ReviewerSandbox) {
            & sbx run --name $ReviewerSandbox -- exec --dangerously-bypass-approvals-and-sandbox $prompt 2>&1 | Tee-Object -FilePath $logFile
        }
        else {
            & sbx run --name $ReviewerSandbox codex $reviewerPath -- exec --dangerously-bypass-approvals-and-sandbox $prompt 2>&1 | Tee-Object -FilePath $logFile
        }
        $agentExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    if ($agentExitCode -ne 0) {
        throw "Codex reviewer exited with code $agentExitCode."
    }

    $reviewCommit = Assert-CleanSingleCommit $reviewerPath $ImplementationCommit
    $changedFiles = @((Invoke-Git $reviewerPath @("diff", "--name-only", "$ImplementationCommit..$reviewCommit")) -split "`n" | Where-Object { $_ })
    if ($changedFiles.Count -ne 1 -or $changedFiles[0] -ne $reportFile) {
        throw "Reviewer may change only $reportFile. Changed: $($changedFiles -join ', ')"
    }

    $body = Invoke-Git $reviewerPath @("show", "-s", "--format=%B", $reviewCommit)
    if ((Get-Trailer $body "Agent-Event" -Required) -ne "review-complete") { throw "Reviewer commit has the wrong Agent-Event." }
    if ((Get-Trailer $body "Task-ID" -Required) -ne $TaskId) { throw "Reviewer commit has the wrong Task-ID." }
    if ((Get-Trailer $body "Instruction-Commit" -Required) -ne $InstructionCommit) { throw "Reviewer commit has the wrong Instruction-Commit." }
    if ((Get-Trailer $body "Implementation-Commit" -Required) -ne $ImplementationCommit) { throw "Reviewer commit has the wrong Implementation-Commit." }
    $verdict = Get-Trailer $body "Verdict" -Required
    if ($verdict -notin @("PASS", "CHANGES_REQUESTED")) { throw "Reviewer verdict must be PASS or CHANGES_REQUESTED." }

    Publish-Commit $reviewerPath $ImplementationCommit
    Write-Host "[$TaskId] Published review $reviewCommit with verdict $verdict" -ForegroundColor Green
    Write-Host "[$TaskId] Pipeline stops here; no automatic builder follow-up." -ForegroundColor Magenta
}

$processed = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
if (Test-Path -LiteralPath $processedPath) {
    foreach ($line in Get-Content -LiteralPath $processedPath) {
        if ($line.Trim()) { [void]$processed.Add($line.Trim()) }
    }
}

Write-Host "Watching local origin: $originPath" -ForegroundColor Green
Write-Host "Claude builder: $BuilderSandbox | Codex reviewer: $ReviewerSandbox"
Write-Host "Stop with Ctrl+C."

while ($true) {
    try {
        $commits = @((Invoke-OriginGit @("rev-list", "--reverse", "refs/heads/main")) -split "`n" | Where-Object { $_ })
        foreach ($commit in $commits) {
            if ($processed.Contains($commit)) { continue }

            $body = Get-CommitBody $commit
            $event = Get-Trailer $body "Agent-Event"

            switch ($event) {
                "instruction" {
                    $taskId = Get-Trailer $body "Task-ID" -Required
                    $taskFile = Get-Trailer $body "Task-File" -Required
                    if (Test-PublishedEvent $commit "build-complete" "Instruction-Commit" $commit) {
                        Write-Host "[$taskId] Implementation already published; skipping duplicate builder run."
                    }
                    else {
                        Invoke-Builder $commit $taskId $taskFile
                    }
                }
                "build-complete" {
                    $taskId = Get-Trailer $body "Task-ID" -Required
                    $taskFile = Get-Trailer $body "Task-File" -Required
                    $instructionCommit = Get-Trailer $body "Instruction-Commit" -Required
                    if (Test-PublishedEvent $commit "review-complete" "Implementation-Commit" $commit) {
                        Write-Host "[$taskId] Review already published; skipping duplicate reviewer run."
                    }
                    else {
                        Invoke-Reviewer $commit $taskId $taskFile $instructionCommit
                    }
                }
                "review-complete" {
                    $taskId = Get-Trailer $body "Task-ID" -Required
                    $verdict = Get-Trailer $body "Verdict" -Required
                    Write-Host "[$taskId] Review recorded: $verdict ($commit)" -ForegroundColor Magenta
                }
                default {
                    Write-Host "Ignoring non-agent commit $($commit.Substring(0, 8))."
                }
            }

            Add-Content -LiteralPath $processedPath -Value $commit
            [void]$processed.Add($commit)
        }
    }
    catch {
        Write-Error $_ -ErrorAction Continue
        Write-Host "Dispatcher stopped. The failing commit was not marked processed; fix the cause and restart to retry." -ForegroundColor Red
        exit 1
    }

    Start-Sleep -Seconds $PollSeconds
}
