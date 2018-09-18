# Running tests

This document describes how to set up everything needed for running Windows sanity tests:
* 3-node test lab (2 Windows compute nodes, 1 Linux controller),
* Windows artifacts deployed on Testbeds,
* tools to run the test suite,
* test runner scripts.

## Test lab preparation

### CodiLime lab

To deploy in local CodiLime VMWare lab, follow [this](https://juniper.github.io/contrail-windows-docs/contrail_deployment/Devenv_in_local_env/) document.

### Juniper lab

Test lab can be provisioned easily in Juniper infra using Deploy-Dev-Env job in Windows CI Jenkins.

### Other

There are different ways to deploy. Refer to [this](https://juniper.github.io/contrail-windows-docs/contrail_deployment/contrail_deployment_manual/) document for more information.

## Deploying artifacts

### Nightly

Artifacts can be deployed from nightly build. The easiest way is to use ansible ad-hoc commands:

```
# Helper alias to run PowerShell on all testbeds
alias run_tb='ansible -i inventory --vault-password-file ~/ansible-vault-key testbed -m win_shell -a'

run_tb "mkdir C:/Artifacts"
run_tb "docker run -v C:\Artifacts:C:\Artifacts mclapinski/contrail-windows-docker-driver"
run_tb "docker run -v C:\Artifacts:C:\Artifacts mclapinski/contrail-windows-vrouter"
run_tb "ls C:/Artifacts"
run_tb "Import-Certificate -CertStoreLocation Cert:\LocalMachine\Root\ C:\Artifacts\vrouter\vRouter.cer"
run_tb "Import-Certificate -CertStoreLocation Cert:\LocalMachine\TrustedPublisher\ C:\Artifacts\vrouter\vRouter.cer"
```

WORKAROUND: vcpython27 is missing on testbeds:
```
run_tb "choco install vcpython27 -y"
```

WORKAROUND: layout of artifacts expected by test suite is slightly different than the one
created by nightly containers. We must move
```
run_tb "Copy-Item -Recurse -Filter *msi 'C:/Artifacts/*/*' 'C:/Artifacts'"
run_tb "Copy-Item -Recurse -Filter *cer 'C:/Artifacts/*/*' 'C:/Artifacts'"

# Verify with:
run_tb "ls 'C:/Artifacts'"
```

## Test suite prerequisites

1. Install Pester:

    ```Install-Module -Name Pester -Force -SkipPublisherCheck -RequiredVersion 4.2.0```

1. Install `powershell-yaml`:

    ```Install-Module powershell-yaml```


## Test configuration

Copy `testenv-conf.yaml.sample` to `testenv-conf.yaml` file and replace all occurences of:
* `<CONTROLLER_IP>` - Controller IP address, accessible from local machine (network 10.84.12.0/24 in current setup)
* `<TESTBED1_NAME>`, `<TESTBED2_NAME>` - Testbeds hostnames
* `<TESTBED1_IP>`, `<TESTBED2_IP>` - Testbeds IP addresses, accessible from local machine (the same network as for Controller)


## Running the tests

Run the whole Windows sanity suite:
```
.\Invoke-ProductTests.ps1 -TestRootDir . -TestenvConfFile ..\testenv-conf.yaml -TestReportDir ../reports
```

Run selected test:

```
Invoke-Pester -Script @{ Path = ".\TunnellingWithAgent.Tests.ps1"; Parameters = @{ TestenvConfFile = "testenv-conf.yaml"}; } -TestName 'Tunnelling with Agent tests'
```

## Debugging the tests

### Install Visual Studio Code with ms-vscode.powershell plugin

1. Open test file you want to debug.
1. At the top of the file, specify path to `TestenvConfFile`, like so:

```
Param (
    [Parameter(Mandatory=$false)] [string] $TestenvConfFile = "C:\Users\mk\Juniper\tmp\contrail-windows-ci\testenv-conf.yaml",
    ...
```
1. Setup any breakpoints.
1. Find the start of test suite `Describe` block.
1. Click `Debug tests` which appears just above the `Describe` block.

Note: if PowerShell session crashes, try `Ctrl`+`Shift`+`P` -> `Powershell: Restart current session`.

## CI Selfcheck

To run CI Selfcheck please see [this document](../../SELFCHECK.md).
