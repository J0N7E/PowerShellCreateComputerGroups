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
        Description = 'Updates CRL for all certificates every 5 minutes and purge caches if successfull'
        TaskPath    = '\'
        Action      =
        @{
            Execute          = 'C:\Windows\system32\WindowsPowerShell\v1.0\powershell.exe'
            Argument         = '-ExecutionPolicy RemoteSigned -NoProfile -File .\CreateComputerGroupsByMatching.ps1'
            WorkingDirectory = "$($PWD.Path)"
        } | ForEach-Object {
            New-ScheduledTaskAction @_
        }
        Trigger     = New-ScheduledTaskTrigger -Once -At (Get-Date -Format "yyyy-MM-dd HH:00") -RepetitionInterval (New-TimeSpan -Minutes 1)
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
$ComputerGroupsDN = "OU=Computer Groups,OU=$DomainName,$BaseDN"

# Configure group names and operating system to match
$Groups =
@(
    #  Name of group           Regex to match operating system
    @{ Name = 'Workstations';  MatchStr = 'Windows \d\d'; },
    @{ Name = 'Servers';       MatchStr = 'Server'; }
)

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
    foreach($Computer in (Get-ADComputer -Filter "Name -like '*' -and OperatingSystem -like 'Windows*'" -Properties OperatingSystem))
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
            elseif (-not $Computer.Enabled) # Remove computer from group if disabled
            {
                Remove-ADPrincipalGroupMembership -Identity $Computer -MemberOf @("$($GroupObj.Name)") -Confirm:$false
            }
        }
        else
        {
            Write-Warning -Message "No group matched `"$($Computer.OperatingSystem)`" for computer `"$($Computer.Name)`""
        }
    }
}

# SIG # Begin signature block
# MIIetgYJKoZIhvcNAQcCoIIepzCCHqMCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBUbehxFFCjqKHL
# LY40j0SBgvm4iqjbA+qFM2ESpHqt9KCCGBIwggUHMIIC76ADAgECAhAlNIx7cQRR
# lkABY7XM1R9ZMA0GCSqGSIb3DQEBCwUAMBAxDjAMBgNVBAMMBUowTjdFMB4XDTIx
# MDYwNzEyNTAzNloXDTIzMDYwNzEzMDAzM1owEDEOMAwGA1UEAwwFSjBON0UwggIi
# MA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDN0XPe0P03RV5vKbDFsHuz5gws
# Uor0uU9w7LIVsChGdgpW4XtDpmJ8UxYiimdFGr9i1qES2ZqTIs/UCY616w5IvQ1E
# TkNA0XLKToPTb8cWGkzQduD2oqm/97cMPfq6q/oObBXKTRSL1MJhlBswOGFr9K9P
# 4hLg8EPB3dFMbpUfvSMb/uVrACGYATv+CPcF3mmLuMydo9pEeySiBsAf+9EbNb6i
# 54bddX0Tk9ZZ5GqDVtNegiEEbVGhJYJcSlwd6QVVKdq0TUUbChkdMNhyo2dQ5AXH
# Ua6BkTumatmx0u+j/WBQJJ0wW9OhT5R66tkj1KV+E93prWNhP8FyCxl2CFZQ7Yzx
# IK5D9L826i0BneRkj/fLdPklCc32X3AxRqgigQzE0roGaxIWASSJB5B5TojRhPmq
# EO6QBkOgQQQcqXXvHRDq/GaIWvTjnVQ/FZnX2c8txxLeLf+QRCNVdzz2Pa9echbW
# vlQcZQHg1R2S1pDbmHFzpz79OzH3rxL4xyrEX1GZEyniDSQAWEEcqPtaFRW3Zn9t
# QtLJvvY4XgELngIJK3VDh4SWHQLUC52RmCP0JAoUjK95MEWyL6LaDoPlwimXl/JB
# CeoOH+P6E3lC4jwPumgt7cw80DmvlbVzrQHyeCsOwl3tecmtfoZ0l3bAg+HVGbMO
# WahTFVeuCcW2DN5NRQIDAQABo10wWzAOBgNVHQ8BAf8EBAMCBaAwKgYDVR0lBCMw
# IQYIKwYBBQUHAwMGCSsGAQQBgjdQAQYKKwYBBAGCNwoDBDAdBgNVHQ4EFgQUQ8Iu
# g1iDDJBUdGsFIj2XSdIzCcswDQYJKoZIhvcNAQELBQADggIBAGIxbxxJLgvU5W7h
# xGJo+uJqpB1S6SCRxPyJYZasActMU/OK8g8jn7uorDMgltqA4zd8mMbR7q2CFpII
# 99VT6w9a9cgoXeujlctR8m63qPmpSqhC3/M25akjXYPWCzU1E5acmCp7V12a+gA6
# fmlnIWqigLhKcPV9PtKuz4bweztB3aP/VdgCmFl8teiI4Wzu7ORAsluGaKSEQlAr
# MoTiLx1yyi5w2F7aW80N+0mpoaWgAvO7TjLUtymAINFu+NTRgNK1nApISP2O/Pz3
# GmXm0yuAZYgryCGNHMZ/SI+Gpv/EU4Vwo/aTjdf/BdZr1bs+U742EiVmZMz9b7CW
# CtF+CRrDLZYuk7xWin629XAt3KnmfhTFENcGFh3vwl+xxvR/CmxT4PM40uskTBeN
# 2Pdb690RmztgjACewIZ/w3Oddak30Ps7OpXQ9PZLORqjmESnedLp0553D/S4oDP6
# XmztYk5Mu0WMOFSTraDm8hm9UrYT1NYC5WI+ZSRW6Ce7iRXhzzvSLliBFnP2XiKH
# m8v1cyhzj/qCiEu1SBPgUPTEpedvC2X8tzOTMM728otvH3cgKY0m7MuP4rxLgACj
# yro9OAtnIaWjOZNZFrdKYZWpM0Sy5lHjWEY2mO020giLB1nhC4/xyPrhOKRQigZU
# 1sJmBw8MeuvPzhmMAWWbsf1J9MryMIIFjTCCBHWgAwIBAgIQDpsYjvnQLefv21Di
# CEAYWjANBgkqhkiG9w0BAQwFADBlMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGln
# aUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMSQwIgYDVQQDExtE
# aWdpQ2VydCBBc3N1cmVkIElEIFJvb3QgQ0EwHhcNMjIwODAxMDAwMDAwWhcNMzEx
# MTA5MjM1OTU5WjBiMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5j
# MRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMSEwHwYDVQQDExhEaWdpQ2VydCBU
# cnVzdGVkIFJvb3QgRzQwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQC/
# 5pBzaN675F1KPDAiMGkz7MKnJS7JIT3yithZwuEppz1Yq3aaza57G4QNxDAf8xuk
# OBbrVsaXbR2rsnnyyhHS5F/WBTxSD1Ifxp4VpX6+n6lXFllVcq9ok3DCsrp1mWpz
# MpTREEQQLt+C8weE5nQ7bXHiLQwb7iDVySAdYyktzuxeTsiT+CFhmzTrBcZe7Fsa
# vOvJz82sNEBfsXpm7nfISKhmV1efVFiODCu3T6cw2Vbuyntd463JT17lNecxy9qT
# XtyOj4DatpGYQJB5w3jHtrHEtWoYOAMQjdjUN6QuBX2I9YI+EJFwq1WCQTLX2wRz
# Km6RAXwhTNS8rhsDdV14Ztk6MUSaM0C/CNdaSaTC5qmgZ92kJ7yhTzm1EVgX9yRc
# Ro9k98FpiHaYdj1ZXUJ2h4mXaXpI8OCiEhtmmnTK3kse5w5jrubU75KSOp493ADk
# RSWJtppEGSt+wJS00mFt6zPZxd9LBADMfRyVw4/3IbKyEbe7f/LVjHAsQWCqsWMY
# RJUadmJ+9oCw++hkpjPRiQfhvbfmQ6QYuKZ3AeEPlAwhHbJUKSWJbOUOUlFHdL4m
# rLZBdd56rF+NP8m800ERElvlEFDrMcXKchYiCd98THU/Y+whX8QgUWtvsauGi0/C
# 1kVfnSD8oR7FwI+isX4KJpn15GkvmB0t9dmpsh3lGwIDAQABo4IBOjCCATYwDwYD
# VR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQU7NfjgtJxXWRM3y5nP+e6mK4cD08wHwYD
# VR0jBBgwFoAUReuir/SSy4IxLVGLp6chnfNtyA8wDgYDVR0PAQH/BAQDAgGGMHkG
# CCsGAQUFBwEBBG0wazAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQu
# Y29tMEMGCCsGAQUFBzAChjdodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGln
# aUNlcnRBc3N1cmVkSURSb290Q0EuY3J0MEUGA1UdHwQ+MDwwOqA4oDaGNGh0dHA6
# Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcmww
# EQYDVR0gBAowCDAGBgRVHSAAMA0GCSqGSIb3DQEBDAUAA4IBAQBwoL9DXFXnOF+g
# o3QbPbYW1/e/Vwe9mqyhhyzshV6pGrsi+IcaaVQi7aSId229GhT0E0p6Ly23OO/0
# /4C5+KH38nLeJLxSA8hO0Cre+i1Wz/n096wwepqLsl7Uz9FDRJtDIeuWcqFItJnL
# nU+nBgMTdydE1Od/6Fmo8L8vC6bp8jQ87PcDx4eo0kxAGTVGamlUsLihVo7spNU9
# 6LHc/RzY9HdaXFSMb++hUD38dglohJ9vytsgjTVgHAIDyyCwrFigDkBjxZgiwbJZ
# 9VVrzyerbHbObyMt9H5xaiNrIv8SuFQtJ37YOtnwtoeW/VvRXKwYw02fc7cBqZ9X
# ql4o4rmUMIIGrjCCBJagAwIBAgIQBzY3tyRUfNhHrP0oZipeWzANBgkqhkiG9w0B
# AQsFADBiMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYD
# VQQLExB3d3cuZGlnaWNlcnQuY29tMSEwHwYDVQQDExhEaWdpQ2VydCBUcnVzdGVk
# IFJvb3QgRzQwHhcNMjIwMzIzMDAwMDAwWhcNMzcwMzIyMjM1OTU5WjBjMQswCQYD
# VQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xOzA5BgNVBAMTMkRpZ2lD
# ZXJ0IFRydXN0ZWQgRzQgUlNBNDA5NiBTSEEyNTYgVGltZVN0YW1waW5nIENBMIIC
# IjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAxoY1BkmzwT1ySVFVxyUDxPKR
# N6mXUaHW0oPRnkyibaCwzIP5WvYRoUQVQl+kiPNo+n3znIkLf50fng8zH1ATCyZz
# lm34V6gCff1DtITaEfFzsbPuK4CEiiIY3+vaPcQXf6sZKz5C3GeO6lE98NZW1Oco
# LevTsbV15x8GZY2UKdPZ7Gnf2ZCHRgB720RBidx8ald68Dd5n12sy+iEZLRS8nZH
# 92GDGd1ftFQLIWhuNyG7QKxfst5Kfc71ORJn7w6lY2zkpsUdzTYNXNXmG6jBZHRA
# p8ByxbpOH7G1WE15/tePc5OsLDnipUjW8LAxE6lXKZYnLvWHpo9OdhVVJnCYJn+g
# GkcgQ+NDY4B7dW4nJZCYOjgRs/b2nuY7W+yB3iIU2YIqx5K/oN7jPqJz+ucfWmyU
# 8lKVEStYdEAoq3NDzt9KoRxrOMUp88qqlnNCaJ+2RrOdOqPVA+C/8KI8ykLcGEh/
# FDTP0kyr75s9/g64ZCr6dSgkQe1CvwWcZklSUPRR8zZJTYsg0ixXNXkrqPNFYLwj
# jVj33GHek/45wPmyMKVM1+mYSlg+0wOI/rOP015LdhJRk8mMDDtbiiKowSYI+RQQ
# EgN9XyO7ZONj4KbhPvbCdLI/Hgl27KtdRnXiYKNYCQEoAA6EVO7O6V3IXjASvUae
# tdN2udIOa5kM0jO0zbECAwEAAaOCAV0wggFZMBIGA1UdEwEB/wQIMAYBAf8CAQAw
# HQYDVR0OBBYEFLoW2W1NhS9zKXaaL3WMaiCPnshvMB8GA1UdIwQYMBaAFOzX44LS
# cV1kTN8uZz/nupiuHA9PMA4GA1UdDwEB/wQEAwIBhjATBgNVHSUEDDAKBggrBgEF
# BQcDCDB3BggrBgEFBQcBAQRrMGkwJAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRp
# Z2ljZXJ0LmNvbTBBBggrBgEFBQcwAoY1aHR0cDovL2NhY2VydHMuZGlnaWNlcnQu
# Y29tL0RpZ2lDZXJ0VHJ1c3RlZFJvb3RHNC5jcnQwQwYDVR0fBDwwOjA4oDagNIYy
# aHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZFJvb3RHNC5j
# cmwwIAYDVR0gBBkwFzAIBgZngQwBBAIwCwYJYIZIAYb9bAcBMA0GCSqGSIb3DQEB
# CwUAA4ICAQB9WY7Ak7ZvmKlEIgF+ZtbYIULhsBguEE0TzzBTzr8Y+8dQXeJLKftw
# ig2qKWn8acHPHQfpPmDI2AvlXFvXbYf6hCAlNDFnzbYSlm/EUExiHQwIgqgWvalW
# zxVzjQEiJc6VaT9Hd/tydBTX/6tPiix6q4XNQ1/tYLaqT5Fmniye4Iqs5f2MvGQm
# h2ySvZ180HAKfO+ovHVPulr3qRCyXen/KFSJ8NWKcXZl2szwcqMj+sAngkSumScb
# qyQeJsG33irr9p6xeZmBo1aGqwpFyd/EjaDnmPv7pp1yr8THwcFqcdnGE4AJxLaf
# zYeHJLtPo0m5d2aR8XKc6UsCUqc3fpNTrDsdCEkPlM05et3/JWOZJyw9P2un8WbD
# Qc1PtkCbISFA0LcTJM3cHXg65J6t5TRxktcma+Q4c6umAU+9Pzt4rUyt+8SVe+0K
# XzM5h0F4ejjpnOHdI/0dKNPH+ejxmF/7K9h+8kaddSweJywm228Vex4Ziza4k9Tm
# 8heZWcpw8De/mADfIBZPJ/tgZxahZrrdVcA6KYawmKAr7ZVBtzrVFZgxtGIJDwq9
# gdkT/r+k0fNX2bwE+oLeMt8EifAAzV3C+dAjfwAL5HYCJtnwZXZCpimHCUcr5n8a
# pIUP/JiW9lVUKx+A+sDyDivl1vupL0QVSucTDh3bNzgaoSv27dZ8/DCCBsAwggSo
# oAMCAQICEAxNaXJLlPo8Kko9KQeAPVowDQYJKoZIhvcNAQELBQAwYzELMAkGA1UE
# BhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMTswOQYDVQQDEzJEaWdpQ2Vy
# dCBUcnVzdGVkIEc0IFJTQTQwOTYgU0hBMjU2IFRpbWVTdGFtcGluZyBDQTAeFw0y
# MjA5MjEwMDAwMDBaFw0zMzExMjEyMzU5NTlaMEYxCzAJBgNVBAYTAlVTMREwDwYD
# VQQKEwhEaWdpQ2VydDEkMCIGA1UEAxMbRGlnaUNlcnQgVGltZXN0YW1wIDIwMjIg
# LSAyMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAz+ylJjrGqfJru43B
# DZrboegUhXQzGias0BxVHh42bbySVQxh9J0Jdz0Vlggva2Sk/QaDFteRkjgcMQKW
# +3KxlzpVrzPsYYrppijbkGNcvYlT4DotjIdCriak5Lt4eLl6FuFWxsC6ZFO7Khbn
# UEi7iGkMiMbxvuAvfTuxylONQIMe58tySSgeTIAehVbnhe3yYbyqOgd99qtu5Wbd
# 4lz1L+2N1E2VhGjjgMtqedHSEJFGKes+JvK0jM1MuWbIu6pQOA3ljJRdGVq/9XtA
# bm8WqJqclUeGhXk+DF5mjBoKJL6cqtKctvdPbnjEKD+jHA9QBje6CNk1prUe2nhY
# HTno+EyREJZ+TeHdwq2lfvgtGx/sK0YYoxn2Off1wU9xLokDEaJLu5i/+k/kezbv
# BkTkVf826uV8MefzwlLE5hZ7Wn6lJXPbwGqZIS1j5Vn1TS+QHye30qsU5Thmh1EI
# a/tTQznQZPpWz+D0CuYUbWR4u5j9lMNzIfMvwi4g14Gs0/EH1OG92V1LbjGUKYvm
# QaRllMBY5eUuKZCmt2Fk+tkgbBhRYLqmgQ8JJVPxvzvpqwcOagc5YhnJ1oV/E9mN
# ec9ixezhe7nMZxMHmsF47caIyLBuMnnHC1mDjcbu9Sx8e47LZInxscS451NeX1XS
# fRkpWQNO+l3qRXMchH7XzuLUOncCAwEAAaOCAYswggGHMA4GA1UdDwEB/wQEAwIH
# gDAMBgNVHRMBAf8EAjAAMBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMIMCAGA1UdIAQZ
# MBcwCAYGZ4EMAQQCMAsGCWCGSAGG/WwHATAfBgNVHSMEGDAWgBS6FtltTYUvcyl2
# mi91jGogj57IbzAdBgNVHQ4EFgQUYore0GH8jzEU7ZcLzT0qlBTfUpwwWgYDVR0f
# BFMwUTBPoE2gS4ZJaHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1
# c3RlZEc0UlNBNDA5NlNIQTI1NlRpbWVTdGFtcGluZ0NBLmNybDCBkAYIKwYBBQUH
# AQEEgYMwgYAwJAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBY
# BggrBgEFBQcwAoZMaHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0
# VHJ1c3RlZEc0UlNBNDA5NlNIQTI1NlRpbWVTdGFtcGluZ0NBLmNydDANBgkqhkiG
# 9w0BAQsFAAOCAgEAVaoqGvNG83hXNzD8deNP1oUj8fz5lTmbJeb3coqYw3fUZPwV
# +zbCSVEseIhjVQlGOQD8adTKmyn7oz/AyQCbEx2wmIncePLNfIXNU52vYuJhZqMU
# KkWHSphCK1D8G7WeCDAJ+uQt1wmJefkJ5ojOfRu4aqKbwVNgCeijuJ3XrR8cuOyY
# QfD2DoD75P/fnRCn6wC6X0qPGjpStOq/CUkVNTZZmg9U0rIbf35eCa12VIp0bcrS
# BWcrduv/mLImlTgZiEQU5QpZomvnIj5EIdI/HMCb7XxIstiSDJFPPGaUr10CU+ue
# 4p7k0x+GAWScAMLpWnR1DT3heYi/HAGXyRkjgNc2Wl+WFrFjDMZGQDvOXTXUWT5D
# mhiuw8nLw/ubE19qtcfg8wXDWd8nYiveQclTuf80EGf2JjKYe/5cQpSBlIKdrAqL
# xksVStOYkEVgM4DgI974A6T2RUflzrgDQkfoQTZxd639ouiXdE4u2h4djFrIHprV
# wvDGIqhPm73YHJpRxC+a9l+nJ5e6li6FV8Bg53hWf2rvwpWaSxECyIKcyRoFfLpx
# tU56mWz06J7UWpjIn7+NuxhcQ/XQKujiYu54BNu90ftbCqhwfvCXhHjjCANdRyxj
# qCU4lwHSPzra5eX25pvcfizM/xdMTQCi2NYBDriL7ubgclWJLCcZYfZ3AYwxggX6
# MIIF9gIBATAkMBAxDjAMBgNVBAMMBUowTjdFAhAlNIx7cQRRlkABY7XM1R9ZMA0G
# CWCGSAFlAwQCAQUAoIGEMBgGCisGAQQBgjcCAQwxCjAIoAKAAKECgAAwGQYJKoZI
# hvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcC
# ARUwLwYJKoZIhvcNAQkEMSIEIB7mlRz3bG2PqmoqxCWzafCcmPVRqXVwpmuDMgZf
# kKMMMA0GCSqGSIb3DQEBAQUABIICAKlaXZDKYcbOrV84JhKiM6Ppyh04ibE8UNkY
# ZLt/xiTor7Az+RfEqgaoNqaXruGJyyP+7YxbjXU9W77rIaFPt4hiSWTNkGLUBYmr
# zDjRHjpjJpMnla4ePIW7zt23pT3/yG47RG6rAyAd3IxRwTBcULD3ic0oMMG3e6uv
# G/mtcq63AdoVAIcrV5GIQq4SgnodbMt24Ry1k0X7PvXToTfGild9TUDXoqbJPl3p
# Zsw02yHiXkx9N/8o9nztU3ptjTS2AkqYNp6xn4yWe+UWrUPKWro5dHZPVbo/35Iz
# vHj2rglX5u+HoswOwlb8ZU1kZh0Zx5rvwZ5jMltJ4/kauDFUqutFrNY8bUHRle0v
# +EnRQKuX9CRrDxEWKG/5SNKMUjlrFxMZz6ua2ilOug1MLSq15FlmlNku4nPceVIi
# 6epm1bT7yjU4jYru+I28drqT2Ef4NWaS8jroA2jwD2mc7Jlq5Jtb5rczE+qpuV4h
# W4ktxmZLc930ijgUKGOTaWPg3WHpVeZPywGgBD4Ij7pWdUIxDsWF2u+aX7KurtM2
# jW5hbDUJ9qjqm16ArUHBCPKGnwrMq34gVt5i0hMuY6EkQZ0pN+qRO+TgqQhJ8TrC
# HPU8V0puGMBltDtidaPG00xTOxbg4QGe+nVJL51a+DsAbspLhBd6Lc6DA904wGMr
# q2LDbW4ooYIDIDCCAxwGCSqGSIb3DQEJBjGCAw0wggMJAgEBMHcwYzELMAkGA1UE
# BhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMTswOQYDVQQDEzJEaWdpQ2Vy
# dCBUcnVzdGVkIEc0IFJTQTQwOTYgU0hBMjU2IFRpbWVTdGFtcGluZyBDQQIQDE1p
# ckuU+jwqSj0pB4A9WjANBglghkgBZQMEAgEFAKBpMBgGCSqGSIb3DQEJAzELBgkq
# hkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8XDTIzMDUxMTEwMDgwNVowLwYJKoZIhvcN
# AQkEMSIEIMVzwqrlsGFBovDKKRlUgkPRv7XJgBM4k4io+e54aWj4MA0GCSqGSIb3
# DQEBAQUABIICADVrEy/1JsPOkR7Mjc9aqDftnNk+o/cdhme+Pk2Nve+1L0HMlcXV
# 02EEAfXbezGv0QAgf5mgrqBPPsaysnjcckkNXhPZeIJSbgeheXBRE9jeNO5+frUS
# qNzuZ4V61S/9ahi3csX7E7AVBIeZaIvIUcS+DMm3D9k2C26+jRHuU7H+RuKEWHwg
# vAaCgheiYG+N4l/rNuVfu1UYx+veRw8YWdPNB4/O/6gltQ2IDPozj22kNNCpp1PH
# MKYSx6NlkJD+VwRG5AQTC/n0gnIjGj1YBfDxjeebUCyEdNsMiqVQR/rCeJs1ZP7s
# 1BLny/8KpZHvG1CgxLLNDOiVtrYH4lKS0jA/19WSENB/4WNVS0UHpO/rKX61Xzbk
# AOWZXgd8CnA8SfkDTBB0qjdpuRj58vsB2eSXXbxGdHN+7kE0E/IHpG8Oyej3MjQy
# vcqsc+auvKZndPnnuxhY8mHfAHpFY9J0op/qkX/j2gte2AkrjNnd9QovJC8TMLrS
# msciZsIwIOW28XeRCkXe77Mxhjd3cF2Fgma9s6CQ69yqvNQJnP1HyUeBEnxLfOK+
# hilieGiDJ32q6aMpBpuHJKG+B4b6lrHmulVjQdGAbbIqQjM5ES9Osf/VxDvOgdOO
# LA0ybK+o9/ag0mc+A2J/f7Em0tw+UNy9kKbL/R1cos7IFnC7uj82FBC3
# SIG # End signature block
