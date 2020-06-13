#Requires -Version 5.0
#
# git era versioning
#
# A simple and hassle free versioning approach for standalone self-contained applications
# using an incremental rollout strategy (CI/CD) without upstream dependencies.
#
#
# Format:
# <DaysElapsed>.<HoursElapsed><MinutesElapsed>.0[-<pre-release>[+<buildMetadata>]],
#   where <pre-release> ::= canary | ci | rc
#   and <build> ::= <currentCommitHashShort>
# This format complies with SemVer 2.0 (cf. https://semver.org/).
#



#
# CONFIGURATION
#
$cfgBranchNameProperties = @{}
$cfgBranchNameProperties["topic"] = @{ Label = "canary"; Nibble = "0" } # Used for active topic branches (aka. feature branches), i.e. for canary builds.
$cfgBranchNameProperties["develop"] = @{ Label = "ci"; Nibble = "4" } # Used for main develop branch, i.e. for CI builds.
$cfgBranchNameProperties["release"] = @{ Label = "rc"; Nibble = "A" } # Used for active release branches, i.e. for RC builds.
$cfgBranchNameProperties["master"] = @{ Label = ""; Nibble = "F" } # Used for master branch, i.e. RTM or stable builds.



#
# TYPES
#
class Commit
{
    # Optionally, add attributes to prevent invalid values
    [ValidateNotNullOrEmpty()][string]$CommitHash
    [ValidateNotNullOrEmpty()][DateTime]$CommitDate
}

class Version
{
    [ValidateNotNullOrEmpty()][string]$AssemblyVersion
    [ValidateNotNullOrEmpty()][string]$FileVersion
    [ValidateNotNullOrEmpty()][string]$SemanticVersion
}



#
# LOGIC
#
function Get-InitialCommit() {
    $hash = (git rev-list --max-parents=0 HEAD) | Out-String
    $shortHash = $hash.Substring(0,7)
    $date = (git show -s --format=%cI $shortHash) | Get-Date
    
    $commit = [Commit]@{
        CommitHash = $hash
        CommitDate = $date
    }

    return $commit
}

function Get-CurrentCommit() {
    $hash = (git rev-parse HEAD) | Out-String
    $shortHash = $hash.Substring(0,7)
    $date = (git show -s --format=%cI $shortHash) | Get-Date

    $commit = [Commit]@{
        CommitHash = $hash
        CommitDate = $date
    }

    return $commit
}

function Get-NextEraVersion
{
    [CmdletBinding()]
    Param(
        [DateTime]$EraBeginningDate,
        [Commit]$CurrentCommit,
        [string]$BranchName
    )

    $length = $(If ($BranchName.IndexOf('/') -gt 0) { $BranchName.IndexOf('/') } Else { $BranchName.Length })
    $branchType = $BranchName.Substring(0, $length)
    $branchNameProperties = $cfgBranchNameProperties[$branchType.ToLower()]

    $branchNibble = $branchNameProperties.Nibble
    $hashUpperWord = $branchNibble + $CurrentCommit.CommitHash.Substring(0,3)
    $hashLowerWord = $CurrentCommit.CommitHash.Substring(3,4)

    $timeSpan = New-TimeSpan -Start $EraBeginningDate -End $CurrentCommit.CommitDate
    $semVerBase = "{0:dd}.{1:hhmm}.0" -f $timeSpan, $timeSpan
    $major = $semVerBase.Split(".")[0]
    $minor = $semVerBase.Split(".")[1]
    $build = [convert]::ToInt32($hashUpperWord, 16)
    $revision = [convert]::ToInt32($hashLowerWord, 16)
    $semVer = "{0}-{1}+{2}" -f $semVerBase, $branchNameProperties.Label, $CurrentCommit.CommitHash.Substring(0,7)

    # NOTE: AssemblyVersion and FileVersion are not fully ascending, but to the same degree unique as the hash!
    #       While the values for Major and Minor are ascending, the values for Build and Revision are composed
    #       of a hash which might produce random results.
    #       Nevertheless, since it is pretty unlikely to have multiple builds within the same minute,
    #       we settle for it!
    $assemblyVersion = "{0}.{1}.{2}.{3}" -f $major, $minor, $build, $revision
    $fileVersion = $assemblyVersion

    # The FileVersion consists of four 16bit values on Win32.
    # Hence, we need an overflow check for the Major value that represents the elapsed days.
    $elapsedDays = $timeSpan.Days
    $elapsedDaysMessage = "The Major value has almost reached its maximum. A value greater than 65535 can cause problems on Win32 systems! Major value is '$elapsedDays'."
    if ($elapsedDays -gt 65500) { Write-Error $elapsedDaysMessage } #-ErrorAction Inquire }
    elseif ($elapsedDays -gt 65170) { Write-Warning $elapsedDaysMessage }

    $version = [Version]@{
        AssemblyVersion = $assemblyVersion
        FileVersion = $fileVersion
        SemanticVersion = $semVer
    }

    return $version
}

function Set-VersionXmlFile
{
    [CmdletBinding()]
    Param(
        [string]$AbsoluteFilePath,
        [Version]$Version
    )

    [xml]$xml = Get-Content -Path $AbsoluteFilePath
    (Select-Xml -Xml $xml -XPath "//PropertyGroup/AssemblyVersion").Node.InnerText = $Version.AssemblyVersion
    (Select-Xml -Xml $xml -XPath "//PropertyGroup/FileVersion").Node.InnerText = $Version.FileVersion
    (Select-Xml -Xml $xml -XPath "//PropertyGroup/InformationalVersion").Node.InnerText = $Version.SemanticVersion
    $xml.Save($AbsoluteFilePath)

    # Sanity check
    # After file processing, we expect a remaining variable for PackageVersion and Version only!
    if (((Select-String -Path $AbsoluteFilePath -Pattern "\$\(InformationalVersion\)") | Measure-Object).Count -ne 2) {
        throw [System.InvalidOperationException] "Error while processing $($AbsoluteFilePath)!"
    }
}
