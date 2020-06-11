
# Pester is a Behavior-Driven Development (BDD) based test runner and mocking framework for PowerShell.
#
# Install-Module -Name Pester -Force -SkipPublisherCheck # to get version '5.0.2'
# Import-Module Pester
# Invoke-Pester -Script $(System.DefaultWorkingDirectory)\MyFirstModule.test.ps1 -OutputFile $(System.DefaultWorkingDirectory)\Test-Pester.XML -OutputFormat NUnitXML

# Load SUT file
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\$sut"

# Configure Pester
$PesterPreference = [PesterConfiguration]::Default
$PesterPreference.Debug.WriteDebugMessages = $true
$PesterPreference.Debug.WriteDebugMessagesFrom = "Mock"
$PesterPreference.Should.ErrorAction = "Continue"

# Tests
Describe -Tags "Unit" -Name "Get-NextEraVersion" {
    It "Correctly constructs AssemblyVersion, FileVersion and SemanticVersion based on given <branchType>" -TestCases @(
        @{ branchType = 'canary'; expectedBranchLabel = 'canary'; expectedBuildNumer = "3431" }
        @{ branchType = 'develop'; expectedBranchLabel = 'ci'; expectedBuildNumer = "19815" }
        @{ branchType = 'release'; expectedBranchLabel = 'rc'; expectedBuildNumer = "44391" }
        @{ branchType = 'master'; expectedBranchLabel = ''; expectedBuildNumer = "64871" }
    ) {
        param
        (
            [string]$branchType,
            [string]$expectedBranchLabel,
            [string]$expectedBuildNumer
        )

        $currentCommit = [Commit]@{
            CommitHash = "d670460b4b4aece5915caf5c68d12f560a9fe3e4"
            CommitDate = "2019-08-16T10:15:00"
        }

        $version = Get-NextEraVersion -EraBeginningDate ([DateTime]"2018-10-01") -CurrentCommit $currentCommit -BranchType $branchType

        $version.AssemblyVersion | Should -Be "319.1015.$expectedBuildNumer.1120"
        $version.FileVersion | Should -Be "319.1015.$expectedBuildNumer.1120"
        $version.SemanticVersion | Should -Be "319.1015.0-$expectedBranchLabel+d670460"
    }

    It "Writes warning message about one year before FileVersion exceeds 16bit boundary" {
        $currentCommit = [Commit]@{
            CommitHash = "d670460b4b4aece5915caf5c68d12f560a9fe3e4"
            CommitDate = "2149-01-01T00:00:00"
        }
        Get-NextEraVersion -EraBeginningDate ([DateTime]"1970-01-01") -CurrentCommit $currentCommit -BranchType "canary" -WarningVariable warningMessage
        $warningMessage | Should -Be "The Major value has almost reached its maximum. A value greater than 65535 can cause problems on Win32 systems! Major value is '65379'."
    }

    It "Writes error message about 30 days before FileVersion exceeds 16bit boundary" {
        $currentCommit = [Commit]@{
            CommitHash = "d670460b4b4aece5915caf5c68d12f560a9fe3e4"
            CommitDate = "2149-07-01T00:00:00"
        }
        Get-NextEraVersion -EraBeginningDate ([DateTime]"1970-01-01") -CurrentCommit $currentCommit -BranchType "canary" -ErrorVariable errorMessage -ErrorAction SilentlyContinue
        $errorMessage | Should -Be "The Major value has almost reached its maximum. A value greater than 65535 can cause problems on Win32 systems! Major value is '65560'."
    }
}

# Describe "test" {

#     new-item (Join-Path $TestDrive 'File.txt') 

#     It "Test if File.txt exist" {
#        (test-path -path (Join-Path $TestDrive 'File.txt')  ) | Should -Be $true
#     }
# }
