function Add-CapabilityFromApplication {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$ApplicationName)

    Write-Host "Checking for application: '$ApplicationName'"
    $application =
        Get-Command -Name $ApplicationName -CommandType Application -ErrorAction Ignore |
        Select-Object -First 1
    if (!$application) {
        Write-Host "Not found."
        return
    }

    Write-Capability -Name $Name -Value $application.Path
}

function Add-CapabilityFromEnvironment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$VariableName,

        [ref]$Value)

    $path = "env:$VariableName"
    Write-Host "Checking: '$path'"
    $val = (Get-Item -LiteralPath $path -ErrorAction Ignore).Value
    if (!$val) {
        Write-Host "Value not found or is empty."
        return
    }

    Write-Capability -Name $Name -Value $val
    if ($Value) {
        $Value.Value = $val
    }
}

function Add-CapabilityFromRegistry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [ValidateSet('CurrentUser', 'LocalMachine')]
        [string]$Hive,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Default', 'Registry32', 'Registry64')]
        [string]$View,

        [Parameter(Mandatory = $true)]
        [string]$KeyName,

        [Parameter(Mandatory = $true)]
        [string]$ValueName,

        [ref]$Value)

    $val = Get-RegistryValue -Hive $Hive -View $View -KeyName $KeyName -ValueName $ValueName
    if ($val -eq $null) {
        return $false
    }

    if ($val -is [string] -and $val -eq '') {
        return $false
    }

    Write-Capability -Name $Name -Value $val
    if ($Value) {
        $Value.Value = $val
    }

    return $true
}


function Add-CapabilityFromRegistryWithLastVersionAvailableForSubkey {
    <#
        .SYNOPSIS
            Retrieves capability from registry for specified key and subkey. Considers that subkey has semver format
    #>
    [CmdletBinding()]
    param(
        # Prefix name of capability
        [Parameter(Mandatory = $true)]
        [string]$PrefixName,
        # Postfix name of capability
        [Parameter(Mandatory = $false)]
        [string]$PostfixName,

        [Parameter(Mandatory = $true)]
        [ValidateSet('CurrentUser', 'LocalMachine')]
        [string]$Hive,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Default', 'Registry32', 'Registry64')]
        [string]$View,
        # Registry key
        [Parameter(Mandatory = $true)]
        [string]$KeyName,

        [Parameter(Mandatory = $true)]
        [string]$ValueName,
        
        # Registry subkey
        [Parameter(Mandatory = $true)]
        [string]$Subkey,
        
        # Regkey subdirectory inside particular version
        [Parameter(Mandatory = $false)]
        [string]$VersionSubdirectory,

        # Major version of tool to be added as capability
        [Parameter(Mandatory = $true)]
        [int]$MajorVersion,
        
        # Minimum major version of tool to be added as capability. All versions detected less than this version - will be ignored. 
        # This is helpful for backward compatibility with already existing logic for previous versions
        [Parameter(Mandatory = $false)]
        [int]$MinimumMajorVersion,

        [ref]$Value)
    try {
        Write-Host $MajorVersion $MinimumMajorVersion
        if ($MajorVersion -lt $MinimumMajorVersion) {
            return $false
        }

        $wholeKey = ""
        if ( -not [string]::IsNullOrEmpty($VersionSubdirectory)) {
            $versionDir = Join-Path -Path $KeyName -ChildPath $Subkey
            $wholeKey = Join-Path -Path $versionDir -ChildPath $VersionSubdirectory
        } else {
            $wholeKey = Join-Path -Path $KeyName -ChildPath $Subkey
        }
 
        $capabilityValue = Get-RegistryValue -Hive $Hive -View $View -KeyName $wholeKey -ValueName $ValueName

        if ([string]::IsNullOrEmpty($capabilityValue)) {
            return $false
        }
   
        $capabilityName = $PrefixName + $MajorVersion + $PostfixName

        Write-Capability -Name $capabilityName -Value $capabilityValue
        if ($Value) {
            $Value.Value = $capabilityValue
        }

        return $true
    } catch {
        return $false
    }
}

function Add-CapabilityFromRegistryWithLastVersionAvailable {
    <#
        .SYNOPSIS
            Retrieves capability from registry with last version. Considers that subkeys for specified key name are versions (in semver format like 1.2.3)
            This is useful to detect last version of tools as agent capabilities

        .EXAMPLE
            If KeyName = 'SOFTWARE\JavaSoft\JDK', and this registry key contains subkeys: 14.0.1, 16.0 - it will write the last one as specified capability
    #>
    [CmdletBinding()]
    param(
        # Prefix name of capability
        [Parameter(Mandatory = $true)]
        [string]$PrefixName,
        # Postfix name of capability
        [Parameter(Mandatory = $false)]
        [string]$PostfixName,

        [Parameter(Mandatory = $true)]
        [ValidateSet('CurrentUser', 'LocalMachine')]
        [string]$Hive,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Default', 'Registry32', 'Registry64')]
        [string]$View,
        # Registry key
        [Parameter(Mandatory = $true)]
        [string]$KeyName,

        # Regkey subdirectory inside particular version
        [Parameter(Mandatory = $false)]
        [string]$VersionSubdirectory,

        [Parameter(Mandatory = $true)]
        [string]$ValueName,
        # Minimum major version of tool to be added as capability. All versions detected less than this version - will be ignored. 
        # This is helpful for backward compatibility with already existing logic for previous versions
        [Parameter(Mandatory = $false)]
        [string]$MinimumMajorVersion,

        [ref]$Value)

    try {
        $subkeys = Get-RegistrySubKeyNames -Hive $Hive -View $View -KeyName $KeyName | Sort-Object

        $versionSubkeys = $subkeys | ForEach {[tuple]::Create((Parse-Version -Version $_), $_)} | Where { ![string]::IsNullOrEmpty($_.Item1)}

        $sortedVersionSubkeys = $versionSubkeys | Sort-Object -Property @{Expression = {$_.Item1}; Descending = $False}
        Write-Host $sortedVersionSubkeys[-1].Item1.Major
        $res = Add-CapabilityFromRegistryWithLastVersionAvailableForSubkey -PrefixName $PrefixName -PostfixName $PostfixName -Hive $Hive -View $View -KeyName $KeyName -ValueName $ValueName -Subkey $sortedVersionSubkeys[-1].Item2 -VersionSubdirectory $VersionSubdirectory -MajorVersion $sortedVersionSubkeys[-1].Item1.Major -Value $Value  -MinimumMajorVersion $MinimumMajorVersion

        if (!$res) {
            Write-Host "An error occured while trying to get last available version for capability: " $PrefixName + "<version>" + $PostfixName
            Write-Host $_ 

            $major = (Parse-Version -Version $subkeys[-1]).Major

            $res = Add-CapabilityFromRegistryWithLastVersionAvailableForSubkey -PrefixName $PrefixName -PostfixName $PostfixName -Hive $Hive -View $View -KeyName $KeyName -ValueName $ValueName -Subkey $subkeys[-1] -MajorVersion $major -Value $Value -MinimumMajorVersion $MinimumMajorVersion

            if(!$res) {
                Write-Host "An error occured while trying to set capability for first found subkey: " $subkeys[-1]
                Write-Host $_

                return $false
            }
        }

        return $true
    } catch {
        Write-Host "An error occured while trying to sort subkeys for capability as versions: " $PrefixName + "<version>" + $PostfixName
        Write-Host $_ 

        return $false
    }
}


function Write-Capability {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [string]$Value)

    $escapeMappings = @( # TODO: WHAT ABOUT "="? WHAT ABOUT "%"?
        New-Object psobject -Property @{ Token = ';' ; Replacement = '%3B' }
        New-Object psobject -Property @{ Token = "`r" ; Replacement = '%0D' }
        New-Object psobject -Property @{ Token = "`n" ; Replacement = '%0A' }
    )
    $formattedName = "$Name"
    $formattedValue = "$Value"
    foreach ($mapping in $escapeMappings) {
        $formattedName = $formattedName.Replace($mapping.Token, $mapping.Replacement)
        $formattedValue = $formattedValue.Replace($mapping.Token, $mapping.Replacement)
    }

    Write-Host "##vso[agent.capability name=$formattedName]$formattedValue"
}

# SIG # Begin signature block
# MIIoKgYJKoZIhvcNAQcCoIIoGzCCKBcCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDzNUrisGwK99/6
# TUFr64joWmjYL/zvXBLbCNaHVyUMmqCCDXYwggX0MIID3KADAgECAhMzAAAEhV6Z
# 7A5ZL83XAAAAAASFMA0GCSqGSIb3DQEBCwUAMH4xCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25p
# bmcgUENBIDIwMTEwHhcNMjUwNjE5MTgyMTM3WhcNMjYwNjE3MTgyMTM3WjB0MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMR4wHAYDVQQDExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQDASkh1cpvuUqfbqxele7LCSHEamVNBfFE4uY1FkGsAdUF/vnjpE1dnAD9vMOqy
# 5ZO49ILhP4jiP/P2Pn9ao+5TDtKmcQ+pZdzbG7t43yRXJC3nXvTGQroodPi9USQi
# 9rI+0gwuXRKBII7L+k3kMkKLmFrsWUjzgXVCLYa6ZH7BCALAcJWZTwWPoiT4HpqQ
# hJcYLB7pfetAVCeBEVZD8itKQ6QA5/LQR+9X6dlSj4Vxta4JnpxvgSrkjXCz+tlJ
# 67ABZ551lw23RWU1uyfgCfEFhBfiyPR2WSjskPl9ap6qrf8fNQ1sGYun2p4JdXxe
# UAKf1hVa/3TQXjvPTiRXCnJPAgMBAAGjggFzMIIBbzAfBgNVHSUEGDAWBgorBgEE
# AYI3TAgBBggrBgEFBQcDAzAdBgNVHQ4EFgQUuCZyGiCuLYE0aU7j5TFqY05kko0w
# RQYDVR0RBD4wPKQ6MDgxHjAcBgNVBAsTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEW
# MBQGA1UEBRMNMjMwMDEyKzUwNTM1OTAfBgNVHSMEGDAWgBRIbmTlUAXTgqoXNzci
# tW2oynUClTBUBgNVHR8ETTBLMEmgR6BFhkNodHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20vcGtpb3BzL2NybC9NaWNDb2RTaWdQQ0EyMDExXzIwMTEtMDctMDguY3JsMGEG
# CCsGAQUFBwEBBFUwUzBRBggrBgEFBQcwAoZFaHR0cDovL3d3dy5taWNyb3NvZnQu
# Y29tL3BraW9wcy9jZXJ0cy9NaWNDb2RTaWdQQ0EyMDExXzIwMTEtMDctMDguY3J0
# MAwGA1UdEwEB/wQCMAAwDQYJKoZIhvcNAQELBQADggIBACjmqAp2Ci4sTHZci+qk
# tEAKsFk5HNVGKyWR2rFGXsd7cggZ04H5U4SV0fAL6fOE9dLvt4I7HBHLhpGdE5Uj
# Ly4NxLTG2bDAkeAVmxmd2uKWVGKym1aarDxXfv3GCN4mRX+Pn4c+py3S/6Kkt5eS
# DAIIsrzKw3Kh2SW1hCwXX/k1v4b+NH1Fjl+i/xPJspXCFuZB4aC5FLT5fgbRKqns
# WeAdn8DsrYQhT3QXLt6Nv3/dMzv7G/Cdpbdcoul8FYl+t3dmXM+SIClC3l2ae0wO
# lNrQ42yQEycuPU5OoqLT85jsZ7+4CaScfFINlO7l7Y7r/xauqHbSPQ1r3oIC+e71
# 5s2G3ClZa3y99aYx2lnXYe1srcrIx8NAXTViiypXVn9ZGmEkfNcfDiqGQwkml5z9
# nm3pWiBZ69adaBBbAFEjyJG4y0a76bel/4sDCVvaZzLM3TFbxVO9BQrjZRtbJZbk
# C3XArpLqZSfx53SuYdddxPX8pvcqFuEu8wcUeD05t9xNbJ4TtdAECJlEi0vvBxlm
# M5tzFXy2qZeqPMXHSQYqPgZ9jvScZ6NwznFD0+33kbzyhOSz/WuGbAu4cHZG8gKn
# lQVT4uA2Diex9DMs2WHiokNknYlLoUeWXW1QrJLpqO82TLyKTbBM/oZHAdIc0kzo
# STro9b3+vjn2809D0+SOOCVZMIIHejCCBWKgAwIBAgIKYQ6Q0gAAAAAAAzANBgkq
# hkiG9w0BAQsFADCBiDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24x
# EDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlv
# bjEyMDAGA1UEAxMpTWljcm9zb2Z0IFJvb3QgQ2VydGlmaWNhdGUgQXV0aG9yaXR5
# IDIwMTEwHhcNMTEwNzA4MjA1OTA5WhcNMjYwNzA4MjEwOTA5WjB+MQswCQYDVQQG
# EwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwG
# A1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSgwJgYDVQQDEx9NaWNyb3NvZnQg
# Q29kZSBTaWduaW5nIFBDQSAyMDExMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIIC
# CgKCAgEAq/D6chAcLq3YbqqCEE00uvK2WCGfQhsqa+laUKq4BjgaBEm6f8MMHt03
# a8YS2AvwOMKZBrDIOdUBFDFC04kNeWSHfpRgJGyvnkmc6Whe0t+bU7IKLMOv2akr
# rnoJr9eWWcpgGgXpZnboMlImEi/nqwhQz7NEt13YxC4Ddato88tt8zpcoRb0Rrrg
# OGSsbmQ1eKagYw8t00CT+OPeBw3VXHmlSSnnDb6gE3e+lD3v++MrWhAfTVYoonpy
# 4BI6t0le2O3tQ5GD2Xuye4Yb2T6xjF3oiU+EGvKhL1nkkDstrjNYxbc+/jLTswM9
# sbKvkjh+0p2ALPVOVpEhNSXDOW5kf1O6nA+tGSOEy/S6A4aN91/w0FK/jJSHvMAh
# dCVfGCi2zCcoOCWYOUo2z3yxkq4cI6epZuxhH2rhKEmdX4jiJV3TIUs+UsS1Vz8k
# A/DRelsv1SPjcF0PUUZ3s/gA4bysAoJf28AVs70b1FVL5zmhD+kjSbwYuER8ReTB
# w3J64HLnJN+/RpnF78IcV9uDjexNSTCnq47f7Fufr/zdsGbiwZeBe+3W7UvnSSmn
# Eyimp31ngOaKYnhfsi+E11ecXL93KCjx7W3DKI8sj0A3T8HhhUSJxAlMxdSlQy90
# lfdu+HggWCwTXWCVmj5PM4TasIgX3p5O9JawvEagbJjS4NaIjAsCAwEAAaOCAe0w
# ggHpMBAGCSsGAQQBgjcVAQQDAgEAMB0GA1UdDgQWBBRIbmTlUAXTgqoXNzcitW2o
# ynUClTAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTALBgNVHQ8EBAMCAYYwDwYD
# VR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAWgBRyLToCMZBDuRQFTuHqp8cx0SOJNDBa
# BgNVHR8EUzBRME+gTaBLhklodHRwOi8vY3JsLm1pY3Jvc29mdC5jb20vcGtpL2Ny
# bC9wcm9kdWN0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFfMDNfMjIuY3JsMF4GCCsG
# AQUFBwEBBFIwUDBOBggrBgEFBQcwAoZCaHR0cDovL3d3dy5taWNyb3NvZnQuY29t
# L3BraS9jZXJ0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFfMDNfMjIuY3J0MIGfBgNV
# HSAEgZcwgZQwgZEGCSsGAQQBgjcuAzCBgzA/BggrBgEFBQcCARYzaHR0cDovL3d3
# dy5taWNyb3NvZnQuY29tL3BraW9wcy9kb2NzL3ByaW1hcnljcHMuaHRtMEAGCCsG
# AQUFBwICMDQeMiAdAEwAZQBnAGEAbABfAHAAbwBsAGkAYwB5AF8AcwB0AGEAdABl
# AG0AZQBuAHQALiAdMA0GCSqGSIb3DQEBCwUAA4ICAQBn8oalmOBUeRou09h0ZyKb
# C5YR4WOSmUKWfdJ5DJDBZV8uLD74w3LRbYP+vj/oCso7v0epo/Np22O/IjWll11l
# hJB9i0ZQVdgMknzSGksc8zxCi1LQsP1r4z4HLimb5j0bpdS1HXeUOeLpZMlEPXh6
# I/MTfaaQdION9MsmAkYqwooQu6SpBQyb7Wj6aC6VoCo/KmtYSWMfCWluWpiW5IP0
# wI/zRive/DvQvTXvbiWu5a8n7dDd8w6vmSiXmE0OPQvyCInWH8MyGOLwxS3OW560
# STkKxgrCxq2u5bLZ2xWIUUVYODJxJxp/sfQn+N4sOiBpmLJZiWhub6e3dMNABQam
# ASooPoI/E01mC8CzTfXhj38cbxV9Rad25UAqZaPDXVJihsMdYzaXht/a8/jyFqGa
# J+HNpZfQ7l1jQeNbB5yHPgZ3BtEGsXUfFL5hYbXw3MYbBL7fQccOKO7eZS/sl/ah
# XJbYANahRr1Z85elCUtIEJmAH9AAKcWxm6U/RXceNcbSoqKfenoi+kiVH6v7RyOA
# 9Z74v2u3S5fi63V4GuzqN5l5GEv/1rMjaHXmr/r8i+sLgOppO6/8MO0ETI7f33Vt
# Y5E90Z1WTk+/gFcioXgRMiF670EKsT/7qMykXcGhiJtXcVZOSEXAQsmbdlsKgEhr
# /Xmfwb1tbWrJUnMTDXpQzTGCGgowghoGAgEBMIGVMH4xCzAJBgNVBAYTAlVTMRMw
# EQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNp
# Z25pbmcgUENBIDIwMTECEzMAAASFXpnsDlkvzdcAAAAABIUwDQYJYIZIAWUDBAIB
# BQCgga4wGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEO
# MAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIBsHP5SgCrHA3qhdJnOgYMVL
# FgS5FPbnhIgUJ3qdIcT0MEIGCisGAQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8A
# cwBvAGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEB
# BQAEggEAMs95QKu4ivPynyvF4egfw3k5Gp9Z+JnH3Qtu0atPnCnLfcOopDESHREK
# ABsNTpJa3M3TlimByBhCjAqcJHS0FAlKSxjh8/Wtmdui7/ApzocWpsQkN9G+vDhL
# nByaHKkOPwk6OEr1X9/CmInvgy39XfkONxWNNp8mCj0F13TlekPEdbZ2jyEWq2hj
# JDZDg0h0KUp4IWld7xTbKMKUifms6smQk2MgLspVNt4tpqiSv9HwkPGkLujihaX0
# 5J72qmE/pYatVdxyOUo5KEt9e8m0nSAraqoE2Oj/eGosg80ZLkLHlTRvFJvJQl63
# qSrihnoZOJm8dzGTTLw9lvmSnFjOh6GCF5QwgheQBgorBgEEAYI3AwMBMYIXgDCC
# F3wGCSqGSIb3DQEHAqCCF20wghdpAgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFSBgsq
# hkiG9w0BCRABBKCCAUEEggE9MIIBOQIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFl
# AwQCAQUABCC672bvhi0lcIunqgKqjhsoSIemOlS4gM9BUync2EC7PgIGaPBvcGnB
# GBMyMDI1MTAyODE0NDk0OC45NTJaMASAAgH0oIHRpIHOMIHLMQswCQYDVQQGEwJV
# UzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1l
# cmljYSBPcGVyYXRpb25zMScwJQYDVQQLEx5uU2hpZWxkIFRTUyBFU046ODkwMC0w
# NUUwLUQ5NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2Wg
# ghHqMIIHIDCCBQigAwIBAgITMwAAAg4syyh9lSB1YwABAAACDjANBgkqhkiG9w0B
# AQsFADB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UE
# BxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYD
# VQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDAeFw0yNTAxMzAxOTQz
# MDNaFw0yNjA0MjIxOTQzMDNaMIHLMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2Fz
# aGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENv
# cnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1lcmljYSBPcGVyYXRpb25z
# MScwJQYDVQQLEx5uU2hpZWxkIFRTUyBFU046ODkwMC0wNUUwLUQ5NDcxJTAjBgNV
# BAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2UwggIiMA0GCSqGSIb3DQEB
# AQUAA4ICDwAwggIKAoICAQCs5t7iRtXt0hbeo9ME78ZYjIo3saQuWMBFQ7X4s9vo
# oYRABTOf2poTHatx+EwnBUGB1V2t/E6MwsQNmY5XpM/75aCrZdxAnrV9o4Tu5sBe
# pbbfehsrOWRBIGoJE6PtWod1CrFehm1diz3jY3H8iFrh7nqefniZ1SnbcWPMyNIx
# uGFzpQiDA+E5YS33meMqaXwhdb01Cluymh/3EKvknj4dIpQZEWOPM3jxbRVAYN5J
# 2tOrYkJcdDx0l02V/NYd1qkvUBgPxrKviq5kz7E6AbOifCDSMBgcn/X7RQw630Qk
# zqhp0kDU2qei/ao9IHmuuReXEjnjpgTsr4Ab33ICAKMYxOQe+n5wqEVcE9OTyhmW
# ZJS5AnWUTniok4mgwONBWQ1DLOGFkZwXT334IPCqd4/3/Ld/ItizistyUZYsml/C
# 4ZhdALbvfYwzv31Oxf8NTmV5IGxWdHnk2Hhh4bnzTKosEaDrJvQMiQ+loojM7f5b
# gdyBBnYQBm5+/iJsxw8k227zF2jbNI+Ows8HLeZGt8t6uJ2eVjND1B0YtgsBP0cs
# BlnnI+4+dvLYRt0cAqw6PiYSz5FSZcbpi0xdAH/jd3dzyGArbyLuo69HugfGEEb/
# sM07rcoP1o3cZ8eWMb4+MIB8euOb5DVPDnEcFi4NDukYM91g1Dt/qIek+rtE88VS
# 8QIDAQABo4IBSTCCAUUwHQYDVR0OBBYEFIVxRGlSEZE+1ESK6UGI7YNcEIjbMB8G
# A1UdIwQYMBaAFJ+nFV0AXmJdg/Tl0mWnG1M1GelyMF8GA1UdHwRYMFYwVKBSoFCG
# Tmh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUy
# MFRpbWUtU3RhbXAlMjBQQ0ElMjAyMDEwKDEpLmNybDBsBggrBgEFBQcBAQRgMF4w
# XAYIKwYBBQUHMAKGUGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2Vy
# dHMvTWljcm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUyMDIwMTAoMSkuY3J0MAwG
# A1UdEwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwDgYDVR0PAQH/BAQD
# AgeAMA0GCSqGSIb3DQEBCwUAA4ICAQB14L2TL+L8OXLxnGSal2h30mZ7FsBFooiY
# kUVOY05F9pnwPTVufEDGWEpNNy2OfaUHWIOoQ/9/rjwO0hS2SpB0BzMAk2gyz92N
# GWOpWbpBdMvrrRDpiWZi/uLS4ZGdRn3P2DccYmlkNP+vaRAXvnv+mp27KgI79mJ9
# hGyCQbvtMIjkbYoLqK7sF7Wahn9rLjX1y5QJL4lvEy3QmA9KRBj56cEv/lAvzDq7
# eSiqRq/pCyqyc8uzmQ8SeKWyWu6DjUA9vi84QsmLjqPGCnH4cPyg+t95RpW+73sn
# hew1iCV+wXu2RxMnWg7EsD5eLkJHLszUIPd+XClD+FTvV03GfrDDfk+45flH/eKR
# Zc3MUZtnhLJjPwv3KoKDScW4iV6SbCRycYPkqoWBrHf7SvDA7GrH2UOtz1Wa1k27
# sdZgpG6/c9CqKI8CX5vgaa+A7oYHb4ZBj7S8u8sgxwWK7HgWDRByOH3CiJu4LJ8h
# 3TiRkRArmHRp0lbNf1iAKuL886IKE912v0yq55t8jMxjBU7uoLsrYVIoKkzh+sAk
# gkpGOoZL14+dlxVM91Bavza4kODTUlwzb+SpXsSqVx8nuB6qhUy7pqpgww1q4SNh
# AxFnFxsxiTlaoL75GNxPR605lJ2WXehtEi7/+YfJqvH+vnqcpqCjyQ9hNaVzuOEH
# X4MyuqcjwjCCB3EwggVZoAMCAQICEzMAAAAVxedrngKbSZkAAAAAABUwDQYJKoZI
# hvcNAQELBQAwgYgxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAw
# DgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24x
# MjAwBgNVBAMTKU1pY3Jvc29mdCBSb290IENlcnRpZmljYXRlIEF1dGhvcml0eSAy
# MDEwMB4XDTIxMDkzMDE4MjIyNVoXDTMwMDkzMDE4MzIyNVowfDELMAkGA1UEBhMC
# VVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNV
# BAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRp
# bWUtU3RhbXAgUENBIDIwMTAwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoIC
# AQDk4aZM57RyIQt5osvXJHm9DtWC0/3unAcH0qlsTnXIyjVX9gF/bErg4r25Phdg
# M/9cT8dm95VTcVrifkpa/rg2Z4VGIwy1jRPPdzLAEBjoYH1qUoNEt6aORmsHFPPF
# dvWGUNzBRMhxXFExN6AKOG6N7dcP2CZTfDlhAnrEqv1yaa8dq6z2Nr41JmTamDu6
# GnszrYBbfowQHJ1S/rboYiXcag/PXfT+jlPP1uyFVk3v3byNpOORj7I5LFGc6XBp
# Dco2LXCOMcg1KL3jtIckw+DJj361VI/c+gVVmG1oO5pGve2krnopN6zL64NF50Zu
# yjLVwIYwXE8s4mKyzbnijYjklqwBSru+cakXW2dg3viSkR4dPf0gz3N9QZpGdc3E
# XzTdEonW/aUgfX782Z5F37ZyL9t9X4C626p+Nuw2TPYrbqgSUei/BQOj0XOmTTd0
# lBw0gg/wEPK3Rxjtp+iZfD9M269ewvPV2HM9Q07BMzlMjgK8QmguEOqEUUbi0b1q
# GFphAXPKZ6Je1yh2AuIzGHLXpyDwwvoSCtdjbwzJNmSLW6CmgyFdXzB0kZSU2LlQ
# +QuJYfM2BjUYhEfb3BvR/bLUHMVr9lxSUV0S2yW6r1AFemzFER1y7435UsSFF5PA
# PBXbGjfHCBUYP3irRbb1Hode2o+eFnJpxq57t7c+auIurQIDAQABo4IB3TCCAdkw
# EgYJKwYBBAGCNxUBBAUCAwEAATAjBgkrBgEEAYI3FQIEFgQUKqdS/mTEmr6CkTxG
# NSnPEP8vBO4wHQYDVR0OBBYEFJ+nFV0AXmJdg/Tl0mWnG1M1GelyMFwGA1UdIARV
# MFMwUQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUHAgEWM2h0dHA6Ly93d3cubWlj
# cm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0b3J5Lmh0bTATBgNVHSUEDDAK
# BggrBgEFBQcDCDAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTALBgNVHQ8EBAMC
# AYYwDwYDVR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAWgBTV9lbLj+iiXGJo0T2UkFvX
# zpoYxDBWBgNVHR8ETzBNMEugSaBHhkVodHRwOi8vY3JsLm1pY3Jvc29mdC5jb20v
# cGtpL2NybC9wcm9kdWN0cy9NaWNSb29DZXJBdXRfMjAxMC0wNi0yMy5jcmwwWgYI
# KwYBBQUHAQEETjBMMEoGCCsGAQUFBzAChj5odHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20vcGtpL2NlcnRzL01pY1Jvb0NlckF1dF8yMDEwLTA2LTIzLmNydDANBgkqhkiG
# 9w0BAQsFAAOCAgEAnVV9/Cqt4SwfZwExJFvhnnJL/Klv6lwUtj5OR2R4sQaTlz0x
# M7U518JxNj/aZGx80HU5bbsPMeTCj/ts0aGUGCLu6WZnOlNN3Zi6th542DYunKmC
# VgADsAW+iehp4LoJ7nvfam++Kctu2D9IdQHZGN5tggz1bSNU5HhTdSRXud2f8449
# xvNo32X2pFaq95W2KFUn0CS9QKC/GbYSEhFdPSfgQJY4rPf5KYnDvBewVIVCs/wM
# nosZiefwC2qBwoEZQhlSdYo2wh3DYXMuLGt7bj8sCXgU6ZGyqVvfSaN0DLzskYDS
# PeZKPmY7T7uG+jIa2Zb0j/aRAfbOxnT99kxybxCrdTDFNLB62FD+CljdQDzHVG2d
# Y3RILLFORy3BFARxv2T5JL5zbcqOCb2zAVdJVGTZc9d/HltEAY5aGZFrDZ+kKNxn
# GSgkujhLmm77IVRrakURR6nxt67I6IleT53S0Ex2tVdUCbFpAUR+fKFhbHP+Crvs
# QWY9af3LwUFJfn6Tvsv4O+S3Fb+0zj6lMVGEvL8CwYKiexcdFYmNcP7ntdAoGokL
# jzbaukz5m/8K6TT4JDVnK+ANuOaMmdbhIurwJ0I9JZTmdHRbatGePu1+oDEzfbzL
# 6Xu/OHBE0ZDxyKs6ijoIYn/ZcGNTTY3ugm2lBRDBcQZqELQdVTNYs6FwZvKhggNN
# MIICNQIBATCB+aGB0aSBzjCByzELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hp
# bmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jw
# b3JhdGlvbjElMCMGA1UECxMcTWljcm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEn
# MCUGA1UECxMeblNoaWVsZCBUU1MgRVNOOjg5MDAtMDVFMC1EOTQ3MSUwIwYDVQQD
# ExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNloiMKAQEwBwYFKw4DAhoDFQBK
# 6HY/ZWLnOcMEQsjkDAoB/JZWCKCBgzCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1w
# IFBDQSAyMDEwMA0GCSqGSIb3DQEBCwUAAgUA7Kq+izAiGA8yMDI1MTAyODA0MDEx
# NVoYDzIwMjUxMDI5MDQwMTE1WjB0MDoGCisGAQQBhFkKBAExLDAqMAoCBQDsqr6L
# AgEAMAcCAQACAiEJMAcCAQACAhPkMAoCBQDsrBALAgEAMDYGCisGAQQBhFkKBAIx
# KDAmMAwGCisGAQQBhFkKAwKgCjAIAgEAAgMHoSChCjAIAgEAAgMBhqAwDQYJKoZI
# hvcNAQELBQADggEBADJ4liKqGztM5lUhJzXP+iPivdzuGNCT4kHuQiJ9nLGK08NR
# xf9EiXzGIo8T1WdcNDOXKYkySNLcy48f0CT3nMz85QaZHcwSAmTVO+Ot+ujI1e9L
# qUZ/ixHxa5w/IfwFc/eW/Pi/CZtQdZH53DNtpUhTVeNIIKfaNLRfknyoEDTgB5NW
# CdPS+rk4hv0rhfcjb9L03PpOA6+HsXRlW5JM1K2VGTjQ8ZQhIQ27/7ry89QC9+Y1
# byLhHOjgz05cMJkiOEDdkPrN9l/DToF4hTmIi00SpbT7/keJgvg90wtxPiDczoX9
# ZBL9Hf8ATqSBj4Ujw5jF9ORfnKTmCUCP6Z7cISUxggQNMIIECQIBATCBkzB8MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNy
# b3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAITMwAAAg4syyh9lSB1YwABAAACDjAN
# BglghkgBZQMEAgEFAKCCAUowGgYJKoZIhvcNAQkDMQ0GCyqGSIb3DQEJEAEEMC8G
# CSqGSIb3DQEJBDEiBCDCeqM3gYGE3032gkugBJqP5UupyrgOBCuI3vQcWqTVrjCB
# +gYLKoZIhvcNAQkQAi8xgeowgecwgeQwgb0EIAF0HXMl8OmBkK267mxobKSihwOd
# P0eUNXQMypPzTxKGMIGYMIGApH4wfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldh
# c2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBD
# b3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIw
# MTACEzMAAAIOLMsofZUgdWMAAQAAAg4wIgQg5BYexX8JcdFy29QXrdN7cOyzx49I
# qsSFdtLTnArb5eUwDQYJKoZIhvcNAQELBQAEggIACZeIXS+WXfT3p3+F0qepnL0s
# /vwiXaBJe9x74DjMPu0DIfLReygCesjAq4zhXMQSZPgq7uJs+E+S1PmJKfpSYiaH
# cZrF2/JVlQMGZ/IHFrIOmKIx50pPO1sfPiROWKNNmBQo+lGUvTl7ijdoVl1TC9Xu
# DNhAXMMLE/zfW/13NNfazj/eUaouDaA9pxMBpcCOPL2SPyGQGBO5F3lNU6nHLSpu
# +w+iLPVuR3qKlNfPeLJuPuYdFmodItg0abctQyEDiSNqTbZD0Bp1s43eHpo1ardX
# B9X4Wdm2KiTT+ZlAdGyr1xn4LpbkdaO+SkeUzcJO2KpAHUk6eG376oFxOGwc6vqF
# PZXZvLKbCukXmO2bSpGweqfBn9gDg+X+4sya0H6N503I72ZdcaSEYPZObRcx2EDj
# vxNT9Npa4OnyW4WaokjxSqPpemG5DFeSNbIgTVoyFFSPlegDhIvvAtnceyC6m4TR
# P+DoziZ7Xr+zDR9a16Hfq/8/OutGzZGhhFaGt/yIRHK59LNkl6MKHJRdoaZ/VMow
# mRpuXY+ED8VfscgWRXWTNFLR8MBh5Hm1p4xifmVysC0oK3BC9Sqq9C7TBK6Ix42t
# jf4aKxsmfu+3hOhmw9IGAu+2PujOWvzxFPYORvs8o1NOhMGO43ZFYSwkA7lU1RX1
# h7elBzBppwkXcq5m48E=
# SIG # End signature block
