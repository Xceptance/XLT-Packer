#!/bin/bash
set -e

## Script parameters ##

XLT_SOURCE="$1"
ARCH="${2:-x64}"

# Check if script is run as root user
if ! test `id -u` -eq 0 ; then
  echo "This script must be run as root"
  exit 1
fi

if [ -z "$XLT_SOURCE" ]; then
  echo "Setup script must be invoked with XLT-Version or path to XLT distribution archive as 1st argument"
  exit 1
fi

if [ "$ARCH" != "x64" -a "$ARCH" != "arm64" ]; then
  echo "Unsupported architecture: \"$ARCH\""
  exit 1
fi

echo "Building image for architecture \"$ARCH\" ..."
## first the variables
SCRIPT_DIR=`realpath -m $0/..`
INIT_SCRIPT_DIR="$(dirname $SCRIPT_DIR)/init.d"

XLT_USER="xlt"
XLT_HOME="/home/$XLT_USER"
XLT_WORKDIR="/mnt/$XLT_USER"
TARGET_ARCHIVE="$XLT_HOME/xlt.zip"

JAVA_HOME=/usr/lib/jvm/java-11-openjdk

USERDATA_START_SCRIPT_NAME="userdata"
XLT_INITD_SCRIPT_NAME="xlt"
XLT_START_SCRIPT_NAME="start-xlt.sh"
ENTRYPOINT_SCRIPT_NAME=entrypoint.sh

if [ "$ARCH" == "arm64" ]; then
  # Mozilla does not provide prebuilt packages of Firefox-ESR/geckodriver for ARM -> have to install them via package manager
  OPENJDK_DOWNLOAD_URL="https://github.com/adoptium/temurin11-binaries/releases/download/jdk-11.0.16.1%2B1/OpenJDK11U-jdk_aarch64_linux_hotspot_11.0.16.1_1.tar.gz"
  OPENJDK_CHECKSUM="2b89cabf0ce1c2cedadd92b798d6e9056bc27c71a06f5ba24ede5dc9c316e3e8"
else
FIREFOX_ESR_VERSION="102.0esr"
FIREFOX_ESR_DOWNLOAD_URL="https://download-installer.cdn.mozilla.net/pub/firefox/releases/${FIREFOX_ESR_VERSION}/linux-x86_64/en-US/firefox-${FIREFOX_ESR_VERSION}.tar.bz2"
FIREFOX_ESR_CHECKSUM="225b5170d80ebedb9c0477a45026f617f4e2bb4d2cd3cdfa1822f8e0c6adff49"
GECKODRIVER_VERSION="v0.31.0"
GECKODRIVER_DOWNLOAD_URL="https://github.com/mozilla/geckodriver/releases/download/${GECKODRIVER_VERSION}/geckodriver-${GECKODRIVER_VERSION}-linux64.tar.gz"

OPENJDK_DOWNLOAD_URL="https://github.com/adoptium/temurin11-binaries/releases/download/jdk-11.0.15%2B10/OpenJDK11U-jdk_x64_linux_hotspot_11.0.15_10.tar.gz"
OPENJDK_CHECKSUM="5fdb4d5a1662f0cca73fec30f99e67662350b1fa61460fa72e91eb9f66b54d0b"
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

## helper function used to determine correct chromedriver version and its download URL
function _chromedriverUrl()
{
  local chromedriver_url="https://chromedriver.storage.googleapis.com"
  local chromium_version=`dpkg-query -s chromium-browser | sed -n 's/Version:\s*\([0-9]*\.[0-9]*\.[0-9]*\).*/\1/p'`
  local chromedriver_version=`curl -Lsf "$chromedriver_url/LATEST_RELEASE_$chromium_version"`

  if [ -z "$chromedriver_version" ]; then
    echo "Failed to determine required version of chromedriver."
    exit 1
  else
    echo "${chromedriver_url}/${chromedriver_version}/chromedriver_linux64.zip"
  fi
}

checkFile $XLT_START_SCRIPT_NAME;
checkFile openjdk-dummy_0.0.1_all.deb
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

# install required progs: unzip, firefox, Xvfb etc.
echo "Install additional packages"
DEBIAN_FRONTEND=noninteractive apt-get --no-install-recommends -y install \
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
  libgconf-2-4 \
  dbus-x11 \
  git \
  jq \
  bzip2 \
  psmisc \
  sudo

# Set chromium-browser and firefox on hold to prevent "accidental" update
DEBIAN_FRONTEND=noninteractive apt-mark hold chromium-browser firefox

# Get rid of SnapD
DEBIAN_FRONTEND=noninteractive apt-get -y purge snapd

# Install OpenJDK11
curl -Ls "$OPENJDK_DOWNLOAD_URL" -o /tmp/openjdk11.tgz
echo "$OPENJDK_CHECKSUM /tmp/openjdk11.tgz" | sha256sum -c --status - || exit 1
mkdir -p $JAVA_HOME
tar -C $JAVA_HOME --strip-components=1 --exclude=demo --exclude=legal -xzf /tmp/openjdk11.tgz
rm /tmp/openjdk11.tgz

## install our OpenJDK dummy package to satisfy dependencies of DEB packages that require Java
dpkg -i $SCRIPT_DIR/openjdk-dummy_0.0.1_all.deb
## update Java alternatives (also links system-default Java runtime binary to installed OpenJDK)
update-alternatives --install /usr/bin/java java $JAVA_HOME/bin/java 1099

cat <<-EOF > /etc/profile.d/jdk.sh
export JAVA_HOME=$JAVA_HOME
export PATH=\$PATH:\$JAVA_HOME/bin
EOF
chmod +x /etc/profile.d/jdk.sh

# Set default keystore type to JKS
sed -i -e 's/^\(keystore\.type\)=.*$/\1=JKS/' $JAVA_HOME/conf/security/java.security

# Install Root CA certs for Java
DEBIAN_FRONTEND=noninteractive apt-get --no-install-recommends install -y ca-certificates-java \
  && rm $JAVA_HOME/lib/security/cacerts \
  && ln -s /etc/ssl/certs/java/cacerts $JAVA_HOME/lib/security/

# Install Maven (Maven needs Java, so install it in the correct order)
DEBIAN_FRONTEND=noninteractive apt-get --no-install-recommends -y install maven

# Install Firefox-ESR, geckodriver, and chromedriver
if [ "$ARCH" == "arm64" ]; then
  # install via package manager as no download available
  # TODO: firefox-esr?
  echo "Install geckodriver + chromedriver via APT"
  DEBIAN_FRONTEND=noninteractive apt-get --no-install-recommends -y install \
    chromium-chromedriver \
    firefox-geckodriver
else
# Download Firefox ESR and put it into path
curl -L $FIREFOX_ESR_DOWNLOAD_URL -o /tmp/firefox.tar.bz2
echo "$FIREFOX_ESR_CHECKSUM /tmp/firefox.tar.bz2" | sha256sum -c --status - || exit 1
tar -xj -C /tmp -f /tmp/firefox.tar.bz2
[ -d /usr/lib/firefox-esr ] && rm -rf /usr/lib/firefox-esr
mv /tmp/firefox /usr/lib/firefox-esr
ln -s /usr/lib/firefox-esr/firefox /usr/bin/firefox-esr
rm /tmp/firefox.tar.bz2

# Download Geckodriver from GitHub and put it into path
echo "Install geckodriver"
curl -L $GECKODRIVER_DOWNLOAD_URL -o /tmp/geckodriver-linux64.tgz
tar -xz -C /usr/bin -f /tmp/geckodriver-linux64.tgz
chown root:root /usr/bin/geckodriver
chmod 755 /usr/bin/geckodriver
rm /tmp/geckodriver-linux64.tgz

# Download chromedriver from Google and put it into path
echo "Install chromedriver"
curl -L $(_chromedriverUrl) -o /tmp/chromedriver_linux64.zip
unzip -d /usr/bin /tmp/chromedriver_linux64.zip
chown root:root /usr/bin/chromedriver
chmod 755 /usr/bin/chromedriver
rm /tmp/chromedriver_linux64.zip
fi

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

## clean up
echo "Clean up setup files"
DEBIAN_FRONTEND=noninteractive apt-get -y clean && apt-get -y autoremove && rm -rf /var/lib/lists/*
cd /
rm -rf "$SCRIPT_DIR" "$INIT_SCRIPT_DIR"

echo "Setup finished."
