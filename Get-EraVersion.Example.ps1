$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$file = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Example\.', '.'
. "$here\$file"

# IDEA: era of beginning can be static date ("2019-08-16T10:15:00") or date of inital commit
# -> might be configurable
# #$eraBeginning = Get-Date "2018-10-01"

$initialCommit = Get-InitialCommit
$currentCommit = Get-CurrentCommit

Write-Host $initialCommit.CommitDate.GetType()
$version = Get-NextVersion -EraBeginningDate $initialCommit.CommitDate -CurrentCommit $currentCommit -BranchType "canary"

Write-Output "AssemblyVersion: $($version.AssemblyVersion)"
Write-Output "FileVersion: $($version.FileVersion)"
Write-Output "SemanticVersion (SemVer): $($version.SemanticVersion)"
