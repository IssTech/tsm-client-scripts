#!/bin/bash

############################################################
# Default Variables                                        #
############################################################

settingsFile='settings.json'



############################################################
# Help                                                     #
############################################################
get_help()
{
   # Display Help
   echo "This is a installation wrapper around $TSM $BAC."
   echo
   echo "Syntax: scriptTemplate [-g|h|v|V]"
   echo "options:"
   echo "h     Print this Help."
   echo "a     Automatic Installation and Configuation using JSON File."
   echo "i     Automatic Installation and manual configuration using defaults from JSON File."
   echo
}

############################################################
############################################################
# Configuration                                            #
############################################################
############################################################

############################################################
# Print Default Configuration from JSON                    #
############################################################
print_configuration()
{
    # Get Default Configuration information from JSON
    if [[ -f $settingsFile ]]; then
        cat $settingsFile | jq -C .  
    else
        echo -e "Cloudn't find $settingsFile file"
    fi
}


############################################################
# Get Default Configuration                                #
############################################################
get_configuration()
{
    # Get Default Configuration information from JSON
    if [[ -f $settingsFile ]]; then

        # Client Installations Directory
        installFilename=($(jq -r '.BaClientDownload[0].filename' $settingsFile))
        downloadDirectory=($(jq -r '.BaClientDownload[0].downloadDirectory' $settingsFile))
        fileURL=($(jq -r '.BaClientDownload[0].fileURL' $settingsFile))

        vendor=($(jq -r '.ProductNames[0].TSM' $settingsFile))
        product=($(jq -r '.ProductNames[0].BAC' $settingsFile))

        # Get all TSM Server Settings
        servernameStanza=($(jq -r '.TSMServerSettings[0].servernameStanza' $settingsFile))
        tcpServerAddress=($(jq -r '.TSMServerSettings[0].tcpServerAddress' $settingsFile))
        tcpPort=($(jq -r '.TSMServerSettings[0].tcpPort' $settingsFile))
        
        # Get all Node Settings
        local useOnlyHostname=($(jq -r '.NodeSettings[0].useOnlyHostname' $settingsFile))
        local extensionBeforeAfterStatic=($(jq -r '.NodeSettings[0].extensionBeforeAfterStatic' $settingsFile))
        if [[ ${useOnlyHostname,,} = "yes" ]]; then
            nodename=($(cat /etc/hostname))
        else
            echo we are here
            if [[ ${extensionBeforeAfterStatic,,} = "before" ]]; then
                local hostname=($(cat /etc/hostname))
                local extension=($(jq -r '.NodeSettings[0].nodeExtension' $settingsFile))
                nodename="$extension$hostname"
            elif [[ ${extensionBeforeAfterStatic,,} = "after" ]]; then
                local hostname=($(cat /etc/hostname))
                local extension=($(jq -r '.NodeSettings[0].nodeExtension' $settingsFile))
                nodename="$hostname$extension"
            else
                nodename=($(jq -r '.NodeSettings[0].staticNodename' $settingsFile))
            fi
        fi

        # Get Password Settings
        local generatePassword=($(jq -r '.NodeSettings[0].generatePassword' $settingsFile))
        local staticPassword=($(jq -r '.NodeSettings[0].staticPassword' $settingsFile))
        if [[ ${generatePassword,,} = 'yes' ]]; then
            newpassword=$(echo $RANDOM | md5sum | head -c 20; echo;)
            oldpassword=$staticPassword
        else 
            newpassword=$staticPassword
            oldpassword=$staticPassword
        fi

    else
        echo -e "Cloudn't find $settingsFile file"
    fi
}

############################################################
# Configure the backup-archive client                      #
############################################################
configuration()
{

    # Get default Configuration
    if [[ ! -n $tcpServerAddress ]]; then
        get_configuration
    fi
    local installDirectory='/opt/tivoli/tsm/client/ba/bin'
    local dsmScheduleLog='/var/log/dsmsched.log'
    local dsmErrorLog='/var/log/dsmerror.log'

    # Copy our dsm.sys and dsm.opt file to our BA Client
    if [[ ! -d $installDirectory ]]; then
        echo $vendor $product is not installed
        exit 1
    fi
    
    for file in dsm.sys dsm.opt; do
        if [[ -f $installDirectory/$file ]]; then
            mv $installDirectory/$file $installDirectory/$file.org
        fi
        echo $file
        cp ./Config/$file $installDirectory
    done

    # Configure dsm.sys and dsm.opt file
    ## Configuration TCP Settings to Storage Protect Server
    sed -i "s/SERVERNAME/$servernameStanza/g" "$installDirectory/dsm.{opt,sys}"
    sed -i "s/SERVERADDRESS/$tcpServerAddress/g" "$installDirectory/dsm.sys"
    sed -i "s/TCPPORTNO/$tcpPort/g" "$installDirectory/dsm.sys"
    
    ## Configure Log Paths
    sed -i "s/PATHTOSCHEDLOG/$dsmSchedLog/g" "$installDirectory/dsm.sys"
    sed -i "s/PATHTOERRORLOG/$dsmErrorLog/g" "$installDirectory/dsm.sys"

    ## Configure Nodename and Password Settings
    sed -i "s/NODENAME/$nodename/g" "$installDirectory/dsm.sys"

}

############################################################
# Default Installation and Upgrade                         #
############################################################
install_client()
{
    # Get Default Configuation and local varaibles to be able to install IBM Storage Protect Backup-Archive Client
    get_configuration
    local tivsm="TIVsm-BA.x86_64.rpm"

    # Check if installation file exist, if not start downloading the installation package from Repository
    if [[ ! -f $downloadDirectory/$installFilename ]]; then
        echo -e "Installation file does not exist, will automatically try to download the client"
        download_client
    fi

    # Check if the tar file has been extracted.
    if [[ ! -f $downloadDirectory/$tivsm ]]; then
        echo -e "Installation tar file has been downloaded but we need to extract the TAR file."
        tar xvf $downloadDirectory/$installFilename
    fi

    # Start installing Backup-Archive Client
    # Collect all Backup-Archive and API packages
    ba_rpm="./TIVsm-BA.x86_64.rpm ./TIVsm-API64.x86_64.rpm"
    # Get all GS-Kit Files that Backup-Archive Client depending on.
    for gsk in $(ls -b --hide="*_pd.rpm" |grep gsk); do
        ba_rpm="$ba_rpm ./$gsk"
    done
    yum install -y $ba_rpm
}

############################################################
# Download Backup-Archive Client                           #
############################################################
download_client()
{
    # Get Default Configuration to be able to download IBM Storage Protect Backup-Archive Client
    get_configuration

    # Check if download directory exist or creating it for you.
    if [ ! -d $downloadDirectory ]; then 
        mkdir $downloadDirectory
    fi

    # Downloading IBM Storage Protect Backup-Archive Client
    wget -P $downloadDirectory $fileURL
}

############################################################
############################################################
# Main program                                             #
############################################################
############################################################



############################################################
# Process the input options. Add options as needed.        #
############################################################
# Get the options
while getopts ":hcpgdi" option; do
   case $option in
        h) # display Help
            get_help
            exit;;
        p) # Print Configuration in JSON Format
            print_configuration
            exit;;  
        c) # Configure your system
            configuration
            exit;;  
        g) # get Configuration from JSON File and set them as variables (Debug only)
            get_configuration
            exit;;  
        i) # Manual Installation of Storage Protect Client
            # get_configuration
            install_client
            exit;;
        d) # Download IBM Storage Protect Backup-Archive Client
            download_client
            exit;;
        \?) # Invalid Option
            echo "Error: Invalid option, please use $0 -h for help"
            exit;;
   esac
done
