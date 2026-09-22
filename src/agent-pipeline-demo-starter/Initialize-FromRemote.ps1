[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Remote,
    [Parameter(Mandatory = $true)][string]$SourceBranch,
    [Parameter(Mandatory = $true)][string]$Destination,
    [Parameter(Mandatory = $true)][string[]]$ValidationCommand,
    [string[]]$GovernancePath = @(),
    [string]$UserName = 'Pipeline Human',
    [string]$UserEmail = 'human@agent-pipeline.local'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'template/automation/Task-Validation.ps1')

function Invoke-CheckedGit {
    param([string[]]$Arguments)
    $previous = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = & git @Arguments 2>&1
        $code = $LASTEXITCODE
    }
    finally { $ErrorActionPreference = $previous }
    if ($code -ne 0) { throw "Git failed (exit $code): $($output -join "`n")" }
    return ($output -join "`n").Trim()
}

# No credentials in remote URLs; use the host credential manager or SSH agent.
if ($Remote -match '^-' -or $Remote -match '[\r\n]' -or
    $Remote -match '^https?://[^/]*@' -or $Remote -match '^https?://.*[?#]') {
    throw 'Use a remote URL without embedded credentials, query parameters or fragments.'
}
Invoke-CheckedGit @('check-ref-format', '--branch', $SourceBranch) | Out-Null
if ($SourceBranch.StartsWith('-') -or $SourceBranch.Contains('@{')) { throw 'Use a literal source branch name.' }
foreach ($command in $ValidationCommand) {
    if (-not $command.Trim() -or $command -match '[\r\n]') { throw 'Supply nonempty single-line validation commands.' }
}
if ($ValidationCommand.Count -eq 0) { throw 'At least one validation command is required.' }
foreach ($path in $GovernancePath) { Assert-SafeRepoPath $path }
$destinationPath = [IO.Path]::GetFullPath($Destination)
if (Test-Path -LiteralPath $destinationPath) { throw "Destination must not exist: $destinationPath" }
# Do not place disposable workspaces inside an existing working tree.
$ancestor = Split-Path $destinationPath -Parent
while ($ancestor) {
    if (Test-Path -LiteralPath (Join-Path $ancestor '.git')) { throw 'Choose a destination outside any existing Git working tree.' }
    $parent = Split-Path $ancestor -Parent
    if ($parent -eq $ancestor) { break }
    $ancestor = $parent
}

$control = Join-Path $destinationPath 'control'
$origin = Join-Path $destinationPath 'origin.git'
$state = Join-Path $destinationPath 'state'
New-Item -ItemType Directory -Path $destinationPath, $state, (Join-Path $destinationPath 'logs') | Out-Null
Set-Content -LiteralPath (Join-Path $state 'setup-pending') -Value 'Review and confirm setup before running agents.' -Encoding UTF8

# Clone a single branch, retaining complete history, with independent Git objects.
Invoke-CheckedGit @('clone', '--no-hardlinks', '--single-branch', '--branch', $SourceBranch, '--origin', 'upstream', '--', $Remote, $control) | Out-Null
$base = Invoke-CheckedGit @('-C', $control, 'rev-parse', 'HEAD')
# The isolated local pipeline consistently uses main, regardless of upstream branch.
Invoke-CheckedGit @('-C', $control, 'checkout', '-B', 'main', $base) | Out-Null
Invoke-CheckedGit @('-C', $control, 'remote', 'remove', 'upstream') | Out-Null
Invoke-CheckedGit @('-C', $control, 'config', 'user.name', $UserName) | Out-Null
Invoke-CheckedGit @('-C', $control, 'config', 'user.email', $UserEmail) | Out-Null

$template = Join-Path $PSScriptRoot 'template'
$imports = @('automation', 'agent-pipeline.config.json', 'examples/TASK-0100-project-task.md')
foreach ($path in $imports) {
    if (Test-Path -LiteralPath (Join-Path $control $path)) { throw "Pipeline path already exists: $path. Review this partial destination; nothing was overwritten." }
}
# Refuse symlinks in paths that setup will write through.
foreach ($path in @('examples', 'builder-instructions', 'reviews', 'followups', '.gitignore')) {
    $target = Join-Path $control $path
    if (Test-Path -LiteralPath $target) {
        if ((Get-Item -LiteralPath $target -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Unsafe setup path: $path" }
    }
}
# Discover case-preserving root guidance; additional governance files are explicit.
$tracked = (Invoke-CheckedGit @('-C', $control, 'ls-tree', '-r', '--name-only', 'HEAD')) -split "`n"
$guidance = @(@($tracked | Where-Object { $_ -imatch '^(AGENTS|CLAUDE)\.md$' }) + $GovernancePath | Select-Object -Unique)
foreach ($path in $guidance) {
    Assert-SafeRepoPath $path
    $entry = Invoke-CheckedGit @('-C', $control, 'ls-tree', 'HEAD', '--', $path)
    if ($entry -notmatch '^100(644|755) blob ') { throw "Governance file must be a committed regular file: $path" }
}
Copy-Item -LiteralPath (Join-Path $template 'automation') -Destination $control -Recurse
foreach ($directory in @('examples', 'builder-instructions', 'reviews', 'followups')) {
    New-Item -ItemType Directory -Path (Join-Path $control $directory) -Force | Out-Null
}
Copy-Item -LiteralPath (Join-Path $template 'examples/TASK-0100-project-task.md') -Destination (Join-Path $control 'examples')
$config = [ordered]@{
    validationProfiles = [ordered]@{ default = @{ commands = @($ValidationCommand); artifacts = @() } }
    governancePaths = @($guidance)
    followups = [ordered]@{ maxRounds = 3 }
}
$config | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $control 'agent-pipeline.config.json') -Encoding UTF8
Add-Content -LiteralPath (Join-Path $control '.gitignore') -Value "`n# Local pipeline validation artifacts`n/test-results/`n/playwright-report/`n" -Encoding UTF8
# Git ignores empty directories; no existing files are changed in these directories.
foreach ($directory in @('builder-instructions', 'reviews', 'followups')) {
    $keep = Join-Path $control "$directory/.gitkeep"
    if (-not (Test-Path -LiteralPath $keep)) { New-Item -ItemType File -Path $keep | Out-Null }
}
Invoke-CheckedGit @('-C', $control, 'add', '--', 'automation', 'agent-pipeline.config.json', 'examples/TASK-0100-project-task.md', '.gitignore', 'builder-instructions/.gitkeep', 'reviews/.gitkeep', 'followups/.gitkeep') | Out-Null
Invoke-CheckedGit @('-C', $control, 'commit', '-m', 'chore: add supervised pipeline configuration') | Out-Null
Invoke-CheckedGit @('init', '--bare', $origin) | Out-Null
Invoke-CheckedGit @('-C', $control, 'remote', 'add', 'origin', $origin) | Out-Null
Invoke-CheckedGit @('-C', $control, 'push', '-u', 'origin', 'main') | Out-Null
Invoke-CheckedGit @("--git-dir=$origin", 'symbolic-ref', 'HEAD', 'refs/heads/main') | Out-Null
foreach ($role in @('builder', 'reviewer')) {
    $checkout = Join-Path $destinationPath $role
    Invoke-CheckedGit @('clone', '--no-hardlinks', $origin, $checkout) | Out-Null
    Invoke-CheckedGit @('-C', $checkout, 'config', 'user.name', "Pipeline $role") | Out-Null
    Invoke-CheckedGit @('-C', $checkout, 'config', 'user.email', "$role@agent-pipeline.local") | Out-Null
}
Set-Content -LiteralPath (Join-Path $state 'source-commit.txt') -Value $base -Encoding ASCII
Set-Content -LiteralPath (Join-Path $destinationPath 'README.txt') -Encoding UTF8 -Value @"
Supervised pipeline cloned from source branch $SourceBranch at $base.
The local pipeline branch is main. The external remote was disconnected.
control: human setup/tasks; builder and reviewer: disposable agent checkouts.
origin.git: LOCAL bare remote; logs and state: uncommitted runtime files.
Review agent-pipeline.config.json, repository governance and environment setup.
Then run automation/Confirm-PipelineSetup.ps1 from control before starting agents.
Do not put application secrets in agent workspaces. Nothing was pushed externally.
"@
Write-Host "Created $destinationPath from $base. Review setup in control before confirming it." -ForegroundColor Green
Write-Host 'No agent, dependency installer, test command or external push was run.'
