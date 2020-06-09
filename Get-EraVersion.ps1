#Requires -Version 5.0
#
# git era versioning
#
# A simple and hassle free versioning approach for standalone self-contained applications
# using an incremental rollout strategy (CI/CD) without upstream dependencies.
#
#
# Fomat:
# <DaysElapsed>.<HoursElapsed><MinutesElapsed>.0[-<pre-release>[+<build>]],
#   where <pre-release> ::= canary | ci | rc
#   and <build> ::= <commitsSinceVersionSource>.<currentCommitHashShort>
#



#
# CONFIGURATION
#
$cfgBranchTypeProperties = @{}
$cfgBranchTypeProperties["canary"] = @{ Label = "canary"; Nibble = "0" } # Used for active topic branches (aka. feature branches), i.e. for canary builds.
$cfgBranchTypeProperties["develop"] = @{ Label = "ci"; Nibble = "4" } # Used for main develop branch, i.e. for CI builds.
$cfgBranchTypeProperties["release"] = @{ Label = "rc"; Nibble = "A" } # Used for active release branches, i.e. for RC builds.
$cfgBranchTypeProperties["master"] = @{ Label = ""; Nibble = "F" } # Used for master branch, i.e. RTM builds.



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

function Get-NextEraVersion ([DateTime]$EraBeginningDate, [Commit]$CurrentCommit, [string]$BranchType)
{
    $timeSpan = New-TimeSpan -Start $EraBeginningDate -End $CurrentCommit.CommitDate
    $semVerBase = "{0:dd}.{1:hhmm}.0" -f $timeSpan, $timeSpan

    $branchTypeProperties = $cfgBranchTypeProperties[$BranchType.ToLower()]
    $branchNibble = $branchTypeProperties.Nibble
    $hashUpperWord = $branchNibble + $CurrentCommit.CommitHash.Substring(0,3)
    $hashLowerWord = $CurrentCommit.CommitHash.Substring(3,4)

    $major = $semVerBase.Split(".")[0]
    $minor = $semVerBase.Split(".")[1]
    $build = [convert]::ToInt32($hashUpperWord, 16)
    $revision = [convert]::ToInt32($hashLowerWord, 16)
    $semVer = "{0}-{1}+{2}" -f $semVerBase, $branchTypeProperties.Label, $CurrentCommit.CommitHash.Substring(0,7)

    # NOTE: AssemblyVersion and FileVersion are not fully ascending, but to the same degree unique as the hash!
    #       While the values for Major and Minor are ascending, the values for Build and Revision are composed
    #       of a hash which might produce random results.
    #       Nevertheless, since it is pretty unlikely to have multiple builds within the same minute,
    #       we settle for it!
    $assemblyVersion = "{0}.{1}.{2}.{3}" -f $major, $minor, $build, $revision

    # FIXME: add 16bit overflow check for FileVersion (warning when -1y, error when -30d)
    $fileVersion = $assemblyVersion

    $version = [Version]@{
        AssemblyVersion = $assemblyVersion
        FileVersion = $fileVersion
        SemanticVersion = $semVer
    }

    return $version
}
