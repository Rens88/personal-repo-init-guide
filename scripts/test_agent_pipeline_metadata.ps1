# Runs metadata checks only; never dot-sources or runs the dispatcher.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$starter = Join-Path $PSScriptRoot '../src/agent-pipeline-demo-starter'
. (Join-Path $starter 'template/automation/Task-Validation.ps1')
$config = Get-Content (Join-Path $starter 'template/agent-pipeline.config.json') -Raw
$task = "---`nid: TASK-0001`ntitle: Example`n---`nTask body"
$noGit = { throw 'Unexpected Git call' }
function Assert-Fails {
    param([scriptblock]$Action)
    $failed = $false
    try { & $Action | Out-Null } catch { $failed = $true }
    if (-not $failed) { throw 'Expected rejection.' }
}
$result = Get-TaskValidation $task $config 'TASK-0001' $noGit
if ($result.VALIDATION_PROFILE -ne 'default' -or $result.VALIDATION_COMMANDS -ne 'npm test') {
    throw 'Legacy default profile failed.'
}
$web = $task.Replace('title: Example', 'validation-profile: web-ui')
$result = Get-TaskValidation $web $config 'TASK-0001' $noGit
if ($result.VALIDATION_COMMANDS -ne "npm test`nnpx playwright test") { throw 'web-ui profile failed.' }
Assert-Fails { Get-TaskValidation ($task.Replace('title: Example', 'validation-profile: npm test; whoami')) $config 'TASK-0001' $noGit }
Assert-Fails { Get-TaskValidation ($task.Replace('title: Example', 'validation-profile: missing')) $config 'TASK-0001' $noGit }
Assert-Fails { Get-TaskValidation ($task.Replace('title: Example', 'spec-path: specs/demo.md')) $config 'TASK-0001' $noGit }
Assert-Fails { Get-TaskValidation ($task.Replace('title: Example', "id: TASK-0001")) $config 'TASK-0001' $noGit }
foreach ($path in @('../spec.md', '/spec.md', 'C:/spec.md', 'specs/../spec.md', 'specs\file.md', '.git/config', 'specs/file:stream', 'specs//file.md')) {
    Assert-Fails { Assert-SafeRepoPath $path }
}
$hash = 'a' * 40
$spec = $task.Replace('title: Example', "spec-path: specs/demo.md`nspec-commit: $hash")
$validGit = {
    param($gitArguments)
    if ($gitArguments[0] -eq 'rev-parse') { return $hash }
    if ($gitArguments[0] -eq 'ls-tree') { return "100644 blob $hash`tspecs/demo.md" }
    throw 'Unexpected command'
}
$result = Get-TaskValidation $spec $config 'TASK-0001' $validGit
if ($result.SPEC_REFERENCE -notlike '*git show*') { throw 'Frozen reference missing.' }
Assert-Fails { Get-TaskValidation $spec $config 'TASK-0001' { return '' } }
Assert-Fails { Get-TaskValidation $spec $config 'TASK-0001' { return "120000 blob $hash`tspecs/demo.md" } }
Assert-Fails { Get-TaskValidation ($spec.Replace($hash, 'main')) $config 'TASK-0001' $validGit }
Get-ChildItem $starter -Recurse -Filter *.ps1 | ForEach-Object {
    $tokens = $null
    $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$tokens, [ref]$errors)
    if ($errors.Count) { throw ($errors | Out-String) }
}
Write-Host 'Metadata rejection/profile checks and starter PowerShell syntax passed.'
