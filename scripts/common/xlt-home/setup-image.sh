#!/bin/bash
set -e

if ! test `id -u` -eq 0 ; then
  echo "This script must be run as root"
  exit 1
fi

## first the variables
SCRIPT_DIR=`realpath -m $0/..`
INIT_SCRIPT_DIR="$(dirname $SCRIPT_DIR)/init.d"

XLT_USER="xlt"
XLT_HOME="/home/$XLT_USER"
XLT_WORKDIR="/mnt/$XLT_USER"

JAVA_HOME=/usr/lib/jvm/java-11-openjdk

IPv6_SCRIPT_NAME="ipv6tunnel"
MOUNT_SCRIPT_NAME="mountdev"
USERDATA_START_SCRIPT_NAME="userdata"
XLT_SERVICE_CONFIG="xlt.service"
XLT_INITD_SCRIPT_NAME="xlt"
XLT_START_SCRIPT_NAME="start-xlt.sh"
NTP_START_SCRIPT="ntptime"

FIREFOX_ESR_VERSION="102.0esr"
FIREFOX_ESR_DOWNLOAD_URL="https://download-installer.cdn.mozilla.net/pub/firefox/releases/${FIREFOX_ESR_VERSION}/linux-x86_64/en-US/firefox-${FIREFOX_ESR_VERSION}.tar.bz2"
FIREFOX_ESR_CHECKSUM="225b5170d80ebedb9c0477a45026f617f4e2bb4d2cd3cdfa1822f8e0c6adff49"
GECKODRIVER_VERSION="v0.31.0"
GECKODRIVER_DOWNLOAD_URL="https://github.com/mozilla/geckodriver/releases/download/${GECKODRIVER_VERSION}/geckodriver-${GECKODRIVER_VERSION}-linux64.tar.gz"

OPENJDK_DOWNLOAD_URL="https://github.com/adoptium/temurin11-binaries/releases/download/jdk-11.0.15%2B10/OpenJDK11U-jdk_x64_linux_hotspot_11.0.15_10.tar.gz"
OPENJDK_CHECKSUM="5fdb4d5a1662f0cca73fec30f99e67662350b1fa61460fa72e91eb9f66b54d0b"

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

checkInitFile $USERDATA_START_SCRIPT_NAME;
checkInitFile $XLT_INITD_SCRIPT_NAME;
checkInitFile $NTP_START_SCRIPT;

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
  jq

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

## install our OpenJDK dummy package to satisfy dependencies
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

apt-get install -y --no-install-recommends ca-certificates-java \
  && rm $JAVA_HOME/lib/security/cacerts \
  && ln -s /etc/ssl/certs/java/cacerts $JAVA_HOME/lib/security/


# Install Maven (Maven needs Java, so install it in the correct order)
DEBIAN_FRONTEND=noninteractive apt-get --no-install-recommends -y install maven


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

# Setup XLT start script
echo "Install XLT start script"
cp $SCRIPT_DIR/$XLT_START_SCRIPT_NAME $XLT_HOME
chmod 755 $XLT_HOME/$XLT_START_SCRIPT_NAME
chown xlt:xlt $XLT_HOME/$XLT_START_SCRIPT_NAME

# Setup NTP script
echo "Install NTP script"
cp $INIT_SCRIPT_DIR/$NTP_START_SCRIPT /etc/init.d/
chmod 755 /etc/init.d/$NTP_START_SCRIPT
update-rc.d $NTP_START_SCRIPT start 19 2 3 4 5 .

# Setup user data script
echo "Install UserData script"
cp $INIT_SCRIPT_DIR/$USERDATA_START_SCRIPT_NAME /etc/init.d/
chmod 755 /etc/init.d/$USERDATA_START_SCRIPT_NAME
update-rc.d $USERDATA_START_SCRIPT_NAME remove

# Setup XLT init scripts
echo "Install initial XLT start script"
update-rc.d $XLT_INITD_SCRIPT_NAME remove
cp $INIT_SCRIPT_DIR/$XLT_INITD_SCRIPT_NAME /etc/init.d/
chmod 755 /etc/init.d/$XLT_INITD_SCRIPT_NAME
if [ -d /etc/systemd ]; then
  # Remove "old" userdata.service - we have XLT service now!
  if [ -f /etc/systemd/system/userdata.service ]; then
    systemctl disable userdata.service
    rm /etc/systemd/system/userdata.service
  fi

  cp $INIT_SCRIPT_DIR/$XLT_SERVICE_CONFIG /etc/systemd/system/
  systemctl daemon-reload
  systemctl enable $XLT_SERVICE_CONFIG

else
  update-rc.d $XLT_INITD_SCRIPT_NAME defaults
fi

# Setup IPv6 script
if [ -e $INIT_SCRIPT_DIR/$IPv6_SCRIPT_NAME ]; then
  echo "Install IPv6 script"
  cp $INIT_SCRIPT_DIR/$IPv6_SCRIPT_NAME /etc/init.d/
  chmod 755 /etc/init.d/$IPv6_SCRIPT_NAME
  update-rc.d $IPv6_SCRIPT_NAME defaults
fi


## tune system limits
echo "Tune system limits"
if ! grep '^\s*\*\s*soft\s*nofile' /etc/security/limits.conf; then
  echo '*       soft    nofile  128000' >> /etc/security/limits.conf
fi
if ! grep '^\s*\*\s*hard\s*nofile' /etc/security/limits.conf; then
  echo '*       hard    nofile  128000' >> /etc/security/limits.conf
fi
if ! grep '^\s*\*\s*soft\s*nproc' /etc/security/limits.conf; then
  echo '*       soft    nproc  16000' >> /etc/security/limits.conf
  fi
if ! grep '^\s*\*\s*hard\s*nproc' /etc/security/limits.conf; then
  echo '*       hard    nproc  16000' >> /etc/security/limits.conf
fi

## tune kernel settings
if [ -d /etc/sysctl.d ]; then
  echo "Tune kernel"
  cat <<-EOF > /etc/sysctl.d/99-xlt.conf
# Enable reuse of ipv4 sockets that are in waiting state
net.ipv4.tcp_tw_reuse=1
# Widen local port range
net.ipv4.ip_local_port_range=1024 65000
EOF

fi

## secure login
echo "Secure login"
if [ "$2" = "enableRootLogin" ]
then
  echo "Enable root login"
  sed -ri 's/^\s*PermitRootLogin\s*no$/PermitRootLogin\ yes/g' /etc/ssh/sshd_config
else
  echo "Disable root login"
  sed -ri 's/^\s*PermitRootLogin\s*yes$/PermitRootLogin\ no/g' /etc/ssh/sshd_config
fi

# remove 'unattended-upgrades'
apt-get -q -y purge unattended-upgrades

# install XLT
echo "Installing XLT"
SOURCE=$1
TARGET_ARCHIVE="$XLT_HOME/xlt.zip"

if [ ! -f $SOURCE ]; then
  SOURCE="https://oss.sonatype.org/service/local/artifact/maven/redirect?r=releases&g=com.xceptance&a=xlt&e=zip&v=$SOURCE"
fi

if [[ $SOURCE == http://* ]] || [[ $SOURCE == https://* ]]; then
  # load from URL
  echo "download ..."
  curl -s -f -o $TARGET_ARCHIVE -L "$SOURCE"
else
  # is not a URL -> must be a file
  if [ -r "$SOURCE" ] && [ -f "$SOURCE" ]; then
    # get from file
    mv $SOURCE $TARGET_ARCHIVE
  fi
fi

if [ ! -f "$TARGET_ARCHIVE" ]; then
  echo "Given parameter '$SOURCE' is neither a valid URL nor points to an existing file."
  exit 2;
fi

echo "set up rights"
chown xlt:xlt $TARGET_ARCHIVE


# prepare AMI creation
echo "Remove SSH stuff ..."

[ -d /etc/ssh ] && rm /etc/ssh/ssh_host_*

# do NOT remove the authorized_keys file but just empty it
if [ -d /home/ubuntu/.ssh ]; then
  echo | tee /home/ubuntu/.ssh/authorized_keys
  if [ $? != 0 ]; then exit 4; fi
fi

# do NOT remove the authorized_keys file but just empty it
if [ -d /root/.ssh ]; then
  echo | tee /root/.ssh/authorized_keys
  if [ $? != 0 ]; then exit 4; fi
fi

# Execute post-installation script if present and executable
if [ -x "$SCRIPT_DIR/post-setup.sh" ]; then
  echo "Running post-setup"
  "$SCRIPT_DIR/post-setup.sh"
  if [ $? != 0 ]; then exit 4; fi
fi


## clean up
echo "Clean up setup files"

apt-get -y clean && apt-get -y autoremove && rm -rf /var/lib/lists/*
cd /
rm -rf $SCRIPT_DIR $INIT_SCRIPT_DIR

echo "Setup finished."
