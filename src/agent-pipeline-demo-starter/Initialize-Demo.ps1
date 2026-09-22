[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Destination = (Join-Path (Get-Location) "agent-pipeline-demo")
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Invoke-Checked {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Command,
        [Parameter(Mandatory = $false)]
        [string[]]$Arguments = @()
    )

    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed ($LASTEXITCODE): $Command $($Arguments -join ' ')"
    }
}

foreach ($command in @("git", "sbx")) {
    if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
        throw "Required command '$command' was not found in PATH."
    }
}

$destinationPath = [System.IO.Path]::GetFullPath($Destination)
if (Test-Path -LiteralPath $destinationPath) {
    throw "Destination already exists: $destinationPath"
}

$templatePath = Join-Path $PSScriptRoot "template"
if (-not (Test-Path -LiteralPath $templatePath -PathType Container)) {
    throw "Template directory is missing: $templatePath"
}

$originPath = Join-Path $destinationPath "origin.git"
$controlPath = Join-Path $destinationPath "control"
$builderPath = Join-Path $destinationPath "builder"
$reviewerPath = Join-Path $destinationPath "reviewer"
$logsPath = Join-Path $destinationPath "logs"
$statePath = Join-Path $destinationPath "state"

New-Item -ItemType Directory -Path $destinationPath, $controlPath, $logsPath, $statePath | Out-Null
Get-ChildItem -LiteralPath $templatePath -Force | Copy-Item -Destination $controlPath -Recurse -Force

Invoke-Checked git @("init", "--bare", $originPath)
Invoke-Checked git @("-C", $controlPath, "init", "-b", "main")
Invoke-Checked git @("-C", $controlPath, "config", "user.name", "Pipeline Human")
Invoke-Checked git @("-C", $controlPath, "config", "user.email", "human@agent-pipeline.local")
Invoke-Checked git @("-C", $controlPath, "add", ".")
Invoke-Checked git @("-C", $controlPath, "commit", "-m", "chore: initialize agent pipeline demo")
Invoke-Checked git @("-C", $controlPath, "remote", "add", "origin", $originPath)
Invoke-Checked git @("-C", $controlPath, "push", "-u", "origin", "main")
Invoke-Checked git @("--git-dir=$originPath", "symbolic-ref", "HEAD", "refs/heads/main")

Invoke-Checked git @("clone", $originPath, $builderPath)
Invoke-Checked git @("clone", $originPath, $reviewerPath)

Invoke-Checked git @("-C", $builderPath, "config", "user.name", "Claude Builder")
Invoke-Checked git @("-C", $builderPath, "config", "user.email", "builder@agent-pipeline.local")
Invoke-Checked git @("-C", $reviewerPath, "config", "user.name", "Codex Reviewer")
Invoke-Checked git @("-C", $reviewerPath, "config", "user.email", "reviewer@agent-pipeline.local")

$rootNote = @"
This directory is managed by the local agent-pipeline demo.

control  - edit and submit instructions here
builder  - dedicated Claude workspace
reviewer - dedicated Codex workspace
origin.git - host-side local bare remote
logs     - agent transcripts
state    - dispatcher progress
"@
Set-Content -LiteralPath (Join-Path $destinationPath "README.txt") -Value $rootNote -Encoding UTF8

Write-Host ""
Write-Host "Demo created at: $destinationPath" -ForegroundColor Green
Write-Host ""
Write-Host "Next:" -ForegroundColor Cyan
Write-Host "  1. Authenticate once: sbx secret set anthropic"
Write-Host "                        sbx secret set openai --oauth"
Write-Host "  2. Start dispatcher:  cd `"$controlPath`""
Write-Host "                        ./automation/Start-AgentPipeline.ps1"
Write-Host "  3. Follow control/README.md to submit the example task."
