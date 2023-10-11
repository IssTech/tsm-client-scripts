# TSM Client Scripts
Here can you find a collection of useful scripts for IBM Storage Protect Clients. 

## Windows
At the moment do we only have a silent installation script build on Powershell where you can do both Manual / Automatic installation of a Backup-Archive Client and create TSM Client Acceptor, TSM Scheduler and TSM Remote Agent services. 

To be able to install IBM Storage Protect Backup-Archive Client on a Windows Server using Powershell you need to run this script as **Administrator**

You can run the installation script in multiple modes and to get all availible modes availible in your version please run `.\install.ps1 help`
- Check
- ba-install
- ba-config (Is not verified)
- ba-upgrade (Is not working)
- Auto 

To be able to run the installation you need manually download the Backup-Archive Client from the (IBM Website)[https://www3.software.ibm.com/storage/tivoli-storage-management/maintenance/client/v8r1/Windows/x64/]

### Automatic Installation
To be able to run automatic installation without any manualy input, you need to modify `settings.json` and `config/ba_dsm.opt`


#### settings.json
The settings file is a JSON file and the main part you should focus on is `tcpServerAddress` to make sure it is pointing to the correct IBM Storage Protect Server and `tcpPort` that is your backup TCP/IP port. (Default is 1500)
The other part you should configure is the `NodeSettings`, as default are we using the Windows Hostname as nodename and the password is in clear text in this JSON File. But as default is the powershell script automatically changing password to a random 20 characters long new password.
If you has been assigned a new Nodename that doesn't match the hostname, you can either set the `extensionBeforeAfter` parameter to `Static` to set a totally new nodename.

```
{
    "Version" : "0.1",
    "InProduction" : "NO",
    "Timestamp" : "2023/10/03",
    "TSMServerSettings" : [
        {
            "tcpServerAddress" : "tsm.corp.com",
            "tcpPort" : "1500",
            "sslEncryption" : "No",
            "sslPort" : "1543"
        },
        {
            "ocAddress" : "oc.corp.com",
            "ocHttpsPort" :  "11090"
        }
    ],
    "NodeSettings" : [
        {
            "useOnlyHostname" : "Yes",
            "nodeExtension" : "DOMAIN-",
            "extensionBeforeAfter" : "Before",
            "StaticNodeName": "StaticNodename",
            "generatePassword" : "No",
            "staticPassword" : "Passw0rdCl3rT3xt"
        }
    ],
    "ClientServices" : [
        {
            "baCadService" : "TSM Client Acceptor",
            "baSchedService" : "TSM Client Scheduler",
            "baRemoteService" : "TSM Remote Client Agent"
        }
    ],
    "ConfigurationFiles" : [
        {
            "optFilePath" : "Config",
            "baDsmOpt" : "ba_dsm.opt",
            "exchDsmOpt" : "exch_dsm.opt",
            "sqlDsmOpt" : "sql_dsm.opt"
        }
    ],
    "BaClientDownload" : [
        {
            "fileName" : "8.1.20.0-TIV-TSMBAC-WinX64.exe",
            "description" : "IBM Storage Protect Backup-Archive Client for Windows",
            "version" : "8.1.20.0",
            "minimumOSLevel" : "Windows Server 2019",
            "fileURL" : "https://www3.software.ibm.com/storage/tivoli-storage-management/maintenance/client/v8r1/Windows/x64/v8120/8.1.20.0-TIV-TSMBAC-WinX64.exe"
        }
    ],
    "ProductNames" : [
        {
            "TSM": "IBM Storage Protect",
            "BAC": "Backup-Archive Client"
        }
    ]
}
```

#### ba_dsm.opt
We are not really changing anything in the `dsm.opt` file accept following parameters 
- NODENAME
- SERVERADDRESS
- TCPPORTNO
- PATHTOERRORLOG
- PATHTOSCHEDLOG

Any other parameters will not be changed, or if you add anything this will not be modified by the powershell script.
```
NodeName         NODENAME
Passwordaccess	generate

CommMethod       TCPIP
TCPServerAddress SERVERADDRESS
TCPPort          TCPPORTNO
* TCPClientAddress LOCALIPADDRESS
* TCPCADAddress	LOCALIPADDRESS
HTTPPort	1581
SSL Yes

Managedservices Webclient Schedule

ErrorLogRetention 14 D
Errorlogname	"PATHTOERRORLOG"
SchedLogRetention 14 D
Schedlogname	"PATHTOSCHEDLOG"

Domain All-Local
```

## Linux
The bash script installation is depending on the `jq` command to be able to run.
