# Pester is a Behavior-Driven Development (BDD) based test runner and mocking framework for PowerShell.
#
# Read https://pester.dev/docs/introduction/installation for instructions. Note special procedure in Windows 10 v1809 and higher!
#
# Install-Module -Name Pester -Force -SkipPublisherCheck # to get version '5.0.2'
# Import-Module Pester
# Invoke-Pester -Script $(System.DefaultWorkingDirectory)\MyFirstModule.test.ps1 -OutputFile $(System.DefaultWorkingDirectory)\Test-Pester.XML -OutputFormat NUnitXML

# Configure Pester
$PesterPreference = [PesterConfiguration]::Default
$PesterPreference.Debug.WriteDebugMessages = $true
$PesterPreference.Debug.WriteDebugMessagesFrom = "Mock"
$PesterPreference.Should.ErrorAction = 'Continue'
$PesterPreference.Output.Verbosity = 'Detailed' # Diagnostic, Detailed, Normal

BeforeAll {
    # DON'T use $MyInvocation.MyCommand.Path
    . $PSCommandPath.Replace('.Tests.ps1','.ps1')
}

# Tests
Describe -Tags "Unit" -Name "Get-NextEraVersion" {
    It "Correctly constructs AssemblyVersion, FileVersion and SemanticVersion based on given <branchName>" -TestCases @(
        @{ branchName = 'topic'; expectedBranchLabel = 'canary'; expectedBuildNumer = "3431" }
        @{ branchName = 'topic/story42'; expectedBranchLabel = 'canary'; expectedBuildNumer = "3431" }
        @{ branchName = 'topic/story42/task7'; expectedBranchLabel = 'canary'; expectedBuildNumer = "3431" }
        @{ branchName = 'develop'; expectedBranchLabel = 'ci'; expectedBuildNumer = "19815" }
        @{ branchName = 'release'; expectedBranchLabel = 'rc'; expectedBuildNumer = "44391" }
        @{ branchName = 'release/3.14'; expectedBranchLabel = 'rc'; expectedBuildNumer = "44391" }
        @{ branchName = 'release/3.14/task7'; expectedBranchLabel = 'rc'; expectedBuildNumer = "44391" }
        @{ branchName = 'master'; expectedBranchLabel = ''; expectedBuildNumer = "64871" }
    ) {
        param
        (
            [string]$branchName,
            [string]$expectedBranchLabel,
            [string]$expectedBuildNumer
        )

        $currentCommit = [EraCommit]@{
            CommitHash = "d670460b4b4aece5915caf5c68d12f560a9fe3e4"
            CommitDate = "2019-08-16T10:15:00"
        }

        $version = Get-NextEraVersion -EraBeginningDate ([DateTime]"2018-10-01") -CurrentCommit $currentCommit -branchName $branchName

        $version.AssemblyVersion | Should -Be "319.1015.$expectedBuildNumer.1120"
        $version.FileVersion | Should -Be "319.1015.$expectedBuildNumer.1120"
        $version.SemanticVersion | Should -Be "319.1015.0-$expectedBranchLabel+d670460"
    }

    It "Writes warning message about one year before FileVersion exceeds 16bit boundary" {
        $currentCommit = [EraCommit]@{
            CommitHash = "d670460b4b4aece5915caf5c68d12f560a9fe3e4"
            CommitDate = "2149-01-01T00:00:00"
        }
        Get-NextEraVersion -EraBeginningDate ([DateTime]"1970-01-01") -CurrentCommit $currentCommit -branchName "canary" -WarningVariable warningMessage
        $warningMessage | Should -Be "The Major value has almost reached its maximum. A value greater than 65535 can cause problems on Win32 systems! Major value is '65379'."
    }

    It "Writes error message about 30 days before FileVersion exceeds 16bit boundary" {
        $currentCommit = [EraCommit]@{
            CommitHash = "d670460b4b4aece5915caf5c68d12f560a9fe3e4"
            CommitDate = "2149-07-01T00:00:00"
        }
        Get-NextEraVersion -EraBeginningDate ([DateTime]"1970-01-01") -CurrentCommit $currentCommit -branchName "canary" -ErrorVariable errorMessage -ErrorAction SilentlyContinue
        $errorMessage | Should -Be "The Major value has almost reached its maximum. A value greater than 65535 can cause problems on Win32 systems! Major value is '65560'."
    }
}

Describe -Tag "Unit" -Name "Set-VersionXmlFile" {
    BeforeEach {
        $content = '<Project><PropertyGroup><AssemblyVersion>$(DUMMY)</AssemblyVersion><FileVersion>$(DUMMY).0</FileVersion><InformationalVersion>$(DUMMY)-dummy.42</InformationalVersion><PackageVersion>$(InformationalVersion)</PackageVersion><Version>$(InformationalVersion)</Version></PropertyGroup></Project>'
        $mockPath = "$TestDrive\version.xml"
        Set-Content $mockPath -Value $content 
    }

    It "Ensures mocked version.xml is existing" {
       (Test-Path -Path $mockPath) | Should -Be $true
       (Get-Content -Path $mockPath) | Should -Be $content
    }

    It "Writes the correct values for AssemblyVersion, FileVersion and InformationalVersion to the version.xml file" {
        $version = [EraVersion]@{
            AssemblyVersion = "3.14.15.92"
            FileVersion = "2.71.82.81"
            SemanticVersion = "1.618.0339-label.GoldenRatio"
        }

        Set-VersionXmlFile -AbsoluteFilePath $mockPath -Version $version

        [xml]$xml = Get-Content -Path $mockPath
        (Select-Xml -Xml $xml -XPath "//PropertyGroup/AssemblyVersion").Node.InnerText | Should -Be "3.14.15.92"
        (Select-Xml -Xml $xml -XPath "//PropertyGroup/FileVersion").Node.InnerText | Should -Be "2.71.82.81"
        (Select-Xml -Xml $xml -XPath "//PropertyGroup/InformationalVersion").Node.InnerText | Should -Be "1.618.0339-label.GoldenRatio"
        (Select-Xml -Xml $xml -XPath "//PropertyGroup/PackageVersion").Node.InnerText | Should -Be '$(InformationalVersion)'
        (Select-Xml -Xml $xml -XPath "//PropertyGroup/Version").Node.InnerText | Should -Be '$(InformationalVersion)'
    }
}
