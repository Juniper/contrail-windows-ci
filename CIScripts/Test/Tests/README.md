# How to run tests from local machine

1. Deploy dev env using `deploy-dev-env` job.

2. Install `powershel-yaml`:

    ```Install-Module powershell-yaml```

3. Copy `testenv-conf.yaml.sample` to `testenv-conf.yaml` file and replace all occurences of `<CONTROLLER_IP>`, `<TESTBED1_NAME>`, `<TESTBED1_IP>`, `<TESTBED2_NAME>`, `<TESTBED2_IP>` with proper values.

4. Run selected test, e.g.:

    ```Invoke-Pester -Script @{ Path = ".\TunnellingWithAgent.Tests.ps1"; Parameters = @{ TestenvConfFile = "testenv-conf.yaml"}; } -TestName 'Tunnelling with Agent tests'```
