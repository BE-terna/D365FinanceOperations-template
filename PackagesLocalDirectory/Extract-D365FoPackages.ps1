[CmdletBinding()]
Param(
    [string]
    $targetFolder
    ,
    [Parameter(ParameterSetName='PackageByFile')]
    [string]
    $deployablePackage

)

Set-StrictMode -Version 2.0
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.Environment]::CurrentDirectory = Get-Location

$package = [System.IO.Compression.ZipFile]::OpenRead($deployablePackage)
try 
{
    #$devPackages = [regex]::new('dynamicsax-(?!.*(test|formadaptor)).+-develop\..+\.zip')
    $devPackages = [regex]::new('dynamicsax-.+\.zip')

    $descriptor = [xml]::new()
    $buffer = [byte[]]::new(8*1024)

    $dp = $package.Entries.Where({$devPackages.IsMatch($_.Name)})
    #$dp|ft -Property Name
    "Found packages: $($dp.Count)"
    $dp | ForEach-Object {
        $devPackage = $_
        "ZIP: $devPackage"
        # $devPackage = $dp[0]

        $devPackageStream = $devPackage.Open()
        $devPackageSzip = [System.IO.Compression.ZipArchive]::new($devPackageStream, [System.IO.Compression.ZipArchiveMode]::Read, $false)
        try
        {
            $files = $devPackageSzip.Entries
            $xref = $devPackageSzip.Entries.Where({$_.FullName.EndsWith('.xref', [System.StringComparison]::OrdinalIgnoreCase)}, "First", 1)[0]
            $packageName = $xref.Name.Replace('.xref','')
            if ($packageName -eq 'BeForecastPlan') {
            }

            $destPackageFolder = Join-Path $targetFolder $packageName
            " Package $packageName files: $($files.Count) - Extraction to $destPackageFolder"
            if (Test-Path $destPackageFolder) {
                Remove-Item -Force -Recurse $destPackageFolder -ErrorAction Stop
            }
            [System.IO.Compression.ZipFileExtensions]::ExtractToDirectory($devPackageSzip, $destPackageFolder)
        }
        finally
        {
            $devPackageSzip.Dispose()
            $devPackageStream.Dispose()
        }
    }
}
finally
{
    $package.Dispose()
}