[CmdletBinding()]
param([ValidateRange(1,1800)][int]$TimeoutSeconds = 600, [string]$DmPath = 'dm.exe')
$ErrorActionPreference = 'Stop'
$previousDm = $env:DM_EXE
try {
    if ($DmPath -ne 'dm.exe') { $env:DM_EXE = $DmPath }
    & (Join-Path $PSScriptRoot '../../RIFT.cmd') compile --mode fast --profile dogmos-test-compile --wall-timeout-seconds $TimeoutSeconds --format result
    exit $LASTEXITCODE
} finally { $env:DM_EXE = $previousDm }
