Param (
    [Parameter(Mandatory=$false)] [string] $TestenvConfFile,
    [Parameter(ValueFromRemainingArguments=$true)] $UnusedParams
)

. $PSScriptRoot\..\VirtualRouter.ps1
. $PSScriptRoot\..\..\..\..\CIScripts\Testenv\Testenv.ps1

function Test-IfVirtualRouterExist {
    Param ([Parameter(Mandatory = $true)] [ContrailNetworkManager] $API,
           [Parameter(Mandatory = $true)] [string] $Name,
           [Parameter(Mandatory = $true)] [string] $Ip)

    $VirtualRouters = $API.Get('virtual-router', $null, $null)
    if($VirtualRouters.PSobject.Properties.Name -contains 'virtual-routers') {
        foreach($VirtualRouter in $VirtualRouters.'virtual-routers') {
            if($VirtualRouter.'fq_name'[-1] -eq $Name) {
                $VirtualRouterDetails = $API.Get('virtual-router', $VirtualRouter.'uuid', $null)
                if($VirtualRouterDetails.'virtual-router'.'virtual_router_ip_address' -eq $Ip) {
                    return $true
                }
                else {
                    return $false
                }
            }
        }
    }
    return $false
}

function Write-Log {
    Param([string] $Log)

    Write-Host $Log
}

Describe 'Contrail Virtual Router API' -Tags CI, Systest {
    BeforeAll {
        $OpenStackConfig = Read-OpenStackConfig -Path $TestenvConfFile
        $ControllerConfig = Read-ControllerConfig -Path $TestenvConfFile
        $ContrailNM = [ContrailNetworkManager]::New([TestenvConfigs]::new($null, $OpenStackConfig, $ControllerConfig))

        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
            "PSUseDeclaredVarsMoreThanAssignments",
            "DNSServer",
            Justification="It's actually used."
        )]
        $VirtualRouterRepo = [VirtualRouterRepo]::New($ContrailNM)
    }

    Context 'Virtual routers creation and removal' {

        It 'can add and remove virtual router' {
            $RouterName = 'CreatedByPS1Script'
            $RouterIp = '1.1.1.1'
            $Router = [VirtualRouter]::New($RouterName, $RouterIp)

            $VirtualRouterRepo.Add($Router)
            $ExistAfterAdd = Test-IfVirtualRouterExist -API $ContrailNM -Name $RouterName -Ip $RouterIp
            $VirtualRouterRepo.Remove($Router)
            $ExistAfterRemoved = Test-IfVirtualRouterExist -API $ContrailNM -Name $RouterName -Ip $RouterIp

            $ExistAfterAdd | Should -BeTrue
            $ExistAfterRemoved | Should -BeFalse
        }

        It 'can remove virtual router by name' {
            $RouterName = 'CreatedByPS1ScriptByName'
            $RouterIp = '1.1.1.1'

            $VirtualRouterRepo.Add([VirtualRouter]::New($RouterName, $RouterIp))
            $ExistAfterAdd = Test-IfVirtualRouterExist -API $ContrailNM -Name $RouterName -Ip $RouterIp
            $VirtualRouterRepo.Remove([VirtualRouter]::New($RouterName, $RouterIp))
            $ExistAfterRemoved = Test-IfVirtualRouterExist -API $ContrailNM -Name $RouterName -Ip $RouterIp

            $ExistAfterAdd | Should -BeTrue
            $ExistAfterRemoved | Should -BeFalse
        }

        It 'can replace virtual router' {
            $RouterName = 'CreatedByPS1ScriptReplace'
            $RouterIp1 = '1.1.1.1'
            $RouterIp2 = '2.2.2.2'

            $VirtualRouterRepo.Add([VirtualRouter]::New($RouterName, $RouterIp1))
            $ExistAfterAdd = Test-IfVirtualRouterExist -API $ContrailNM -Name $RouterName -Ip $RouterIp1
            $VirtualRouterRepo.AddOrReplace([VirtualRouter]::New($RouterName, $RouterIp2))
            $Replaced = Test-IfVirtualRouterExist -API $ContrailNM -Name $RouterName -Ip $RouterIp2
            $VirtualRouterRepo.Remove([VirtualRouter]::New($RouterName, $RouterIp2))
            $ExistAfterRemoved = Test-IfVirtualRouterExist -API $ContrailNM -Name $RouterName -Ip $RouterIp2

            $ExistAfterAdd | Should -BeTrue
            $Replaced | Should -BeTrue
            $ExistAfterRemoved | Should -BeFalse
        }
    }
}
