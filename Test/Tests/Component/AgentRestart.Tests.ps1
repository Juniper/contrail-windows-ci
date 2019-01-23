Param (
    [Parameter(Mandatory = $false)] [string] $TestenvConfFile,
    [Parameter(Mandatory = $false)] [string] $LogDir = 'pesterLogs',
    [Parameter(Mandatory = $false)] [bool] $PrepareEnv = $true,
    [Parameter(ValueFromRemainingArguments = $true)] $UnusedParams
)

. $PSScriptRoot\..\..\..\CIScripts\Common\Aliases.ps1
. $PSScriptRoot\..\..\..\CIScripts\Common\Init.ps1

. $PSScriptRoot\..\..\Utils\ContrailAPI\ContrailAPI.ps1

. $PSScriptRoot\..\..\PesterHelpers\PesterHelpers.ps1

. $PSScriptRoot\..\..\PesterLogger\PesterLogger.ps1
. $PSScriptRoot\..\..\PesterLogger\RemoteLogCollector.ps1

. $PSScriptRoot\..\..\Utils\MultiNode\ContrailMultiNodeProvisioning.ps1
. $PSScriptRoot\..\..\Utils\Testenv\Testenv.ps1

. $PSScriptRoot\..\..\TestConfigurationUtils.ps1

. $PSScriptRoot\..\..\Utils\WinContainers\Containers.ps1
. $PSScriptRoot\..\..\Utils\NetAdapterInfo\RemoteContainer.ps1
. $PSScriptRoot\..\..\Utils\Network\Connectivity.ps1
. $PSScriptRoot\..\..\Utils\ComputeNode\Initialize.ps1
. $PSScriptRoot\..\..\Utils\ComputeNode\Service.ps1
. $PSScriptRoot\..\..\Utils\DockerNetwork\Commands.ps1

$ContrailProject = 'ci_tests_dummy1'

$ContainerIds = @('jolly-lumberjack', 'juniper-tree', 'mountain-mama')
$ContainerNetInfos = @($null, $null, $null)

$Subnet = [Subnet]::new(
    '10.0.5.0',
    24,
    '10.0.5.1',
    '10.0.5.19',
    '10.0.5.83'
)
$VirtualNetwork = [VirtualNetwork]::New('testnet_dummy1', $ContrailProject, $Subnet)

Test-WithRetries 1 {
    Describe 'Dummy tests no.1' -Tag 'Smoke' {
        It 'is a sunny day' {
            $true | Should -BeTrue
        }

        BeforeAll {
            $Testenv = [Testenv]::New()
            $Testenv.Initialize($TestenvConfFile, $LogDir, $ContrailProject, $PrepareEnv)
        }

        AfterAll {
            $Testenv.Cleanup()

            Write-Host "Error variable: $Error"
        }
    }
}
