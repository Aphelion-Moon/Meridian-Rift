# APHELION MODULE - Stage a private, immutable Nova artwork source; never alter the backup.
# Compatible with Windows PowerShell 5.1. The native helper performs authoritative validation.
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$BackupMetadata,
    [string]$BackupImageRoot,
    [string]$RepositoryRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$maxJson = 32MB
$maxPng = 1MB
$utf8 = [Text.UTF8Encoding]::new($false, $true)
if (-not $RepositoryRoot) { $RepositoryRoot = Join-Path $PSScriptRoot '../..' }

<#
.SYNOPSIS
Reject symbolic links and junctions anywhere along a staging path.
#>
function Assert-PlainPath([string]$Path) {
    $cursor = [IO.Path]::GetFullPath($Path)
    while ($cursor) {
        if (Test-Path -LiteralPath $cursor) {
            $item = Get-Item -LiteralPath $cursor -Force
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                throw 'Staging paths must not contain symbolic links or junctions.'
            }
        }
        $parent = [IO.Path]::GetDirectoryName($cursor)
        if ($parent -eq $cursor) { break }
        $cursor = $parent
    }
}

<#
.SYNOPSIS
Read a regular input within its byte limit, checking again after the read.
#>
function Read-Bounded([string]$Path, [long]$Limit) {
    Assert-PlainPath $Path
    $info = Get-Item -LiteralPath $Path -Force
    if ($info.PSIsContainer -or $info.Length -gt $Limit) {
        throw 'A staging input has an invalid type or exceeds the size limit.'
    }
    $bytes = [IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -gt $Limit) { throw 'A staging input changed beyond the size limit.' }
    return ,$bytes
}

<#
.SYNOPSIS
Compute a lowercase SHA-256 fingerprint for exact-byte staging verification.
#>
function Get-ByteHash([byte[]]$Bytes) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($sha.ComputeHash($Bytes)).Replace('-', '').ToLowerInvariant() }
    finally { $sha.Dispose() }
}

<#
.SYNOPSIS
Read an optional JSON property without flattening arrays or failing strict mode.
#>
function Get-Field($Object, [string]$Name) {
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return ,$property.Value
}

<#
.SYNOPSIS
Accept only decoded integer types for catalog versions and image dimensions.
#>
function Test-Integer($Value) {
    return ($Value -is [int] -or $Value -is [long])
}

<#
.SYNOPSIS
Decode an unsigned four-byte PNG header value at the supplied offset.
#>
function Read-BigEndian32([byte[]]$Bytes, [int]$Offset) {
    return [long]$Bytes[$Offset] * 16777216 + [long]$Bytes[$Offset + 1] * 65536 +
        [long]$Bytes[$Offset + 2] * 256 + [long]$Bytes[$Offset + 3]
}

<#
.SYNOPSIS
Check the PNG signature and recorded dimensions before authoritative native decoding.
#>
function Assert-PngHeader([byte[]]$Bytes, [long]$Width, [long]$Height) {
    if ($Bytes.Length -lt 33 -or
        [BitConverter]::ToString($Bytes, 0, 16) -ne '89-50-4E-47-0D-0A-1A-0A-00-00-00-0D-49-48-44-52' -or
        (Read-BigEndian32 $Bytes 16) -ne $Width -or
        (Read-BigEndian32 $Bytes 20) -ne $Height) {
        throw 'A referenced image has an invalid PNG signature or mismatched dimensions.'
    }
}

<#
.SYNOPSIS
Allow an existing destination only when its bounded bytes match the source digest.
#>
function Assert-Destination([string]$Path, [string]$ExpectedHash, [long]$Limit) {
    Assert-PlainPath $Path
    if (Test-Path -LiteralPath $Path) {
        if ((Get-ByteHash (Read-Bounded $Path $Limit)) -ne $ExpectedHash) {
            throw 'An existing destination differs from the backup; nothing may overwrite it.'
        }
    }
}

<#
.SYNOPSIS
Publish a flushed, verified, read-only source copy without overwriting an existing destination.
#>
function Copy-Verified([string]$Source, [string]$Destination, [string]$ExpectedHash, [long]$Limit) {
    Assert-Destination $Destination $ExpectedHash $Limit
    if (Test-Path -LiteralPath $Destination) {
        $attributes = [IO.File]::GetAttributes($Destination)
        if (-not ($attributes -band [IO.FileAttributes]::ReadOnly)) {
            [IO.File]::SetAttributes($Destination, $attributes -bor [IO.FileAttributes]::ReadOnly)
        }
        return $false
    }
    $bytes = Read-Bounded $Source $Limit
    if ((Get-ByteHash $bytes) -ne $ExpectedHash) { throw 'The backup changed during staging; retry from a stable backup.' }
    $directory = [IO.Path]::GetDirectoryName($Destination)
    Assert-PlainPath $directory
    [IO.Directory]::CreateDirectory($directory) | Out-Null
    $temporary = Join-Path $directory ('.nova-stage-' + [Guid]::NewGuid().ToString('N') + '.tmp')
    try {
        $stream = [IO.File]::Open($temporary, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
        try { $stream.Write($bytes, 0, $bytes.Length); $stream.Flush($true) }
        finally { $stream.Dispose() }
        if ((Get-ByteHash (Read-Bounded $temporary $Limit)) -ne $ExpectedHash) { throw 'Staged copy verification failed.' }
        [IO.File]::SetAttributes($temporary, [IO.File]::GetAttributes($temporary) -bor [IO.FileAttributes]::ReadOnly)
        Assert-PlainPath $Destination
        # The two-argument Move rejects an existing destination on every supported .NET runtime.
        [IO.File]::Move($temporary, $Destination)
        Assert-Destination $Destination $ExpectedHash $Limit
        return $true
    }
    finally {
        if (Test-Path -LiteralPath $temporary) {
            [IO.File]::SetAttributes($temporary, [IO.FileAttributes]::Normal)
            [IO.File]::Delete($temporary)
        }
    }
}

$repository = [IO.Path]::GetFullPath($RepositoryRoot).TrimEnd([IO.Path]::DirectorySeparatorChar)
$metadata = [IO.Path]::GetFullPath($BackupMetadata)
if (-not $BackupImageRoot) { $BackupImageRoot = Join-Path ([IO.Path]::GetDirectoryName($metadata)) 'paintings/images' }
$imageRoot = [IO.Path]::GetFullPath($BackupImageRoot).TrimEnd([IO.Path]::DirectorySeparatorChar)
$destinationRoot = Join-Path $repository 'config/nova'
$destinationMetadata = Join-Path $destinationRoot 'paintings.json'
$destinationImages = Join-Path $destinationRoot 'paintings/images'
Assert-PlainPath $repository
Assert-PlainPath $metadata
Assert-PlainPath $imageRoot
Assert-PlainPath $destinationRoot
if (-not (Test-Path -LiteralPath $repository -PathType Container) -or
    -not (Test-Path -LiteralPath $imageRoot -PathType Container)) { throw 'Repository and backup image directories must exist.' }
$sourcePrefix = $destinationRoot + [IO.Path]::DirectorySeparatorChar
if ($metadata.StartsWith($sourcePrefix, [StringComparison]::OrdinalIgnoreCase) -or
    $imageRoot.StartsWith($sourcePrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'The backup must be separate from the destination Nova directory.'
}
foreach ($ignored in @('config/nova/paintings.json', 'config/nova/paintings/images/00000000000000000000000000000000.png')) {
    & git -c core.excludesFile= -C $repository check-ignore --quiet -- $ignored
    if ($LASTEXITCODE -ne 0) { throw 'The private Nova metadata and image destination must be Git-ignored before staging.' }
}

$metadataBytes = Read-Bounded $metadata $maxJson
$metadataHash = Get-ByteHash $metadataBytes
$jsonOptions = @{}
if ((Get-Command ConvertFrom-Json).Parameters.ContainsKey('DateKind')) { $jsonOptions.DateKind = 'String' }
try { $catalog = $utf8.GetString($metadataBytes) | ConvertFrom-Json @jsonOptions }
catch { throw 'The backup metadata is not a valid UTF-8 JSON document.' }
if ($catalog -isnot [pscustomobject] -or -not (Test-Integer (Get-Field $catalog 'version')) -or
    (Get-Field $catalog 'version') -ne 3) { throw 'The backup must be a version-3 painting catalog.' }
$rows = Get-Field $catalog 'paintings'
if ($rows -isnot [array] -or $rows.Count -gt 10000) { throw 'The backup must contain a painting array with at most 10000 records.' }
$ids = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
$plan = [Collections.Generic.List[object]]::new()
$dimensions = @('11x11', '19x19', '23x19', '23x23', '24x24', '36x24', '45x27')
foreach ($row in $rows) {
    if ($row -isnot [pscustomobject]) { throw 'Every painting record must be an object.' }
    $id = Get-Field $row 'md5'
    if ($id -isnot [string] -or $id -cnotmatch '^[a-f0-9]{32}$' -or -not $ids.Add($id)) { throw 'Painting identities must be unique lowercase 32-character hexadecimal strings.' }
    $width = Get-Field $row 'width'
    $height = Get-Field $row 'height'
    if (-not (Test-Integer $width) -or -not (Test-Integer $height) -or "$($width)x$($height)" -notin $dimensions) { throw 'A painting has unsupported dimensions.' }
    foreach ($field in @('title', 'creator_name', 'creation_date', 'patron_name', 'medium', 'frame_type')) {
        $value = Get-Field $row $field
        if ($null -ne $value -and ($value -isnot [string] -or $utf8.GetByteCount($value) -gt 4096 -or $value.Contains([char]0))) { throw 'A painting text field is invalid or too long.' }
    }
    foreach ($field in @('creator_ckey', 'patron_ckey')) {
        $value = Get-Field $row $field
        if ($null -ne $value -and ($value -isnot [string] -or $value.Length -gt 128 -or $value -cnotmatch '^[a-z0-9]*$')) { throw 'A painting account identity is invalid.' }
    }
    $source = Join-Path $imageRoot ($id + '.png')
    $destination = Join-Path $destinationImages ($id + '.png')
    $bytes = Read-Bounded $source $maxPng
    Assert-PngHeader $bytes $width $height
    $hash = Get-ByteHash $bytes
    Assert-Destination $destination $hash $maxPng
    $plan.Add([pscustomobject]@{ id = $id; source = $source; destination = $destination; sha256 = $hash })
}
Assert-Destination $destinationMetadata $metadataHash $maxJson

# Everything has passed preliminary checks before the first destination write.
# Complete images before publishing metadata. An interrupted first run can be rerun safely.
$copied = 0
foreach ($entry in $plan) {
    if (Copy-Verified $entry.source $entry.destination $entry.sha256 $maxPng) { $copied++ }
}
$metadataCopied = Copy-Verified $metadata $destinationMetadata $metadataHash $maxJson
$manifestText = ($plan | Sort-Object id | ForEach-Object { $_.id + ' ' + $_.sha256 + "`n" }) -join ''
[ordered]@{
    schema = 1
    painting_count = $rows.Count
    referenced_images = $plan.Count
    images_copied = $copied
    images_already_present = $plan.Count - $copied
    metadata_copied = $metadataCopied
    metadata_sha256 = $metadataHash
    images_manifest_sha256 = Get-ByteHash ($utf8.GetBytes($manifestText))
} | ConvertTo-Json -Compress
