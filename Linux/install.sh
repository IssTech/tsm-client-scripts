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
   echo "This is a installation wrapper around IBM Storage Protect Backup-Archive Client."
   echo
   echo "Syntax: $0 [-h|a|i|c|d|p|P|s]"
   echo "options:"
   echo "h     Print this Help."
   echo "a     Automatic Installation and Configuation using JSON File."
   echo "i     Download and Install IBM Storage Protect."
   echo "c     Configure IBM Storage Protect Client."
   echo "d     Download IBM Storage Protect from IBM Website."
   echo "p     Print Configuration file (settings.json)."
   echo "P     Configure the Node Password."
   echo "s     Configure the IBM Storage Protect Schedule Services"
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
            newPassword=$(echo $RANDOM | md5sum | head -c 20; echo;)
            oldPassword=$staticPassword
        else 
            newPassword=$staticPassword
            oldPassword=$staticPassword
        fi

        # Set Other variables
        installDirectory='/opt/tivoli/tsm/client/ba/bin'
        dsmSchedLog='/var/log/dsmsched.log'
        dsmErrorLog='/var/log/dsmerror.log'

    else
        echo -e "Cloudn't find $settingsFile file"
    fi
}

############################################################
# Configure the bac/opt/tivoli/tsm/client/ba/bin/dsm.optkup-archive client                      #
############################################################
configuration()
{

    # Get default Configuration
    if [[ ! -n $tcpServerAddress ]]; then
        get_configuration
    fi

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
    echo Modify dsm.opt and dsm.sys
    sed -i "s/SERVERNAME/$servernameStanza/g" "$installDirectory/dsm.opt"
    sed -i "s/SERVERNAME/$servernameStanza/g" "$installDirectory/dsm.sys"
    sed -i "s/SERVERADDRESS/$tcpServerAddress/g" "$installDirectory/dsm.sys"

    sed -i "s/TCPPORTNO/$tcpPort/g" "$installDirectory/dsm.sys"

    ## Configure Log Paths
    sed -i "s#PATHTOSCHEDLOG#$dsmSchedLog#g" "$installDirectory/dsm.sys"
    
    sed -i "s#PATHTOERRORLOG#$dsmErrorLog#g" "$installDirectory/dsm.sys"

    ## Configure Nodename and Password Settings
    sed -i "s/NODENAME/$nodename/g" "$installDirectory/dsm.sys"

}

############################################################
# Set Node Password                                        #
############################################################
set_password()
{
    # Get Default Configuration to be able to download IBM Storage Protect Backup-Archive Client
    get_configuration
    echo Configure Node Password
    $installDirectory/dsmc set password $oldPassword $newPassword
}

############################################################
# Configure and start TSM Schedule Services                #
############################################################
configure_services()
{
    # Get Default Configuration to be able to download IBM Storage Protect Backup-Archive Client
    get_configuration
    echo -e "Configure the IBM Storage Protect Schedule Services (dsmcad)"
    echo -e "Running systemctl enable dsmcad --now"
    systemctl enable dsmcad --now
    
    local counter=1
    
    if [ -f $dsmSchedLog ];
     then
        rm -rf $dsmSchedLog
    fi
    
    while [ ! -f $dsmSchedLog ];
        do
            echo Waiting for $dsmSchedLog to be updated, sleep for another 10 seconds
            sleep 10
            (( counter++ ))

            if [ $counter -gt 60 ];
             then
                cat $dsmErrorLog
                echo -e "Problem to start Schedule service" > $dsmSchedLog
            fi
        done
    tail -50 $dsmSchedLog

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
        cd $downloadDirectory
        echo -e "Installation tar file has been downloaded but we need to extract the TAR file."
        tar xvf $installFilename
        cd..
    fi

    cd $downloadDirectory
    # Start installing Backup-Archive Client
    # Collect all Backup-Archive and API packages
    ba_rpm="./TIVsm-BA.x86_64.rpm ./TIVsm-API64.x86_64.rpm"
    # Get all GS-Kit Files that Backup-Archive Client depending on.
    for gsk in $(ls -b --hide="*_pd.rpm" |grep gsk); do
        ba_rpm="$ba_rpm ./$gsk"
    done
    yum install -y $ba_rpm
    cd ..
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
# Uninstall                                                #
############################################################
uninstall()
{
    
    echo -e "Uninstall Schedule Service"
    systemctl stop dsmcad 
    systemctl disable dsmcad
    
    rpm -e TIVsm-BA-8.1.20-0.x86_64
    rpm -e TIVsm-API64-8.1.20-0.x86_64

    rm -rf /opt/tivoli

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
while getopts ":hcpgdiPsau" option; do
   case $option in
        h) # display Help
            get_help
            exit;;
        p) # Print Configuration in JSON Format
            print_configuration
            exit;;  
        P) # Set Node Password
            set_password
            exit;;  
        s) # Configure Schedule Services
            configure_services
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

        u) # Uninstall IBM Storage Protect Client
            uninstall
            exit;;

        a) # Fully Automatic Installation and Configuration
            install_client
            configuration
            set_password
            configure_services
            exit;;
        \?) # Invalid Option
            echo "Error: Invalid option, please use $0 -h for help"
            exit;;
   esac
done
