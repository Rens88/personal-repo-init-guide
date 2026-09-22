# Pure metadata helpers. Dot-sourcing this file never starts agents or runs checks.
function Assert-SafeRepoPath {
    param([string]$Path)
    if ($Path -notmatch '^[A-Za-z0-9_.-]+(/[A-Za-z0-9_.-]+)*$') {
        throw "Expected a repository-relative forward-slash path: $Path"
    }
    foreach ($part in $Path.Split('/')) {
        if ($part -in @('.', '..', '.git') -or $part.EndsWith('.')) {
            throw "Unsafe repository path: $Path"
        }
    }
}

function Get-TaskFields {
    param([string]$Contents)
    $match = [regex]::Match($Contents, '\A\uFEFF?---\r?\n(.*?)\r?\n---(?:\r?\n|$)', 'Singleline')
    if (-not $match.Success) { throw 'Task must begin with YAML-style front matter.' }
    $fields = @{}
    foreach ($line in ($match.Groups[1].Value -split '\r?\n')) {
        if ($line -match '^([a-z][a-z-]*):[ \t]*(.*)$') {
            $key = $Matches[1]
            if ($fields.ContainsKey($key)) { throw "Duplicate task field: $key" }
            $fields[$key] = $Matches[2].Trim()
        }
        elseif ($line.Trim() -and -not $line.Trim().StartsWith('#')) {
            throw 'Use simple, single-line key: value task fields.'
        }
    }
    return $fields
}

# Splits a task or draft into its front matter and the body after it. Use
# Match, not Replace: Replace's four-argument overload does not reliably apply
# Singleline here and silently returns the whole file. The BOM is built rather
# than written literally so this file stays ASCII under any source encoding.
function Split-TaskDocument {
    param([string]$Contents)
    $pattern = '\A' + [char]0xFEFF + '?---\r?\n(.*?)\r?\n---(?:\r?\n|$)'
    $match = [regex]::Match($Contents, $pattern, 'Singleline')
    if (-not $match.Success) { throw 'Task must begin with YAML-style front matter.' }
    return @{
        FrontMatter = $match.Groups[1].Value
        Body = $Contents.Substring($match.Length)
    }
}

function Get-TaskBody {
    param([string]$Contents)
    return (Split-TaskDocument $Contents).Body
}

function Get-FollowupRounds {
    param([string]$Configuration)
    $config = ConvertFrom-Json -InputObject $Configuration
    if ($config.PSObject.Properties.Name -notcontains 'followups') { return 3 }
    $followups = $config.followups
    if ($followups.PSObject.Properties.Name -notcontains 'maxRounds') { return 3 }
    # ConvertFrom-Json may hand back Int32 or Int64 depending on the host.
    $rounds = $followups.maxRounds
    if (($rounds -isnot [int]) -and ($rounds -isnot [long])) {
        throw 'followups.maxRounds must be an integer between 1 and 10.'
    }
    if ($rounds -lt 1 -or $rounds -gt 10) {
        throw 'followups.maxRounds must be an integer between 1 and 10.'
    }
    return [int]$rounds
}

function Get-TaskFilePath {
    param([scriptblock]$ReadGit, [string]$SnapshotCommit, [string]$TaskId)
    if ($TaskId -notmatch '^TASK-[0-9]+$') { throw "Malformed task id: $TaskId" }
    $listing = & $ReadGit @('ls-tree', '-r', '--name-only', $SnapshotCommit, '--', 'builder-instructions')
    $files = @(($listing -split "`n") | Where-Object { $_ })
    # Not $Matches: that name is an automatic variable written by -match.
    $candidates = @($files | Where-Object {
        [System.IO.Path]::GetFileName($_).StartsWith("$TaskId-", [System.StringComparison]::OrdinalIgnoreCase)
    })
    if ($candidates.Count -ne 1) { throw "Expected exactly one committed task file for ${TaskId}; found $($candidates.Count)." }
    return $candidates[0]
}

# Walks parent-task links through committed task files. Because every link is read
# from the snapshot rather than from the submitted text, a task cannot understate
# its own round and escape the budget.
function Assert-FollowupDepth {
    param(
        [scriptblock]$ReadGit,
        [string]$SnapshotCommit,
        [string]$TaskId,
        [string]$ParentTask,
        [int]$MaxRounds
    )
    if (-not $ParentTask) { return 0 }
    if (-not $SnapshotCommit) { return 0 }
    $seen = @{ $TaskId = $true }
    $depth = 0
    $current = $ParentTask
    while ($current) {
        if ($current -notmatch '^TASK-[0-9]+$') { throw "Malformed parent-task reference: $current" }
        if ($seen.ContainsKey($current)) { throw "Follow-up chain for $TaskId contains a cycle at $current." }
        $seen[$current] = $true
        $depth++
        if ($depth -gt $MaxRounds) {
            throw "Follow-up chain for $TaskId is $depth rounds deep; the committed budget is $MaxRounds. Close the thread or raise followups.maxRounds deliberately."
        }
        $parentFile = Get-TaskFilePath $ReadGit $SnapshotCommit $current
        $parentFields = Get-TaskFields (& $ReadGit @('show', "${SnapshotCommit}:$parentFile"))
        $current = $parentFields['parent-task']
    }
    return $depth
}

function Get-TaskValidation {
    param(
        [string]$Contents,
        [string]$Configuration,
        [string]$TaskId,
        [scriptblock]$ReadGit,
        [string]$SnapshotCommit = ""
    )
    $fields = Get-TaskFields $Contents
    if ($fields['id'] -cne $TaskId) { throw 'Task front-matter id does not match Task-ID.' }
    $parentTask = $fields['parent-task']
    if ($parentTask) {
        if ($parentTask -notmatch '^TASK-[0-9]+$') { throw "Invalid parent-task: $parentTask" }
        if ($parentTask -ceq $TaskId) { throw 'A task cannot be its own parent.' }
    }
    $name = $fields['validation-profile']
    if (-not $name) { $name = 'default' }
    if ($name -notmatch '^[a-z][a-z0-9-]*$') { throw "Invalid validation profile: $name" }
    $config = ConvertFrom-Json -InputObject $Configuration
    $profiles = $config.validationProfiles
    $property = @($profiles.PSObject.Properties | Where-Object { $_.Name -ceq $name })
    if ($property.Count -ne 1) { throw "Unknown committed validation profile: $name" }
    $profile = $property[0].Value
    if ($profile.commands -isnot [array] -or $profile.commands.Count -eq 0) {
        throw "Profile $name must define a nonempty commands array."
    }
    foreach ($command in $profile.commands) {
        if ($command -isnot [string] -or -not $command.Trim() -or $command -match '[\r\n]') {
            throw "Profile $name contains an invalid command."
        }
    }
    if ($profile.artifacts -isnot [array]) { throw "Profile $name must define an artifacts array." }
    foreach ($artifact in $profile.artifacts) {
        if ($artifact -isnot [string]) { throw 'Artifact paths must be strings.' }
        Assert-SafeRepoPath $artifact.TrimEnd('/')
    }
    $governance = @()
    if ($config.PSObject.Properties.Name -contains 'governancePaths') {
        if ($config.governancePaths -isnot [array]) { throw 'governancePaths must be an array.' }
        $governance = @($config.governancePaths)
        foreach ($path in $governance) {
            if ($path -isnot [string]) { throw 'Governance paths must be strings.' }
            Assert-SafeRepoPath $path
            if ($SnapshotCommit) {
                $entry = & $ReadGit @('ls-tree', $SnapshotCommit, '--', $path)
                if ($entry -notmatch '^100(644|755) blob ') { throw "Missing regular governance file: $path" }
            }
        }
    }
    $specPath = $fields['spec-path']
    $specCommit = $fields['spec-commit']
    if ([bool]$specPath -ne [bool]$specCommit) { throw 'spec-path and spec-commit must both be supplied or both be empty.' }
    $spec = 'No specification reference.'
    if ($specPath) {
        Assert-SafeRepoPath $specPath
        if ($specCommit -notmatch '^(?:[0-9a-fA-F]{40}|[0-9a-fA-F]{64})$') {
            throw 'spec-commit must be a full immutable Git commit hash.'
        }
        $null = & $ReadGit @('rev-parse', '--verify', "$specCommit^{commit}")
        $entry = & $ReadGit @('ls-tree', $specCommit, '--', $specPath)
        if ($entry -notmatch '^100(644|755) blob ') { throw 'Spec must be a committed regular file (no directory, symlink or submodule).' }
        if ($SnapshotCommit) {
            $null = & $ReadGit @('merge-base', '--is-ancestor', $specCommit, $SnapshotCommit)
        }
        $spec = "Read the frozen specification with: git show ${specCommit}:$specPath"
    }
    $maxRounds = Get-FollowupRounds $Configuration
    $round = Assert-FollowupDepth $ReadGit $SnapshotCommit $TaskId $parentTask $maxRounds
    $priorReview = 'This is the first round for this thread; there is no earlier review.'
    if ($parentTask) {
        $priorReview = "This is follow-up round $round of at most $maxRounds. The review that produced it is committed at reviews/$parentTask.md and its draft at followups/$parentTask.draft.md. Read both before implementing."
    }
    return @{
        GOVERNANCE_PATHS = ($governance -join ", ")
        VALIDATION_PROFILE = $name
        VALIDATION_COMMANDS = ($profile.commands -join "`n")
        VALIDATION_ARTIFACTS = ($profile.artifacts -join ', ')
        SPEC_REFERENCE = $spec
        PARENT_TASK = $(if ($parentTask) { $parentTask } else { 'none' })
        FOLLOWUP_ROUND = $round
        MAX_FOLLOWUP_ROUNDS = $maxRounds
        PRIOR_REVIEW = $priorReview
    }
}

# Validates a reviewer-authored follow-up draft. A draft is deliberately not a
# submittable task: its id is empty, so only a human promotion can name it and
# move it into builder-instructions/.
function Get-FollowupDraft {
    param(
        [string]$Contents,
        [string]$Configuration,
        [string]$ParentTaskId,
        [string]$Verdict
    )
    $fields = Get-TaskFields $Contents
    if ($fields['id']) { throw 'A follow-up draft must leave id empty; promotion assigns the next task id.' }
    if ($fields['parent-task'] -cne $ParentTaskId) {
        throw "Follow-up draft parent-task must be $ParentTaskId."
    }
    if (-not $fields['title']) { throw 'A follow-up draft must have a title.' }
    $expectedReason = @{ 'CHANGES_REQUESTED' = 'changes-requested'; 'DECISION_REQUIRED' = 'decision-required' }[$Verdict]
    if (-not $expectedReason) { throw "A follow-up draft is not permitted for verdict $Verdict." }
    if ($fields['follow-up-reason'] -cne $expectedReason) {
        throw "Follow-up draft follow-up-reason must be '$expectedReason' to match verdict $Verdict."
    }
    $name = $fields['validation-profile']
    if (-not $name) { $name = 'default' }
    if ($name -notmatch '^[a-z][a-z0-9-]*$') { throw "Invalid validation profile in follow-up draft: $name" }
    $config = ConvertFrom-Json -InputObject $Configuration
    $property = @($config.validationProfiles.PSObject.Properties | Where-Object { $_.Name -ceq $name })
    if ($property.Count -ne 1) { throw "Follow-up draft names an unknown validation profile: $name" }
    if (-not (Get-TaskBody $Contents).Trim()) { throw 'A follow-up draft must have a body.' }
    if ($Verdict -eq 'DECISION_REQUIRED' -and (Get-TaskBody $Contents) -notmatch '(?mi)^#+\s*Decisions required\s*$') {
        throw 'A DECISION_REQUIRED draft must contain a "# Decisions required" section.'
    }
    return $fields
}
