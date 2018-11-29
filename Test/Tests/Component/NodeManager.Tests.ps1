Param (
    [Parameter(Mandatory=$false)] [string] $TestenvConfFile,
    [Parameter(Mandatory=$false)] [string] $LogDir = "pesterLogs",
    [Parameter(ValueFromRemainingArguments=$true)] $UnusedParams
)

. $PSScriptRoot\..\..\..\CIScripts\Common\Init.ps1
. $PSScriptRoot\..\..\..\CIScripts\Common\Aliases.ps1

. $PSScriptRoot\..\..\..\CIScripts\Testenv\Testbed.ps1

. $PSScriptRoot\..\..\PesterHelpers\PesterHelpers.ps1
. $PSScriptRoot\..\..\PesterLogger\PesterLogger.ps1
. $PSScriptRoot\..\..\PesterLogger\RemoteLogCollector.ps1
. $PSScriptRoot\..\..\Utils\ComputeNode\Initialize.ps1
. $PSScriptRoot\..\..\Utils\ComputeNode\Service.ps1

. $PSScriptRoot\..\..\Utils\ComputeNode\Configuration.ps1

. $PSScriptRoot\..\..\TestConfigurationUtils.ps1
. $PSScriptRoot\..\..\Utils\ContrailNetworkManager.ps1
. $PSScriptRoot\..\..\Utils\MultiNode\ContrailMultiNodeProvisioning.ps1

# TODO: This variable is not passed down to New-NodeMgrConfig in ComponentsInstallation.ps1
#       Should be refactored.

$LogPath = Get-NodeMgrLogPath


function Clear-NodeMgrLogs {
    Param (
        [Parameter(Mandatory = $true)] [PSSessionT] $Session
    )

    Invoke-Command -Session $Session -ScriptBlock {
        if (Test-Path -Path $Using:LogPath) {
            Remove-Item $Using:LogPath -Force
        }
    }
}

function Test-NodeMgrLogs {
    Param (
        [Parameter(Mandatory = $true)] [PSSessionT] $Session
    )

    $Res = Invoke-Command -Session $Session -ScriptBlock {
        return Test-Path -Path $Using:LogPath
    }

    return $Res
}

function Test-NodeMgrConnectionWithController {
    Param (
        [Parameter(Mandatory = $true)] [PSSessionT] $Session,
        [Parameter(Mandatory = $true)] [string] $ControllerIP
    )

    $TestbedHostname = Invoke-Command -Session $Session -ScriptBlock {
        hostname
    }
    $Out = Invoke-RestMethod ("http://" + $ControllerIP + ":8089/Snh_ShowCollectorServerReq?")
    $OurNode = $Out.ShowCollectorServerResp.generators.list.GeneratorSummaryInfo.source | Where-Object "#text" -Like "$TestbedHostname"

    return [bool]($OurNode)
}

function Test-ControllerReceivesNodeStatus {
    Param (
        [Parameter(Mandatory = $true)] [PSSessionT] $Session
    )

    # TODO

    return $true
}

Describe "Node manager" {
    It "starts" {
        Eventually {
            Test-NodeMgrLogs -Session $Session | Should Be True
        } -Duration 60
    }

    It "connects to controller" {
        Eventually {
            Test-NodeMgrConnectionWithController `
                -Session $Session `
                -ControllerIP $MultiNode.Configs.Controller.Address | Should Be True
        } -Duration 60
    }

    It "sets node state as 'Up'" -Pending {
        Eventually {
            Test-ControllerReceivesNodeStatus -Session $Session | Should Be True
        } -Duration 60
    }

    AfterEach {
        Merge-Logs -DontCleanUp -LogSources $LogSources
    }

    BeforeAll {
        Initialize-PesterLogger -OutDir $LogDir

        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
            "PSUseDeclaredVarsMoreThanAssignments",
            "MultiNode",
            Justification="It's actually used."
        )]
        $MultiNode = New-MultiNodeSetup -TestenvConfFile $TestenvConfFile

        foreach ($Session in $MultiNode.Sessions) {
            Install-Components -Session $Session
        }

        $Session = $MultiNode.Sessions[0]

        $Session = $MultiNode.Sessions[0]

        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
            "PSUseDeclaredVarsMoreThanAssignments",
            "LogSources",
            Justification="It's actually used."
        )]
        [LogSource[]] $LogSources = New-ComputeNodeLogSources -Sessions $Session

        Clear-NodeMgrLogs -Session $Session

        Initialize-ComputeServices `
            -Session $Session `
            -SystemConfig $MultiNode.Configs.System `
            -OpenStackConfig $MultiNode.Configs.OpenStack `
            -ControllerConfig $MultiNode.Configs.Controller
    }

    AfterAll {
        if (Get-Variable "MultiNode" -ErrorAction SilentlyContinue) {

            foreach ($Session in $MultiNode.Sessions) {
                Uninstall-Components -Session $Session
            }
            Clear-Logs -LogSources $LogSources

            Remove-MultiNodeSetup -MultiNode $MultiNode
            Remove-Variable "MultiNode"
        }
    }
}
