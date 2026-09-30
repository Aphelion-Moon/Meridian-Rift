[CmdletBinding()]
param(
    [string]$OutputDirectory,
    [switch]$SkipTests
)
$ErrorActionPreference = 'Stop'
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $PSScriptRoot '..\..' }
<#
.SYNOPSIS
Hash a file as a stream, like verify.ps1. Get-FileHash is missing when Windows PowerShell inherits PowerShell 7's module path.
#>
function Get-PaintingStoreHash([string]$Path) {
    $sha = [Security.Cryptography.SHA256]::Create()
    $stream = [IO.File]::OpenRead($Path)
    try { return [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-', '').ToLowerInvariant() }
    finally { $stream.Dispose(); $sha.Dispose() }
}
# Services such as TGS don't always have the account's cargo directory on PATH.
$cargoHome = if ($env:CARGO_HOME) { $env:CARGO_HOME } else { Join-Path $env:USERPROFILE '.cargo' }
$env:PATH = "$(Join-Path $cargoHome 'bin');$env:PATH"
if (-not (Get-Command rustup -ErrorAction SilentlyContinue)) {
    throw 'Rebuilding the painting store needs rustup and the Visual Studio C++ build tools with x86 libraries.'
}
# The pinned compiler and 32-bit target are installed only when missing, so rebuilds can run offline.
# A build must never update rustup itself, which other tools on the machine share.
if (-not ((& rustup toolchain list) -match '^1\.89\.0-')) {
    & rustup toolchain install 1.89.0 --profile minimal --target i686-pc-windows-msvc --no-self-update
    if ($LASTEXITCODE -ne 0) { throw 'Installing Rust 1.89.0 failed.' }
}
if ((& rustup target list --installed --toolchain 1.89.0) -notcontains 'i686-pc-windows-msvc') {
    & rustup target add --toolchain 1.89.0 i686-pc-windows-msvc
    if ($LASTEXITCODE -ne 0) { throw 'Installing the i686-pc-windows-msvc target failed.' }
}
$manifest = Join-Path $PSScriptRoot 'Cargo.toml'
if (-not $SkipTests) {
    & cargo +1.89.0 test --locked --manifest-path $manifest --target i686-pc-windows-msvc
    if ($LASTEXITCODE -ne 0) { throw 'Painting store tests failed.' }
}
& cargo +1.89.0 build --release --locked --manifest-path $manifest --target i686-pc-windows-msvc
if ($LASTEXITCODE -ne 0) { throw 'Painting store build failed.' }
$targetDirectory = if ($env:CARGO_TARGET_DIR) { $env:CARGO_TARGET_DIR } else { Join-Path $PSScriptRoot 'target' }
$binary = Join-Path $targetDirectory 'i686-pc-windows-msvc\release\meridian_painting_store.dll'
if (-not (Test-Path -LiteralPath $OutputDirectory -PathType Container)) { throw 'Output directory must already exist.' }
Copy-Item -LiteralPath $binary -Destination (Join-Path $OutputDirectory 'meridian_painting_store.dll') -Force
$sources = [ordered]@{}
foreach ($relative in @('Cargo.toml', 'Cargo.lock', 'rust-toolchain.toml', 'src/lib.rs', 'src/store.rs', 'src/store/tests.rs')) {
    $sources[$relative] = Get-PaintingStoreHash (Join-Path $PSScriptRoot $relative)
}
$binaryHash = Get-PaintingStoreHash $binary
$manifestData = [ordered]@{
    api = 1
    target = 'i686-pc-windows-msvc'
    rust = '1.89.0'
    binary = 'meridian_painting_store.dll'
    sha256 = $binaryHash
    sources = $sources
}
$manifestData | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'binary-manifest.json') -Encoding ASCII
Write-Output "Built meridian_painting_store.dll, SHA256 $binaryHash. Commit it with binary-manifest.json."
