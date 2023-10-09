Param([parameter(Mandatory=$True)]$parameter)

Function Get-BaClientExist {
    $TSMClientExistVersion = (Get-ItemProperty -Path "HKLM:\SOFTWARE\IBM\ADSM\CurrentVersion\BackupClient" -Name PtfLevel).PtfLevel
    if (test-path "HKLM:\SOFTWARE\IBM\ADSM\CurrentVersion\BackupClient") {
        Write-Output " "
        Write-Output "You have already a $TSM Client Installed version: $TSMClientExistVersion"
        Write-Output "Please uninstall the $TSM Client before continue and"
        Write-Output "delete the key HKLM:\SOFTWARE\IBM\ADSM\CurrentVersion\BackupClient"
        $Global:InstallBaClient = $False
        $Global:UpgradeBaClient = $True
        $Global:ExitErrorMsg = "$TSM $BAC already exist, Upgrade is not supported yet"
        $Global:ExitCode = "ISS9999E"

        }

    else {
        $Global:InstallBaClient = $True
        $Global:UpgradeBaClient = $False
        $Global:ExitCode = "0"
        }

    Write-Output ""
}

Function Set-BaSetup-Default {
    $Global:TcpServerAddress = $TcpServerAddressDefault
    $Global:TcpPort = $TcpPortDefault
    $Global:NodeName = $NodeNameDefault
    Get-NetIPAddress |fl IPAddress
    Write-Output "*****************************************************************"
    Write-Output "***************** Please run following commands *****************"
    Write-Output "*****************       or run the WebUI        *****************"
    Write-Output "*****************************************************************"
    Write-Output " "
    Write-Output "To register the node in IBM Storage Protect Server"
    Write-Output "TSM> Register node $NodeName $NodePassword domain=<DOMAIN NAME>"
    Write-Output " "
    Write-Output "Please assign the node to a Scheduler before continue"
    Write-Output "TSM> define association <DOMAIN NAME> <SCHEDULE NAME> $NodeName "
}

Function Set-BaSetup {
    $Global:TcpServerAddress = Read-Host "Please enter Storage Protect Server Address (Default: $TcpServerAddressDefault)"
    if (!$TcpServerAddress) {
        $Global:TcpServerAddress = $TcpServerAddressDefault
        }
    $Global:TcpPort = Read-Host "Please enter Storage Protect Server Port (Default: $TcpPortDefault)"
    if (!$TcpPort) {
        $Global:TcpPort = $TcpPortDefault
        }
    $Global:NodeName = Read-Host "Please enter your hostname (Default: $NodeNameDefault)"
    if (!$NodeName) {
        $Global:NodeName = $NodeNameDefault
        }
    Get-NetIPAddress |fl IPAddress
    $Global:TcpClientAddress = Read-Host "Please enter your Local IP Address"
    #$Password = Read-Host -assecurestring "Please enter your password"
    Write-Output "*****************************************************************"
    Write-Output "***************** Please run following commands *****************"
    Write-Output "*****************       or run the WebUI        *****************"
    Write-Output "*****************************************************************"
    Write-Output " "
    Write-Output "To register the node in IBM Storage Protect Server"
    Write-Output "TSM> Register node $NodeName $NodePassword domain=<DOMAIN NAME>"
    pause
    Write-Output " "
    Write-Output "Please assign the node to a Scheduler before continue"
    Write-Output "TSM> define association <DOMAIN NAME> <SCHEDULE NAME> $NodeName "
    pause
}

Function Upgrade-Baclient {
       #You find Services here
       #HKLM:\SOFTWARE\IBM\ADSM\CurrentVersion\BackupClient\Scheduler Service\

        $DataStamp = Get-Date -Format yyyyMMDDTHHmmss
        $TSMShortName = "tsm-ba-client"
        $logFile = '{0}-{1}.log' -f $TSMShortName,$DataStamp
        $MSIArguments = @(
            '/i'
            ('"{0}"' -f $BaInstallFile)
            'RebootYesNo="No"'
            'REBOOT="Suppress"'
            "/qn"
            "/l*v"
            $logFile
        )
        Set-Location .\TSMClient
        Start-Process -FilePath "msiexec.exe" -ArgumentList "$MSIArguments" -Wait
        Set-Location ..

}

Function Get-BaInstallPath {
    if (-not (test-path -path "$BaInstPath\$BaInstFile")) {
        Write-Output " "
        Write-Output "Future release will we automatic download the installation client for you..."

        $Global:BaInstFiles = $False
        #$Global:Download = $BaClientDownloadUrl
        $Global:ExitErrorMsg = "Can't find the installations files for $TSM $BAC in $BaInstPath"
        $Global:ExitCode = "ISS9999E"
        Exit-Error
    }

    else {
        if (-not (test-path -path "$DsmPath\$BaDsmFile")) {
            $Global:ExitCode = "ISS0004E"
            $Global:ExitErrorMsg = "Does not found default $BaDsmFile file under directory $DsmPath"
            Exit-Error
        }
    }
    Write-Output ""
    Write-Output ""
}

Function Install-BaClient {
    Write-Output "Installing Microsoft Windows 64-Bit C++ Runtime and IBM Java"
    Write-Output "Please Wait ..."
    Write-Output ""
    
    Get-ChildItem ".\TSMClient\ISSetupPrerequisites" -Filter *.exe -Recurse | Foreach-Object {
    $filename = $_.FullName
    if ( $filename -match "dist" ) {
        Write-Output "Installing Microsoft Windows 64-Bits C++ Runtime"
        $Arguments = "/install /quiet /norestart /log vcredist.log"
        Start-Process $filename -ArgumentList $Arguments -Wait
        
    } else {
        Write-Output "Installing IBM Java 8 Runtime"
        $Arguments = @(
            '/s'
            '/v"RebootYesNo="No" Reboot="ReallySuppress" ALLUSERS=1 /qb /l*v "jre_log.txt""'
        )
        Start-Process $filename -ArgumentList $Arguments -Wait
    }
}

    Write-Output "Installing $TSM $BAC"
    Write-Output "Please Wait ..."
    Write-Output ""
    $DataStamp = Get-Date -Format yyyyMMDDTHHmmss
    $TSMShortName = "tsm-ba-client"
    $logFile = '{0}-{1}.log' -f $TSMShortName,$DataStamp
    $MSIArguments = @(
        '/i'
        ('"{0}"' -f $BaInstallFile)
        'RebootYesNo="No"'
        'REBOOT="Suppress"'
        "ALLUSERS=1"
        'ADDLOCAL="BackupArchiveGUI,BackupArchiveWeb,Api64Runtime"'
        "TRANSFORMS=1033.mst"
        "/qb"
        "/l*v"
        $logFile
    )
    Set-Location $BaInstPath
    Start-Process -FilePath "msiexec.exe" -ArgumentList "$MSIArguments" -Wait
    Set-Location ..
    }

Function Register-Node {
    Write-Output " "
    Write-Output " "
    # This will be fix in a letar version with direct access to the Rest Interface.
}

Function Config-BaClient {
    $BaClientInstallPath = (Get-ItemProperty -Path "HKLM:\SOFTWARE\IBM\ADSM\CurrentVersion" -Name TSMClientPath).TSMClientPath
    $baclientdir = "$BaClientInstallPath" + "baclient"
    $dsmopt = "$BaClientInstallPath" + "baclient\dsm.opt"
    $errorlogname = "$BaClientInstallPath" + "baclient\dsmerror.log"
    $schedlogname = "$BaClientInstallPath" + "baclient\dsmsched.log"

    Copy-Item $DsmPath\$BaDsmFile "$dsmopt"
    (Get-Content "$dsmopt").replace('NODENAME', "$NodeName") | Set-Content "$dsmopt"
    (Get-Content "$dsmopt").replace('TCPPORTNO', "$TcpPort") | Set-Content "$dsmopt"
    (Get-Content "$dsmopt").replace('SERVERADDRESS', "$TcpServerAddress") | Set-Content "$dsmopt"
    (Get-Content "$dsmopt").replace('LOCALIPADDRESS', "$TcpClientAddress") | Set-Content "$dsmopt"
    (Get-Content "$dsmopt").replace('PATHTOERRORLOG', "$errorlogname") | Set-Content "$dsmopt"
    (Get-Content "$dsmopt").replace('PATHTOSCHEDLOG', "$schedlogname") | Set-Content "$dsmopt"

    Set-Location $baclientdir

    $Argument1 = @(
        "install",
        "Scheduler",
        "/name:""$BaSched""",
        "/optfile:""$dsmopt""",
        "/node:$NodeName",
        "/password:$NodePassword",
        "/autostart:no"
        "/startnow:no"
    )

    $Argument2 = @(
        "install",
        "CAD",
        "/name:""$BaCad""",
        "/optfile:""$dsmopt""",
        "/node:$NodeName",
        "/password:$NodePassword",
        "/validate:yes",
        "/autostart:yes",
        "/startnow:no",
        "/CadSchedName:""$BaSched"""
        )
    $Argument3 = @(
        "install",
        "remoteagent"
        "/name:""$BaRemote""",
        "/optfile:""$dsmopt""",
        "/node:$NodeName",
        "/password:$NodePassword",
        "/validate:yes",
        "/startnow:no",
        "/partnername:""$BaCad"""
        )
    
    Write-Output "Creating $BaSched Service"
    Start-Process -FilePath "dsmcutil.exe" -ArgumentList "$Argument1" -Wait

    Write-Output "Creating $BaCad Service"
    Start-Process -FilePath "dsmcutil.exe" -ArgumentList "$Argument2" -Wait

    Write-Output "Creating $BaRemote Service"
    Start-Process -FilePath "dsmcutil.exe" -ArgumentList "$Argument3" -Wait
}

Function Test-BaClient {
    $BaClientInstallPath = (Get-ItemProperty -Path "HKLM:\SOFTWARE\IBM\ADSM\CurrentVersion" -Name TSMClientPath).TSMClientPath
    $baclientdir = "$BaClientInstallPath" + "baclient"
    Set-Location "$BaClientdir"
    $newNodePassword = Get-NodePassword

    $Argument = @(
            "set",
            "password",
            "$NodeName",
            "$NodePassword",
            "$newNodePassword"
            )
    Start-Process -FilePath "dsmc.exe" -ArgumentList "$Argument" -Wait
}


########################################## GENERIC FUNCTIONS ##########################################
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
    Set-Location $PSCommandPath
    pause
    exit $ExitCode
}

if ($parameter -eq "Check") {
    Get-BaClientExist
    Get-BaInstallPath
    }

if ($parameter -eq "Install") {
    Set-BaSetup
    Install-BaClient
    Register-Node
    Config-BaClient
    Test-BaClient
    }

if ($parameter -eq "auto") {
    Set-BaSetup-default
    Install-BaClient
    Register-Node
    Config-BaClient
    Test-BaClient
}

if (!$parameter) {
    Write-Output "Invalid Command."
    Write-Output "Please run ""Get-Help .\install.ps1"" to get more information" }