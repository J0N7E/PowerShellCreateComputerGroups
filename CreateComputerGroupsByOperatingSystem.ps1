<#
 .SYNOPSIS
    Populate dynamic groups with computers by operating system

 .DESCRIPTION
    Configure distinguished name where to create groups
    Create groups named after existing operating systems
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
            Argument         = '-ExecutionPolicy RemoteSigned -NoProfile -File .\CreateComputerGroupsByOperatingSystem.ps1'
            WorkingDirectory = "$($PWD.Path)"
        } | ForEach-Object {
            New-ScheduledTaskAction @_
        }
        Trigger     = New-ScheduledTaskTrigger -Once -At (Get-Date -Format "yyyy-MM-dd HH:00") -RepetitionInterval (New-TimeSpan -Minutes 5)
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

# Check path
if (Test-Path -Path "AD:$ComputerGroupsDN")
{
    # Get all computer objects running Windows
    foreach($Computer in (Get-ADComputer -Filter "Name -like '*' -and OperatingSystem -like 'Windows*'" -Properties OperatingSystem))
    {
        # Get group
        $GroupObj = Get-ADGroup -Filter "Name -eq '$DomainPrefix $($Computer.OperatingSystem)'" -SearchBase $ComputerGroupsDN -SearchScope OneLevel -Properties Member

        # Check if group exist
        if(-not $GroupObj -and $Computer.Enabled)
        {
            # Create new group
            $GroupObj = New-ADGroup -Name "$DomainPrefix $($Computer.OperatingSystem)" -DisplayName "$DomainPrefix $($Computer.OperatingSystem)" -Description $Computer.OperatingSystem -Path $ComputerGroupsDN -GroupScope Global -GroupCategory Security -PassThru
        }

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
}

# SIG # Begin signature block
# MIIetgYJKoZIhvcNAQcCoIIepzCCHqMCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDx0BxkQTYuHaqO
# hrkpG/8ZZr718mD1rWy52NpzfY5QB6CCGBIwggUHMIIC76ADAgECAhAlNIx7cQRR
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
# ARUwLwYJKoZIhvcNAQkEMSIEIOvaWWK9Iktj8Zxa5R5pZKJXuEtXeQvpEH+69U0j
# qPCRMA0GCSqGSIb3DQEBAQUABIICADr/hhgs5VjNfpgZZMtDD6Dh0CC7DJL04LBg
# 5S535zRKBlduaraAgHKJ7U2gz1S2VpT6MUs28Wud72uYgBW5QtnUTpvLkv29feVl
# +fzsW4s6N9iiTy5Px4D/15/XBWQ/0TUaW/HrOXtGXpq593xNL/nvxkpop3eT84h4
# l7VHuuGcrDUkV+cC3brXoLKL4VbLcUdo3qLRJjTNb3Db2g4hfuc8QoSXbTYAunhm
# rO0oTHVhpdMbd6JAyXE5fmVpok1OKwMN1txlvbtYvuZ/wA1TEcpjTP33qBc410Fu
# L7K4rrnHi2jZGplC2crnukPL0kqlI5OgE+Lmzp9QOVdJdaWFZr5Bok/zgk2SIqb5
# 2UdwZFpoz5oYVZhHwoNaTKu4mU+lO1xQOtyQSseiE+RlOHXq07nkUQCFR5bRQFrY
# Vn6Bmzs36Jhgb+QzMygfDNmysgMzHy/w0wEW97VYMreHk3rLiLaNyNDDkvdPhDCj
# GnZ49+fRKL7DFec5a1repacAYfVldgFdOxREN1XN0N4bZ3F5pmUD05M5nKpDodc1
# jhcA7Uo7Cry8XLX6Z+RPpthoNpEns8MfgSD0/SKISvB4nF/kXOudb066gPL3d48F
# uphoxN5LD8vW0tPC8njlY3Qn0shIqr6nhf16YmlNFtVg1hzKcg65iHEkPP5qQgV+
# jPTA1pgzoYIDIDCCAxwGCSqGSIb3DQEJBjGCAw0wggMJAgEBMHcwYzELMAkGA1UE
# BhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMTswOQYDVQQDEzJEaWdpQ2Vy
# dCBUcnVzdGVkIEc0IFJTQTQwOTYgU0hBMjU2IFRpbWVTdGFtcGluZyBDQQIQDE1p
# ckuU+jwqSj0pB4A9WjANBglghkgBZQMEAgEFAKBpMBgGCSqGSIb3DQEJAzELBgkq
# hkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8XDTIzMDUxMTEwMDgwNVowLwYJKoZIhvcN
# AQkEMSIEICeAxhE4OYLpFW7YEtslwz8ViYCntFFc7BB4T0tG0OnXMA0GCSqGSIb3
# DQEBAQUABIICALeqLrvHeXtVjudAd5S3lKVWnbGevFiHQ3W5gQ6nYdsZc4GL00Cb
# gVt7mpsAd9PiQ4behjK55rdDB6CrY5uV9d3MvflYNYfzKqTtXZaUvtRIEUvaZxnq
# v7uoKjyXa+E7aAqRQ40dOim33RnR/upOhWg9RtuQzYqW2qfY4Zzjm6TakCWJNBfe
# ZURIr+gJTTbzQnxmHBBm6dC62caMP7dBEf3TLrqH3+ocbuhK8HeUa3oBC1tR99Az
# BReSpUAjSUE6L5esVci4C7B5v/0UE7Ob8iBb6xd3nno1UiLM0EnZ8VPjxBiwoGTO
# A3C/i8+LBev9+6GyR8cFW4W/AfjKV3cVFkxMuhWI7WrtDFssMxG2VbYYK0nmDYXc
# ZMrw1z8rlP/CoHc0oeOWmj0Qri+ykqwf+1H52FuYD31I97Yol8Bz9vdut/ODmJo/
# tEaHeoKggpJMsSFhOBA0OLZT+PAJ5O++VEQ7I7SNQJuVsuYlLuEfudbn/DKq1DNi
# oAO5KP7HW2Rq4k055ZJ2eY8YcT2vxxGNe4xrjOPQfYg8v6ZBL44NjWVITZ8HTN97
# e2nf/Ta18wLzROXarX8MUFwMrIsQmr9c54J94EreaTzF3gGyBYOm80evP9u9SljU
# UxFebkxBAH9+109E1es+wdKuAR6u/S/sT3lWmegNr9BUQCMcTyv3MNL2
# SIG # End signature block
