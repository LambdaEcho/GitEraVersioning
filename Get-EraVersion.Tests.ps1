
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
$PesterPreference = [PesterConfiguration]::Defaultinv
$PesterPreference.Debug.WriteDebugMessages = $true
$PesterPreference.Debug.WriteDebugMessagesFrom = "Mock"
$PesterPreference.Should.ErrorAction = "Continue"

# Tests
Describe -Tags "Unit" -Name "NameOfTestGroup" {

}



Describe -tag "Tag1" -name "Tag1Name1" {
    It "true is not false" {
        $true | Should -Be $true
    }
}

Describe -tag "Tag2" -name "Tag2Name1" {
    It "true is never false" {
        $true | Should -Not -Be $false 
    }
}
