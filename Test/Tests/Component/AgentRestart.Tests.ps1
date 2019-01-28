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

$ContrailProject = 'ci_tests_agentrestart'

# $ContainerIds = @('jolly-lumberjack', 'juniper-tree', 'mountain-mama')
# $ContainerNetInfos = @($null, $null, $null)

# $Subnet = [Subnet]::new(
#     '10.0.5.0',
#     24,
#     '10.0.5.1',
#     '10.0.5.19',
#     '10.0.5.83'
# )
# $VirtualNetwork = [VirtualNetwork]::New('testnet_agentrestart', $ContrailProject, $Subnet)

Test-WithRetries 3 {
    Describe 'Dummy test' -Tags Smoke, EnvSafe {
        It 'Removes project' {
            $Project = [Project]::new($ContrailProject)
            $ContrailRepo.Remove($Project) | Out-Null
        }

        It 'Adds project' {
            $Project = [Project]::new($ContrailProject)
            $ContrailRepo.AddOrReplace($Project) | Out-Null
        }

        BeforeAll {
            Initialize-PesterLogger -OutDir $LogDir

            $OpenStack = [OpenStackConfig]::LoadFromFile($TestenvConfFile)
            $Controller = [ControllerConfig]::LoadFromFile($TestenvConfFile)

            $Authenticator = [AuthenticatorFactory]::GetAuthenticator($Controller.AuthMethod, $OpenStack)
            $ContrailRestApi = [ContrailRestApi]::new($Controller.RestApiUrl(), $Authenticator)
            $ContrailRepo = [ContrailRepo]::new($ContrailRestApi)
            $ContrailRepo | Out-Null
        }

        AfterAll {
        }

        BeforeEach {
        }

        AfterEach {
        }
    }
}
