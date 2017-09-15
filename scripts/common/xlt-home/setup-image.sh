#!/bin/bash

## first the variables
SCRIPT_DIR=`dirname $0`
SCRIPT_DIR="$SCRIPT_DIR/../xlt-home"
INIT_SCRIPT_DIR="$SCRIPT_DIR/../init.d"

XLT_USER="xlt"
XLT_HOME="/home/$XLT_USER"

IPv6_SCRIPT_NAME="ipv6tunnel"
MOUNT_SCRIPT_NAME="mountdev"
UPDATE_SCRIPT_NAME="update-xlt.sh"
IMAGE_PREPARATION_SCRIPT_NAME="prepare-image-creation.sh"
USERDATA_START_SCRIPT_NAME="userdata"
XLT_SERVICE_CONFIG="xlt.service"
XLT_INITD_SCRIPT_NAME="xlt"
XLT_START_SCRIPT_NAME="start-xlt.sh"
XLT_VERSION=${1:-LATEST}
NTP_START_SCRIPT="ntptime"

FIREFOX_ESR_DOWNLOAD_URL="https://download.mozilla.org/?product=firefox-45.0.2esr&os=linux64"
FIREFOX_ESR_CHECKSUM="3df50fb2290244dba849b3655d14a816107625a2"
GECKODRIVER_VERSION="v0.17.0"
GECKODRIVER_DOWNLOAD_URL="https://github.com/mozilla/geckodriver/releases/download/${GECKODRIVER_VERSION}/geckodriver-${GECKODRIVER_VERSION}-linux64.tar.gz"

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

checkInitFile $USERDATA_START_SCRIPT_NAME;
checkInitFile $XLT_INITD_SCRIPT_NAME;
checkInitFile $NTP_START_SCRIPT;

## create XLT user
echo "Create XLT user"
sudo adduser --disabled-login --disabled-password $XLT_USER


## update system
echo "Update system"
# enable Oracle Java
sudo add-apt-repository -y ppa:webupd8team/java
# update available packages
sudo apt-get update
DEBIAN_FRONTEND=noninteractive sudo -E apt-get -y upgrade
# install required progs: unzip, firefox, Xvfb etc.
DEBIAN_FRONTEND=noninteractive sudo -E apt-get --no-install-recommends -y install \
	wget \
	curl \
	unzip \
	tar \
	xvfb \
	dos2unix \
	software-properties-common \
	firefox \
	ipv6calc \
	chromium-browser \
	chromium-chromedriver \
	dbus-x11 \
	jq

# install Java and automatically accept Java license
echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true | sudo /usr/bin/debconf-set-selections
DEBIAN_FRONTEND=noninteractive sudo -E apt-get install -y oracle-java8-installer oracle-java8-set-default


# Download Firefox ESR and put it into path
curl -L $FIREFOX_ESR_DOWNLOAD_URL -o /tmp/firefox.tar.bz2
echo "$FIREFOX_ESR_CHECKSUM /tmp/firefox.tar.bz2" | sha1sum -c -
sudo tar -xj -C /tmp -f /tmp/firefox.tar.bz2
sudo mv /tmp/firefox /usr/lib/firefox-esr
sudo ln -s /usr/lib/firefox-esr/firefox /usr/bin/firefox-esr
rm /tmp/firefox.tar.bz2

# Download Geckodriver from GitHub and put it into path
curl -L $GECKODRIVER_DOWNLOAD_URL -o /tmp/geckodriver-linux64.tgz
sudo tar -xz -C /usr/bin -f /tmp/geckodriver-linux64.tgz
sudo chown root:root /usr/bin/geckodriver
sudo chmod 755 /usr/bin/geckodriver

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

# set ntp script
echo "Install NTP script"
sudo cp $INIT_SCRIPT_DIR/$NTP_START_SCRIPT /etc/init.d/
sudo chmod 755 /etc/init.d/$NTP_START_SCRIPT
sudo update-rc.d $NTP_START_SCRIPT start 19 2 3 4 5 .

# user data script
echo "Install UserData script"
sudo cp $INIT_SCRIPT_DIR/$USERDATA_START_SCRIPT_NAME /etc/init.d/
sudo chmod 755 /etc/init.d/$USERDATA_START_SCRIPT_NAME
sudo update-rc.d $USERDATA_START_SCRIPT_NAME remove

# set start script
echo "Install initial XLT start script"
sudo update-rc.d $XLT_INITD_SCRIPT_NAME remove
sudo cp $INIT_SCRIPT_DIR/$XLT_INITD_SCRIPT_NAME /etc/init.d/
sudo chmod 755 /etc/init.d/$XLT_INITD_SCRIPT_NAME
if [ -d /etc/systemd ]; then
	# Remove "old" userdata.service - we have XLT service now!
	if [ -f /etc/systemd/system/userdata.service ]; then
		sudo systemctl disable userdata.service
		sudo rm /etc/systemd/system/userdata.service
	fi

	sudo cp $INIT_SCRIPT_DIR/$XLT_SERVICE_CONFIG /etc/systemd/system/
	sudo systemctl daemon-reload
	sudo systemctl enable $XLT_SERVICE_CONFIG

else
	sudo update-rc.d $XLT_INITD_SCRIPT_NAME defaults
fi

# set IPv6 script
if [ -e $INIT_SCRIPT_DIR/$IPv6_SCRIPT_NAME ]; then
	echo "Install IPv6 script"
	sudo cp $INIT_SCRIPT_DIR/$IPv6_SCRIPT_NAME /etc/init.d/
	sudo chmod 755 /etc/init.d/$IPv6_SCRIPT_NAME
	sudo update-rc.d $IPv6_SCRIPT_NAME defaults
fi


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
while true; do
	read -p "Do you want to download and install the latest version of XLT? [Y/n] : " yn
	case $yn in
		''|[yY] )
			sudo $XLT_HOME/$UPDATE_SCRIPT_NAME "https://lab.xceptance.de/nexus/service/local/artifact/maven/redirect?g=com.xceptance&a=xlt&r=public&p=zip&v=${XLT_VERSION}"
			break
			;;
		[nN] )
			echo "If you want to install XLT execute $XLT_HOME/$UPDATE_SCRIPT_NAME ."
			echo "If you intent to create an AMI don't forget to call $XLT_HOME/$IMAGE_PREPARATION_SCRIPT_NAME ."
			break
			;;
		* )
			echo "Please answer 'y', 'Y', 'n', or 'N'. If nothing is entered the default answer is 'y'."
			;;
	esac
done


## clean up
while true; do
	read -p "Do you want to clean up setup files? [Y/n] : " yn
	case $yn in
		''|[yY] )
			echo "Clean up setup files"
			cd $HOME
			sudo rm -rf $SCRIPT_DIR
			sudo rm -rf $INIT_SCRIPT_DIR
			break
			;;
		[nN] )
			break
			;;
		* )
			echo "Please answer 'y', 'Y', 'n', or 'N'. If nothing is entered the default answer is 'y'."
			;;
	esac
done

echo "Setup finished."
