﻿$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\$sut"

Describe "Testenv" {
    It "can read controller config from a .yaml file" {
        $Controller = Read-ControllerConfig -Path "TestYaml.yaml"

        $Controller["os_credentials"]["Address"] | Should -Be "1.2.3.1"
        $Controller["os_credentials"]["Port"] | Should -Be "5000"
        $Controller["os_credentials"]["Username"] | Should -Be "AzureDiamond"
        $Controller["os_credentials"]["Password"] | Should -Be "hunter2"

        $Controller["rest_api"]["Address"] | Should -Be "1.2.3.1"
        $Controller["rest_api"]["Port"] | Should -Be "8082"

        $Controller["default_project"] | Should -Be "ci_tests"
    }

    It "can read configuration of testbeds from .yaml file" {
        $Testbeds = Read-TestbedsConfig -Path "TestYaml.yaml"
        $Testbeds[0]["Address"] | Should -Be "1.2.3.2"
        $Testbeds[1]["Address"] | Should -Be "1.2.3.3"
        $Testbeds[0]["Username"] | Should -Be "TBUsername"
        $Testbeds[1]["Username"] | Should -Be "TBUsername"
        $Testbeds[0]["Password"] | Should -Be "TBPassword"
        $Testbeds[1]["Password"] | Should -Be "TBPassword"
    }

    BeforeEach {
        $Yaml = @"
controller:
  os_credentials:
    username: AzureDiamond
    password: hunter2
    address: 1.2.3.1
    port: 5000

  rest_api:
    address: 1.2.3.1
    port: 8082

  default_project: ci_tests

testbeds:
  - name: Testbed1
    address: 1.2.3.2
    username: TBUsername
    password: TBPassword
  - name: Testbed2
    address: 1.2.3.3
    username: TBUsername
    password: TBPassword
"@
        $Yaml | Out-File "TestYaml.yaml"
    }

    AfterEach {
        Remove-Item "TestYaml.yaml"
    }
}
