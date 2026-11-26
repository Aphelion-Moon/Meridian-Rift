param([Parameter(Mandatory=$true)][string]$EvidenceRoot)
$ErrorActionPreference = 'Stop'
$EvidenceRoot = [IO.Path]::GetFullPath($EvidenceRoot)
if (Test-Path -LiteralPath $EvidenceRoot) { throw 'Choose a fresh fixture evidence directory.' }
$cases = @()
foreach ($scenario in @('success', 'failure', 'preexisting', 'replacement', 'consumed', 'cleanup-failure')) {
    $root = Join-Path $EvidenceRoot $scenario
    $toolRoot = Join-Path $root 'tools/dogmos'
    New-Item -ItemType Directory -Path $toolRoot,(Join-Path $root 'data') -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot '../profile_server.ps1') -Destination $toolRoot
    $marker = Join-Path $root 'data/enable_tracy'
    if ($scenario -eq 'preexisting') { [IO.File]::WriteAllText($marker, 'preexisting') }
    $body = switch ($scenario) {
        'replacement' { '@echo replacement> "%~dp0data\enable_tracy"' }
        'consumed' { '@del "%~dp0data\enable_tracy"' }
        'cleanup-failure' { '@attrib +R "%~dp0data\enable_tracy"' }
        default { '@echo fixture server' }
    }
    $expectedExit = if ($scenario -eq 'failure') { 42 } elseif ($scenario -eq 'cleanup-failure') { 1 } else { 0 }
    $childExit = if ($scenario -eq 'failure') { 42 } else { 0 }
    [IO.File]::WriteAllText((Join-Path $root 'RUN_SERVER.cmd'), "$body`r`n@exit /b $childExit`r`n")
    & powershell.exe -NoProfile -NonInteractive -File (Join-Path $toolRoot 'profile_server.ps1') *> (Join-Path $root 'output.log')
    $actualExit = $LASTEXITCODE
    if ($actualExit -ne $expectedExit) { throw "Unexpected exit for $scenario : $actualExit" }
    $remains = Test-Path -LiteralPath $marker
    if ($remains -ne ($scenario -in @('preexisting', 'replacement', 'cleanup-failure'))) { throw "Marker ownership failed for $scenario" }
    if ($scenario -eq 'preexisting' -and [IO.File]::ReadAllText($marker) -ne 'preexisting') { throw 'Preexisting marker changed.' }
    $cases += @{scenario=$scenario;passed=$true;exit=$actualExit;marker_retained=$remains}
}
@{scope='Profile wrapper with fixture server; no game launched';cases=$cases} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $EvidenceRoot 'result.json')
Write-Output "Passed $($cases.Count) marker ownership scenarios."
exit 0
