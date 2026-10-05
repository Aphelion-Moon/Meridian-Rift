[CmdletBinding()]
param(
    [ValidateRange(1,1800)][int]$TimeoutSeconds = 300,
    [ValidateSet('fast','full')][string]$CompileMode = 'fast',
    [string]$DmPath = 'dm.exe',
    [string]$DreamDaemonPath = 'dreamdaemon.exe',
    [switch]$SkipCompile
)
$ErrorActionPreference = 'Stop'
if ($SkipCompile) { throw 'SkipCompile is retired: isolated RIFT runs require a fresh compile.' }
if ($DreamDaemonPath -ne 'dreamdaemon.exe') { throw 'Select the pinned BYOND installation with DmPath; its sibling DreamDaemon is verified by RIFT.' }
$previousDm = $env:DM_EXE
try {
    if ($DmPath -ne 'dm.exe') { $env:DM_EXE = $DmPath }
    & (Join-Path $PSScriptRoot '../../RIFT.cmd') run --compile-mode $CompileMode --profile dogmos --map _maps/runtimestation.json --run-seconds 0 --wall-timeout-seconds $TimeoutSeconds --readiness-timeout-seconds ([Math]::Min($TimeoutSeconds,900)) --format result
    exit $LASTEXITCODE
} finally { $env:DM_EXE = $previousDm }
