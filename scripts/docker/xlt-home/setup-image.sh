#!/bin/bash
set -e

## Script parameters ##

XLT_SOURCE="$1"
export ARCH="${2:-amd64}"

# Check if script is run as root user
if ! test `id -u` -eq 0 ; then
  echo "This script must be run as root"
  exit 1
fi

if [ -z "$XLT_SOURCE" ]; then
  echo "Setup script must be invoked with XLT-Version or path to XLT distribution archive as 1st argument"
  exit 1
fi

if [ "$ARCH" != "amd64" -a "$ARCH" != "arm64" ]; then
  echo "Unsupported architecture: \"$ARCH\""
  exit 1
fi

echo "Building image for architecture \"$ARCH\" ..."


## first the variables
export SCRIPT_DIR=`realpath -m $0/..`
export INIT_SCRIPT_DIR="$(dirname $SCRIPT_DIR)/init.d"

XLT_USER="xlt"
XLT_HOME="/home/$XLT_USER"
XLT_WORKDIR="/mnt/$XLT_USER"
TARGET_ARCHIVE="$XLT_HOME/xlt.zip"

JAVA_HOME=/usr/lib/jvm/java-11-openjdk-$ARCH

USERDATA_START_SCRIPT_NAME="userdata"
XLT_INITD_SCRIPT_NAME="xlt"
XLT_START_SCRIPT_NAME="start-xlt.sh"
ENTRYPOINT_SCRIPT_NAME=entrypoint.sh

GECKODRIVER_VERSION="v0.32.0"
if [ "$ARCH" == "arm64" ]; then
  GECKODRIVER_DOWNLOAD_URL="https://github.com/mozilla/geckodriver/releases/download/${GECKODRIVER_VERSION}/geckodriver-${GECKODRIVER_VERSION}-linux-aarch64.tar.gz"
else
  GECKODRIVER_DOWNLOAD_URL="https://github.com/mozilla/geckodriver/releases/download/${GECKODRIVER_VERSION}/geckodriver-${GECKODRIVER_VERSION}-linux64.tar.gz"
fi

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

checkFile $XLT_START_SCRIPT_NAME;
checkFile $ENTRYPOINT_SCRIPT_NAME

checkInitFile $USERDATA_START_SCRIPT_NAME;
checkInitFile $XLT_INITD_SCRIPT_NAME;

## create XLT user
echo "Create XLT user"
adduser --disabled-login --disabled-password --gecos "" $XLT_USER

## update system
echo "Update system"
# update available packages
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get -y upgrade

# install required packages
echo "Install additional packages"
DEBIAN_FRONTEND=noninteractive apt-get --no-install-recommends -y install \
  curl \
  unzip \
  tar \
  xvfb \
  dos2unix \
  software-properties-common \
  ipv6calc \
  firefox-esr \
  chromium \
  chromium-driver \
  libgconf-2-4 \
  dbus-x11 \
  git \
  jq \
  bzip2 \
  psmisc \
  sudo \
  openjdk-11-jdk \
  maven

# TODO: tools should be in the PATH already
# add script to set JAVA_HOME and add java tools to the PATH
cat <<-EOF > /etc/profile.d/jdk.sh
export JAVA_HOME=$JAVA_HOME
export PATH=\$PATH:\$JAVA_HOME/bin
EOF
chmod +x /etc/profile.d/jdk.sh

# TODO: still needed? there should be a fallback in the JDK.
# Set default keystore type to JKS
#sed -i -e 's/^\(keystore\.type\)=.*$/\1=JKS/' $JAVA_HOME/conf/security/java.security

# Download Geckodriver from GitHub and put it into path
echo "Install geckodriver"
curl -L $GECKODRIVER_DOWNLOAD_URL -o /tmp/geckodriver-linux64.tgz
tar -xz -C /usr/bin -f /tmp/geckodriver-linux64.tgz
chown root:root /usr/bin/geckodriver
chmod 755 /usr/bin/geckodriver
rm /tmp/geckodriver-linux64.tgz

# Setup XLT start script
echo "Install XLT start script"
cp $SCRIPT_DIR/$XLT_START_SCRIPT_NAME $XLT_HOME
chmod 755 $XLT_HOME/$XLT_START_SCRIPT_NAME
chown xlt:xlt $XLT_HOME/$XLT_START_SCRIPT_NAME

# Setup user data script
echo "Install UserData script"
cp $INIT_SCRIPT_DIR/$USERDATA_START_SCRIPT_NAME /etc/init.d/
chmod 755 /etc/init.d/$USERDATA_START_SCRIPT_NAME

# Setup XLT init script
echo "Install initial XLT start script"
cp $INIT_SCRIPT_DIR/$XLT_INITD_SCRIPT_NAME /etc/init.d/
chmod 755 /etc/init.d/$XLT_INITD_SCRIPT_NAME

# Setup container start script
echo "Install container start script"
cp $SCRIPT_DIR/$ENTRYPOINT_SCRIPT_NAME /
chmod 755 /$ENTRYPOINT_SCRIPT_NAME

# install XLT
echo "Installing XLT"

if [ ! -f $XLT_SOURCE ]; then
  XLT_SOURCE="https://oss.sonatype.org/service/local/artifact/maven/redirect?r=releases&g=com.xceptance&a=xlt&e=zip&v=$XLT_SOURCE"
fi

if [[ $XLT_SOURCE == http://* ]] || [[ $XLT_SOURCE == https://* ]]; then
  # load from URL
  echo "download ..."
  curl -s -f -o "$TARGET_ARCHIVE" -L "$XLT_SOURCE"
else
  # is not a URL -> must be a file
  if [ -r "$XLT_SOURCE" ] && [ -f "$XLT_SOURCE" ]; then
    # get from file
    mv "$XLT_SOURCE" "$TARGET_ARCHIVE"
  fi
fi

if [ ! -f "$TARGET_ARCHIVE" ]; then
  echo "Given parameter '$XLT_SOURCE' is neither a valid URL nor points to an existing file."
  exit 2;
fi

echo "Set up rights"
chown xlt:xlt "$TARGET_ARCHIVE"

# Execute post-installation script if present and executable
if [ -x "$SCRIPT_DIR/post-setup.sh" ]; then
  echo "Running post-setup"
  "$SCRIPT_DIR/post-setup.sh"
  if [ $? != 0 ]; then exit 4; fi
fi

# print version of installed tools for verification
echo "------------------------------------------------"
echo "JDK:"
java --version
echo
echo "Chromium:"
chromium --version
echo
echo "Chromedriver:"
chromedriver --version
echo
echo "Firefox:"
# TODO: complains about being run as root
#firefox --version
echo
echo "Geckodriver:"
geckodriver --version
echo "------------------------------------------------"

## clean up
echo "Clean up setup files"
DEBIAN_FRONTEND=noninteractive apt-get -y clean && apt-get -y autoremove && rm -rf /var/lib/lists/*
cd /
rm -rf "$SCRIPT_DIR" "$INIT_SCRIPT_DIR"

echo "Setup finished."
