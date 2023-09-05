<#
 .SYNOPSIS
    Populate defined groups with computers by matching operating system

 .DESCRIPTION
    Configure distinguished name where to create groups
    Configure group names and operating system to match
    Disabled computer objects will not be member of its group

 .NOTES
    AUTHOR Jonas Henriksson

 .EXAMPLE
    Register task with:

    @{
        TaskName    = "Create Computer Groups"
        Description = 'Populate defined groups with computers by matching operating system'
        TaskPath    = '\'
        Action      =
        @{
            Execute          = 'C:\Windows\system32\WindowsPowerShell\v1.0\powershell.exe'
            Argument         = '-ExecutionPolicy RemoteSigned -NoProfile -File .\CreateComputerGroupsByMatching.ps1'
            WorkingDirectory = "$($PWD.Path)"
        } | ForEach-Object {
            New-ScheduledTaskAction @_
        }
        Trigger     = New-ScheduledTaskTrigger -Once -At (Get-Date -Format "yyyy-MM-dd HH:00") -RepetitionInterval (New-TimeSpan -Minutes 10)
        Principal   = New-ScheduledTaskPrincipal -UserId 'NT AUTHORITY\SYSTEM' -LogonType ServiceAccount -RunLevel Highest
        Settings    = New-ScheduledTaskSettingsSet
    } | ForEach-Object {
        Register-ScheduledTask @_
    }

 .LINK
    https://github.com/J0N7E
#>

# Get domain info
$BaseDN = Get-ADDomain | Select-Object -ExpandProperty DistinguishedName
$DomainName = Get-AdDomainController | Select-Object -ExpandProperty Domain
$DomainNetbiosName = Get-ADDomain | Select-Object -ExpandProperty NetBIOSName
$DomainPrefix = $DomainNetbiosName.Substring(0, 1).ToUpper() + $DomainNetbiosName.Substring(1)

# Configure where to create groups
$ComputerGroupsDN = "OU=Computer Groups,OU=RES,OU=Vaxholm,$BaseDN"

# Configure group names and operating system to match
$Groups =
@(
    #  Name of group           Regex to match operating system
    @{ Name = 'Workstations';  MatchStr = 'Windows \d\d'; },
    @{ Name = 'Windows 7';     MatchStr = 'Windows 7'; },
    @{ Name = 'Servers';       MatchStr = 'Server'; },

    # Keep for non-matched objects
    @{ Name = "Non-Matched Operating Systems";  MatchStr = $null; }
)

$NonMatchGroupName = "$DomainPrefix $($Groups[-1].Name)"

# Check path
if (Test-Path -Path "AD:$ComputerGroupsDN")
{
    foreach($Group in $Groups)
    {
        # Get group
        New-Variable -Name $Group.Name -Force -Value (Get-ADGroup -Filter "Name -eq '$DomainPrefix $($Group.Name)'" -SearchBase $ComputerGroupsDN -SearchScope OneLevel -Properties Member)

        # Check if group exist
        if(-not (Get-Variable -Name $Group.Name -ValueOnly))
        {
            # Create new group
            New-Variable -Name $Group.Name -Force -Value (New-ADGroup -Name "$DomainPrefix $($Group.Name)" -DisplayName "$DomainPrefix $($Group.Name)" -Description $Group.Name -Path $ComputerGroupsDN -GroupScope Global -GroupCategory Security -PassThru)
        }
    }

    # Get all computer objects running Windows
    foreach($Computer in (Get-ADComputer -Filter "Name -like '*' -and OperatingSystem -like 'Windows*'" -Properties OperatingSystem,MemberOf))
    {
        # Initialize
        $GroupObj = $null

        # Check groups
        foreach($Group in $Groups)
        {
            if ($Group.MatchStr -and $Computer.OperatingSystem -match $Group.MatchStr)
            {
                $GroupObj = Get-Variable -Name $Group.Name -ValueOnly
            }
        }

        # Check if group found
        if ($GroupObj)
        {
            # Add computer to group if enabled and not member of group
            if($Computer.Enabled -and
               -not $GroupObj.Member.Where({ $_.StartsWith("CN=$($Computer.Name),") }))
            {
                Add-ADPrincipalGroupMembership -Identity $Computer -MemberOf @("$($GroupObj.Name)")
            }
            # Remove computer from group if disabled
            elseif (-not $Computer.Enabled -and
               $GroupObj.Member.Where({ $_.StartsWith("CN=$($Computer.Name),") }))
            {
                Remove-ADPrincipalGroupMembership -Identity $Computer -MemberOf @("$($GroupObj.Name)") -Confirm:$false
            }

            if ($Computer.MemberOf -match "$NonMatchGroupName")
            {
                Remove-ADPrincipalGroupMembership -Identity $Computer -MemberOf @("$NonMatchGroupName") -Confirm:$false
            }
        }
        else
        {
            $GroupObj = Get-Variable -Name "$NoMatchGroupName" -ValueOnly

            if (-not $GroupObj.Member.Where({ $_.StartsWith("CN=$($Computer.Name),") }))
            {
                Add-ADPrincipalGroupMembership -Identity $Computer -MemberOf @("$($GroupObj.Name)")
            }
        }
    }
}
