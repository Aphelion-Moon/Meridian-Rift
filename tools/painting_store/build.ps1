[CmdletBinding()]
param(
    [string]$OutputDirectory,
    [switch]$SkipTests
)
$ErrorActionPreference = 'Stop'
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $PSScriptRoot '..\..' }
$manifest = Join-Path $PSScriptRoot 'Cargo.toml'
if (-not $SkipTests) {
    & cargo +1.89.0 test --locked --manifest-path $manifest --target i686-pc-windows-msvc
    if ($LASTEXITCODE -ne 0) { throw 'Painting store tests failed.' }
}
& cargo +1.89.0 build --release --locked --manifest-path $manifest --target i686-pc-windows-msvc
if ($LASTEXITCODE -ne 0) { throw 'Painting store build failed.' }
$binary = Join-Path $PSScriptRoot 'target\i686-pc-windows-msvc\release\meridian_painting_store.dll'
if (-not (Test-Path -LiteralPath $OutputDirectory -PathType Container)) { throw 'Output directory must already exist.' }
Copy-Item -LiteralPath $binary -Destination (Join-Path $OutputDirectory 'meridian_painting_store.dll') -Force
$sources = [ordered]@{}
foreach ($relative in @('Cargo.toml', 'Cargo.lock', 'rust-toolchain.toml', 'src/lib.rs', 'src/store.rs', 'src/store/tests.rs')) {
    $sources[$relative] = (Get-FileHash -LiteralPath (Join-Path $PSScriptRoot $relative) -Algorithm SHA256).Hash.ToLowerInvariant()
}
$manifestData = [ordered]@{
    api = 1
    target = 'i686-pc-windows-msvc'
    rust = '1.89.0'
    binary = 'meridian_painting_store.dll'
    sha256 = (Get-FileHash -LiteralPath $binary -Algorithm SHA256).Hash.ToLowerInvariant()
    sources = $sources
}
$manifestData | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'binary-manifest.json') -Encoding ASCII
Get-FileHash -LiteralPath $binary -Algorithm SHA256
