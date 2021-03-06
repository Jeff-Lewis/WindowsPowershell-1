function Use-BotSchematic
{
    <#
    .Synopsis
        Installs a bot onto the system
    .Description
        Installs bots related to a module onto a system.



        The bot schematic's parameters are a table of command names and parameters (similar to the WebCommand section).


        Each key is the name of the command.  
        The value can be a timespan describing the frequency the command will be run

            
            'Sync-Somthing' = '00:10:00'
        
        It can also be a table of parameters to be directly provided to Start-At, such as:          

            'Start-CloudCommand' = @{
                UserTableName = 'MyUsers'
                TableName = 'MyUsers'
                Filter = "Pending eq 'True'"            
                CheckEvery = "00:01:00"
                ClearProperty = 'Pending'
            }

        Bots may also include one special value:  As, which can include a pair of SecureSetting names


            As = MyUserNameSetting, MyPasswordSetting


        If no securesetting are found matching the value in As, a setting pair will be created an a credential will be requested.  
                
    #>
    param(
    # Any parameters for the schematic
    [Parameter(Mandatory=$true,ParameterSetName='ProcessSchematic')]
    [Hashtable]$Parameter,
    
    # The pipeworks manifest, which is used to validate common parameters
    [Parameter(Mandatory=$true,ParameterSetName='ProcessSchematic')]
    [Hashtable]$Manifest,
    
    # The directory the schemtic is being deployed to
    [Parameter(Mandatory=$true,ParameterSetName='ProcessSchematic')]
    [string]$DeploymentDirectory,
    
    # The directory the schematic is being deployed from
    [Parameter(Mandatory=$true,ParameterSetName='ProcessSchematic')]
    [string]$InputDirectory,
    
    # If provided, will output the schematic parameters, including optional parameters
    [Parameter(Mandatory=$true,ParameterSetName='GetSchematicParameters')]
    [string]$GetSchematicParameter,
    
    # If set, will output the schematic's optional parameters
    [Parameter(Mandatory=$true,ParameterSetName='GetSchematicParameters')]
    [Switch]$IncludeOptional,


    # If set, will output the schematic's optional parameters
    [Parameter(Mandatory=$true,ParameterSetName='GetSchematicHelp')]    
    [Switch]$Help
    )


    begin {        
        $requiredSchematicParameters = @{
        }
         
        $optionalSchematicParameters = @{
            "BackgroundColor" = "The background color of the page"
        }
                
    }

    process {                             
        # 
        if ($psCmdlet.ParameterSetName -eq 'GetSchematicParameters') {                                    
            if ($IncludeOptional) {
                $requiredSchematicParameters  + $optionalSchematicParameters
            } else {
                $requiredSchematicParameters  
            }            
        }
        
        if ($psCmdlet.ParameterSetName -eq 'GetAllSchematicParameters') {
            return $requiredSchematicParameters                        

        }
        
        if ($psCmdlet.ParameterSetName -eq 'GetSchematicHelp') {
            $helpObj = $myInvocation.MyCommand | Get-Help           

            if ($helpObj -isnot [string]) {
                $helpObj.description[0].text 
            } 

        } 
        

        
        
        $ParameterMinusAs = @{} + $Parameter        

        $asUserSetting = ""
        $asPasswordSetting = ""
        $asProvided = $false
        if ($Parameter.As -and $Parameter.As.Count -eq 2) {
            $asProvided  = $true
            $asUserSetting, $asPasswordSetting = $Parameter.AS


            
        } else {
            

        }

        $null = $ParameterMinusAs.Remove("As")
        $asCred = $null
        foreach ($kv in $parameterMinusAs.GetEnumerator()) {
            if (-not $asProvided) {
                $asUserSetting = $kv.Key + "_Username"
                $asPasswordSetting = $kv.Key + "_Password"
            }

            $asUser = "" # Get-secureSetting $asUserSetting -ValueOnly -Type String
            $asPassword = "" #Get-secureSetting $asPasswordSetting -ValueOnly -Type String
                

            if ($asUser -and $asPassword) {
                $asCred = New-Object Management.Automation.PSCredential $asUser, (
                    ConvertTo-SecureString -AsPlainText -Force
                )
            } else {
                if (-not $asCred) {
                    $asCred = Get-Credential -Message "Bot RunAs Credentials"
                }
                
            }

            if (-not $asCred) {
                continue
            }

            if ((-not $asUser) -or (-not $asPassword)) {
#                Add-SecureSetting -Name $asUserSetting -String $asCred.UserName
#                Add-SecureSetting -Name $asPasswordSetting -String $asCred.GetNetworkCredential().Password
            }

            $startAtParams = @{}
            $startAtScript = ""

            if ($realModule) {
                $moduleList = @($realModule.RequiredModules | Select-Object -ExpandProperty Name)  + $realModule.Name
                $startAtScript += "Import-Module $($ModuleList -join ',')"
            }
            $startAtScript += "
$($kv.Key)"

            $startAtParams.ScriptBlock  = [ScriptBlock]::Create($startAtScript)
            if ($kv.Value -is [Hashtable]) {
                $startAtParams += $kv.Value
                $startAtParams["As"] = $asCred
                if (-not $startAtParams.Name) {
                    $startAtParams.Name = $kv.Key
                }

                if (-not $startAtParams.Folder) {
                    if ($realModule) {
                        $startAtParams.Folder = $realModule.Name
                    } else {
                        $startAtParams.Folder = "Bots"
                    }
                }
                Start-At @startAtParams

            } elseif ($kv.Value -as [Timespan]) {
                
                $startAtParams["As"] = $asCred
                if ($realModule) {
                    $startAtParams.Folder = $realModule.Name
                } else {
                    $startAtParams.Folder = "Bots"
                }    


                $frequency = $kv.Value -as [Timespan]
                
                $startAtParams.Name = $kv.Key + "_Now"
                Start-At @startAtParams -RepeatEvery $frequency -Now
            
                $startAtParams.Name = $kv.Key + "_Boot"
                Start-At @startAtParams -RepeatEvery $frequency -Boot 
            }


        }        
    }

} 

# SIG # Begin signature block
# MIINGAYJKoZIhvcNAQcCoIINCTCCDQUCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUzLZAS91qTby8gf5MDv+rYcv0
# B16gggpaMIIFIjCCBAqgAwIBAgIQAupQIxjzGlMFoE+9rHncOTANBgkqhkiG9w0B
# AQsFADByMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYD
# VQQLExB3d3cuZGlnaWNlcnQuY29tMTEwLwYDVQQDEyhEaWdpQ2VydCBTSEEyIEFz
# c3VyZWQgSUQgQ29kZSBTaWduaW5nIENBMB4XDTE0MDcxNzAwMDAwMFoXDTE1MDcy
# MjEyMDAwMFowaTELMAkGA1UEBhMCQ0ExCzAJBgNVBAgTAk9OMREwDwYDVQQHEwhI
# YW1pbHRvbjEcMBoGA1UEChMTRGF2aWQgV2F5bmUgSm9obnNvbjEcMBoGA1UEAxMT
# RGF2aWQgV2F5bmUgSm9obnNvbjCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoC
# ggEBAM3+T+61MoGxUHnoK0b2GgO17e0sW8ugwAH966Z1JIzQvXFa707SZvTJgmra
# ZsCn9fU+i9KhC0nUpA4hAv/b1MCeqGq1O0f3ffiwsxhTG3Z4J8mEl5eSdcRgeb+1
# jaKI3oHkbX+zxqOLSaRSQPn3XygMAfrcD/QI4vsx8o2lTUsPJEy2c0z57e1VzWlq
# KHqo18lVxDq/YF+fKCAJL57zjXSBPPmb/sNj8VgoxXS6EUAC5c3tb+CJfNP2U9vV
# oy5YeUP9bNwq2aXkW0+xZIipbJonZwN+bIsbgCC5eb2aqapBgJrgds8cw8WKiZvy
# Zx2qT7hy9HT+LUOI0l0K0w31dF8CAwEAAaOCAbswggG3MB8GA1UdIwQYMBaAFFrE
# uXsqCqOl6nEDwGD5LfZldQ5YMB0GA1UdDgQWBBTnMIKoGnZIswBx8nuJckJGsFDU
# lDAOBgNVHQ8BAf8EBAMCB4AwEwYDVR0lBAwwCgYIKwYBBQUHAwMwdwYDVR0fBHAw
# bjA1oDOgMYYvaHR0cDovL2NybDMuZGlnaWNlcnQuY29tL3NoYTItYXNzdXJlZC1j
# cy1nMS5jcmwwNaAzoDGGL2h0dHA6Ly9jcmw0LmRpZ2ljZXJ0LmNvbS9zaGEyLWFz
# c3VyZWQtY3MtZzEuY3JsMEIGA1UdIAQ7MDkwNwYJYIZIAYb9bAMBMCowKAYIKwYB
# BQUHAgEWHGh0dHBzOi8vd3d3LmRpZ2ljZXJ0LmNvbS9DUFMwgYQGCCsGAQUFBwEB
# BHgwdjAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tME4GCCsG
# AQUFBzAChkJodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRTSEEy
# QXNzdXJlZElEQ29kZVNpZ25pbmdDQS5jcnQwDAYDVR0TAQH/BAIwADANBgkqhkiG
# 9w0BAQsFAAOCAQEAVlkBmOEKRw2O66aloy9tNoQNIWz3AduGBfnf9gvyRFvSuKm0
# Zq3A6lRej8FPxC5Kbwswxtl2L/pjyrlYzUs+XuYe9Ua9YMIdhbyjUol4Z46jhOrO
# TDl18txaoNpGE9JXo8SLZHibwz97H3+paRm16aygM5R3uQ0xSQ1NFqDJ53YRvOqT
# 60/tF9E8zNx4hOH1lw1CDPu0K3nL2PusLUVzCpwNunQzGoZfVtlnV2x4EgXyZ9G1
# x4odcYZwKpkWPKA4bWAG+Img5+dgGEOqoUHh4jm2IKijm1jz7BRcJUMAwa2Qcbc2
# ttQbSj/7xZXL470VG3WjLWNWkRaRQAkzOajhpTCCBTAwggQYoAMCAQICEAQJGBtf
# 1btmdVNDtW+VUAgwDQYJKoZIhvcNAQELBQAwZTELMAkGA1UEBhMCVVMxFTATBgNV
# BAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTEkMCIG
# A1UEAxMbRGlnaUNlcnQgQXNzdXJlZCBJRCBSb290IENBMB4XDTEzMTAyMjEyMDAw
# MFoXDTI4MTAyMjEyMDAwMFowcjELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lD
# ZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTExMC8GA1UEAxMoRGln
# aUNlcnQgU0hBMiBBc3N1cmVkIElEIENvZGUgU2lnbmluZyBDQTCCASIwDQYJKoZI
# hvcNAQEBBQADggEPADCCAQoCggEBAPjTsxx/DhGvZ3cH0wsxSRnP0PtFmbE620T1
# f+Wondsy13Hqdp0FLreP+pJDwKX5idQ3Gde2qvCchqXYJawOeSg6funRZ9PG+ykn
# x9N7I5TkkSOWkHeC+aGEI2YSVDNQdLEoJrskacLCUvIUZ4qJRdQtoaPpiCwgla4c
# SocI3wz14k1gGL6qxLKucDFmM3E+rHCiq85/6XzLkqHlOzEcz+ryCuRXu0q16XTm
# K/5sy350OTYNkO/ktU6kqepqCquE86xnTrXE94zRICUj6whkPlKWwfIPEvTFjg/B
# ougsUfdzvL2FsWKDc0GCB+Q4i2pzINAPZHM8np+mM6n9Gd8lk9ECAwEAAaOCAc0w
# ggHJMBIGA1UdEwEB/wQIMAYBAf8CAQAwDgYDVR0PAQH/BAQDAgGGMBMGA1UdJQQM
# MAoGCCsGAQUFBwMDMHkGCCsGAQUFBwEBBG0wazAkBggrBgEFBQcwAYYYaHR0cDov
# L29jc3AuZGlnaWNlcnQuY29tMEMGCCsGAQUFBzAChjdodHRwOi8vY2FjZXJ0cy5k
# aWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURSb290Q0EuY3J0MIGBBgNVHR8E
# ejB4MDqgOKA2hjRodHRwOi8vY3JsNC5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1
# cmVkSURSb290Q0EuY3JsMDqgOKA2hjRodHRwOi8vY3JsMy5kaWdpY2VydC5jb20v
# RGlnaUNlcnRBc3N1cmVkSURSb290Q0EuY3JsME8GA1UdIARIMEYwOAYKYIZIAYb9
# bAACBDAqMCgGCCsGAQUFBwIBFhxodHRwczovL3d3dy5kaWdpY2VydC5jb20vQ1BT
# MAoGCGCGSAGG/WwDMB0GA1UdDgQWBBRaxLl7KgqjpepxA8Bg+S32ZXUOWDAfBgNV
# HSMEGDAWgBRF66Kv9JLLgjEtUYunpyGd823IDzANBgkqhkiG9w0BAQsFAAOCAQEA
# PuwNWiSz8yLRFcgsfCUpdqgdXRwtOhrE7zBh134LYP3DPQ/Er4v97yrfIFU3sOH2
# 0ZJ1D1G0bqWOWuJeJIFOEKTuP3GOYw4TS63XX0R58zYUBor3nEZOXP+QsRsHDpEV
# +7qvtVHCjSSuJMbHJyqhKSgaOnEoAjwukaPAJRHinBRHoXpoaK+bp1wgXNlxsQyP
# u6j4xRJon89Ay0BEpRPw5mQMJQhCMrI2iiQC/i9yfhzXSUWW6Fkd6fp0ZGuy62ZD
# 2rOwjNXpDd32ASDOmTFjPQgaGLOBm0/GkxAG/AeB+ova+YJJ92JuoVP6EpQYhS6S
# kepobEQysmah5xikmmRR7zGCAigwggIkAgEBMIGGMHIxCzAJBgNVBAYTAlVTMRUw
# EwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20x
# MTAvBgNVBAMTKERpZ2lDZXJ0IFNIQTIgQXNzdXJlZCBJRCBDb2RlIFNpZ25pbmcg
# Q0ECEALqUCMY8xpTBaBPvax53DkwCQYFKw4DAhoFAKB4MBgGCisGAQQBgjcCAQwx
# CjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGC
# NwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFE3axqAokidZu8gv
# CBpGnE3U+PrfMA0GCSqGSIb3DQEBAQUABIIBAHmcAt3eelkuy2dLifIZA1GR7jrB
# mwpknwpLbnrrvNSzqFLKzitDAUexBhQq4IhRoOWglKojLhL5HoOwHnysODm9QDzh
# ZzPs7oP6b7DFnr7JLYOfRk4CuFOwQHAulQsXBkb7xeED8skX8LeIIZOaP6lS2HTn
# iR8WVP2HXR4ape0x0ak/F19Zpq2P2g25DH8xE6/5wWGd112RPBf+ClinLKBbH9td
# ijZbAIcEbGr9RKlDF7gN1NkVfea9MMwQj3LShAMhPUTGH/RE7IaTT2vgc000LpbC
# Dxzz/W5RxkK5HP2YC4fzluG6UURQ2S1xhPOVCC7xyX4r9Gx+VK/hLuX/UTI=
# SIG # End signature block
