#!/bin/bash

# What is my name?
SCRIPTNAME=`basename $0`

# Some defaults
AGENT_PREFIX=ac
DOWNLOAD_ARCHIVE=xlt.zip
START_PORT=8500
PASSWORD_FILE=/home/xlt/.acpass

ARCHIVE_LOCATION="${1}"
TARGET_DIR="${2}"
AGENT_DIR="$TARGET_DIR/ac"

function help() {
  echo "Start XLT."
  echo "  xlt-archive-file      :  Archive containing the XLT version to start"
  echo "  target-dir            :  Where to extract the archive to? This will be the working directory for XLT."
  echo "Usage: $SCRIPTNAME <xlt-archive-file> <target-dir>"
}

function err() {
  >&2 echo "FATAL: $1"
  exit 1
}


for arg in $@ ; do
  case $arg in
    --help)
      help
      exit0
      ;;
  esac
done

# Check for at least two input parameters, stop otherwise
if [ $# -lt 2 ]; then
  help
  echo ""
  err "Incorrect command line. Please specify the XLT archive and installation directory."

fi


# Check existience of archive to unpack
if [ ! -e $ARCHIVE_LOCATION ]; then
  err "$ARCHIVE_LOCATION does not exist. Aborting."
fi


# check target
if [ ! -d $TARGET_DIR ]; then
  err "Target dir '$TARGET_DIR' does not exist. Aborting."
fi


# can we write?
touch $TARGET_DIR/test
if [ "$?" -ne "0" ]; then
  err "Target dir '$TARGET_DIR' is not writable. Aborting."
fi

echo "Cleaning target dir '$TARGET_DIR'"
rm -rf $TARGET_DIR/*


# Unzipping
echo "Unzipping XLT archive..."
unzip $ARCHIVE_LOCATION \
  -x "*/doc/*" "*/samples/*" "*/tools/*" "*/etc/*" "*/bin/*.cmd" \
  -d $TARGET_DIR


# Removing temp if existing
if [ -d $AGENT_DIR ]; then
  echo "Removing old agent dir $AGENT_DIR ..."
  rm -rf $AGENT_DIR
fi

# Renaming install dir
echo "Renaming XLT dir..."
mv $TARGET_DIR/xlt-* $AGENT_DIR

# Setting rights
echo "Setting execution rights..."
chmod a+x $AGENT_DIR/bin/*.sh

PASSWORD=""
if [ -f $PASSWORD_FILE ]; then
  PASSWORD=$(< $PASSWORD_FILE)
fi

# Configure port and password
sed -i 's/com.xceptance.xlt.agentcontroller.port =.*/com.xceptance.xlt.agentcontroller.port = 8500/g' $AGENT_DIR/config/agentcontroller.properties
if [ -n "$PASSWORD" ]; then
  sed -i 's/^com.xceptance.xlt.agentcontroller.password = .*$/com.xceptance.xlt.agentcontroller.password = $PASSWORD/g' $AGENT_DIR/config/agentcontroller.properties
else
  sed -i 's/^\(com.xceptance.xlt.agentcontroller.password =.*\)$/#\1/g' $AGENT_DIR/config/agentcontroller.properties
fi


# Start agentcontroller
CURRENT_USER=`whoami`
echo "Kill current java processes (if any)"
killall -9 -u $CURRENT_USER java

echo "Starting XLT Agent Controller"
$AGENT_DIR/bin/agentcontroller.sh&

exit 0
