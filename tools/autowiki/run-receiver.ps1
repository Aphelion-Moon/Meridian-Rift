param(
    [Parameter(Mandatory=$true)][string]$Node,
    [Parameter(Mandatory=$true)][string]$Receiver,
    [Parameter(Mandatory=$true)][string]$Configuration,
    [Parameter(Mandatory=$true)][string]$Log
)
$ErrorActionPreference = 'Stop'
# Call at the end of the existing wiki job schedule. Deploy a protected runtime copy.
if ((Test-Path -LiteralPath $Log) -and (Get-Item -LiteralPath $Log).Length -gt 5MB) {
    Move-Item -LiteralPath $Log -Destination ($Log + '.old') -Force
}
$result = & $Node $Receiver $Configuration 2>&1
$code = $LASTEXITCODE
if ($code -ne 0) {
    Add-Content -LiteralPath $Log -Encoding UTF8 -Value ((Get-Date -Format o) + ' Receiver failed; active reference retained.')
    $result | ForEach-Object { Add-Content -LiteralPath $Log -Encoding UTF8 -Value $_ }
}
# Reuse the existing job schedule for read-only queue health, after the heartbeat.
# Store only the bounded maintenance JSON; PHP failures belong in the private log.
try {
    $config = Get-Content -LiteralPath $Configuration -Raw | ConvertFrom-Json
    $priorWiki = $env:MW_WIKI
    Push-Location -LiteralPath $config.extensionDirectory
    try {
        $env:MW_WIKI = if ($config.wiki) { $config.wiki } else { 'meridian' }
        $health = & $config.php -d memory_limit=1G $config.maintenanceRunner './maintenance/Operations.php' --conf $config.settings --notify 2>&1
        $healthCode = $LASTEXITCODE
    } finally { Pop-Location; $env:MW_WIKI = $priorWiki }
    $status = ($health -join "`n") | ConvertFrom-Json -ErrorAction Stop
    if ($status.state -notin @('healthy', 'waiting', 'error') -or -not $status.checkedAt) { throw 'Invalid operations status' }
    $target = $config.statusFile + '.operations.json'
    $temporary = $target + '.' + $PID + '.pending'
    [System.IO.File]::WriteAllText($temporary, ($status | ConvertTo-Json -Depth 8), [System.Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $temporary -Destination $target -Force
    if ($healthCode -ne 0) { $code = 1; Add-Content -LiteralPath $Log -Value ((Get-Date -Format o) + ' Autowiki service health needs attention; inspect operations status.') }
} catch {
    $code = 1
    if ($config.statusFile) {
        $target = $config.statusFile + '.operations.json'
        $temporary = $target + '.' + $PID + '.pending'
        $unavailable = @{ state = 'error'; checkedAt = (Get-Date).ToUniversalTime().ToString('o'); message = 'The operations check could not complete.' }
        [System.IO.File]::WriteAllText($temporary, ($unavailable | ConvertTo-Json), [System.Text.UTF8Encoding]::new($false))
        Move-Item -LiteralPath $temporary -Destination $target -Force
    }
    Add-Content -LiteralPath $Log -Value ((Get-Date -Format o) + ' Autowiki service health check failed; inspect private maintenance diagnostics.')
}
exit $code
