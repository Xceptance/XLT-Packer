#!/bin/bash

function help {
	echo "prepare-image-creation.sh [options]"
	echo "Options"
	echo "  -y      Answer all questions with YES"
	echo "  --help  Show this menu"
}

function prepareAmi {
	echo "Remove ssh stuff ..."

	sudo rm /etc/ssh/ssh_host_*
	if [ $? != 0 ]; then exit 4; fi

	sudo rm /home/ubuntu/.ssh/authorized_keys
	if [ $? != 0 ]; then exit 4; fi

	sudo rm /root/.ssh/authorized_keys
	if [ $? != 0 ]; then exit 4; fi

	echo "Image creation preparation finished."
}

# set option defaults
FORCE=false

# read options
while [ "$1" != "" ]; do
  case ${1} in
	-f)
		FORCE=true
		;;
	--help)
		help
		exit 0
		;;
	*)
		help
		exit 1
		;;
  esac
  shift
done

# get user confirmation if necessary
CONFIRMED=false
if [[ $FORCE != true ]]; then
	echo "Image creation preparation."
	echo "This step includes removing of SSH keys. You'll not be able to open a"
	echo "secure shell to the CURRENT instance if you continue but this step is"
	echo "mantadory if you intend to create an AMI based on this instance."
	while true; do
		read -p "Continue? [Y/n] : " yn
		case $yn in
			[Yy]|'' )
				CONFIRMED=true
				break
				;;
			[Nn] )
				break
				;;
			* )
				echo "Please answer 'y', 'Y', 'n', or 'N'. If nothing is entered the default answer is 'y'."
				;;
		esac
	done
else
	CONFIRMED=true
fi

if [[ $CONFIRMED == true ]]; then
	prepareAmi
fi
