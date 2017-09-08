#!/bin/bash

#
# This script updates XLT and prepares instance for image creation.
# For first parameter the XLT package file is expected. This might be a local file or URL.
#

XLT_HOME=/home/xlt
XLT_ZIP=xlt.zip
XLT_WORKDIR=/mnt/xlt
IMAGE_PREPARATION_SCRIPT_NAME=prepare-image-creation.sh
XLT_STARTUP_FILE=$XLT_HOME/.xlt-starting

TARGET_ARCHIVE=$XLT_HOME/$XLT_ZIP

function help {
	echo "update-xlt.sh [options] <xlt-archive>"
	echo "example: update-xlt.sh https://lab.xceptance.de/releases/xlt/4.7.0/xlt-4.7.0.zip"
	echo "example: update-xlt.sh -upgrade /home/foo/xlt-4.7.0.zip"
	echo ""
	echo "Options"
	echo "  -u  --upgrade        Upgrade software packages to latest version"
	echo "  -p  --prepare-image  Remove SSH keys to prepare AMI creation"
	echo "      --help           Show this menu"
	exit 1;
}

function prepareAmi {
	sudo $XLT_HOME/$IMAGE_PREPARATION_SCRIPT_NAME -f
}

# check if parameters are empty
if [ $# -lt 1 ] || [ $1 == "--help" ]; then
	help
fi

# SOURCE is last argument
SOURCE=${!#}

# set option defaults
UPGRADE=false
PREPARE_AMI=false

# read options
while [ "$1" != "" ]; do
	case ${1} in
		-u|--upgrade)
			UPGRADE=true
			;;
		-p|--prepare-image)
			PREPARE_AMI=true
			;;
		--help)
			help
			exit 0
			;;
		*)
			;;
	esac
	shift
done

# update script in XLT home
# sudo cp $0 $XLT_HOME

# update XLT archive
echo "get XLT from $SOURCE"
if [[ $SOURCE == http://* ]] || [[ $SOURCE == https://* ]]; then
	# load from URL
	echo "download ..."
	sudo curl -s -f -o $TARGET_ARCHIVE -L $SOURCE
else
	# is not a URL -> must be a file
	if [ -r "$SOURCE" ] && [ -f "$SOURCE" ]; then
		# get from file
		sudo mv $SOURCE $TARGET_ARCHIVE
	fi
fi

if [ ! -f "$TARGET_ARCHIVE" ]; then
	echo "Given parameter '$SOURCE' is neither a valid URL nor points to an existing file."
	exit 2;
fi

echo "set up rights"
sudo chown xlt:xlt $TARGET_ARCHIVE


if [ -f "$XLT_STARTUP_FILE" ]; then
	echo "Seems like XLT startup did not finish yet.. will wait until it has"
	while [ -f "$XLT_STARTUP_FILE" ]; do
		sleep 5s;
	done
fi
 
echo "stop old XLT"
sudo /etc/init.d/xlt stop
sleep 5s

echo "purge old XLT version"
sudo rm -rf $XLT_WORKDIR/*
if [ $? != 0 ]; then
	echo "Unable to purge XLT from $XLT_WORKDIR ." 
	exit 3;
fi


# update system
if [[ $UPGRADE == true ]]; then
	sudo apt-get update
	sudo DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" dist-upgrade
fi


# prepare AMI creation
if [[ $PREPARE_AMI == true ]]; then
	prepareAmi
else
	echo "Do you want to prepare AMI creation now (all SSH keys will get removed from instance)?"	
	while true; do
		read -p "Continue? [Y/n] : " yn
		case $yn in
			[Yy]|'' )
				prepareAmi
				break
				;;
			[Nn] )
				exit 0
				;;
			* )
				echo "Please answer 'y', 'Y', 'n', or 'N'. If nothing is entered the default answer is 'y'."
				;;
		esac
	done
fi

