# Run with Windows PowerShell 5.1 or pwsh; never starts a sandbox or the dispatcher.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$path = Join-Path $PSScriptRoot '../src/agent-pipeline-demo-starter/template/automation/Start-AgentPipeline.ps1'
$tokens = $null
$errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile(
    (Resolve-Path $path).Path, [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw ($errors | Out-String) }
foreach ($name in @('Expand-Prompt', 'ConvertTo-AgentOutputText')) {
    $definition = $ast.Find({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name
    }, $true)
    if ($null -eq $definition) { throw "Missing function: $name" }
    . ([scriptblock]::Create($definition.Extent.Text))
}

# BOM-less UTF-8 is the case that defaults to ANSI in Windows PowerShell 5.1.
$file = [System.IO.Path]::GetTempFileName()
try {
    $unicode = 'PASS ' + [char]0x2014 + ' caf' + [char]0x00e9 + ' ' + [char]0x4e2d
    [System.IO.File]::WriteAllText($file, "{{TASK_ID}}: $unicode", [System.Text.UTF8Encoding]::new($false))
    $actual = Expand-Prompt $file @{ TASK_ID = 'TASK-0100' }
    if ($actual -cne "TASK-0100: $unicode") { throw 'UTF-8 prompt was corrupted.' }
    foreach ($message in @('', 'Attaching to sandbox', $unicode, 'ERROR: launch failed')) {
        $exception = [System.Management.Automation.RemoteException]::new($message)
        $record = [System.Management.Automation.ErrorRecord]::new(
            $exception, 'NativeCommandError',
            [System.Management.Automation.ErrorCategory]::NotSpecified, $null)
        $result = @($record | ConvertTo-AgentOutputText)
        if ($result.Count -ne 1 -or $result[0] -cne $message) {
            throw 'Native stderr text was altered or lost.'
        }
    }
    if (($unicode | ConvertTo-AgentOutputText) -cne $unicode) { throw 'stdout text was altered.' }
}
finally {
    Remove-Item -LiteralPath $file
}
Write-Host 'UTF-8 prompt and native stderr formatting checks passed.'
