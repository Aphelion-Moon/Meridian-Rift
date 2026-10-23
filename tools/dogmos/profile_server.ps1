[CmdletBinding()]
param([Parameter(ValueFromRemainingArguments=$true)][string[]]$ServerArguments)
$ErrorActionPreference = 'Stop'
$gameRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$marker = Join-Path $gameRoot 'data/enable_tracy'
$ownedMarker = $null
$serverExit = 1
$serverError = $null
$cleanupError = $null
try {
    if (-not (Test-Path -LiteralPath $marker)) {
        $stream = [IO.File]::Open($marker, 'CreateNew', 'Write', 'ReadWrite,Delete')
        $stream.Dispose()
        $ownedMarker = Get-Item -LiteralPath $marker
        $createdUtc = $ownedMarker.CreationTimeUtc
        $writtenUtc = $ownedMarker.LastWriteTimeUtc
    }
    & (Join-Path $gameRoot 'RUN_SERVER.cmd') @ServerArguments
    $serverExit = $LASTEXITCODE
} catch {
    $serverError = $_
} finally {
    if ($null -ne $ownedMarker -and (Test-Path -LiteralPath $marker)) {
        $current = Get-Item -LiteralPath $marker
        if ($current.Length -eq 0 -and $current.CreationTimeUtc -eq $createdUtc -and $current.LastWriteTimeUtc -eq $writtenUtc) {
            try { Remove-Item -LiteralPath $marker -ErrorAction Stop }
            catch { $cleanupError = $_ }
        }
    }
}
if ($null -ne $serverError) { Write-Error -ErrorRecord $serverError -ErrorAction Continue }
if ($null -ne $cleanupError) {
    Write-Error -ErrorRecord $cleanupError -ErrorAction Continue
    if ($serverExit -eq 0) { $serverExit = 1 }
}
exit $serverExit
