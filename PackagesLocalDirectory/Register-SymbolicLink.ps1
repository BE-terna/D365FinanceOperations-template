param(
    # PackagesLocalDirectory
    [Parameter()]
    [string]
    $PackagesLocalDirectory = (Join-Path $env:SERVICEDRIVE 'AosService\PackagesLocalDirectory')
    ,
    [string]
    $GitPackagesDirectory = '.'
)

$ErrorActionPreference = "Stop"

$ModelFolders = Get-ChildItem $GitPackagesDirectory -Directory
foreach ($ModelFolder in $ModelFolders)
{
	#$Target = Get-Item -Directory (Join-Path $RepoMetadataPath $ModelFolder)
	New-Item -ItemType SymbolicLink -Path $PackagesLocalDirectory -Name $ModelFolder.Name -Value $ModelFolder.FullName -Verbose
}