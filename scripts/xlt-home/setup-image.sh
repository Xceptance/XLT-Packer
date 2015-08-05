#!/bin/bash

## first the variables
SCRIPT_DIR=`dirname $0`
SCRIPT_DIR="$SCRIPT_DIR/../xlt-home"
INIT_SCRIPT_DIR="$SCRIPT_DIR/../init.d"

XLT_USER="xlt"
XLT_HOME="/home/$XLT_USER"

XLT_VERSION=$1

IPv6_SCRIPT_NAME="ipv6tunnel"
MOUNT_SCRIPT_NAME="mountdev"
UPDATE_SCRIPT_NAME="update-xlt.sh"
IMAGE_PREPARATION_SCRIPT_NAME="prepare-image-creation.sh"
USERDATA_START_SCRIPT_NAME="userdata"
XLT_INITD_SCRIPT_NAME="xlt"
XLT_START_SCRIPT_NAME="start-xlt.sh"
NTP_START_SCRIPT="ntptime"

## check referenced files existance
function checkFile {
	local FILE="$SCRIPT_DIR/$1"
	if [ ! -e $FILE ]; then
		echo "Can not find $FILE"
        exit 1
    fi
}

function checkInitFile {
    local FILE="$INIT_SCRIPT_DIR/$1"
    if [ ! -e $FILE ]; then
        echo "Cannot find $FILE"
        exit 1
    fi
}

checkFile $UPDATE_SCRIPT_NAME;
checkFile $IMAGE_PREPARATION_SCRIPT_NAME;
checkFile $XLT_START_SCRIPT_NAME;

checkInitFile $IPv6_SCRIPT_NAME;
checkInitFile $MOUNT_SCRIPT_NAME;
checkInitFile $USERDATA_START_SCRIPT_NAME;
checkInitFile $XLT_INITD_SCRIPT_NAME;
checkInitFile $NTP_START_SCRIPT;

if [ -z $XLT_VERSION ]; then
        echo "No XLT version set. Using Latest."
        XLT_VERSION='LATEST'
fi

## create XLT user
echo "Create XLT user"
sudo adduser $XLT_USER


## update system
echo "Update system"
# enable Oracle Java
sudo add-apt-repository -y ppa:webupd8team/java
# update available packages
sudo apt-get update
sudo apt-get -y upgrade
# install unzip, firefox and Xvdb
sudo apt-get install -y unzip firefox Xvfb ipv6calc
# install Java and automatically accept Java license
echo oracle-java7-installer shared/accepted-oracle-license-v1-1 select true | sudo /usr/bin/debconf-set-selections
sudo apt-get install -y oracle-java7-installer
sudo apt-get install -y oracle-java7-set-default


## move scripts to their destination folder and setup permissions

# set update script
echo "Install update script"
sudo cp $SCRIPT_DIR/$UPDATE_SCRIPT_NAME $XLT_HOME
sudo chmod 755 $XLT_HOME/$UPDATE_SCRIPT_NAME
sudo chown xlt:xlt $XLT_HOME/$UPDATE_SCRIPT_NAME

# set image preparation script
echo "Install image preparation script"
sudo cp $SCRIPT_DIR/$IMAGE_PREPARATION_SCRIPT_NAME $XLT_HOME
sudo chmod 755 $XLT_HOME/$IMAGE_PREPARATION_SCRIPT_NAME
sudo chown xlt:xlt $XLT_HOME/$IMAGE_PREPARATION_SCRIPT_NAME

# setup XLT start script
echo "Install XLT start script"
sudo cp $SCRIPT_DIR/$XLT_START_SCRIPT_NAME $XLT_HOME
sudo chmod 755 $XLT_HOME/$XLT_START_SCRIPT_NAME
sudo chown xlt:xlt $XLT_HOME/$XLT_START_SCRIPT_NAME

# set mount script for temp directory
echo "Install temporary mount script"
sudo cp $INIT_SCRIPT_DIR/$MOUNT_SCRIPT_NAME /etc/init.d/
sudo chmod 755 /etc/init.d/$MOUNT_SCRIPT_NAME
# start with priority 5 in run levels 2,3,4 and 5
sudo update-rc.d $MOUNT_SCRIPT_NAME start 5 2 3 4 5 .

# set ntp script
echo "Install ntp script"
sudo cp $INIT_SCRIPT_DIR/$NTP_START_SCRIPT /etc/init.d/
sudo chmod 755 /etc/init.d/$NTP_START_SCRIPT
sudo update-rc.d $NTP_START_SCRIPT start 19 2 3 4 5 .

# user data script
sudo cp $INIT_SCRIPT_DIR/$USERDATA_START_SCRIPT_NAME /etc/init.d/
sudo chmod 755 /etc/init.d/$USERDATA_START_SCRIPT_NAME
sudo update-rc.d $USERDATA_START_SCRIPT_NAME defaults 19 21

# set IPv6 script
echo "Install IPv6 script"
sudo cp $INIT_SCRIPT_DIR/$IPv6_SCRIPT_NAME /etc/init.d/
sudo chmod 755 /etc/init.d/$IPv6_SCRIPT_NAME
sudo update-rc.d $IPv6_SCRIPT_NAME defaults 19 21

# set start script
echo "Install initial XLT start script"
sudo cp $INIT_SCRIPT_DIR/$XLT_INITD_SCRIPT_NAME /etc/init.d/
sudo chmod 755 /etc/init.d/$XLT_INITD_SCRIPT_NAME
sudo update-rc.d $XLT_INITD_SCRIPT_NAME defaults 21 19


## tune the file system
echo "Tune file system"
FOUND=$(grep '^\s*\*\s*soft\s*nofile' /etc/security/limits.conf)
if [ ! $? -eq 0 ]; then
    sudo bash -c 'echo "*       soft    nofile  128000" >> /etc/security/limits.conf'
fi
FOUND=$(grep '^\s*\*\s*hard\s*nofile' /etc/security/limits.conf)
if [ ! $? -eq 0 ]; then
    sudo bash -c 'echo "*       hard    nofile  128000" >> /etc/security/limits.conf'
fi


## secure login
echo "Secure login"
sudo sed -ri 's/^\s*PermitRootLogin\s*yes$/PermitRootLogin\ no/g' /etc/ssh/sshd_config


## install XLT

sudo $XLT_HOME/$UPDATE_SCRIPT_NAME "https://lab.xceptance.de/nexus/service/local/artifact/maven/redirect?g=com.xceptance&a=xlt&r=public&p=zip&v=$XLT_VERSION"


## clean up
echo "Clean up setup files"
sudo rm -rf $SCRIPT_DIR
sudo rm -rf $INIT_SCRIPT_DIR

echo "Setup finished."
