[CmdletBinding()]
param([string]$RepositoryRoot)
$ErrorActionPreference = 'Stop'
if (-not $RepositoryRoot) { $RepositoryRoot = Join-Path $PSScriptRoot '..\..' }
<#
.SYNOPSIS
Hash a file as a stream to verify the pinned native binary and source inventory.
#>
function Get-PaintingStoreHash([string]$Path) {
    $sha = [Security.Cryptography.SHA256]::Create()
    $stream = [IO.File]::OpenRead($Path)
    try { return [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-', '').ToLowerInvariant() }
    finally { $stream.Dispose(); $sha.Dispose() }
}
$manifest = Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot 'binary-manifest.json') | ConvertFrom-Json
if ($manifest.api -ne 1 -or $manifest.target -ne 'i686-pc-windows-msvc' -or $manifest.binary -ne 'meridian_painting_store.dll') {
    throw 'Invalid painting-store binary manifest.'
}
$binary = Join-Path $RepositoryRoot 'meridian_painting_store.dll'
if ((Get-PaintingStoreHash $binary) -ne $manifest.sha256) {
    throw 'Painting-store DLL hash mismatch. Rebuild from the pinned source before deploying.'
}
foreach ($relative in @('Cargo.toml', 'Cargo.lock', 'rust-toolchain.toml', 'src/lib.rs', 'src/store.rs', 'src/store/tests.rs')) {
    $expected = $manifest.sources.$relative
    if (-not $expected -or (Get-PaintingStoreHash (Join-Path $PSScriptRoot $relative)) -ne $expected) {
        throw "Painting-store source changed: $relative. Rebuild the DLL and manifest before deploying."
    }
}
$bytes = [IO.File]::ReadAllBytes($binary)
if ($bytes.Length -lt 256 -or $bytes[0] -ne 0x4d -or $bytes[1] -ne 0x5a) { throw 'Painting-store DLL is not a PE binary.' }
$peOffset = [BitConverter]::ToInt32($bytes, 0x3c)
if ($peOffset -lt 0 -or ($peOffset + 6) -gt $bytes.Length -or [BitConverter]::ToUInt32($bytes, $peOffset) -ne 0x00004550 -or [BitConverter]::ToUInt16($bytes, $peOffset + 4) -ne 0x014c) {
    throw 'Painting-store DLL must target 32-bit x86 BYOND.'
}
Write-Output 'Painting-store API 1 source and x86 DLL hashes verified.'
