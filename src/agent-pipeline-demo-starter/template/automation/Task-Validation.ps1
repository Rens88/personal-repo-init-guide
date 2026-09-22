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
    return @{
        VALIDATION_PROFILE = $name
        VALIDATION_COMMANDS = ($profile.commands -join "`n")
        VALIDATION_ARTIFACTS = ($profile.artifacts -join ', ')
        SPEC_REFERENCE = $spec
    }
}
