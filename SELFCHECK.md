# CI Selfcheck

CI has a set of unit and integration tests, called 'selfcheck'.

## To run unit tests and static analysis of CI:

```
.\Invoke-Selfcheck.ps1
```

## To also run system tests of CI:

```
.\Invoke-Selfcheck.ps1 -TestenvConfFile './path/to/testenvconf.yaml'
```

Note: to make sure that system tests pass, some requirements must be met.

### Systest requirements:

* testenvconf.yaml
* Reportunit 1.5.0-beta present in PATH

## Disabling static analysis

```
.\Invoke-Selfcheck.ps1 -NoStaticAnalysis
```

## Skip unit tests

```
.\Invoke-Selfcheck.ps1 -SkipUnit
```

------------------

## Note to developers

The idea behind this tool is that anyone can run the basic set of tests without ANY preparation.
A new developer should be able to run `.\Invoke-Selfcheck.ps1` and it should pass 100% of the time,
without any special requirements, like libraries, testbed machines etc.
Special flags may be passed to invoke more complicated tests (that have requirements), but
the default should require nothing.
