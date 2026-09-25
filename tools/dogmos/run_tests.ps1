[CmdletBinding()]
param(
    [string[]]$Focus,
    [ValidateRange(1,3600)][int]$TimeoutSeconds = 2400,
    [ValidateRange(0,10000)][int]$MinimumTests = 0,
    [ValidateSet('RuntimeStation','MetaStation')][string]$Map = 'RuntimeStation'
)
$ErrorActionPreference = 'Stop'
$mapPath = if ($Map -eq 'RuntimeStation') { '_maps/runtimestation.json' } else { '_maps/metastation.json' }
$riftArguments = @('test','--profile','dogmos-ci','--map',$mapPath,'--wall-timeout-seconds',"$TimeoutSeconds",'--format','result')
foreach ($test in $Focus) { $riftArguments += @('--focus',$test) }
if ($MinimumTests) { $riftArguments += @('--minimum-tests',"$MinimumTests") }
& (Join-Path $PSScriptRoot '../../RIFT.cmd') @riftArguments
exit $LASTEXITCODE
