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
# --- follow-up loop -------------------------------------------------------
if ((Get-FollowupRounds $config) -ne 3) { throw 'Default follow-up budget should be 3.' }
if ((Get-FollowupRounds '{"validationProfiles":{},"followups":{"maxRounds":1}}') -ne 1) { throw 'maxRounds not honoured.' }
foreach ($bad in @('{"followups":{"maxRounds":0}}', '{"followups":{"maxRounds":11}}', '{"followups":{"maxRounds":"3"}}')) {
    Assert-Fails { Get-FollowupRounds $bad }
}

# parent-task shape is rejected before any Git call happens.
Assert-Fails { Get-TaskValidation ($task.Replace('title: Example', 'parent-task: nonsense')) $config 'TASK-0001' $noGit }
Assert-Fails { Get-TaskValidation ($task.Replace('title: Example', 'parent-task: TASK-0001')) $config 'TASK-0001' $noGit }
$firstRound = Get-TaskValidation $task $config 'TASK-0001' $noGit
if ($firstRound.PARENT_TASK -ne 'none' -or $firstRound.FOLLOWUP_ROUND -ne 0) { throw 'A parentless task must be round 0.' }

# A chain walker backed by a fake repository: TASK-0004 -> 0003 -> 0002 -> 0001.
function New-ChainGit {
    param([hashtable]$Parents)
    return {
        param($gitArguments)
        if ($gitArguments[0] -eq 'ls-tree' -and $gitArguments[1] -eq '-r') {
            return (($Parents.Keys | Sort-Object | ForEach-Object { "builder-instructions/$_-x.md" }) -join "`n")
        }
        if ($gitArguments[0] -eq 'show') {
            $id = [regex]::Match($gitArguments[1], 'TASK-[0-9]+').Value
            $parent = $Parents[$id]
            return "---`nid: $id`nparent-task: $parent`n---`nbody"
        }
        throw "Unexpected command: $($gitArguments -join ' ')"
    }.GetNewClosure()
}
$chain = New-ChainGit @{ 'TASK-0001' = ''; 'TASK-0002' = 'TASK-0001'; 'TASK-0003' = 'TASK-0002'; 'TASK-0004' = 'TASK-0003' }
$depth = Assert-FollowupDepth $chain 'HEAD' 'TASK-0003' 'TASK-0002' 3
if ($depth -ne 2) { throw "Expected depth 2, got $depth." }
Assert-Fails { Assert-FollowupDepth $chain 'HEAD' 'TASK-0004' 'TASK-0003' 2 }
$cycle = New-ChainGit @{ 'TASK-0001' = 'TASK-0002'; 'TASK-0002' = 'TASK-0001' }
Assert-Fails { Assert-FollowupDepth $cycle 'HEAD' 'TASK-0003' 'TASK-0001' 5 }
# A missing parent file cannot be silently treated as the end of the chain.
Assert-Fails { Assert-FollowupDepth $chain 'HEAD' 'TASK-0009' 'TASK-0042' 3 }

# Follow-up drafts.
$draft = @(
    '---', 'id:', 'parent-task: TASK-0001', 'title: Fix operand validation',
    'follow-up-reason: changes-requested', '---', '', '# Goal', 'Tighten validation.'
) -join "`n"
$fields = Get-FollowupDraft $draft $config 'TASK-0001' 'CHANGES_REQUESTED'
if ($fields['title'] -ne 'Fix operand validation') { throw 'Draft title not parsed.' }
Assert-Fails { Get-FollowupDraft $draft $config 'TASK-0001' 'PASS' }
Assert-Fails { Get-FollowupDraft $draft $config 'TASK-0002' 'CHANGES_REQUESTED' }
Assert-Fails { Get-FollowupDraft $draft $config 'TASK-0001' 'DECISION_REQUIRED' }
Assert-Fails { Get-FollowupDraft ($draft.Replace('id:', 'id: TASK-0002')) $config 'TASK-0001' 'CHANGES_REQUESTED' }
Assert-Fails { Get-FollowupDraft ($draft.Replace('title: Fix operand validation', 'title:')) $config 'TASK-0001' 'CHANGES_REQUESTED' }
Assert-Fails { Get-FollowupDraft ($draft.Replace("`n`n# Goal`nTighten validation.", '')) $config 'TASK-0001' 'CHANGES_REQUESTED' }
$badProfile = $draft.Replace('title: Fix operand validation', "title: T`nvalidation-profile: missing")
Assert-Fails { Get-FollowupDraft $badProfile $config 'TASK-0001' 'CHANGES_REQUESTED' }

$decision = $draft.Replace('follow-up-reason: changes-requested', 'follow-up-reason: decision-required')
Assert-Fails { Get-FollowupDraft $decision $config 'TASK-0001' 'DECISION_REQUIRED' }
$null = Get-FollowupDraft ($decision + "`n`n# Decisions required`n1. Which?") $config 'TASK-0001' 'DECISION_REQUIRED'

Get-ChildItem $starter -Recurse -Filter *.ps1 | ForEach-Object {
    $tokens = $null
    $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$tokens, [ref]$errors)
    if ($errors.Count) { throw ($errors | Out-String) }
}
Write-Host 'Metadata rejection/profile checks and starter PowerShell syntax passed.'
