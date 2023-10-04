<#
    .Synopsis
       Easy Deployment tool for IBM Storage Software.
    .DESCRIPTION
       This script will help you to easy deploy IBM Storage Protect Backup-Archive Clients
       
    .CONFIGURATION
       For configure the default values go though the settings.json file with a standard text editor such Notepad.
       Change each value that fits you such following lines where you can change tsm.corp.com to your IBM Storage Protect Server Address.
        "TSMServerSettings" : [
         {
            "tcpServerAddress" : "tsm.corp.com",
            "tcpPort" : "1500",
            "sslEncryption" : "No",
            "sslPort" : "1543"
         },

       For Nodename section you can change if you want to use Default hostname or if you want to add a suffix to your nodename,
       Do you want to generate a password or sett it on your own

       "NodeSettings" : [
        {
            "useOnlyHostname" : "No",
            "nodeExtension" : "-DOMAIN",
            "extensionBeforeAfter" : "After",
            "generatePassword" : "Yes",
            "staticPassword" : "Passw0rdCl3rT3xt"
        },
        
    .EXAMPLE
       ispinstall.ps1 auto

       Will try automatic to find out if any client is installed and can be upgraded, or do a fresh install and
       automatic configure Backup-Archive Client.

    .EXAMPLE
       ispinstall.ps1 ba-install

       Will only install the IBM Storage Protect Backup-Archive Client for you.

    .EXAMPLE
       ispinstall.ps1 ba-config

       Will only Configure IBM Storage Protect Backup-Archive Client

    .NOTES
       Written by Christian Petersson
       I take no responsibility for any issues caused by this script.

    .FUNCTIONALITY
       Automatic Install IBM Storage Protect Client
    .LINK
       https://isstech.io

#>
Param([parameter()]$parameter)

$FullPathIncFileName = $MyInvocation.MyCommand.Definition
$CurrentScriptName = $MyInvocation.MyCommand.Name
$CurrentExecutingPath = $fullPathIncFileName.Replace($currentScriptName, "")

Function Get-InstallConfig {
    # This is only Standard Global Variables that the script is calling

    Write-Output ""
    Write-Output ""

    ####### IBM Storage Protect Server Settings #######
    ####### Installations Files #######
    $Global:BaInstPath = ".\TSMClient"
    $Global:BaInstallFile = "IBM Spectrum Protect Client.msi"

    ###### Get Service Names from JSON ######
    $ServiceName = (Get-JsonConfig ClientServices)
    $Global:BaCad = $ServiceName[0].baCadService
    $Global:BaSched = $ServiceName[0].baSchedService
    $Global:BaRemote = $ServiceName[0].baRemoteService
    
    ###### Get Configuration Files from JSON ######
    $ConfigData = (Get-JsonConfig ConfigurationFiles)
    $Global:DsmPath = $ConfigData.optFilePath
    $Global:BaDsmFile = $ConfigData.baDsmOpt
    
    ####### Product Names #######
    $ProductNames = (Get-JsonConfig ProductNames)
    $Global:ISP = $ProductNames.TSM
    $Global:BAC = $ProductNames.BAC
}

Function Get-OSInformation {
    $Global:osversion = (Get-WmiObject -class Win32_OperatingSystem).Caption
    $Global:true64bit = (Get-WmiObject Win32_OperatingSystem).OSArchitecture
    $Global:LocalHostName = (Get-WmiObject Win32_OperatingSystem).CSName

    if (-not ($osversion)) {
        $Global:ExitErrorMsg = "Can't find the Operating System Version"
        $Global:ExitCode = "ISS0003E"
        Exit-Error
        }

    if (-not ($true64bit -eq "64-Bit")) {
        $Global:ExitErrorMsg = "This script is not supporting 32-Bits Operating Systems"
        $Global:ExitCode = "ISS0002E"
        Exit-Error
        }

    if (-not ($LocalHostName)) {
        $Global:ExitErrorMsg = "Can't find the hostname of this client"
        $Global:ExitCode = "ISS0001E"
        Exit-Error
        }

}

Function Set-TSMSettings {
    $TSMSettings = (Get-JsonConfig TSMServerSettings)
    $Global:TcpServerAddressDefault = ($TSMSettings.tcpServerAddress)
    $Global:TcpPortDefault = ($TSMSettings.tcpPort)
}

Function Set-NodeSettings {
    $NodeSettings = (Get-JsonConfig NodeSettings)
    if ($NodeSettings.useOnlyHostName -eq "Yes") {
        $Global:NodeNameDefault = (Get-WmiObject Win32_OperatingSystem).CSName
    }
    else {
        $NodeExtension = ($NodeSettings.nodeExtension)
        if ($NodeSettings.extensionBeforeAfter -eq "Before") {
            $HostName = (Get-WmiObject Win32_OperatingSystem).CSName
            $TempNodeName = (Write-Output $NodeExtension | Foreach{ $_ + $HostName })
            $Global:NodeNameDefault = $TempNodeName
        }
        elseif ($NodeSettings.extensionBeforeAfter -eq "After") {
            $HostName = (Get-WmiObject Win32_OperatingSystem).CSName
            $TempNodeName = (Write-Output $HostName | Foreach{ $_ + $NodeExtension })
            $Global:NodeNameDefault = $TempNodeName
        }
        else {
            $Global:NodeNameDefault = $NodeSettings.StaticNodeName
            Write-Host $NodeNameDefault
        }
    }

    if ($NodeSettings.generatePassword -eq "Yes") {
        $alphabet=$NULL;For ($a=65;$a -le 90;$a++) {$alphabet+=,[char][byte]$a }
        $Global:NodePassword = (Get-NodePassword -length 24 -sourcedata $alphabet)
    }
    else {
        $Global:NodePassword = ($NodeSettings.staticPassword)
    }
}

## This is Generation functions that covers all components
Function Show-Status  {
    Write-Output "Hostname: $LocalHostName"
    Write-Output "Operating System: $osversion"
    Write-Output "Bit Version: $true64bit"
    Write-Output " "
    Write-Output "TSM Address: $TcpServerAddressDefault"
    Write-Output "TSM Port: $TcpPortDefault"
    Write-Output "TSM Nodename: $NodeNameDefault"
    # Write-Output "TSM Password: $NodePassword"
    Write-Output " "
    #Write-Output "Installing:  "
    #Write-Output " "
    Write-Output "Backup-Archive Client Services:"
    Write-Output "$BaCad $BaSched $BaRemote"
    Write-Output " "
    }

Function CleanUp-Install  {
    Remove-Variable LocalHostName -EA 0
    Remove-Variable osversion -EA 0
    Remove-Variable true64bit -EA 0
    Remove-Variable TcpServerAddress -EA 0
    Remove-Variable TcpPort -EA 0
    Remove-Variable NodeNameDefault -EA 0
    Remove-Variable NodePassword -EA 0
    Remove-Variable BaCad -EA 0
    Remove-Variable BaSched -EA 0
    Remove-Variable BaRemote -EA 0
    Remove-Variable DsmPath -EA 0
    Remove-Variable BaDsmFile -EA 0
    Remove-Variable TSM -EA 0
    Remove-Variable BAC -EA 0
    }

Function Get-NodePassword() {
    Param(
        [int]$length=10,
        [string[]]$sourcedata
        )

    For ($loop=1; $loop -le $length; $loop++) {
        $TempPassword+=($sourcedata | GET-RANDOM)
        }

    return $TempPassword
}

function Exit-Error {
    Write-Output " "
    Write-Output " "
    Write-Output "*******************************************************************************"
    Write-Output "************************************ ERROR ************************************"
    Write-Output "*******************************************************************************"
    Write-Output " "
    Write-Output "$ExitCode - $ExitErrorMsg"
    Write-Output " "
    Write-Output "*******************************************************************************"
    Write-Output "************************************ ERROR ************************************"
    Write-Output "*******************************************************************************"
    Set-Location $CurrentExecutingPath
    pause
    exit $ExitCode
}

Function Get-JsonConfig() {
    param([parameter()]$jsonvalue)

    $f = (Get-Content -Raw -Path settings.json | ConvertFrom-Json)
    $json = $f.$jsonvalue
    Return $json
    }

function Get-Help {
    $ScriptVersion = (Get-JsonConfig Version)
    Write-Output "*******************************************************************************"
    Write-Output "********************************** HELP MENU **********************************"
    Write-Output "*******************************************************************************"
    Write-Output "Version: $ScriptVersion "
    Write-Output "Usage: $CurrentScriptName Auto (Default)"
    Write-Output "       $CurrentScriptName Check"
    Write-Output "       $CurrentScriptName BA-Install"
    Write-Output "       $CurrentScriptName BA-Config"
    Write-Output "       $CurrentScriptName BA-Upgrade"
    Write-Output "       $CurrentScriptName help (This help)"
    Write-Output " "
    Write-Output "For more help please use Get-Help $CurrentScriptName"
    Write-Output " "
    Write-Output "Thanks for using this script..."
    Write-Output "https://isstech.io"
    Write-Output " "

    Set-Location $CurrentExecutingPath
    pause
    exit $ExitCode
}

function Test-NewFunction {
   # Here are we testing new functions
 
}   

## This is the main part where the program starts
if ($parameter -eq "help") { Get-Help }

Write-Output "*******************************************************************************"
Write-Output "*******************     Welcome To IBM Storage Protect      *******************"
Write-Output "*******************           Installation Script           *******************"
Write-Output "*******************    OpenSource Project by IssTech AB     *******************"
Write-Output "*******************************************************************************"
Get-InstallConfig
Get-OSInformation
Set-TSMSettings
Set-NodeSettings
# Test-NewFunction

if (!$parameter) {
    $parameter = "Check"
 }

elseif ($parameter -eq "Check") {
    & .\baclient.ps1 Check
    Show-Status
    }

elseif ($parameter -eq "auto") {
    & .\baclient.ps1 auto
    }

elseif ($parameter -eq "ba-install") {
    & .\baclient.ps1 install
    }

elseif ($parameter -eq "ba-config") {
    & .\baclient.ps1 config
    }

elseif ($parameter -eq "ba-upgrade") {
    & .\baclient.ps1 upgrade
    }
 
else {
    Get-Help
}
CleanUp-Install