#!/bin/bash

# What is my name?
SCRIPTNAME=`basename $0`

# Some defaults
AGENT_PREFIX=ac
DOWNLOAD_ARCHIVE=xlt.zip
START_PORT=8500
PASSWORD_FILE=/home/xlt/.acpass

NONE="none"

ARCHIVE_LOCATION="${1}"
TARGET_DIR="${2}"
NUMBER_OF_AC="${3}"
COMMAND="${4:-NONE}"

# HELP
if [ "$1" == "--help" ]; then
	echo "Start XLT."
	echo "  xlt-archive-file      :  Archive containing the XLT version to start"
	echo "  target-dir            :  Where to extract the archive to? This will be the working directory for XLT."
	echo "  number-of-agentctrls  :  How many agent controllers to start?"
	echo "  noremove              :  Remove old agent controller directories (if any)?"
	echo "Usage: $SCRIPTNAME <xlt-archive-file> <target-dir> <number-of-agentctlrs> [noremove]"
	exit 1
fi


# Check for at least three input parameter, stop otherwise
if [ $# -lt 3 ]; then
	echo "Incorrect command line. Please specify the archive and the number of agent-controllers to install."
	exit 1
fi


# Check existience of archive to unpack
if [ ! -e $ARCHIVE_LOCATION ]; then
	echo "$ARCHIVE_LOCATION does not exist. Aborting."
	exit 1
fi


# check target
if [ ! -d $TARGET_DIR ]; then
	echo "Target dir '$TARGET_DIR' is not existing. Aborting."
	exit 1
fi


# can we write?
touch $TARGET_DIR/test
if [ "$?" -ne "0" ]; then
	echo "Target dir '$TARGET_DIR' is not writable. Aborting."
	exit 1
fi

echo "Cleaning target dir '$TARGET_DIR'"
rm -rf $TARGET_DIR/*


# Unzipping
echo "Unzipping XLT archive..."
unzip $ARCHIVE_LOCATION -d $TARGET_DIR


# Go to target
cd $TARGET_DIR


# Removing temp if existing
echo "Removing temp dir $TEMP..."
rm -rf $TEMP


# Renaming install dir
TEMP=_$AGENT_PREFIX
echo "Renaming XLT dir..."
mv xlt-* $TEMP


# Cleaning install dir
echo "Cleaning XLT agent template..."
rm -rf $TEMP/doc
rm -rf $TEMP/samples
rm -rf $TEMP/tools
rm $TEMP/bin/*cmd


# Setting rights
echo "Setting execution rights..."
chmod a+x $TEMP/bin/*sh


# Remove all agents currently installed
if [ $COMMAND != "noremove" ]; then
	for f in `ls -d $AGENT_PREFIX*`; do
		echo "Removing $f..."
		rm -rf $f
	done
fi

PASSWORD=""
if [ -f $PASSWORD_FILE ]; then
	PASSWORD=`cat $PASSWORD_FILE`
fi
# Creating agents dirs
for (( i = 0 ; i < $NUMBER_OF_AC ; i++ )); do
	echo "Copying $TEMP to $AGENT_PREFIX$i..."
	if [ ! -d $AGENT_PREFIX$i ]; then
		mkdir $AGENT_PREFIX$i;
	fi
	cp -rp $TEMP/* $AGENT_PREFIX$i

	# ok, adjust the agentcontroller properties
	PORT=`expr $START_PORT + $i`

	sed -i "s/com.xceptance.xlt.agentcontroller.port = 8500/com.xceptance.xlt.agentcontroller.port = $PORT/g" $AGENT_PREFIX$i/config/agentcontroller.properties

	if [ -n "$PASSWORD" ]; then
		sed -i "s/^com.xceptance.xlt.agentcontroller.password = .*$/com.xceptance.xlt.agentcontroller.password = $PASSWORD/g" $AGENT_PREFIX$i/config/agentcontroller.properties
	fi
done


# Removing temp
echo "Removing temp dir $TEMP..."
rm -rf $TEMP


# Start agents
CURRENT_USER=`whoami`
echo "Kill current java processes (if any)"
killall -9 -u $CURRENT_USER java
for f in `ls -d $AGENT_PREFIX*`; do
	$f/bin/agentcontroller.sh&
done

# Return
cd -

# That's it
