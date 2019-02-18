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

FIREFOX_ESR_VERSION="60.5.1esr"
FIREFOX_ESR_DOWNLOAD_URL="https://download-installer.cdn.mozilla.net/pub/firefox/releases/${FIREFOX_ESR_VERSION}/linux-x86_64/en-US/firefox-${FIREFOX_ESR_VERSION}.tar.bz2"
FIREFOX_ESR_CHECKSUM="2d8e6cb8c1211e58631f5cb2ff73bcd30a8a28c762c649fd40e9fd7e1a3570ce"
GECKODRIVER_VERSION="v0.24.0"
GECKODRIVER_DOWNLOAD_URL="https://github.com/mozilla/geckodriver/releases/download/${GECKODRIVER_VERSION}/geckodriver-${GECKODRIVER_VERSION}-linux64.tar.gz"
CHROMEDRIVER_VERSION="2.46"
CHROMEDRIVER_DOWNLOAD_URL="https://chromedriver.storage.googleapis.com/${CHROMEDRIVER_VERSION}/chromedriver_linux64.zip"

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
  libgconf-2-4 \
  dbus-x11 \
  git \
  jq

# install OpenJDK8
DEBIAN_FRONTEND=noninteractive sudo -E apt-get install -y openjdk-8-jdk

# install Maven (Maven needs Java, so install it in the correct order)
DEBIAN_FRONTEND=noninteractive sudo -E apt-get --no-install-recommends -y install maven


# Download Firefox ESR and put it into path
curl -L $FIREFOX_ESR_DOWNLOAD_URL -o /tmp/firefox.tar.bz2
echo "$FIREFOX_ESR_CHECKSUM /tmp/firefox.tar.bz2" | sha256sum -c --status - || exit 1
sudo tar -xj -C /tmp -f /tmp/firefox.tar.bz2
[ -d /usr/lib/firefox-esr ] && sudo rm -rf /usr/lib/firefox-esr
sudo mv /tmp/firefox /usr/lib/firefox-esr
sudo ln -s /usr/lib/firefox-esr/firefox /usr/bin/firefox-esr
rm /tmp/firefox.tar.bz2

# Download Geckodriver from GitHub and put it into path
curl -L $GECKODRIVER_DOWNLOAD_URL -o /tmp/geckodriver-linux64.tgz
sudo tar -xz -C /usr/bin -f /tmp/geckodriver-linux64.tgz
sudo chown root:root /usr/bin/geckodriver
sudo chmod 755 /usr/bin/geckodriver

# Download chromedriver from Google and put it into path
curl -L $CHROMEDRIVER_DOWNLOAD_URL -o /tmp/chromedriver_linux64.zip
sudo unzip -d /usr/bin /tmp/chromedriver_linux64.zip
sudo chown root:root /usr/bin/chromedriver
sudo chmod 755 /usr/bin/chromedriver
rm /tmp/chromedriver_linux64.zip

## Clean up
sudo apt-get clean && rm -rf /var/lib/lists/*

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


## tune system limits
echo "Tune system limits"
FOUND=$(grep '^\s*\*\s*soft\s*nofile' /etc/security/limits.conf)
if [ ! $? -eq 0 ]; then
  echo '*       soft    nofile  128000' | sudo tee -a /etc/security/limits.conf >/dev/null
fi
FOUND=$(grep '^\s*\*\s*hard\s*nofile' /etc/security/limits.conf)
if [ ! $? -eq 0 ]; then
  echo '*       hard    nofile  128000' | sudo tee -a /etc/security/limits.conf >/dev/null
fi
### ... same for SystemD
if [ -f /etc/systemd/system.conf ]; then
  FOUND=$(grep '^\s*DefaultLimitNOFILE=' /etc/systemd/system.conf)
  if [ ! $? -eq 0 ]; then
    echo "DefaultLimitNOFILE=128000" | sudo tee -a /etc/systemd/system.conf >/dev/null
  fi
fi


## secure login
echo "Secure login"
sudo sed -ri 's/^\s*PermitRootLogin\s*yes$/PermitRootLogin\ no/g' /etc/ssh/sshd_config

# install XLT
echo "Installing XLT"
sudo $XLT_HOME/$UPDATE_SCRIPT_NAME "https://lab.xceptance.de/nexus/service/rest/v1/search/assets/download?group=com.xceptance&name=xlt&repository=public&maven.extension=zip&version=${XLT_VERSION}"

## clean up
echo "Clean up setup files"
cd $HOME
sudo rm -rf $SCRIPT_DIR
sudo rm -rf $INIT_SCRIPT_DIR

echo "Setup finished."
