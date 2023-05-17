[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $MetadataPath,

    [Parameter(Mandatory = $true)]
    [string] $OutputPath
)

$rnrProjTemplate = 
@"
<?xml version="1.0" encoding="utf-8"?>
<Project ToolsVersion="14.0" DefaultTargets="Build" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
    <PropertyGroup>
        <Configuration Condition=" '`$(Configuration)' == '' ">Debug</Configuration>
        <Platform Condition=" '`$(Platform)' == '' ">AnyCPU</Platform>
        <BuildTasksDirectory Condition=" '`$(BuildTasksDirectory)' == ''">`$(MSBuildProgramFiles32)\MSBuild\Microsoft\Dynamics\AX</BuildTasksDirectory>
        <Model>AdactaAdriaticLocalization</Model>
        <TargetFrameworkVersion>v4.6</TargetFrameworkVersion>
        <OutputPath>bin</OutputPath>
        <SchemaVersion>2.0</SchemaVersion>
        <ProjectGuid>{bf3c4f71-b115-446e-b5ba-2600eeceab2f}</ProjectGuid>
        <Name>AdactaAdriaticLocalizationCore</Name>
        <RootNamespace>AdactaAdriaticLocalizationCore</RootNamespace>
    </PropertyGroup>
    <PropertyGroup Condition="'`$(Configuration)|`$(Platform)' == 'Debug|AnyCPU'">
        <Configuration>Debug</Configuration>
        <DBSyncInBuild>False</DBSyncInBuild>
        <GenerateFormAdaptors>False</GenerateFormAdaptors>
        <Company>
        </Company>
        <Partition>initial</Partition>
        <PlatformTarget>AnyCPU</PlatformTarget>
        <DataEntityExpandParentChildRelations>False</DataEntityExpandParentChildRelations>
        <DataEntityUseLabelTextAsFieldName>False</DataEntityUseLabelTextAsFieldName>
    </PropertyGroup>
    <PropertyGroup Condition=" '`$(Configuration)' == 'Debug' ">
        <DebugSymbols>true</DebugSymbols>
        <EnableUnmanagedDebugging>false</EnableUnmanagedDebugging>
    </PropertyGroup>
    <Import Project="`$(MSBuildBinPath)\Microsoft.Common.targets" />
    <Import Project="`$(BuildTasksDirectory)\Microsoft.Dynamics.Framework.Tools.BuildTasks.targets" />
</Project>
"@

$xmlns = "http://schemas.microsoft.com/developer/msbuild/2003"

$dictModels = @{}
$dictModelsGuid = @{}

Get-ChildItem $metadataPath -Directory -Recurse |
Where-Object { $_.Name -eq "Descriptor" } |
ForEach-Object { 
    Get-ChildItem $_.FullName -Filter "*.xml" |
    ForEach-Object { 
        [Xml]$descriptorXml = Get-Content -Path $_.FullName
                    
        $descriptorPath = $_.FullName
        $modelName = $descriptorXml.AxModelInfo.ModelModule
                                      
        $dictModels."$modelName" = $descriptorPath
        $dictModelsGuid."$modelName" = [guid]::NewGuid().ToString('B')

        Write-Output "Model descriptor found: $modelName"
    }
}

$dictModels.Keys | % { 
    $modelName = "$_"
    $descriptorPath = $dictModels.Item($_)

    Write-Output "Creating project file for $modelName"

    $projFile = "$outputPath\$modelName.rnrproj"

    if (Test-Path $projFile -PathType Leaf) {
        Remove-Item -Path $projFile -Force
    }    
    New-Item -Path $projFile -Force

    [Xml]$projFileXml = [Xml]$rnrProjTemplate

    $projFileXml.Project.PropertyGroup[0].Model = $modelName
    $projFileXml.Project.PropertyGroup[0].Name = $modelName
    $projFileXml.Project.PropertyGroup[0].RootNamespace = $modelName
    $projFileXml.Project.PropertyGroup[0].ProjectGuid = $dictModelsGuid[$modelName]
    
    [Xml]$descriptorXml = Get-Content -Path $descriptorPath

    $descriptorXml.AxModelInfo.ModuleReferences.string | % {
        if ($dictModels.ContainsKey($_)) {
            Write-Output "Adding project reference to the model: $_"

            $itemGroup = $projFileXml.CreateElement("ItemGroup", $xmlns)
            $projectReference = $projFileXml.CreateElement("ProjectReference", $xmlns)
            $include = $projFileXml.CreateAttribute("Include")
            $project = $projFileXml.CreateElement("Project", $xmlns)
            $name = $projFileXml.CreateElement("Name", $xmlns)
            
            $projFileXml.Project.AppendChild($itemGroup)
            $itemGroup.AppendChild($projectReference)
            $projectReference.Attributes.Append($include)
            $projectReference.AppendChild($project)
            $projectReference.AppendChild($name)

            $include.InnerText = "$_.rnrproj"
            $project.InnerText = $dictModelsGuid[$_]
            $name.InnerText = "$_"
        }
    }

    $packagePath = Split-Path $descriptorPath
    $packagePath = "$packagePath\.."

    if (Test-Path $packagePath -PathType Container) {
        Get-ChildItem $packagePath -Directory -Recurse |
        Where-Object { ($_.Name -eq "bin") -or ($_.Name -eq "AxResource") } |
        ForEach-Object { 
            Get-ChildItem $_.FullName -Filter "*.dll" -Recurse |
            ForEach-Object { 
                Write-Host "Adding dll reference to the file: $_"

                $itemGroup = $projFileXml.CreateElement("ItemGroup", $xmlns)
                $reference = $projFileXml.CreateElement("Reference", $xmlns)
                $include = $projFileXml.CreateAttribute("Include")
                $hintPath = $projFileXml.CreateElement("HintPath", $xmlns)

                $projFileXml.Project.AppendChild($itemGroup)
                $itemGroup.AppendChild($reference)
                $reference.Attributes.Append($include)
                $reference.AppendChild($hintPath)

                $include.InnerText = [io.path]::GetFileNameWithoutExtension("$_")
                $dllRefFullName = $_.FullName
                $hintPath.InnerText = $dllRefFullName
            }
        }
    }

    $projFileXml.Save($projFile)
}

$solutionFile = "$OutputPath\D365FO-Build.sln"
if (Test-Path $solutionFile -PathType Leaf) {
    Remove-Item -Path $solutionFile -Force
}
New-Item -Path $solutionFile -Force

Write-Host "Creating solution file"

""                                                                       | Out-File -FilePath $solutionFile
"Microsoft Visual Studio Solution File, Format Version 12.00"            | Out-File -FilePath $solutionFile -Append
"# Visual Studio 14"                                                     | Out-File -FilePath $solutionFile -Append
"VisualStudioVersion = 14.0.25420.1"                                     | Out-File -FilePath $solutionFile -Append
"MinimumVisualStudioVersion = 10.0.40219.1"                              | Out-File -FilePath $solutionFile -Append

$dictModelsGuid.Keys | % { 
    $modelName = $_
    $modelGuid = $dictModelsGuid.Item($_)
    
    "Project(""{FC65038C-1B2F-41E1-A629-BED71D161FFF}"") = ""$modelName"", ""$modelName.rnrproj"", ""$modelGuid""" | Out-File -FilePath $solutionFile -Append
    "EndProject"                                                         | Out-File -FilePath $solutionFile -Append
}

"Global"                                                                 | Out-File -FilePath $solutionFile -Append
"	GlobalSection(SolutionConfigurationPlatforms) = preSolution"         | Out-File -FilePath $solutionFile -Append
"		Debug|Any CPU = Debug|Any CPU"                                   | Out-File -FilePath $solutionFile -Append
"	EndGlobalSection"                                                    | Out-File -FilePath $solutionFile -Append
"	GlobalSection(ProjectConfigurationPlatforms) = postSolution"         | Out-File -FilePath $solutionFile -Append

$dictModelsGuid.Keys | % { 
    $modelName = $_
    $modelGuid = $dictModelsGuid.Item($_)
    
    "		$modelGuid.Debug|Any CPU.ActiveCfg = Debug|Any CPU"              | Out-File -FilePath $solutionFile -Append
    "		$modelGuid.Debug|Any CPU.Build.0 = Debug|Any CPU"                | Out-File -FilePath $solutionFile -Append
}

"	EndGlobalSection"                                                    | Out-File -FilePath $solutionFile -Append
"	GlobalSection(SolutionProperties) = preSolution"                     | Out-File -FilePath $solutionFile -Append
"		HideSolutionNode = FALSE"                                        | Out-File -FilePath $solutionFile -Append
"	EndGlobalSection"                                                    | Out-File -FilePath $solutionFile -Append
"EndGlobal"                                                              | Out-File -FilePath $solutionFile -Append