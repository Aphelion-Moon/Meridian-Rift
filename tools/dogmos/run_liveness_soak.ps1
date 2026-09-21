[CmdletBinding()]
param(
    [ValidateSet('RuntimeStation', 'MetaStation')][string]$Map = 'RuntimeStation',
    [ValidateRange(30, 1800)][int]$SoakSeconds = 300
)
$ErrorActionPreference = 'Stop'
$gameRepository = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Push-Location -LiteralPath $gameRepository
try {
    & python -B tools/dogmos/verify_contract.py verify-installed --root .
    if ($LASTEXITCODE -ne 0) { throw 'Installed native contract failed verification.' }
    $mapPath = if ($Map -eq 'RuntimeStation') { '_maps/runtimestation.json' } else { '_maps/metastation.json' }
    & bun tools/rift/rift.ts soak --profile dogmos --map $mapPath --run-seconds $SoakSeconds
    if ($LASTEXITCODE -ne 0) { throw 'Native liveness soak failed.' }
} finally { Pop-Location }
