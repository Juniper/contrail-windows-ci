. $PSScriptRoot\Repair-NUnitReport.ps1
. $PSScriptRoot\..\Common\Invoke-NativeCommand.ps1

function Convert-TestReportsToHtml {
    param (
        [Parameter(Mandatory = $true)] [String] $XmlReportsDir,
        [Parameter(Mandatory = $true)] [string] $OutputDir,
        [Parameter(Mandatory = $false)] $GeneratorFunc = (Get-Item function:Invoke-RealReportunit)
    )

    $FixedReportsDir = "$OutputDir/raw_NUnit"
    $PrettyDir = "$OutputDir/pretty_test_report"

    New-Item -Type Directory -Force $FixedReportsDir | Out-Null
    New-FixedTestReports -OriginalReportsDir $XmlReportsDir -FixedReportsDir $FixedReportsDir

    & $GeneratorFunc -NUnitDir $FixedReportsDir
    New-Item -Type Directory -Force $PrettyDir | Out-Null
    Move-Item "$FixedReportsDir/*.html" $PrettyDir

    $GeneratedHTMLFiles = Get-ChildItem $PrettyDir -File
    if (-not $GeneratedHTMLFiles) {
        throw "Generation failed, not a single html file was generated."
    }
    
    if(-not (Test-IndexHtmlExists -Files $GeneratedHTMLFiles)) {
        Repair-LackOfIndexHtml -Files $GeneratedHTMLFiles
    }

    New-ReportsLocationsJson -OutputDir $OutputDir
}

function Invoke-RealReportunit {
    param([Parameter(Mandatory = $true)] [string] $NUnitDir)
    Invoke-NativeCommand -ScriptBlock {
        ReportUnit.exe $NUnitDir
    }
}

function New-FixedTestReports {
    param(
        [Parameter(Mandatory = $true)] [string] $OriginalReportsDir,
        [Parameter(Mandatory = $true)] [string] $FixedReportsDir
    )

    foreach ($ReportFile in Get-ChildItem $OriginalReportsDir -Filter *.xml) {
        [string] $Content = Get-Content $ReportFile.FullName
        $FixedContent = Repair-NUnitReport -InputData $Content
        $FixedContent | Out-File "$FixedReportsDir/$($ReportFile.Name)" -Encoding "utf8"
    }
}

function Test-IndexHtmlExists {
    param([Parameter(Mandatory = $true)] [System.IO.FileSystemInfo[]] $Files)
    $JustFilenames = $Files | Select-Object -ExpandProperty Name
    return $JustFilenames -contains "Index.html"
}

function Repair-LackOfIndexHtml {
    param([Parameter(Mandatory = $true)] [System.IO.FileSystemInfo[]] $Files)
    # ReportUnit 1.5.0 won't generate Index.html if there is only one input xml file.
    # We need Index.html to use in Monitoring to provide link to logs.
    # To fix this, rename a file to Index.html
    $RenameFrom = $Files[0].FullName
    $BaseDir = Split-Path $RenameFrom
    $RenameTo = (Join-Path $BaseDir "Index.html")
    Write-Host "Index.html not found, renaming $RenameFrom to $RenameTo"
    Rename-Item $RenameFrom $RenameTo
}

function New-ReportsLocationsJson {
    param(
        [Parameter(Mandatory = $true)] [string] $OutputDir
    )

    Push-Location $OutputDir

    try {
        function ConvertTo-RelativePath([string] $FullPath) {
            (Resolve-Path -Relative $FullPath).split('\') -join '/'
        }

        $Xmls = Get-ChildItem -Recurse -Filter '*.xml'
        $XmlPaths = $Xmls | Foreach-Object { ConvertTo-RelativePath $_.FullName }

        $IndexHtml = Get-ChildItem -Recurse -Filter 'Index.html'

        @{
            xml_reports = , $XmlPaths
            html_report = ConvertTo-RelativePath $IndexHtml.FullName
        } | ConvertTo-Json -Depth 10 | Out-File "reports-locations.json" -Encoding "utf8"
    }
    finally {
        Pop-Location
    }
}