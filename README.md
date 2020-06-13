# Git Era Versioning
A simple and hassle free versioning approach for standalone self-contained applications using an incremental rollout strategy (CI/CD) without upstream dependencies.

The following version formats are generated:
* AssemblyVersion (for .NET assemblies)
* FileVersion (for Win32 DLL files)
* Semantic Version

### Semantic Version Format
```
<DaysElapsed>.<HoursElapsed><MinutesElapsed>.0[-<pre-release>[+<buildMetadata>]],
   where <pre-release> ::= canary | ci | rc
   and <build> ::= <currentCommitHashShort>
```
This format complies with [SemVer 2.0](https://semver.org/).

**Example**
```
319.1015.0-canary+d670460
319.1015.0-ci+d670460
319.1015.0-rc+d670460
319.1015.0
```

## Usage
1. Add `src\version.xml` and `src\Set-EraVersion.ps1` to your repository.
2. Import `version.xml` in every `*.csproj` file, like `<Import Project="version.xml" />`.
2. On every build, run the code inside of `src\Set-EraVersion.Example.ps1` right before your repository will be compiled.
