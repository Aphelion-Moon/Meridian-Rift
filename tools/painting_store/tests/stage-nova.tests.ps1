# APHELION MODULE - Isolated staging checks; no external backup or game data is used.
[CmdletBinding()]
param([string]$StageScript)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (-not $StageScript) { $StageScript = Join-Path $PSScriptRoot '../stage-nova.ps1' }
$utf8 = [Text.UTF8Encoding]::new($false)
$temporaryBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$fixtureRoot = Join-Path $temporaryBase ('meridian-nova-staging-test-' + [Guid]::NewGuid().ToString('N'))
$repository = Join-Path $fixtureRoot 'repository'
$source = Join-Path $fixtureRoot 'backup'
$sourceImages = Join-Path $source 'paintings/images'
$sourceMetadata = Join-Path $source 'paintings.json'
$id = '0123456789abcdef0123456789abcdef'
$otherId = 'fedcba9876543210fedcba9876543210'
$unreferencedId = 'cccccccccccccccccccccccccccccccc'
$png = [Convert]::FromBase64String('iVBORw0KGgoAAAANSUhEUgAAAAsAAAALCAIAAAAmzuBxAAAAE0lEQVR4nGNQiW3CjxhGVVBdBQBGaHpscjfFbgAAAABJRU5ErkJggg==')
$catalog = @{
    version = 3
    future_catalog_field = @{ preserve = $true }
    paintings = @(
        @{ md5 = $id; width = 11; height = 11; creator_ckey = 'syntheticartist'; creator_name = 'Anonymous'; creation_date = '2020-03-18T01:02:03Z'; future_field = 'keep' },
        @{ md5 = $otherId; width = 11; height = 11; creator_name = 'Synthetic historical signature' }
    )
}

<#
.SYNOPSIS
Stop the isolated staging check when an expected invariant does not hold.
#>
function Assert($Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}
<#
.SYNOPSIS
Require the supplied operation to reject its invalid staging scenario.
#>
function Expect-Failure([scriptblock]$Operation, [string]$Message) {
    $failed = $false
    try { & $Operation | Out-Null } catch { $failed = $true }
    Assert $failed $Message
}
<#
.SYNOPSIS
Run the real staging script against this test's private backup and repository.
#>
function Invoke-Stage {
    & $StageScript -BackupMetadata $sourceMetadata -BackupImageRoot $sourceImages -RepositoryRoot $repository | ConvertFrom-Json
}
<#
.SYNOPSIS
Capture content, timestamp, and attributes to detect otherwise invisible file modifications.
#>
function Get-State([string]$Path) {
    $item = Get-Item -LiteralPath $Path
    return '{0}:{1}:{2}' -f (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash, $item.LastWriteTimeUtc.Ticks, [int]$item.Attributes
}
<#
.SYNOPSIS
Write the current synthetic metadata as UTF-8 into the isolated backup.
#>
function Write-FixtureCatalog {
    [IO.File]::WriteAllText($sourceMetadata, ($catalog | ConvertTo-Json -Depth 8), $utf8)
}

try {
    [IO.Directory]::CreateDirectory($repository) | Out-Null
    [IO.Directory]::CreateDirectory($sourceImages) | Out-Null
    & git -C $repository init --quiet
    if ($LASTEXITCODE -ne 0) { throw 'Could not initialize the isolated test repository.' }
    [IO.File]::WriteAllText((Join-Path $repository '.gitignore'), "/config/nova/paintings.json`n/config/nova/paintings/`n", $utf8)
    $nova = Join-Path $repository 'config/nova'
    [IO.Directory]::CreateDirectory($nova) | Out-Null
    $unrelated = Join-Path $nova 'unrelated.txt'
    [IO.File]::WriteAllText($unrelated, 'Preserve unrelated Nova configuration.', $utf8)
    Write-FixtureCatalog
    foreach ($imageId in @($id, $otherId, $unreferencedId)) { [IO.File]::WriteAllBytes((Join-Path $sourceImages ($imageId + '.png')), $png) }
    $sourceState = Get-State $sourceMetadata
    $sourceImageState = Get-State (Join-Path $sourceImages ($id + '.png'))
    $unrelatedState = Get-State $unrelated

    $first = Invoke-Stage
    Assert ($first.painting_count -eq 2 -and $first.images_copied -eq 2 -and $first.metadata_copied) 'The initial staging result is incorrect.'
    $destinationMetadata = Join-Path $nova 'paintings.json'
    $destinationImage = Join-Path $nova ('paintings/images/' + $id + '.png')
    Assert ((Get-FileHash -LiteralPath $destinationMetadata).Hash -eq (Get-FileHash -LiteralPath $sourceMetadata).Hash) 'Staging rewrote metadata instead of preserving its exact bytes.'
    Assert (-not (Test-Path -LiteralPath (Join-Path $nova ('paintings/images/' + $unreferencedId + '.png')))) 'An unreferenced image was copied.'
    foreach ($path in @($destinationMetadata, $destinationImage)) { Assert ([IO.File]::GetAttributes($path) -band [IO.FileAttributes]::ReadOnly) 'A staged file is not read-only.' }
    Assert ((Get-State $sourceMetadata) -eq $sourceState -and (Get-State (Join-Path $sourceImages ($id + '.png'))) -eq $sourceImageState) 'Staging modified the backup.'
    Assert ((Get-State $unrelated) -eq $unrelatedState) 'Staging modified unrelated Nova contents.'
    $metadataState = Get-State $destinationMetadata
    $imageState = Get-State $destinationImage
    $again = Invoke-Stage
    Assert ($again.images_copied -eq 0 -and -not $again.metadata_copied -and $again.images_manifest_sha256 -eq $first.images_manifest_sha256) 'Repeated staging was not a no-op.'
    Assert ((Get-State $destinationMetadata) -eq $metadataState -and (Get-State $destinationImage) -eq $imageState) 'Repeated staging changed bytes, timestamps, or attributes.'

    [IO.File]::SetAttributes($destinationImage, [IO.FileAttributes]::Normal)
    [IO.File]::WriteAllBytes($destinationImage, [byte[]]@(1, 2, 3))
    $divergentImageState = Get-State $destinationImage
    Expect-Failure { Invoke-Stage } 'A divergent destination image was accepted.'
    Assert ((Get-State $destinationImage) -eq $divergentImageState -and (Get-State $destinationMetadata) -eq $metadataState) 'Rejecting a collision changed an existing file.'
    [IO.File]::WriteAllBytes($destinationImage, $png)
    [IO.File]::SetAttributes($destinationImage, [IO.FileAttributes]::ReadOnly)

    [IO.File]::SetAttributes($destinationMetadata, [IO.FileAttributes]::Normal)
    [IO.File]::WriteAllText($destinationMetadata, '{"version":3,"paintings":[]}', $utf8)
    $divergentMetadataState = Get-State $destinationMetadata
    Expect-Failure { Invoke-Stage } 'Divergent destination metadata was accepted.'
    Assert ((Get-State $destinationMetadata) -eq $divergentMetadataState) 'Rejecting metadata divergence changed the destination.'
    [IO.File]::WriteAllBytes($destinationMetadata, [IO.File]::ReadAllBytes($sourceMetadata))
    [IO.File]::SetAttributes($destinationMetadata, [IO.FileAttributes]::ReadOnly)

    $catalog.paintings[0].md5 = '../escape'
    Write-FixtureCatalog
    Expect-Failure { Invoke-Stage } 'A path-escape identity was accepted.'
    $catalog.paintings[0].md5 = $id
    $catalog.paintings[0].width = 24
    Write-FixtureCatalog
    Expect-Failure { Invoke-Stage } 'Unsupported metadata dimensions were accepted.'
    $catalog.paintings[0].height = 24
    Write-FixtureCatalog
    Expect-Failure { Invoke-Stage } 'Metadata dimensions differing from PNG content were accepted.'
    $catalog.paintings[0].width = 11
    $catalog.paintings[0].height = 11
    $catalog.version = '3'
    Write-FixtureCatalog
    Expect-Failure { Invoke-Stage } 'A string metadata version was accepted.'
    $catalog.version = 3
    $catalog.paintings[1].md5 = $id
    Write-FixtureCatalog
    Expect-Failure { Invoke-Stage } 'Duplicate identities were accepted.'
    $catalog.paintings[1].md5 = $otherId
    Write-FixtureCatalog
    [IO.File]::WriteAllBytes((Join-Path $sourceImages ($id + '.png')), [byte[]]@(1, 2, 3))
    Expect-Failure { Invoke-Stage } 'An invalid PNG signature was accepted.'
    Write-Output 'Nova staging tests passed: exact copy, read-only, no unreferenced images, no-op retry, collisions, path escapes, versions, identities, and PNG dimensions/signatures.'
}
finally {
    $resolved = [IO.Path]::GetFullPath($fixtureRoot)
    if (-not $resolved.StartsWith($temporaryBase, [StringComparison]::OrdinalIgnoreCase) -or
        [IO.Path]::GetFileName($resolved) -notmatch '^meridian-nova-staging-test-[a-f0-9]{32}$') { throw 'Refusing unexpected fixture cleanup path.' }
    if (Test-Path -LiteralPath $resolved) {
        if (Get-ChildItem -LiteralPath $resolved -Recurse -Force -Attributes ReparsePoint) { throw 'Refusing fixture cleanup through a link.' }
        Get-ChildItem -LiteralPath $resolved -Recurse -Force -File | ForEach-Object { [IO.File]::SetAttributes($_.FullName, [IO.FileAttributes]::Normal) }
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
