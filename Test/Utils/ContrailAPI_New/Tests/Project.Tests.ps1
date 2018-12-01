Param (
    [Parameter(Mandatory=$false)] [string] $TestenvConfFile,
    [Parameter(ValueFromRemainingArguments=$true)] $UnusedParams
)

. $PSScriptRoot\..\Project.ps1
. $PSScriptRoot\..\..\..\..\CIScripts\Testenv\Testenv.ps1

function Test-IfProjectExist {
    Param ([Parameter(Mandatory = $true)] [ContrailNetworkManager] $API,
           [Parameter(Mandatory = $true)] [string] $Name)

    $Projects = $API.Get('project', $null, $null)
    if($Projects.PSobject.Properties.Name -contains 'projects') {
        foreach($Project in $Projects.'projects') {
            if($Project.'fq_name'[-1] -eq $Name) {
                return $true
            }
        }
    }
    return $false
}

function Write-Log {
    Param([string] $Log)

    Write-Host $Log
}

Describe 'Contrail Project API' -Tags CI, Systest {
    BeforeAll {
        $OpenStackConfig = Read-OpenStackConfig -Path $TestenvConfFile
        $ControllerConfig = Read-ControllerConfig -Path $TestenvConfFile
        $ContrailNM = [ContrailNetworkManager]::New([TestenvConfigs]::new($null, $OpenStackConfig, $ControllerConfig))

        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
            "PSUseDeclaredVarsMoreThanAssignments",
            "DNSServer",
            Justification="It's actually used."
        )]
        $ProjectRepo = [ProjectRepo]::New($ContrailNM)
    }

    Context 'Projects creation and removal' {

        It 'can add and remove project' {
            $ProjectName = 'CreatedByPS1Script'
            $Project = [Project]::New($ProjectName)

            $ProjectRepo.Add($Project)
            $ExistAfterAdd = Test-IfProjectExist -API $ContrailNM -Name $ProjectName
            $ProjectRepo.Remove($Project)
            $ExistAfterRemoved = Test-IfProjectExist -API $ContrailNM -Name $ProjectName

            $ExistAfterAdd | Should -BeTrue
            $ExistAfterRemoved | Should -BeFalse
        }

        It 'can remove project by name' {
            $ProjectName = 'CreatedByPS1ScriptByName'

            $ProjectRepo.Add([Project]::New($ProjectName))
            $ExistAfterAdd = Test-IfProjectExist -API $ContrailNM -Name $ProjectName
            $ProjectRepo.Remove([Project]::New($ProjectName))
            $ExistAfterRemoved = Test-IfProjectExist -API $ContrailNM -Name $ProjectName

            $ExistAfterAdd | Should -BeTrue
            $ExistAfterRemoved | Should -BeFalse
        }

        It 'can replace project' {
            $ProjectName = 'CreatedByPS1ScriptReplace'

            $Uuid1 = $ProjectRepo.Add([Project]::New($ProjectName))
            $ExistAfterAdd = Test-IfProjectExist -API $ContrailNM -Name $ProjectName
            $Uuid2 = $ProjectRepo.AddOrReplace([Project]::New($ProjectName))
            Test-IfProjectExist -API $ContrailNM -Name $ProjectName
            $Replaced = ($Uuid1 -ne $Uuid2)
            $ProjectRepo.Remove([Project]::New($ProjectName))
            $ExistAfterRemoved = Test-IfProjectExist -API $ContrailNM -Name $ProjectName

            $ExistAfterAdd | Should -BeTrue
            $Replaced | Should -BeTrue
            $ExistAfterRemoved | Should -BeFalse
        }
    }
}
